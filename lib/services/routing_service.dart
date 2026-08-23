import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/app_logger.dart';

/// A drivable road route between two points.
class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.isApproximate,
  });

  /// A straight line between two points, used when routing is unavailable so
  /// the map always has something to draw.
  factory RoadRoute.straightLine(LatLng from, LatLng to) {
    return RoadRoute(
      points: <LatLng>[from, to],
      distanceMeters: const Distance().as(LengthUnit.Meter, from, to),
      durationSeconds: 0,
      isApproximate: true,
    );
  }

  /// Ordered points from origin to destination, following real roads unless
  /// [isApproximate] is set.
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// True when this is a straight-line stand-in rather than a real road route.
  final bool isApproximate;

  bool get isUsable => points.length >= 2;

  double get distanceKm => distanceMeters / 1000;

  /// Serialised for the `ride_routes.route_points` jsonb column, which the live
  /// ride map already reads back as `{lat, lng}` pairs.
  List<Map<String, double>> toRoutePoints() {
    return points
        .map((p) => <String, double>{'lat': p.latitude, 'lng': p.longitude})
        .toList();
  }
}

/// Fetches road routes from the public OSRM server.
///
/// OSRM needs no API key, which keeps it consistent with the other free
/// services this app already calls (Nominatim, Overpass, Open-Meteo). Results
/// are cached in memory for the session; the durable cache is the
/// `ride_routes.route_points` column, so a route is normally fetched once per
/// ride and then shared by every rider in the group.
class RoutingService {
  static const String _host = 'router.project-osrm.org';
  static const Duration _timeout = Duration(seconds: 12);

  /// Upper bound on stored/rendered points. OSRM's full geometry can run to
  /// several thousand points on a long ride, which bloats the jsonb payload for
  /// no visible benefit.
  static const int _maxPoints = 500;

  static final Map<String, RoadRoute> _cache = <String, RoadRoute>{};

  /// Road route from [from] to [to], or null when it cannot be determined.
  ///
  /// Never throws: callers get null and can fall back to
  /// [RoadRoute.straightLine].
  Future<RoadRoute?> fetchRoute(LatLng from, LatLng to) async {
    final key = _cacheKey(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      // OSRM takes coordinates as lon,lat - the reverse of LatLng.
      final path =
          '/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}';
      final uri = Uri.https(_host, path, <String, String>{
        'overview': 'full',
        'geometries': 'polyline',
        'alternatives': 'false',
        'steps': 'false',
      });

      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.warning('OSRM returned HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if ((decoded['code'] ?? '').toString() != 'Ok') {
        AppLogger.warning('OSRM route unavailable: ${decoded['code']}');
        return null;
      }

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final first = routes.first;
      if (first is! Map<String, dynamic>) return null;

      final geometry = (first['geometry'] ?? '').toString();
      if (geometry.isEmpty) return null;

      final points = _downsample(decodePolyline(geometry));
      if (points.length < 2) return null;

      final route = RoadRoute(
        points: points,
        distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0,
        isApproximate: false,
      );
      _cache[key] = route;
      return route;
    } catch (error) {
      // Offline, DNS failure, timeout, malformed body - all non-fatal.
      AppLogger.warning('Could not fetch road route: $error');
      return null;
    }
  }

  /// Rounded to ~11 m so near-identical requests share a cache entry.
  String _cacheKey(LatLng from, LatLng to) {
    String fmt(double v) => v.toStringAsFixed(4);
    return '${fmt(from.latitude)},${fmt(from.longitude)}'
        '->${fmt(to.latitude)},${fmt(to.longitude)}';
  }

  /// Evenly thins [points] to at most [_maxPoints], always keeping the first and
  /// last so the line still starts at the origin and ends at the destination.
  List<LatLng> _downsample(List<LatLng> points) {
    if (points.length <= _maxPoints) return points;
    final step = (points.length - 1) / (_maxPoints - 1);
    final thinned = <LatLng>[];
    for (var i = 0; i < _maxPoints - 1; i++) {
      thinned.add(points[(i * step).round()]);
    }
    thinned.add(points.last);
    return thinned;
  }
}

/// Decodes an encoded polyline into coordinates.
///
/// This is Google's polyline algorithm, which OSRM uses for
/// `geometries=polyline` at precision 5. Written out here because the project
/// has no polyline package. Malformed input yields the points decoded so far
/// rather than throwing.
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  if (encoded.isEmpty) return const <LatLng>[];

  final factor = math.pow(10, precision).toDouble();
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final latDelta = _decodeValue(encoded, index);
    if (latDelta == null) break;
    index = latDelta.nextIndex;
    lat += latDelta.value;

    final lngDelta = _decodeValue(encoded, index);
    if (lngDelta == null) break;
    index = lngDelta.nextIndex;
    lng += lngDelta.value;

    points.add(LatLng(lat / factor, lng / factor));
  }

  return points;
}

/// Reads one zig-zag encoded varint starting at [start].
/// Returns null when the chunk is truncated.
({int value, int nextIndex})? _decodeValue(String encoded, int start) {
  var index = start;
  var shift = 0;
  var result = 0;
  int byte;

  do {
    if (index >= encoded.length) return null;
    byte = encoded.codeUnitAt(index) - 63;
    if (byte < 0) return null;
    index++;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    // A well-formed value fits in 32 bits; anything longer is corrupt.
    if (shift > 35) return null;
  } while (byte >= 0x20);

  // Low bit set means the original value was negative.
  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value: value, nextIndex: index);
}
