import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/rider_location.dart';

enum RiderLiveStatus {
  moving,
  stopped,
  waiting,
  leader,
  offline,
  sos,
  background,
}

class RideEngineCore {
  static const double driftTeleportThresholdMeters = 120;
  static const double locationWriteThresholdMeters = 4;
  static const double headingWriteThresholdDegrees = 8;
  static const double speedWriteThresholdMps = 0.8;

  static Duration syncIntervalFor({
    required double speedMps,
    required bool emergency,
    required int stationarySamples,
  }) {
    if (emergency) return const Duration(seconds: 1);
    final speedKmh = math.max(0, speedMps * 3.6);
    if (speedKmh > 15) return const Duration(seconds: 2);
    if (speedKmh >= 5) return const Duration(seconds: 4);
    if (speedKmh >= 1) return const Duration(seconds: 6);
    if (stationarySamples >= 6) return const Duration(seconds: 20);
    return const Duration(seconds: 10);
  }

  static bool shouldSyncLocation({
    required Position current,
    Position? previous,
    bool emergency = false,
  }) {
    if (emergency || previous == null) return true;

    final movedMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    if (movedMeters >= locationWriteThresholdMeters) return true;

    final currentHeading = current.heading >= 0 ? current.heading : null;
    final previousHeading = previous.heading >= 0 ? previous.heading : null;
    if (currentHeading != null && previousHeading != null) {
      final delta = headingDelta(previousHeading, currentHeading).abs();
      if (delta >= headingWriteThresholdDegrees) return true;
    }

    final currentSpeed = current.speed >= 0 ? current.speed : 0.0;
    final previousSpeed = previous.speed >= 0 ? previous.speed : 0.0;
    return (currentSpeed - previousSpeed).abs() >= speedWriteThresholdMps;
  }

  static double headingDelta(double from, double to) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) {
      delta += 360;
    }
    return delta;
  }

  static LatLng predictPosition(RiderLocation location, DateTime now) {
    final speed = location.speed ?? 0;
    final heading = location.heading;
    if (speed <= 0.2 || heading == null) {
      return LatLng(location.latitude, location.longitude);
    }

    final elapsedSeconds =
        now.difference(location.updatedAt).inMilliseconds / 1000.0;
    final cappedSeconds = elapsedSeconds.clamp(0.0, 8.0);
    final distanceMeters = speed * cappedSeconds;
    if (distanceMeters <= 0) {
      return LatLng(location.latitude, location.longitude);
    }

    return offset(
      LatLng(location.latitude, location.longitude),
      distanceMeters,
      heading,
    );
  }

  static LatLng offset(LatLng start, double meters, double headingDegrees) {
    const earthRadius = 6378137.0;
    final angularDistance = meters / earthRadius;
    final bearing = headingDegrees * math.pi / 180;
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  static RiderLiveStatus statusFor(
    RiderLocation location, {
    required bool isLeader,
    required bool hasSos,
  }) {
    if (hasSos) return RiderLiveStatus.sos;
    if (isLeader) return RiderLiveStatus.leader;
    final age = DateTime.now().difference(location.updatedAt);
    if (age > const Duration(minutes: 5)) return RiderLiveStatus.offline;
    if (age > const Duration(minutes: 2)) return RiderLiveStatus.background;
    final speed = location.speed ?? 0;
    if (speed >= 1.0) return RiderLiveStatus.moving;
    if (age > const Duration(seconds: 45)) return RiderLiveStatus.waiting;
    return RiderLiveStatus.stopped;
  }
}

class RiderDistanceCache {
  final Map<String, double> _cache = <String, double>{};
  DateTime _updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, double> update({
    required List<RiderLocation> locations,
    required String leaderId,
    Duration ttl = const Duration(seconds: 2),
  }) {
    final now = DateTime.now();
    if (now.difference(_updatedAt) < ttl && _cache.isNotEmpty) {
      return Map.unmodifiable(_cache);
    }

    _cache.clear();
    final leader = locations.where((loc) => loc.userId == leaderId).firstOrNull;
    if (leader == null) return Map.unmodifiable(_cache);

    for (final loc in locations) {
      if (loc.userId == leader.userId) continue;
      _cache[loc.userId] = Geolocator.distanceBetween(
        loc.latitude,
        loc.longitude,
        leader.latitude,
        leader.longitude,
      );
    }
    _updatedAt = now;
    return Map.unmodifiable(_cache);
  }

  void clear() => _cache.clear();
}
