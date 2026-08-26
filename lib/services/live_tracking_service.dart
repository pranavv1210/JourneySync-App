import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rider_location.dart';
import 'ride_engine_core.dart';

/// Service responsible for:
///  - Syncing the current user's GPS position to Supabase (live_locations)
///  - Receiving all riders' live positions via Supabase Realtime
///  - Adaptive update frequency based on live speed and emergency state
///  - Auto-reconnect on channel drop
///  - Offline queue with automatic flush on reconnect
///
/// Usage:
///   final svc = LiveTrackingService();
///   final stream = svc.watchRideLocations('ride-uuid');
///   stream.listen((riders) { /* update map */ });
///
///   svc.startSyncing(rideId: ..., userId: ..., userName: ..., ...);
///   // on dispose:
///   await svc.dispose();
class LiveTrackingService {
  LiveTrackingService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Stream ──────────────────────────────────────────────────────────────────
  final StreamController<List<RiderLocation>> _streamController =
      StreamController<List<RiderLocation>>.broadcast();

  final Map<String, RiderLocation> _locationCache = {};

  /// Profile photo URL per rider id; an empty string means "looked up, has no
  /// photo". Static so every screen in a session shares one lookup.
  ///
  /// `live_locations` denormalises `user_name` and `bike_name` but carries no
  /// avatar, so without this the map can only ever draw a rider's initial.
  static final Map<String, String> _avatarUrls = <String, String>{};

  /// Guards against firing a second profile lookup while one is in flight, and
  /// against retrying a failed one on every realtime tick.
  static bool _avatarFetchInFlight = false;
  static DateTime? _avatarFetchFailedAt;
  static const Duration _avatarRetryCooldown = Duration(seconds: 30);

  /// Set when the deployment has no `profiles.avatar_url` column at all, which
  /// no amount of retrying will fix. Older installs are in this state until the
  /// migration runs, and they should fall back to initials quietly.
  static bool _avatarColumnMissing = false;

  /// The current ride being watched.
  String? _watchedRideId;

  /// Realtime channel for incoming location updates.
  RealtimeChannel? _locationChannel;

  /// Auto-reconnect timer.
  Timer? _reconnectTimer;
  bool _isChannelActive = false;

  /// Whether the realtime channel is currently subscribed.
  bool get isChannelActive => _isChannelActive;

  // ── Sync state ───────────────────────────────────────────────────────────────
  /// Active position subscription from geolocator.
  StreamSubscription<Position>? _positionSubscription;

  /// Periodic sync timer — drives the 4 s / 10 s adaptive upload.
  Timer? _syncTimer;

  /// Latest GPS position captured by the stream.
  Position? _latestPosition;

  /// Ride context used during syncing.
  String? _syncRideId;
  String? _syncUserId;
  String? _syncUserName;
  String? _syncBikeName;
  bool _syncIsLeader = false;
  bool _emergencySync = false;
  Position? _lastSyncedPosition;

  /// Battery level accessor (injected so tests can override).
  Future<int?> Function()? batteryLevelProvider;

  // ── Android channels ────────────────────────────────────────────────────────
  static const _kFgChannel = MethodChannel(
    'com.example.journeysync/foreground_service',
  );
  // Wake lock channel — reserved for Android background persistence.
  // ignore: unused_field
  static const _kWakeLockChannel = MethodChannel(
    'com.example.journeysync/wake_lock',
  );

  // ── Offline queue ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _offlineQueue = [];
  static const int _maxQueueSize = 200;
  static const String _offlineQueuePrefix = 'liveTrackingOfflineQueue';

