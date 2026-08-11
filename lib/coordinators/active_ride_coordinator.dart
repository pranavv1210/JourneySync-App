import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/presence_info.dart';
import '../models/ride_member.dart';
import '../models/ride_route.dart';
import '../models/rider_location.dart';
import '../services/live_tracking_service.dart';
import '../services/ride_service.dart';
import '../services/supabase_service.dart';
import 'realtime_coordinator.dart' show RealtimeCoordinator;

enum ActiveRideStatus { idle, scheduled, active, completed, unknown }

class ActiveRideSnapshot {
  const ActiveRideSnapshot({
    required this.rideId,
    required this.status,
    this.hostId = '',
    this.currentProfileId = '',
    this.isHost = false,
    this.route,
    this.members = const <RideMember>[],
    this.locations = const <RiderLocation>[],
    this.lastAlert,
  });

  final String rideId;
  final ActiveRideStatus status;
  final String hostId;
  final String currentProfileId;
  final bool isHost;
  final RideRoute? route;
  final List<RideMember> members;
  final List<RiderLocation> locations;
  final Map<String, dynamic>? lastAlert;

  bool get hasActiveRide => rideId.trim().isNotEmpty;

  ActiveRideSnapshot copyWith({
    String? rideId,
    ActiveRideStatus? status,
    String? hostId,
    String? currentProfileId,
    bool? isHost,
    RideRoute? route,
    List<RideMember>? members,
    List<RiderLocation>? locations,
    Map<String, dynamic>? lastAlert,
  }) {
    return ActiveRideSnapshot(
      rideId: rideId ?? this.rideId,
      status: status ?? this.status,
      hostId: hostId ?? this.hostId,
      currentProfileId: currentProfileId ?? this.currentProfileId,
      isHost: isHost ?? this.isHost,
      route: route ?? this.route,
      members: members ?? this.members,
      locations: locations ?? this.locations,
      lastAlert: lastAlert ?? this.lastAlert,
    );
  }

  static const empty = ActiveRideSnapshot(
    rideId: '',
    status: ActiveRideStatus.idle,
  );
}

class ActiveRideCoordinator extends ChangeNotifier {
  ActiveRideCoordinator._();

  static final ActiveRideCoordinator instance = ActiveRideCoordinator._();

  final RideService _rideService = RideService();
  final SupabaseService _supabaseService = SupabaseService();
  final LiveTrackingService _trackingService = LiveTrackingService();
  final RealtimeCoordinator _realtimeCoordinator = RealtimeCoordinator.instance;

  static const String _activeRideKey = 'activeRideId';
  static const String _activeRideStatusKey = 'activeRideStatus';

  ActiveRideSnapshot _snapshot = ActiveRideSnapshot.empty;
  StreamSubscription<List<RiderLocation>>? _locationSubscription;
  bool _restoring = false;

  ActiveRideSnapshot get snapshot => _snapshot;
  LiveTrackingService get trackingService => _trackingService;

  Future<void> restore() async {
    if (_restoring || _snapshot.hasActiveRide) return;
    _restoring = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rideId = (prefs.getString(_activeRideKey) ?? '').trim();
      final profileId = (prefs.getString('userId') ?? '').trim();
      if (rideId.isEmpty || profileId.isEmpty) return;

      final ride = await _supabaseService.fetchRideById(rideId);
      if (ride == null) {
        await clear();
        return;
      }

      await attachRide(
        rideId: rideId,
        profileId: profileId,
        startTracking: false,
      );
    } finally {
      _restoring = false;
    }
  }

  Future<void> attachRide({
    required String rideId,
    required String profileId,
    bool startTracking = true,
    String profileName = 'Rider',
    String bikeName = 'No bike added',
  }) async {
    final normalizedRideId = rideId.trim();
    final normalizedProfileId = profileId.trim();
    if (normalizedRideId.isEmpty || normalizedProfileId.isEmpty) return;

    final ride = await _supabaseService.fetchRideById(normalizedRideId);
    final hostId = _hostIdFromRide(ride ?? const <String, dynamic>{});
    final status = _statusFromRide(ride ?? const <String, dynamic>{});

    final membersFuture = _rideService.fetchRideMembers(normalizedRideId);
    final routeFuture = _rideService.fetchRideRoute(normalizedRideId);
    final results = await Future.wait<Object?>([membersFuture, routeFuture]);

    _snapshot = ActiveRideSnapshot(
      rideId: normalizedRideId,
      status: status,
      hostId: hostId,
      currentProfileId: normalizedProfileId,
      isHost: hostId == normalizedProfileId,
      members: (results[0] as List<RideMember>?) ?? const <RideMember>[],
      route: results[1] as RideRoute?,
      locations:
          _snapshot.rideId == normalizedRideId ? _snapshot.locations : const [],
    );
    notifyListeners();

    // Update presence for active ride
    unawaited(
      _realtimeCoordinator.updateMyPresence(
        profileId: normalizedProfileId,
        status: RiderPresenceStatus.tracking,
        currentRideId: normalizedRideId,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRideKey, normalizedRideId);
    await prefs.setString(_activeRideStatusKey, status.name);

    await _locationSubscription?.cancel();
    _locationSubscription = _trackingService
        .watchRideLocations(normalizedRideId)
        .listen((locations) {
          _snapshot = _snapshot.copyWith(locations: locations);
          notifyListeners();
        });

    await _realtimeCoordinator.startRideSession(
      rideId: normalizedRideId,
      profileId: normalizedProfileId,
      onAlert: (alert) {
        _snapshot = _snapshot.copyWith(lastAlert: alert);
        notifyListeners();
      },
      onRouteChanged: refreshRoute,
      onMembersChanged: (members) {
        _snapshot = _snapshot.copyWith(members: members);
        notifyListeners();
      },
    );

    if (startTracking) {
      await _trackingService.startSyncing(
        rideId: normalizedRideId,
        userId: normalizedProfileId,
        userName: profileName,
        bikeName: bikeName,
        isLeader: hostId == normalizedProfileId,
      );
    }
  }

  Future<void> refreshRoute() async {
    final rideId = _snapshot.rideId.trim();
    if (rideId.isEmpty) return;
    final route = await _rideService.fetchRideRoute(rideId);
    _snapshot = _snapshot.copyWith(route: route);
    notifyListeners();
  }

  Future<void> markCompleted() async {
    final rideId = _snapshot.rideId.trim();
    final profileId = _snapshot.currentProfileId.trim();
    if (rideId.isNotEmpty && profileId.isNotEmpty) {
      await _trackingService.clearLiveLocation(
        rideId: rideId,
        userId: profileId,
      );
    }
    await clear();
  }

  Future<void> clear() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _realtimeCoordinator.stopRideSession();
    await _trackingService.stopSyncing();
    _snapshot = ActiveRideSnapshot.empty;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRideKey);
    await prefs.remove(_activeRideStatusKey);
  }

  String _hostIdFromRide(Map<String, dynamic> ride) {
    return (ride['host_id'] ??
            ride['profile_id'] ??
            ride['creator_id'] ??
            ride['user_id'] ??
            '')
        .toString()
        .trim();
  }

  ActiveRideStatus _statusFromRide(Map<String, dynamic> ride) {
    final status = (ride['status'] ?? '').toString().trim().toLowerCase();
    return switch (status) {
      'active' || 'live' => ActiveRideStatus.active,
      'completed' || 'ended' => ActiveRideStatus.completed,
      'scheduled' || 'pending' || '' => ActiveRideStatus.scheduled,
      _ => ActiveRideStatus.unknown,
    };
  }
}
