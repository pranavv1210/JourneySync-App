import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/presence_info.dart';
import '../models/ride_member.dart';
import '../models/ride_record.dart';
import '../models/ride_route.dart';
import '../services/notification_service.dart';
import '../services/ride_service.dart';
import 'notification_coordinator.dart';

/// Central realtime coordinator — the single source of truth for all
/// real-time state in JourneySync.
///
/// Responsibilities:
/// - Supabase Realtime channels (rides, members, routes, alerts, presence)
/// - Ride radar with automatic refresh and distance filtering
/// - SOS alert propagation
/// - Route change notifications
/// - Member join/leave synchronization
/// - Presence system (online/offline/tracking/idle/background/sos)
/// - Connection state management
/// - Auto-reconnect with exponential backoff
/// - Ride lifecycle notifications (started, ended)
///
/// Singleton — use [instance].
class RealtimeCoordinator extends ChangeNotifier {
  RealtimeCoordinator._()
    : _client = Supabase.instance.client,
      _rideService = RideService(),
      _notificationService = NotificationService.instance,
      _notificationCoordinator = NotificationCoordinator.instance,
      _connectivity = Connectivity();

  static final RealtimeCoordinator instance = RealtimeCoordinator._();

  // ── Dependencies ───────────────────────────────────────────────────────────
  final SupabaseClient _client;
  final RideService _rideService;
  final NotificationService _notificationService;
  final NotificationCoordinator _notificationCoordinator;
  final Connectivity _connectivity;

  // ── Connection state ───────────────────────────────────────────────────────
  RealtimeConnectionState _connectionState =
      RealtimeConnectionState.disconnected;
  RealtimeConnectionState get connectionState => _connectionState;

  // ── Radar state ────────────────────────────────────────────────────────────
  final List<RadarRide> _radarRides = <RadarRide>[];
  bool _radarLoading = false;
  String _radarError = '';
  double? _originLat;
  double? _originLng;
  double _radarRadiusKm = 25;
  String _radarProfileId = '';

  bool get radarLoading => _radarLoading;
  String get radarError => _radarError;
  List<RadarRide> get radarRides => List.unmodifiable(_radarRides);

  // ── Ride session state ─────────────────────────────────────────────────────
  String _activeRideId = '';
  String _activeProfileId = '';
  List<RideMember> _members = const <RideMember>[];
  RideRoute? _route;
  Map<String, dynamic>? _lastAlert;

  List<RideMember> get members => List.unmodifiable(_members);
  RideRoute? get route => _route;
  Map<String, dynamic>? get lastAlert => _lastAlert;

  // ── Presence state ─────────────────────────────────────────────────────────
  final Map<String, PresenceInfo> _presenceMap = <String, PresenceInfo>{};
  List<PresenceInfo> get presenceList =>
      _presenceMap.values.toList(growable: false);
  PresenceInfo? presenceFor(String profileId) => _presenceMap[profileId.trim()];

  // ── Callbacks ──────────────────────────────────────────────────────────────
  VoidCallback? _onRouteChanged;
  ValueChanged<Map<String, dynamic>>? _onAlert;
  ValueChanged<List<RideMember>>? _onMembersChanged;

  // ── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  RealtimeChannel? _radarRideChannel;
  RealtimeChannel? _radarMemberChannel;
  RealtimeChannel? _rideMemberChannel;
  RealtimeChannel? _rideRouteChannel;
  RealtimeChannel? _rideAlertChannel;
  RealtimeChannel? _presenceChannel;
  Timer? _radarRefreshDebounce;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  // ── Ride lifecycle tracking ────────────────────────────────────────────────
  final Set<String> _seenRideIds = <String>{};

  // =============================================================================
  // PUBLIC API
  // =============================================================================

