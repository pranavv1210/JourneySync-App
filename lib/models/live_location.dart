class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.speedMps,
    this.heading,
    this.battery,
    this.signal,
  });

  final String userId;
  final String rideId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final double? speedMps;
  final double? heading;
  final String? battery;
  final String? signal;

  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(minutes: 5);
}
