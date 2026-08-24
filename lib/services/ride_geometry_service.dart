import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../models/ride_record.dart';
import '../utils/app_logger.dart';
import 'geocoding_service.dart';
import 'routing_service.dart';
import 'supabase_service.dart';

/// Where a ride starts and ends, plus the road route between the two.
class RideGeometry {
  const RideGeometry({this.start, this.destination, this.route});

  static const RideGeometry empty = RideGeometry();

  final LatLng? start;
  final LatLng? destination;
  final RoadRoute? route;

  /// True when there is a line worth drawing.
  bool get hasRoute => (route?.isUsable ?? false);

  /// True when at least one endpoint is known, so a map can be centred.
  bool get hasAnyPoint => start != null || destination != null;

  List<LatLng> get points => route?.points ?? const <LatLng>[];

  /// Every point a map needs to frame: the route plus both endpoints.
  List<LatLng> get framingPoints {
    final all = <LatLng>[
      ...points,
      if (start != null) start!,
      if (destination != null) destination!,
    ];
    return all;
  }
}

/// Resolves and caches the geometry of a ride.
///
/// Rides are stored with text locations only, so this fills the gap: it reads
/// any route already saved for the ride, otherwise geocodes the start and end
/// labels, asks OSRM for the road route, and writes the result back to
/// `ride_routes.route_points`. That write is what makes the work happen once per
/// ride rather than once per rider per screen.
class RideGeometryService {
  RideGeometryService({
    SupabaseService? supabaseService,
    GeocodingService? geocodingService,
    RoutingService? routingService,
  }) : _supabase = supabaseService ?? SupabaseService(),
       _geocoder = geocodingService ?? GeocodingService(),
       _router = routingService ?? RoutingService();

  final SupabaseService _supabase;
  final GeocodingService _geocoder;
  final RoutingService _router;

  /// A stored point list shorter than this is treated as pit-stop coordinates
  /// (what older builds saved here) rather than a road route, and gets replaced
  /// by real road geometry. A genuine OSRM route has far more points than this,
  /// except for very short hops - those are re-fetched at most once per session
  /// thanks to [_cache].
  static const int minRoadRoutePoints = 8;

  static final Map<String, RideGeometry> _cache = <String, RideGeometry>{};
  static final Map<String, Future<RideGeometry>> _inFlight =
      <String, Future<RideGeometry>>{};

  /// Cached geometry for [rideId], if it has already been resolved this session.
  RideGeometry? cached(String rideId) => _cache[rideId.trim()];

  /// Resolves the geometry for [ride], reusing any in-flight request.
  ///
  /// Never throws; an unresolvable ride yields [RideGeometry.empty].
  Future<RideGeometry> resolve(RideRecord ride) {
    return resolveFor(
      rideId: ride.id,
      startLabel: ride.startLocation,
      endLabel: ride.endLocation,
    );
  }

  /// Same as [resolve] but for callers holding raw ride fields rather than a
  /// [RideRecord] - the live ride screen reads its ride as a plain map.
  Future<RideGeometry> resolveFor({
    required String rideId,
    required String startLabel,
    required String endLabel,
  }) {
    final id = rideId.trim();
    if (id.isEmpty) return Future.value(RideGeometry.empty);

    final cachedValue = _cache[id];
    if (cachedValue != null) return Future.value(cachedValue);

    final pending = _inFlight[id];
    if (pending != null) return pending;

    final request = _resolve(id, startLabel, endLabel)
        .then((geometry) {
          _cache[id] = geometry;
          return geometry;
        })
        .catchError((Object error) {
          AppLogger.warning('Could not resolve ride geometry: $error');
          return RideGeometry.empty;
        })
        .whenComplete(() => _inFlight.remove(id));

    _inFlight[id] = request;
    return request;
  }

  Future<RideGeometry> _resolve(
    String rideId,
    String startLabelInput,
    String endLabelInput,
  ) async {
    final row = await _readRouteRow(rideId);

    LatLng? destination = _pointFrom(
      row?['destination_lat'],
      row?['destination_lng'],
    );

    // A route already stored for this ride is authoritative - every rider in the
    // group then draws the same line without anyone calling OSRM again.
    final stored = _storedPoints(row?['route_points']);
    if (stored.length >= minRoadRoutePoints) {
      return RideGeometry(
        start: stored.first,
        destination: destination ?? stored.last,
        route: RoadRoute(
          points: stored,
          distanceMeters: _lengthOf(stored),
          durationSeconds: 0,
          isApproximate: false,
        ),
      );
    }

    // Nothing usable stored, so resolve the endpoints from their labels.
    final startLabel = _firstNonEmpty(<String?>[
      startLabelInput,
      row?['start_label']?.toString(),
    ]);
    final endLabel = _firstNonEmpty(<String?>[
      endLabelInput,
      row?['end_label']?.toString(),
    ]);

    final start =
        startLabel == null ? null : await _geocoder.resolve(startLabel);
    destination ??= endLabel == null ? null : await _geocoder.resolve(endLabel);

    if (start == null || destination == null) {
      // One endpoint is enough to centre a map on, just not to draw a route.
      return RideGeometry(start: start, destination: destination);
    }

    final road = await _router.fetchRoute(start, destination);
    final route = road ?? RoadRoute.straightLine(start, destination);

    // Only a real road route is worth sharing; a straight line is a local
    // placeholder and must not be persisted as though it were the route.
    if (road != null) {
      await _persist(rideId, destination, road);
    }

    return RideGeometry(start: start, destination: destination, route: route);
  }

  /// Computes and stores the road route for a ride whose endpoints are already
  /// known, skipping geocoding entirely.
  ///
  /// Called right after a ride is created, where the host's GPS position and the
  /// chosen destination are both in hand. Safe to fire and forget: it never
  /// throws, and a failure just means the route is resolved later on demand.
  Future<void> primeRoute({
    required String rideId,
    required LatLng start,
    required LatLng destination,
  }) async {
    final id = rideId.trim();
    if (id.isEmpty) return;

    final road = await _router.fetchRoute(start, destination);
    if (road == null) return;

    _cache[id] = RideGeometry(
      start: start,
      destination: destination,
      route: road,
    );
    await _persist(id, destination, road);
  }

  Future<Map<String, dynamic>?> _readRouteRow(String rideId) async {
    try {
      return await _supabase.fetchRideRouteMap(rideId);
    } catch (error) {
      AppLogger.warning('Could not read stored route: $error');
      return null;
    }
  }

  Future<void> _persist(
    String rideId,
    LatLng destination,
    RoadRoute road,
  ) async {
    try {
      await _supabase.upsertRideRoute(
        rideId: rideId,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
        routePoints: road.toRoutePoints(),
      );
    } catch (error) {
      // Caching the route is an optimisation, not a requirement - a failure here
      // costs another lookup later but must not break the map.
      AppLogger.warning('Could not cache ride route: $error');
    }
  }

  List<LatLng> _storedPoints(Object? raw) {
    if (raw is! List) return const <LatLng>[];
    final points = <LatLng>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final point = _pointFrom(entry['lat'], entry['lng']);
      if (point != null) points.add(point);
    }
    return points;
  }

  LatLng? _pointFrom(Object? lat, Object? lng) {
    final latitude = _toDouble(lat);
    final longitude = _toDouble(lng);
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return LatLng(latitude, longitude);
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double _lengthOf(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return total;
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Forgets the cached geometry for a ride, so the next resolve refetches.
  static void invalidate(String rideId) {
    _cache.remove(rideId.trim());
  }
}