  Future<void> start() async {
    if (_connectivitySub != null) return;

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty ||
          results.every((item) => item == ConnectivityResult.none);
      _setConnectionState(
        offline
            ? RealtimeConnectionState.offline
            : RealtimeConnectionState.reconnecting,
      );
      if (!offline) {
        _reconnectAttempts = 0;
        _debouncedRadarRefresh();
        if (_activeRideId.isNotEmpty) {
          unawaited(_refreshRideSession());
          _resubscribeRideSessionChannels();
        }
        if (_radarProfileId.isNotEmpty) {
          _resubscribeRadarChannels();
        }
        _resubscribePresence();
      }
    });
  }

  /// Starts the ride radar for the given [profileId].
  Future<void> startRideRadar({
    required String profileId,
    double radiusKm = 25,
    bool requestPermissionIfNeeded = true,
  }) async {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty) return;

    await start();
    _radarProfileId = normalizedProfileId;
    _radarRadiusKm = radiusKm;
    _radarRides.clear();
    _setConnectionState(RealtimeConnectionState.connecting);

    await _resolveRadarOrigin(requestPermissionIfNeeded);
    await _refreshRadar();
    _subscribeRadarChannels();
  }

  Future<void> stopRideRadar() async {
    await _radarRideChannel?.unsubscribe();
    await _radarMemberChannel?.unsubscribe();
    _radarRideChannel = null;
    _radarMemberChannel = null;
    _radarRides.clear();
    _radarProfileId = '';
    notifyListeners();
  }

  /// Starts listening for real-time ride session events.
  Future<void> startRideSession({
    required String rideId,
    required String profileId,
    ValueChanged<Map<String, dynamic>>? onAlert,
    VoidCallback? onRouteChanged,
    ValueChanged<List<RideMember>>? onMembersChanged,
  }) async {
    final normalizedRideId = rideId.trim();
    final normalizedProfileId = profileId.trim();
    if (normalizedRideId.isEmpty || normalizedProfileId.isEmpty) return;

    await start();

    // If already on this ride, just update callbacks.
    if (_activeRideId == normalizedRideId &&
        _activeProfileId == normalizedProfileId) {
      _onAlert = onAlert;
      _onRouteChanged = onRouteChanged;
      _onMembersChanged = onMembersChanged;
      return;
    }

    await stopRideSession();
    _activeRideId = normalizedRideId;
    _activeProfileId = normalizedProfileId;
    _onAlert = onAlert;
    _onRouteChanged = onRouteChanged;
    _onMembersChanged = onMembersChanged;
    _setConnectionState(RealtimeConnectionState.connecting);

    await _refreshRideSession();
    _subscribeRideSessionChannels(normalizedRideId);
  }

  Future<void> stopRideSession() async {
    await _rideMemberChannel?.unsubscribe();
    await _rideRouteChannel?.unsubscribe();
    await _rideAlertChannel?.unsubscribe();
    _rideMemberChannel = null;
    _rideRouteChannel = null;
    _rideAlertChannel = null;
    _activeRideId = '';
    _activeProfileId = '';
    _members = const <RideMember>[];
    _route = null;
    _lastAlert = null;
    _onAlert = null;
    _onRouteChanged = null;
    _onMembersChanged = null;
    notifyListeners();
  }

  /// Fires an SOS alert for the given ride.
  Future<void> triggerSOS({
    required String rideId,
    required String profileId,
    required String profileName,
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{
      'ride_id': rideId.trim(),
      'profile_id': profileId.trim(),
      'user_name': profileName.trim().isEmpty ? 'Rider' : profileName.trim(),
      'type': 'sos',
      'message': 'SOS alert triggered',
      'latitude': latitude,
      'longitude': longitude,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _client.from('ride_alerts').insert(payload);
    await _notificationCoordinator.persist(
      profileId: profileId,
      title: 'SOS alert sent',
      body: 'Emergency alert is live for your ride.',
      category: AppNotificationCategory.sos,
      rideId: rideId,
      data: payload,
    );
    await _notificationService.showLocal(
      title: 'SOS alert sent',
      body: 'Emergency alert is live for your ride.',
    );
  }

  /// Get presence status for a specific profile (legacy compatibility).
  RiderPresenceStatus legacyPresenceFor(String profileId) {
    final normalized = profileId.trim();
    if (normalized.isEmpty) return RiderPresenceStatus.offline;
    final presence = _presenceMap[normalized];
    if (presence != null) return presence.status;
    if (_lastAlert != null &&
        (_lastAlert!['profile_id'] ?? _lastAlert!['user_id'] ?? '') ==
            normalized) {
      return RiderPresenceStatus.sos;
    }
    return RiderPresenceStatus.online;
  }

  // =============================================================================
  // RADAR
  // =============================================================================

  void _subscribeRadarChannels() {
    _radarRideChannel?.unsubscribe();
    _radarMemberChannel?.unsubscribe();

    _radarRideChannel = _client.channel('radar:rides');
    _radarRideChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          callback: (payload) {
            _handleRideChange(payload);
            _debouncedRadarRefresh();
          },
        )
        .subscribe((status, [error]) {
          if (error != null) debugPrint('[Realtime] radar rides error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _setConnectionState(RealtimeConnectionState.connected);
          }
        });

    _radarMemberChannel = _client.channel('radar:members');
    _radarMemberChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_members',
          callback: (_) => _debouncedRadarRefresh(),
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[Realtime] radar members error: $error');
          }
        });
  }

  void _resubscribeRadarChannels() {
    if (_radarProfileId.isEmpty) return;
    _subscribeRadarChannels();
    _debouncedRadarRefresh();
  }

  /// Handles ride lifecycle events and fires notifications.
  void _handleRideChange(PostgresChangePayload payload) {
    final record =
        payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
    final rideId = (record['id'] ?? '').toString().trim();
    if (rideId.isEmpty) return;

    final status = (record['status'] ?? '').toString().trim().toLowerCase();
    final title = (record['title'] ?? 'Ride').toString().trim();

    // Detect ride started (insert or status change to active)
    if (payload.eventType == PostgresChangeEvent.insert) {
      _seenRideIds.add(rideId);
    } else if (status == 'active' || status == 'live') {
      if (!_seenRideIds.contains(rideId)) {
        _seenRideIds.add(rideId);
        unawaited(
          _notificationCoordinator.persist(
            profileId:
                _radarProfileId.isNotEmpty ? _radarProfileId : _activeProfileId,
            title: 'Ride started',
            body: '$title is now live!',
            category: AppNotificationCategory.rideStarted,
            rideId: rideId,
          ),
        );
      }
    } else if (status == 'completed' || status == 'ended') {
      if (_seenRideIds.remove(rideId)) {
        unawaited(
          _notificationCoordinator.persist(
            profileId:
                _radarProfileId.isNotEmpty ? _radarProfileId : _activeProfileId,
            title: 'Ride ended',
            body: '$title has ended.',
            category: AppNotificationCategory.rideEnded,
            rideId: rideId,
          ),
        );
      }
    }
  }

  Future<void> _resolveRadarOrigin(bool requestPermissionIfNeeded) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied &&
          requestPermissionIfNeeded) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _originLat = position.latitude;
      _originLng = position.longitude;
    } catch (error) {
      debugPrint('[Realtime] radar origin unavailable: $error');
    }
  }

  Future<void> _refreshRadar() async {
    if (_radarProfileId.isEmpty) return;

    _radarLoading = true;
    _radarError = '';
    notifyListeners();

    try {
      final nearby = await _rideService.searchNearbyRides(
        _radarProfileId,
        currentLat: _originLat,
        currentLng: _originLng,
        maxDistanceKm: _radarRadiusKm,
      );
      _radarRides
        ..clear()
        ..addAll(nearby.map(_toRadarRide));
      _setConnectionState(RealtimeConnectionState.connected);
    } catch (error) {
      _radarError = 'Radar is reconnecting.';
      _setConnectionState(RealtimeConnectionState.reconnecting);
      debugPrint('[Realtime] radar refresh failed: $error');
    } finally {
      _radarLoading = false;
      notifyListeners();
    }
  }

  RadarRide _toRadarRide(NearbyRide ride) {
    final start = _parseLatLng(ride.ride.startLocation);
    final distance =
        start == null || _originLat == null || _originLng == null
            ? null
            : Geolocator.distanceBetween(
                  _originLat!,
                  _originLng!,
                  start.lat,
                  start.lng,
                ) /
                1000;
    return RadarRide(nearbyRide: ride, distanceKm: distance);
  }

  ({double lat, double lng})? _parseLatLng(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat: lat, lng: lng);
  }

  void _debouncedRadarRefresh() {
    _radarRefreshDebounce?.cancel();
    _radarRefreshDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_refreshRadar()),
    );
  }

  // =============================================================================
  // RIDE SESSION
  // =============================================================================

  void _subscribeRideSessionChannels(String rideId) {
    _rideMemberChannel = _client.channel('ride:$rideId:members');
    _rideMemberChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (_) {
            unawaited(_refreshRideSession());
          },
        )
        .subscribe((status, [error]) {
          if (error != null) debugPrint('[Realtime] members error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _setConnectionState(RealtimeConnectionState.connected);
          }
        });

    _rideRouteChannel = _client.channel('ride:$rideId:route');
    _rideRouteChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_routes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (_) {
            unawaited(_refreshRideSession());
            _onRouteChanged?.call();
          },
        )
        .subscribe((status, [error]) {
          if (error != null) debugPrint('[Realtime] route error: $error');
        });

    _rideAlertChannel = _client.channel('ride:$rideId:alerts');
    _rideAlertChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            final alert = Map<String, dynamic>.from(payload.newRecord);
            _lastAlert = alert;

            // Update presence for SOS
            final alertProfileId =
                (alert['profile_id'] ?? alert['user_id'] ?? '')
                    .toString()
                    .trim();
            if (alertProfileId.isNotEmpty) {
              _presenceMap[alertProfileId] = PresenceInfo(
                profileId: alertProfileId,
                status: RiderPresenceStatus.sos,
                lastSeenAt: DateTime.now(),
                isInRide: true,
                currentRideId: rideId,
              );
              notifyListeners();
            }

            _onAlert?.call(alert);
            unawaited(
              _notificationService.showLocal(
                title: 'Ride SOS alert',
                body: '${alert['user_name'] ?? 'A rider'} needs help now.',
              ),
            );
            notifyListeners();
          },
        )
        .subscribe();
  }

  void _resubscribeRideSessionChannels() {
    if (_activeRideId.isEmpty) return;
    _subscribeRideSessionChannels(_activeRideId);
  }

  Future<void> _refreshRideSession() async {
    if (_activeRideId.isEmpty) return;

    _setConnectionState(RealtimeConnectionState.syncing);
    try {
      final results = await Future.wait<Object?>([
        _rideService.fetchRideMembers(_activeRideId),
        _rideService.fetchRideRoute(_activeRideId),
      ]);

      final newMembers =
          (results[0] as List<RideMember>?) ?? const <RideMember>[];
      final prevMemberIds = _members.map((m) => m.userId).toSet();
      final newMemberIds = newMembers.map((m) => m.userId).toSet();

      // Detect member joins/leaves
      if (_activeProfileId.isNotEmpty) {
        final joined = newMemberIds.difference(prevMemberIds);
        final left = prevMemberIds.difference(newMemberIds);

        for (final joinedId in joined) {
          if (joinedId != _activeProfileId) {
            final member = newMembers.firstWhere(
              (m) => m.userId == joinedId,
              orElse:
                  () => RideMember(
                    userId: joinedId,
                    name: 'Rider',
                    bike: 'No bike added',
                    avatarUrl: '',
                    isHost: false,
                  ),
            );
            unawaited(
              _notificationCoordinator.persist(
                profileId: _activeProfileId,
                title: 'Member joined',
                body: '${member.name} has joined the ride.',
                category: AppNotificationCategory.memberJoined,
                rideId: _activeRideId,
              ),
            );
          }
        }

        for (final leftId in left) {
          unawaited(
            _notificationCoordinator.persist(
              profileId: _activeProfileId,
              title: 'Member left',
              body: 'A rider has left the ride.',
              category: AppNotificationCategory.memberLeft,
              rideId: _activeRideId,
            ),
          );
        }
      }

      _members = newMembers;
      _route = results[1] as RideRoute?;
      _onMembersChanged?.call(_members);
      _setConnectionState(RealtimeConnectionState.connected);
      notifyListeners();
    } catch (error) {
      debugPrint('[Realtime] session refresh failed: $error');
      _setConnectionState(RealtimeConnectionState.reconnecting);
    }
  }

  // =============================================================================
  // PRESENCE SYSTEM
  // =============================================================================

  void _subscribePresence() {
    _presenceChannel?.unsubscribe();
    _presenceChannel = _client.channel('presence');
    _presenceChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final record =
                payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord;
            final profileId = (record['id'] ?? '').toString().trim();
            if (profileId.isEmpty) return;

            final lastSeenStr = (record['last_seen_at'] ?? '').toString();
            final fcmToken = (record['fcm_token'] ?? '').toString().trim();
            final activeRideId =
                (record['active_ride_id'] ?? '').toString().trim();

            // Determine status from available data
            RiderPresenceStatus status;
            if (fcmToken.isEmpty) {
              status = RiderPresenceStatus.offline;
            } else if (activeRideId.isNotEmpty) {
              status = RiderPresenceStatus.tracking;
            } else {
              status = RiderPresenceStatus.online;
            }

            // If last seen is older than 5 minutes, mark as background
            final lastSeen = DateTime.tryParse(lastSeenStr);
            if (lastSeen != null &&
                DateTime.now().difference(lastSeen).inMinutes > 5) {
              status = RiderPresenceStatus.background;
            }

            _presenceMap[profileId] = PresenceInfo(
              profileId: profileId,
              status: status,
              lastSeenAt: lastSeen,
              currentRideId: activeRideId.isNotEmpty ? activeRideId : null,
              isInRide: activeRideId.isNotEmpty,
            );
            notifyListeners();
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[Realtime] presence error: $error');
          }
        });
  }

  void _resubscribePresence() {
    _subscribePresence();
  }

  /// Updates the current user's presence status in the database.
  Future<void> updateMyPresence({
    required String profileId,
    RiderPresenceStatus status = RiderPresenceStatus.online,
    String? currentRideId,
  }) async {
    final payload = <String, dynamic>{
      'last_seen_at': DateTime.now().toIso8601String(),
      if (currentRideId != null) 'active_ride_id': currentRideId,
    };

    try {
      await _client.from('profiles').update(payload).eq('id', profileId.trim());
      _presenceMap[profileId] = PresenceInfo(
        profileId: profileId,
        status: status,
        lastSeenAt: DateTime.now(),
        currentRideId: currentRideId,
        isInRide: currentRideId != null,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('[Realtime] presence update failed: $error');
    }
  }

  // =============================================================================
  // CONNECTION STATE
  // =============================================================================

  void _setConnectionState(RealtimeConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();

    if (state == RealtimeConnectionState.reconnecting ||
        state == RealtimeConnectionState.connecting) {
      _scheduleReconnect();
    } else {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setConnectionState(RealtimeConnectionState.disconnected);
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(
      milliseconds: (_baseReconnectDelay.inMilliseconds *
              math.pow(2, _reconnectAttempts))
          .toInt()
          .clamp(1000, 30000),
    );
    _reconnectAttempts++;

    debugPrint(
      '[Realtime] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (_activeRideId.isNotEmpty) {
        unawaited(_refreshRideSession());
        _resubscribeRideSessionChannels();
      }
      if (_radarProfileId.isNotEmpty) {
        _resubscribeRadarChannels();
      }
      _resubscribePresence();
    });
  }

  // =============================================================================
  // CLEANUP
  // =============================================================================

  Future<void> disposeCoordinator() async {
    _radarRefreshDebounce?.cancel();
    _reconnectTimer?.cancel();
    await _connectivitySub?.cancel();
    _connectivitySub = null;

    await stopRideRadar();
    await stopRideSession();

    await _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    _presenceMap.clear();

    _seenRideIds.clear();
    _connectionState = RealtimeConnectionState.disconnected;
    notifyListeners();
  }
}

// =============================================================================
// SUPPORTING TYPES
// =============================================================================

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  syncing,
  offline,
  reconnecting,
}

class RadarRide {
  const RadarRide({required this.nearbyRide, this.distanceKm});
  final NearbyRide nearbyRide;
  final double? distanceKm;
}

/// Fire-and-forget helper (suppresses the unawaited future lint).
void unawaited(Future<void> future) {
  future.ignore();
}
