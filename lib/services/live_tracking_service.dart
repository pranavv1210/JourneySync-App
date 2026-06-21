import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rider_location.dart';

/// Service responsible for:
///  - Syncing the current user's GPS position to Supabase (live_locations)
///  - Receiving all riders' live positions via Supabase Realtime
///  - Adaptive update frequency (4 s moving, 10 s stationary)
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

  /// Battery level accessor (injected so tests can override).
  Future<int?> Function()? batteryLevelProvider;

  // ── Android foreground service channel ──────────────────────────────────────
  static const _kFgChannel = MethodChannel(
    'com.example.journeysync/foreground_service',
  );

  // ── Offline queue ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _offlineQueue = [];
  static const int _maxQueueSize = 50;

  /// Whether the last sync attempt failed (offline state).
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  // ── Adaptive interval ─────────────────────────────────────────────────────
  static const Duration _movingInterval = Duration(seconds: 4);
  static const Duration _stationaryInterval = Duration(seconds: 10);
  static const double _stationaryThresholdMps = 1.0; // < 1 m/s = stationary

  int _stationaryCount = 0;
  static const int _stationaryCountToSwitch = 2;

  Duration get _currentSyncInterval =>
      _stationaryCount >= _stationaryCountToSwitch
          ? _stationaryInterval
          : _movingInterval;

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

  // ── Sync (outbound) ────────────────────────────────────────────────────────

  /// Manually syncs a specific location to the Supabase database.
  Future<void> syncLocation({
    required String rideId,
    required String userId,
    required Position position,
    String? battery,
    String? signal,
  }) async {
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
    await _client.from('live_locations').upsert(payload);
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
        distanceFilter: 5, // don't fire unless moved 5 m
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

    // Start the initial sync timer.
    _scheduleSyncTimer();
  }

  void _updateStationaryCounter(Position pos) {
    final speed = pos.speed >= 0 ? pos.speed : 0.0;
    if (speed < _stationaryThresholdMps) {
      _stationaryCount = math.min(
        _stationaryCount + 1,
        _stationaryCountToSwitch + 1,
      );
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
      await _client.from('live_locations').upsert(payload);
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
    _offlineQueue.add(payload);
    if (_offlineQueue.length > _maxQueueSize) {
      // Keep only the most recent entries
      _offlineQueue.removeRange(0, _offlineQueue.length - _maxQueueSize);
    }
  }

  Future<void> _flushOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final payload in batch) {
      try {
        // Only send the latest payload for each rider to avoid spamming.
        await _client.from('live_locations').upsert(payload);
      } catch (e) {
        debugPrint('[LiveTracking] Flush failed: $e');
        _enqueueOffline(payload); // put back
        break; // stop if still offline
      }
    }
  }

  // ── Leader update ──────────────────────────────────────────────────────────

  /// Call this when the user's leader status changes (e.g. leader handed off).
  void updateLeaderStatus(bool isLeader) {
    _syncIsLeader = isLeader;
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
    );
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> stopSyncing() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _latestPosition = null;
    _syncRideId = null;
    _syncUserId = null;
    _stationaryCount = 0;

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
