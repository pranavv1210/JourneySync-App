import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/rider_location.dart';
import 'ride_engine_core.dart';

enum GroupConnectionQuality { excellent, good, weak, offline }

enum GroupHealthRating { excellent, good, poor, needsAttention }

enum GroupAlertType {
  stopped,
  separated,
  oppositeDirection,
  offline,
  reconnected,
  resumed,
  lowBattery,
}

class GroupRiderSnapshot {
  const GroupRiderSnapshot({
    required this.location,
    required this.status,
    required this.connectionQuality,
    required this.gpsQuality,
    required this.distanceFromLeaderMeters,
    required this.leaderRelation,
    required this.etaToLeader,
    required this.batteryState,
    required this.trail,
  });

  final RiderLocation location;
  final RiderLiveStatus status;
  final GroupConnectionQuality connectionQuality;
  final String gpsQuality;
  final double distanceFromLeaderMeters;
  final String leaderRelation;
  final Duration? etaToLeader;
  final String batteryState;
  final List<LatLng> trail;

  double get speedKmh => (location.speed ?? 0) * 3.6;
  bool get isTracking => connectionQuality != GroupConnectionQuality.offline;
}

class GroupRideSnapshot {
  const GroupRideSnapshot({
    required this.riders,
    required this.leaderId,
    required this.totalRiders,
    required this.trackingRiders,
    required this.averageSpeedKmh,
    required this.groupSpreadMeters,
    required this.healthRating,
    required this.healthScore,
    this.slowestRider,
    this.fastestRider,
    this.leader,
    this.etaToDestination,
  });

  final List<GroupRiderSnapshot> riders;
  final String? leaderId;
  final int totalRiders;
  final int trackingRiders;
  final double averageSpeedKmh;
  final double groupSpreadMeters;
  final GroupHealthRating healthRating;
  final int healthScore;
  final GroupRiderSnapshot? slowestRider;
  final GroupRiderSnapshot? fastestRider;
  final GroupRiderSnapshot? leader;
  final Duration? etaToDestination;

  GroupRiderSnapshot? riderFor(String userId) =>
      riders.where((rider) => rider.location.userId == userId).firstOrNull;
}

class GroupRideAlert {
  const GroupRideAlert({
    required this.key,
    required this.type,
    required this.message,
    required this.riderId,
  });

  final String key;
  final GroupAlertType type;
  final String message;
  final String riderId;
}

class GroupRideIntelligence {
  final Map<String, List<LatLng>> _trails = <String, List<LatLng>>{};
  final Map<String, RiderLiveStatus> _lastStatuses =
      <String, RiderLiveStatus>{};
  final Map<String, DateTime> _alertedAt = <String, DateTime>{};
  GroupRideSnapshot _lastSnapshot = const GroupRideSnapshot(
    riders: <GroupRiderSnapshot>[],
    leaderId: null,
    totalRiders: 0,
    trackingRiders: 0,
    averageSpeedKmh: 0,
    groupSpreadMeters: 0,
    healthRating: GroupHealthRating.needsAttention,
    healthScore: 0,
  );

  GroupRideSnapshot get lastSnapshot => _lastSnapshot;