  /// Whether the last sync attempt failed (offline state).
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _kFgChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (error) {
      debugPrint('[LiveTracking] Battery optimization check failed: $error');
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _kFgChannel.invokeMethod<bool>('openBatteryOptimizationSettings');
    } catch (error) {
      debugPrint('[LiveTracking] Battery optimization settings failed: $error');
    }
  }

  // ── Adaptive interval ─────────────────────────────────────────────────────
  static const double _stationaryThresholdMps = 1.0; // < 1 m/s = stationary

  int _stationaryCount = 0;
  static const int _idleCountToSwitch = 6;

  Duration get _currentSyncInterval {
    final latestSpeed = _latestPosition?.speed;
    return RideEngineCore.syncIntervalFor(
      speedMps: latestSpeed != null && latestSpeed >= 0 ? latestSpeed : 0,
      emergency: _emergencySync,
      stationarySamples: _stationaryCount,
    );
  }

  // ── Watch ─────────────────────────────────────────────────────────────────

  /// Returns a broadcast stream of all riders' live locations for [rideId].
  /// Immediately emits cached data if available, then streams realtime updates.
  Stream<List<RiderLocation>> watchRideLocations(String rideId) {
    if (_watchedRideId == rideId && !_streamController.isClosed) {
      return _streamController.stream;
    }

    _watchedRideId = rideId;
    _locationCache.clear();
    _disconnectLocationChannel();

    // Load initial snapshot, then subscribe.
    _primeLocationCache(
      rideId,
    ).then((_) => _subscribeToLocationChannel(rideId));

    return _streamController.stream;
  }

  Future<void> _primeLocationCache(String rideId) async {
    try {
      final rows = await _client
          .from('live_locations')
          .select()
          .eq('ride_id', rideId)
          .order('updated_at');
      for (final row in rows) {
        final loc = _parseRow(Map<String, dynamic>.from(row));
        if (loc != null) _locationCache[loc.userId] = loc;
      }
      _emit();
      unawaited(_hydrateAvatars());
    } catch (e) {
      debugPrint('[LiveTracking] prime failed: $e');
      _emit(); // emit empty list so UI doesn't hang
    }
  }

  void _subscribeToLocationChannel(String rideId) {
    _disconnectLocationChannel();

    _locationChannel = _client.channel('live_tracking:$rideId');
    _locationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            final record =
                payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord;
            final loc = _parseRow(Map<String, dynamic>.from(record));
            if (loc == null) return;

            if (payload.eventType == PostgresChangeEvent.delete) {
              _locationCache.remove(loc.userId);
            } else {
              _locationCache[loc.userId] = loc;
            }
            _emit();
            // A rider who just appeared needs their photo looked up; riders
            // already known are skipped inside the hydrator.
            unawaited(_hydrateAvatars());
          },
        )
        .subscribe((status, [error]) {
          _isChannelActive = status == RealtimeSubscribeStatus.subscribed;
          if (error != null) {
            debugPrint('[LiveTracking] channel error: $error');
            _scheduleReconnect(rideId);
          }
        });
  }

  void _disconnectLocationChannel() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _locationChannel?.unsubscribe();
    _locationChannel = null;
    _isChannelActive = false;
  }

  void _scheduleReconnect(String rideId) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_watchedRideId == rideId && !_streamController.isClosed) {
        debugPrint('[LiveTracking] Reconnecting channel for ride $rideId…');
        _subscribeToLocationChannel(rideId);
      }
    });
  }

  void _emit() {
    if (_streamController.isClosed) return;
    final sorted =
        _locationCache.values.toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    _streamController.add(sorted);
  }

  /// Looks up profile photos for any rider whose photo is not known yet, then
  /// re-emits so the map can swap initials for real faces.
  ///
  /// One batched query covers every unknown rider. Failures are not cached as
  /// "no photo" - that would make a transient outage permanent - but they do
  /// start a short cooldown so a broken lookup is not retried on every incoming
  /// location update. A deployment with no avatar column stops being asked at
  /// all.
  Future<void> _hydrateAvatars() async {
    if (_avatarFetchInFlight || _avatarColumnMissing) return;

    final failedAt = _avatarFetchFailedAt;
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _avatarRetryCooldown) {
      return;
    }

    final missing = _locationCache.keys
        .where((id) => id.isNotEmpty && !_avatarUrls.containsKey(id))
        .toSet()
        .toList(growable: false);
    if (missing.isEmpty) return;

    _avatarFetchInFlight = true;
    try {
      final rows = await _client
          .from('profiles')
          .select('id,avatar_url')
          .inFilter('id', missing);

      for (final row in rows) {
        final id = (row['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        _avatarUrls[id] = (row['avatar_url'] ?? '').toString().trim();
      }
      // Riders with no profile row still count as resolved, so they are not
      // looked up again for the rest of the session.
      for (final id in missing) {
        _avatarUrls.putIfAbsent(id, () => '');
      }
      _avatarFetchFailedAt = null;
    } catch (e) {
      debugPrint('[LiveTracking] avatar lookup failed: $e');
      // A column that does not exist will not appear on the next tick either,
      // so stop asking. Anything else - offline, timeout, a transient 5xx - is
      // worth retrying once the cooldown passes, and must not be recorded as
      // "this rider has no photo".
      if (e is PostgrestException && _isMissingAvatarColumn(e)) {
        _avatarColumnMissing = true;
      } else {
        _avatarFetchFailedAt = DateTime.now();
      }
      return;
    } finally {
      _avatarFetchInFlight = false;
    }

    var changed = false;
    for (final entry in _locationCache.entries.toList()) {
      final url = _avatarUrls[entry.key];
      if (url == null || url.isEmpty) continue;
      if (entry.value.avatarUrl == url) continue;
      _locationCache[entry.key] = entry.value.copyWith(avatarUrl: url);
      changed = true;
    }
    if (changed) _emit();
  }

  /// True when the failure is "there is no avatar_url column", rather than a
  /// problem that might resolve itself. 42703 is Postgres' undefined column;
  /// PGRST204 is PostgREST failing to find it in its schema cache.
  ///
  /// Mirrors the same check in ride_lobby_screen, which covers installs whose
  /// profiles table predates the avatar migration.
  bool _isMissingAvatarColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('avatar_url');
  }

  // ── Sync (outbound) ────────────────────────────────────────────────────────

  /// Manually syncs a specific location to the Supabase database.
  Future<void> syncLocation({
    required String rideId,
    required String userId,
    required Position position,
    String? battery,
    String? signal,
  }) async {
    if (!RideEngineCore.shouldSyncLocation(
      current: position,
      previous: _lastSyncedPosition,
      emergency: _emergencySync,
    )) {
      return;
    }
    final payload = <String, dynamic>{
      'ride_id': rideId.trim(),
      'profile_id': userId.trim(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': position.heading >= 0 ? position.heading : null,
      'speed': position.speed >= 0 ? position.speed : null,
      'speed_mps': position.speed >= 0 ? position.speed : null,
      'battery': battery,
      'signal': signal,
      'user_name': _syncUserName ?? 'Rider',
      'bike_name': _syncBikeName ?? 'No bike added',
      'is_leader': _syncIsLeader,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client
        .from('live_locations')
        .upsert(payload, onConflict: 'ride_id,profile_id');
    _lastSyncedPosition = position;
  }

  /// Starts continuous GPS capture + periodic Supabase sync.
  ///
  /// Call this once when entering Ride Mode. The service handles everything:
  /// position streaming, adaptive interval, offline queue.
  Future<void> startSyncing({
    required String rideId,
    required String userId,
    required String userName,
    required String bikeName,
    required bool isLeader,
  }) async {
    _syncRideId = rideId;
    _syncUserId = userId;
    _syncUserName = userName;
    _syncBikeName = bikeName;
    _syncIsLeader = isLeader;
    await _restoreOfflineQueue();

    // Ensure permission before starting.
    final ok = await _ensureLocationPermission();
    if (!ok) {
      debugPrint(
        '[LiveTracking] Location permission denied — cannot start sync',
      );
      return;
    }

    // Cancel any existing streams.
    await _positionSubscription?.cancel();
    _syncTimer?.cancel();

    // Start Android foreground service to keep GPS alive in background.
    if (Platform.isAndroid) {
      try {
        await _kFgChannel.invokeMethod<bool>('startLocationService');
      } catch (e) {
        debugPrint('[LiveTracking] Could not start foreground service: $e');
      }
    }

    // GPS stream — captures position for later upload.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen(
      (position) {
        _latestPosition = position;
        _updateStationaryCounter(position);
        _rescheduleAdaptiveTimer();
      },
      onError: (e) {
        debugPrint('[LiveTracking] GPS stream error: $e');
      },
    );

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _latestPosition = initial;
      _updateStationaryCounter(initial);
      await _uploadPosition();
    } catch (e) {
      debugPrint('[LiveTracking] Initial GPS sync unavailable: $e');
    }

    // Start the initial sync timer.
    _scheduleSyncTimer();
  }

  void _updateStationaryCounter(Position pos) {
    final speed = pos.speed >= 0 ? pos.speed : 0.0;
    if (speed < _stationaryThresholdMps) {
      _stationaryCount = math.min(_stationaryCount + 1, _idleCountToSwitch + 1);
    } else {
      _stationaryCount = 0; // reset immediately on movement
    }
  }

  void _rescheduleAdaptiveTimer() {
    // Only reschedule if the interval has changed to avoid unnecessary work.
    final wasStationary = _syncTimer?.isActive == true;
    if (!wasStationary) return;
    // Simply let the current timer expire and _scheduleSyncTimer will pick the
    // correct interval on next fire. No action needed here for smoothness.
  }

  void _scheduleSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer(_currentSyncInterval, () async {
      await _uploadPosition();
      if (_syncRideId != null) _scheduleSyncTimer(); // reschedule adaptively
    });
  }

  Future<void> _uploadPosition() async {
    if (_latestPosition == null || _syncRideId == null || _syncUserId == null) {
      return;
    }

    final pos = _latestPosition!;
    if (!RideEngineCore.shouldSyncLocation(
      current: pos,
      previous: _lastSyncedPosition,
      emergency: _emergencySync,
    )) {
      return;
    }

    final battery = await _getBatteryLevel();

    final payload = <String, dynamic>{
      'ride_id': _syncRideId,
      'profile_id': _syncUserId,
      'user_name': _syncUserName ?? 'Rider',
      'bike_name': _syncBikeName ?? 'No bike added',
      'is_leader': _syncIsLeader,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'heading': pos.heading >= 0 ? pos.heading : null,
      'speed': pos.speed >= 0 ? pos.speed : null,
      'speed_mps': pos.speed >= 0 ? pos.speed : null, // backward compat
      'battery': battery,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client
          .from('live_locations')
          .upsert(payload, onConflict: 'ride_id,profile_id');
      _lastSyncedPosition = pos;
      if (_isOffline) {
        _isOffline = false;
        debugPrint('[LiveTracking] Back online — flushing offline queue');
        unawaited(_flushOfflineQueue());
      }
    } catch (e) {
      debugPrint('[LiveTracking] Upload failed (offline?): $e');
      _isOffline = true;
      _enqueueOffline(payload);
    }
  }

  void _enqueueOffline(Map<String, dynamic> payload) {
    _mergeQueuedPayload(payload);
    if (_offlineQueue.length > _maxQueueSize) {
      _offlineQueue.removeRange(0, _offlineQueue.length - _maxQueueSize);
    }
    unawaited(_persistOfflineQueue());
  }

  void _mergeQueuedPayload(Map<String, dynamic> payload) {
    final profileId = (payload['profile_id'] ?? '').toString();
    final timestamp = DateTime.tryParse(
      (payload['updated_at'] ?? '').toString(),
    );

    if (_emergencySync || profileId.isEmpty || timestamp == null) {
      _offlineQueue.add(payload);
      return;
    }

    for (var i = _offlineQueue.length - 1; i >= 0; i--) {
      final queued = _offlineQueue[i];
      if ((queued['profile_id'] ?? '').toString() != profileId) continue;
      final queuedTime = DateTime.tryParse(
        (queued['updated_at'] ?? '').toString(),
      );
      if (queuedTime == null ||
          timestamp.difference(queuedTime).abs() < const Duration(seconds: 2)) {
        _offlineQueue[i] = payload;
        return;
      }
      break;
    }
    _offlineQueue.add(payload);
  }

  Future<void> _flushOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_offlineQueue)..sort((a, b) {
      final at =
          DateTime.tryParse((a['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt =
          DateTime.tryParse((b['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    _offlineQueue.clear();
    await _persistOfflineQueue();

    for (final payload in batch) {
      try {
        await _client
            .from('live_locations')
            .upsert(payload, onConflict: 'ride_id,profile_id');
        await _persistOfflineQueue();
      } catch (e) {
        debugPrint('[LiveTracking] Flush failed: $e');
        _enqueueOffline(payload); // put back
        break; // stop if still offline
      }
    }
  }

  // ── Leader update ──────────────────────────────────────────────────────────

  Future<void> _restoreOfflineQueue() async {
    final key = _offlineQueueKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _offlineQueue
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .take(_maxQueueSize),
        );
    } catch (error) {
      debugPrint('[LiveTracking] Queue restore failed: $error');
    }
  }

  Future<void> _persistOfflineQueue() async {
    final key = _offlineQueueKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_offlineQueue.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(_offlineQueue));
      }
    } catch (error) {
      debugPrint('[LiveTracking] Queue persist failed: $error');
    }
  }

  String? get _offlineQueueKey {
    final rideId = _syncRideId?.trim();
    final userId = _syncUserId?.trim();
    if (rideId == null || rideId.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }
    return '$_offlineQueuePrefix:$rideId:$userId';
  }

  /// Call this when the user's leader status changes (e.g. leader handed off).
  void updateLeaderStatus(bool isLeader) {
    _syncIsLeader = isLeader;
  }

  void setEmergencySync(bool enabled) {
    if (_emergencySync == enabled) return;
    _emergencySync = enabled;
    if (_syncRideId != null) {
      _scheduleSyncTimer();
      unawaited(_uploadPosition());
    }
  }

  // ── Clear on ride end ──────────────────────────────────────────────────────

  /// Removes this user's location from the live_locations table and cleans up
  /// their active_ride_id in the users table.
  Future<void> clearLiveLocation({
    required String rideId,
    required String userId,
  }) async {
    try {
      await _client
          .from('live_locations')
          .delete()
          .eq('ride_id', rideId)
          .eq('profile_id', userId);
    } catch (_) {}
    try {
      await _client
          .from('profiles')
          .update({'active_ride_id': null})
          .eq('id', userId);
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<String?> _getBatteryLevel() async {
    if (batteryLevelProvider != null) {
      final level = await batteryLevelProvider!();
      return level != null ? '$level%' : null;
    }
    return null; // battery read handled by caller if needed
  }

  RiderLocation? _parseRow(Map<String, dynamic> row) {
    final userId =
        (row['profile_id'] ?? row['user_id'] ?? '').toString().trim();
    final rideId = (row['ride_id'] ?? '').toString().trim();
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    final updatedAt = DateTime.tryParse((row['updated_at'] ?? '').toString());

    if (userId.isEmpty ||
        rideId.isEmpty ||
        lat == null ||
        lng == null ||
        updatedAt == null) {
      return null;
    }

    // Support both 'speed' and legacy 'speed_mps' column names.
    final speed =
        (row['speed'] as num?)?.toDouble() ??
        (row['speed_mps'] as num?)?.toDouble();

    // The row wins if a future migration denormalises the photo onto
    // live_locations; until then it comes from the profile lookup cache.
    final rowAvatar = (row['avatar_url'] ?? '').toString().trim();
    final avatarUrl = rowAvatar.isNotEmpty ? rowAvatar : _avatarUrls[userId];

    return RiderLocation(
      userId: userId,
      rideId: rideId,
      latitude: lat,
      longitude: lng,
      updatedAt: updatedAt,
      userName: (row['user_name'] ?? 'Rider').toString().trim(),
      bikeName: (row['bike_name'] ?? 'No bike added').toString().trim(),
      isLeader: (row['is_leader'] as bool?) ?? false,
      heading: (row['heading'] as num?)?.toDouble(),
      speed: speed != null && speed >= 0 ? speed : null,
      battery:
          (row['battery'] ?? '').toString().trim().isEmpty
              ? null
              : row['battery'].toString().trim(),
      signal:
          (row['signal'] ?? '').toString().trim().isEmpty
              ? null
              : row['signal'].toString().trim(),
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
    );
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> stopSyncing() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _latestPosition = null;
    _lastSyncedPosition = null;
    _syncRideId = null;
    _syncUserId = null;
    _stationaryCount = 0;
    _emergencySync = false;

    // Stop Android foreground service when ride ends.
    if (Platform.isAndroid) {
      try {
        await _kFgChannel.invokeMethod<bool>('stopLocationService');
      } catch (e) {
        debugPrint('[LiveTracking] Could not stop foreground service: $e');
      }
    }
  }

  Future<void> dispose() async {
    await stopSyncing();
    _disconnectLocationChannel();
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }
}

/// Fire-and-forget helper (suppresses the unawaited future lint).
void unawaited(Future<void> future) {
  future.ignore();
}
