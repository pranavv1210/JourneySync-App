/// Enriched rider location model combining live GPS data with rider metadata.
///
/// This model is returned by [LiveTrackingService.watchRideLocations] and
/// contains everything needed to render a premium map marker without requiring
/// a separate member-list lookup.
class RiderLocation {
  const RiderLocation({
    required this.userId,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    required this.userName,
    required this.bikeName,
    required this.isLeader,
    this.heading,
    this.speed,
    this.battery,
    this.signal,
    this.avatarUrl,
  });

  final String userId;
  final String rideId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  /// Display name of the rider (from live_locations.user_name).
  final String userName;

  /// Bike name of the rider (from live_locations.bike_name).
  final String bikeName;

  /// Whether this rider is currently the ride leader.
  final bool isLeader;

  /// GPS heading in degrees (0–360, 0 = north). Null if unavailable.
  final double? heading;

  /// Speed in m/s. Null if unavailable or negative (invalid GPS).
  final double? speed;

  /// Battery percentage string e.g. "85%". Null if not reported.
  final String? battery;

  /// Signal strength string. Null if not reported.
  final String? signal;

  /// Avatar URL from the users table. Null if not loaded.
  final String? avatarUrl;

  /// True when the last update was more than 2 minutes ago (rider offline/stale).
  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(minutes: 2);

  /// Speed in km/h for display purposes.
  double? get speedKmh => speed != null ? speed! * 3.6 : null;

  /// True when rider is considered stationary (< 1 m/s).
  bool get isStationary => speed == null || speed! < 1.0;

  /// Create a copy with optional field overrides.
  RiderLocation copyWith({
    String? userId,
    String? rideId,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    String? userName,
    String? bikeName,
    bool? isLeader,
    double? heading,
    double? speed,
    String? battery,
    String? signal,
    String? avatarUrl,
  }) {
    return RiderLocation(
      userId: userId ?? this.userId,
      rideId: rideId ?? this.rideId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      bikeName: bikeName ?? this.bikeName,
      isLeader: isLeader ?? this.isLeader,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      battery: battery ?? this.battery,
      signal: signal ?? this.signal,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  String toString() =>
      'RiderLocation($userName @ $latitude,$longitude speed=${speedKmh?.toStringAsFixed(1)} km/h)';
}