  GroupRideSnapshot update({
    required List<RiderLocation> locations,
    required String? leaderId,
    required String currentUserId,
    LatLng? destination,
    String? sosRiderId,
    bool trailsEnabled = true,
  }) {
    final leader =
        leaderId == null
            ? null
            : locations.where((loc) => loc.userId == leaderId).firstOrNull;
    final riders = <GroupRiderSnapshot>[];

    for (final location in locations) {
      final isLeader = location.userId == leaderId || location.isLeader;
      final status = RideEngineCore.statusFor(
        location,
        isLeader: isLeader,
        hasSos: sosRiderId == location.userId,
      );
      final distanceFromLeader =
          leader == null || leader.userId == location.userId
              ? 0.0
              : Geolocator.distanceBetween(
                location.latitude,
                location.longitude,
                leader.latitude,
                leader.longitude,
              );
      final relation = _leaderRelation(location, leader, distanceFromLeader);
      final eta = _eta(distanceFromLeader, location.speed);
      final trail = trailsEnabled ? _updateTrail(location) : const <LatLng>[];

      riders.add(
        GroupRiderSnapshot(
          location: location,
          status: status,
          connectionQuality: _connectionQuality(location),
          gpsQuality: _gpsQuality(location),
          distanceFromLeaderMeters: distanceFromLeader,
          leaderRelation: relation,
          etaToLeader: eta,
          batteryState: _batteryState(location.battery),
          trail: trail,
        ),
      );
    }

    final movingRiders =
        riders
            .where(
              (rider) =>
                  rider.connectionQuality != GroupConnectionQuality.offline,
            )
            .toList();
    final speeds = movingRiders.map((rider) => rider.speedKmh).toList();
    final averageSpeed =
        speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a + b) / speeds.length;
    final spread = _groupSpread(riders);
    final healthScore = _healthScore(riders, spread);
    final snapshot = GroupRideSnapshot(
      riders: riders,
      leaderId: leaderId,
      totalRiders: riders.length,
      trackingRiders: movingRiders.length,
      averageSpeedKmh: averageSpeed,
      groupSpreadMeters: spread,
      healthScore: healthScore,
      healthRating: _healthRating(healthScore),
      slowestRider: _slowest(movingRiders),
      fastestRider: _fastest(movingRiders),
      leader:
          leaderId == null
              ? null
              : riders
                  .where((rider) => rider.location.userId == leaderId)
                  .firstOrNull,
      etaToDestination: _destinationEta(currentUserId, riders, destination),
    );
    _lastSnapshot = snapshot;
    return snapshot;
  }

  List<GroupRideAlert> detectAlerts(GroupRideSnapshot snapshot) {
    final alerts = <GroupRideAlert>[];
    for (final rider in snapshot.riders) {
      final riderId = rider.location.userId;
      final previous = _lastStatuses[riderId];
      _lastStatuses[riderId] = rider.status;

      if (rider.status == RiderLiveStatus.offline) {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.offline,
          '${rider.location.userName} disconnected.',
          cooldown: const Duration(minutes: 4),
        );
      } else if (previous == RiderLiveStatus.offline) {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.reconnected,
          '${rider.location.userName} reconnected.',
          cooldown: const Duration(minutes: 2),
        );
      }

      if (rider.status == RiderLiveStatus.waiting ||
          (rider.status == RiderLiveStatus.stopped &&
              DateTime.now().difference(rider.location.updatedAt) >
                  const Duration(minutes: 5))) {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.stopped,
          '${rider.location.userName} has stopped.',
          cooldown: const Duration(minutes: 5),
        );
      }

      if (rider.distanceFromLeaderMeters > 1800 &&
          rider.status != RiderLiveStatus.offline) {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.separated,
          '${rider.location.userName} is ${formatDistance(rider.distanceFromLeaderMeters)} from the leader.',
          cooldown: const Duration(minutes: 4),
        );
      }

      if (rider.leaderRelation == 'off-route' &&
          rider.status == RiderLiveStatus.moving) {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.oppositeDirection,
          '${rider.location.userName} appears to be moving away from the group.',
          cooldown: const Duration(minutes: 5),
        );
      }

      if (rider.batteryState == 'Critical') {
        _addAlert(
          alerts,
          rider,
          GroupAlertType.lowBattery,
          '${rider.location.userName} has critical battery.',
          cooldown: const Duration(minutes: 10),
        );
      }
    }
    return alerts;
  }

  void _addAlert(
    List<GroupRideAlert> alerts,
    GroupRiderSnapshot rider,
    GroupAlertType type,
    String message, {
    required Duration cooldown,
  }) {
    final key = '${type.name}:${rider.location.userId}';
    final last = _alertedAt[key];
    final now = DateTime.now();
    if (last != null && now.difference(last) < cooldown) return;
    _alertedAt[key] = now;
    alerts.add(
      GroupRideAlert(
        key: key,
        type: type,
        message: message,
        riderId: rider.location.userId,
      ),
    );
  }

  List<LatLng> _updateTrail(RiderLocation location) {
    final point = LatLng(location.latitude, location.longitude);
    final trail = _trails.putIfAbsent(location.userId, () => <LatLng>[]);
    if (trail.isEmpty ||
        const Distance().as(LengthUnit.Meter, trail.last, point) >= 4) {
      trail.add(point);
    }
    while (_trailLength(trail) > 300 && trail.length > 2) {
      trail.removeAt(0);
    }
    return List.unmodifiable(trail);
  }

  double _trailLength(List<LatLng> trail) {
    var total = 0.0;
    for (var i = 1; i < trail.length; i++) {
      total += const Distance().as(LengthUnit.Meter, trail[i - 1], trail[i]);
    }
    return total;
  }

  String _leaderRelation(
    RiderLocation location,
    RiderLocation? leader,
    double distanceMeters,
  ) {
    if (leader == null || leader.userId == location.userId) return 'leader';
    if (distanceMeters < 40) return 'with group';
    final leaderHeading = leader.heading;
    if (leaderHeading == null) return 'behind';

    final bearingToRider = Geolocator.bearingBetween(
      leader.latitude,
      leader.longitude,
      location.latitude,
      location.longitude,
    );
    final delta = RideEngineCore.headingDelta(leaderHeading, bearingToRider);
    if (delta.abs() > 135 && distanceMeters > 120) return 'behind';
    if (delta.abs() < 45 && distanceMeters > 120) return 'ahead';

    final riderHeading = location.heading;
    if (riderHeading != null &&
        RideEngineCore.headingDelta(leaderHeading, riderHeading).abs() > 135 &&
        distanceMeters > 250) {
      return 'off-route';
    }
    return 'nearby';
  }

  GroupConnectionQuality _connectionQuality(RiderLocation rider) {
    final age = DateTime.now().difference(rider.updatedAt);
    if (age < const Duration(seconds: 15)) {
      return GroupConnectionQuality.excellent;
    }
    if (age < const Duration(seconds: 45)) return GroupConnectionQuality.good;
    if (age < const Duration(minutes: 2)) return GroupConnectionQuality.weak;
    return GroupConnectionQuality.offline;
  }

  String _gpsQuality(RiderLocation rider) {
    final age = DateTime.now().difference(rider.updatedAt);
    if (age > const Duration(minutes: 2)) return 'Weak';
    final speed = rider.speed ?? 0;
    if (speed > 1 && rider.heading == null) return 'Medium';
    return 'Strong';
  }

  Duration? _eta(double distanceMeters, double? speedMps) {
    final speed = speedMps ?? 0;
    if (distanceMeters <= 0 || speed < 1) return null;
    return Duration(seconds: (distanceMeters / speed).round());
  }

  Duration? _destinationEta(
    String currentUserId,
    List<GroupRiderSnapshot> riders,
    LatLng? destination,
  ) {
    if (destination == null) return null;
    final current =
        riders
            .where((rider) => rider.location.userId == currentUserId)
            .firstOrNull;
    if (current == null || (current.location.speed ?? 0) < 1) return null;
    final distance = Geolocator.distanceBetween(
      current.location.latitude,
      current.location.longitude,
      destination.latitude,
      destination.longitude,
    );
    return _eta(distance, current.location.speed);
  }

  String _batteryState(String? battery) {
    if (battery == null || battery.trim().isEmpty) return 'Unknown';
    final value = int.tryParse(battery.replaceAll('%', '').trim());
    if (value == null) return 'Unknown';
    if (value <= 10) return 'Critical';
    if (value <= 20) return 'Low Battery';
    return 'Normal';
  }

  double _groupSpread(List<GroupRiderSnapshot> riders) {
    var spread = 0.0;
    for (var i = 0; i < riders.length; i++) {
      for (var j = i + 1; j < riders.length; j++) {
        spread = math.max(
          spread,
          Geolocator.distanceBetween(
            riders[i].location.latitude,
            riders[i].location.longitude,
            riders[j].location.latitude,
            riders[j].location.longitude,
          ),
        );
      }
    }
    return spread;
  }

  int _healthScore(List<GroupRiderSnapshot> riders, double spreadMeters) {
    if (riders.isEmpty) return 0;
    var score = 100;
    final offline =
        riders
            .where(
              (rider) =>
                  rider.connectionQuality == GroupConnectionQuality.offline,
            )
            .length;
    final weak =
        riders
            .where(
              (rider) => rider.connectionQuality == GroupConnectionQuality.weak,
            )
            .length;
    final staleGps = riders.where((rider) => rider.gpsQuality == 'Weak').length;
    score -= offline * 22;
    score -= weak * 10;
    score -= staleGps * 8;
    if (spreadMeters > 2500) {
      score -= 18;
    } else if (spreadMeters > 1200) {
      score -= 8;
    }
    return score.clamp(0, 100);
  }

  GroupHealthRating _healthRating(int score) {
    if (score >= 85) return GroupHealthRating.excellent;
    if (score >= 70) return GroupHealthRating.good;
    if (score >= 45) return GroupHealthRating.poor;
    return GroupHealthRating.needsAttention;
  }

  GroupRiderSnapshot? _slowest(List<GroupRiderSnapshot> riders) {
    if (riders.isEmpty) return null;
    final sorted = [...riders]
      ..sort((a, b) => a.speedKmh.compareTo(b.speedKmh));
    return sorted.first;
  }

  GroupRiderSnapshot? _fastest(List<GroupRiderSnapshot> riders) {
    if (riders.isEmpty) return null;
    final sorted = [...riders]
      ..sort((a, b) => b.speedKmh.compareTo(a.speedKmh));
    return sorted.first;
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return '--';
    if (duration.inMinutes < 1) return '${duration.inSeconds}s';
    if (duration.inHours < 1) return '${duration.inMinutes}m';
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  static String qualityLabel(GroupConnectionQuality quality) {
    return switch (quality) {
      GroupConnectionQuality.excellent => 'Excellent',
      GroupConnectionQuality.good => 'Good',
      GroupConnectionQuality.weak => 'Weak',
      GroupConnectionQuality.offline => 'Offline',
    };
  }

  static String healthLabel(GroupHealthRating rating) {
    return switch (rating) {
      GroupHealthRating.excellent => 'Excellent',
      GroupHealthRating.good => 'Good',
      GroupHealthRating.poor => 'Poor',
      GroupHealthRating.needsAttention => 'Needs Attention',
    };
  }

  void clear() {
    _trails.clear();
    _lastStatuses.clear();
    _alertedAt.clear();
  }
}
