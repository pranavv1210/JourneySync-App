class RouteStop {
  const RouteStop({
    required this.label,
    this.latitude,
    this.longitude,
    required this.order,
  });

  final String label;
  final double? latitude;
  final double? longitude;
  final int order;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'order': order,
  };

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      label: (json['label'] ?? '').toString().trim(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

class RideRoute {
  const RideRoute({
    required this.rideId,
    required this.startLabel,
    required this.endLabel,
    required this.stops,
  });

  final String rideId;
  final String startLabel;
  final String endLabel;
  final List<RouteStop> stops;
}
