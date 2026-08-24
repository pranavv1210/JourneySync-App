import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// Turns human place names into coordinates.
///
/// Rides store their start and end as free text (a Nominatim display name, or
/// whatever the host typed), so anything that needs to draw a map has to
/// resolve that text first. Results are cached in memory and on disk, and
/// requests are serialised with a ~1s gap to respect the Nominatim usage
/// policy.
class GeocodingService {
  static const String _host = 'nominatim.openstreetmap.org';
  static const String _userAgent =
      'JourneySync/1.1.1 (journeysync.app@gmail.com)';
  static const String _prefsKey = 'geocodeCacheV1';
  static const Duration _timeout = Duration(seconds: 10);

  /// Nominatim asks for no more than one request per second.
  static const Duration _minRequestGap = Duration(milliseconds: 1100);

  /// Keeps the on-disk cache from growing without bound.
  static const int _maxCacheEntries = 300;

  static final Map<String, LatLng?> _memory = <String, LatLng?>{};
  static Map<String, String?>? _disk;
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void> _queue = Future<void>.value();

  /// Coordinates for [place], or null when it cannot be resolved.
  ///
  /// Never throws. A network failure returns null without being cached, so the
  /// next attempt retries; only an authoritative "no such place" is remembered.
  Future<LatLng?> resolve(String place) async {
    final query = place.trim();
    if (query.isEmpty) return null;

    // Several screens store a location as raw "lat, lng" text.
    final direct = parseLatLng(query);
    if (direct != null) return direct;

    final key = query.toLowerCase();
    if (_memory.containsKey(key)) return _memory[key];

    final disk = await _loadDisk();
    if (disk.containsKey(key)) {
      final raw = disk[key];
      final point = raw == null ? null : parseLatLng(raw);
      _memory[key] = point;
      return point;
    }

    final outcome = await _lookup(query);
    if (outcome.definitive) {
      _memory[key] = outcome.point;
      await _remember(key, outcome.point);
    }
    return outcome.point;
  }

  /// Resolves several places, reusing cached values and avoiding duplicate
  /// lookups for repeated text.
  Future<Map<String, LatLng?>> resolveAll(Iterable<String> places) async {
    final unique = <String>{
      for (final place in places)
        if (place.trim().isNotEmpty) place.trim(),
    };
    final results = <String, LatLng?>{};
    for (final place in unique) {
      results[place] = await resolve(place);
    }
    return results;
  }

  /// Queries Nominatim, falling back to progressively broader versions of the
  /// query. `definitive` is false when the lookup failed for a reason that might
  /// not recur, such as being offline.
  Future<({LatLng? point, bool definitive})> _lookup(String query) async {
    var sawDefinitiveMiss = false;

    for (final candidate in _queryVariants(query)) {
      final outcome = await _request(candidate);
      if (outcome.point != null) return outcome;
      if (outcome.definitive) {
        sawDefinitiveMiss = true;
      } else {
        // Offline or server error - stop trying and do not cache.
        return (point: null, definitive: false);
      }
    }
    return (point: null, definitive: sawDefinitiveMiss);
  }

  /// The full query first, then broader forms made by dropping trailing
  /// address components, which is how an over-specific display name still
  /// resolves to its city.
  List<String> _queryVariants(String query) {
    final variants = <String>[query];
    final parts =
        query.split(',').map((p) => p.trim()).toList()
          ..removeWhere((p) => p.isEmpty);
    if (parts.length > 3) {
      variants.add(parts.take(3).join(', '));
    }
    if (parts.length > 2) {
      variants.add(parts.take(2).join(', '));
    }
    return variants;
  }

  Future<({LatLng? point, bool definitive})> _request(String query) {
    return _serialised(() async {
      try {
        final uri = Uri.https(_host, '/search', <String, String>{
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
        });
        final response = await http
            .get(uri, headers: <String, String>{'User-Agent': _userAgent})
            .timeout(_timeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          AppLogger.warning('Nominatim returned HTTP ${response.statusCode}');
          return (point: null, definitive: false);
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! List || decoded.isEmpty) {
          // A clean empty answer: this text genuinely has no match.
          return (point: null, definitive: true);
        }

        final first = decoded.first;
        if (first is! Map) return (point: null, definitive: true);
        final lat = double.tryParse((first['lat'] ?? '').toString());
        final lon = double.tryParse((first['lon'] ?? '').toString());
        if (lat == null || lon == null) {
          return (point: null, definitive: true);
        }
        return (point: LatLng(lat, lon), definitive: true);
      } catch (error) {
        AppLogger.warning('Could not geocode "$query": $error');
        return (point: null, definitive: false);
      }
    });
  }

  /// Runs [action] after any in-flight lookup, keeping at least
  /// [_minRequestGap] between outbound requests.
  Future<T> _serialised<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequest);
      if (elapsed < _minRequestGap) {
        await Future<void>.delayed(_minRequestGap - elapsed);
      }
      _lastRequest = DateTime.now();
      try {
        completer.complete(await action());
      } catch (error, stack) {
        // Kept off _queue so one failure cannot stall every later lookup.
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<Map<String, String?>> _loadDisk() async {
    final cached = _disk;
    if (cached != null) return cached;
    final loaded = <String, String?>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            loaded[entry.key.toString()] = entry.value?.toString();
          }
        }
      }
    } catch (error) {
      AppLogger.warning('Could not read geocode cache: $error');
    }
    _disk = loaded;
    return loaded;
  }

  Future<void> _remember(String key, LatLng? point) async {
    final disk = await _loadDisk();
    disk[key] = point == null ? null : '${point.latitude},${point.longitude}';

    // Dart maps keep insertion order, so this drops the oldest entries.
    while (disk.length > _maxCacheEntries) {
      disk.remove(disk.keys.first);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(disk));
    } catch (error) {
      AppLogger.warning('Could not persist geocode cache: $error');
    }
  }
}

/// Parses `"12.97, 77.59"` into a point, or returns null when [value] is not a
/// coordinate pair. Rejects out-of-range values so a string like `"91, 200"` is
/// treated as text rather than a location.
LatLng? parseLatLng(String value) {
  final parts = value.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}
