import 'package:latlong2/latlong.dart';

/// Utility for parsing Google Maps links to extract destination coordinates
class RouteParser {
  /// Parses a Google Maps link and extracts the destination coordinates
  ///
  /// Supports various Google Maps URL formats:
  /// - https://www.google.com/maps?q=lat,lng
  /// - https://www.google.com/maps/@lat,lng,zoom
  /// - https://www.google.com/maps/dir//lat,lng
  /// - https://www.google.com/maps/place/.../@lat,lng
  /// - Short URLs like goo.gl/maps/...
  ///
  /// Returns [LatLng] if coordinates found, null otherwise
  static LatLng? parseGoogleMapsLink(String url) {
    if (url.isEmpty) return null;

    final trimmed = url.trim();

    // Validate that it's a Google Maps link
    if (!_isGoogleMapsUrl(trimmed)) {
      return null;
    }

    // Try different parsing strategies
    LatLng? result;

    // 1. Try ?q=lat,lng format
    result = _parseQueryParam(trimmed);
    if (result != null) return result;

    // 2. Try /@lat,lng format
    result = _parseAtSignFormat(trimmed);
    if (result != null) return result;

    // 3. Try /dir/.../lat,lng format
    result = _parseDirectionsFormat(trimmed);
    if (result != null) return result;

    // 4. Try searching for any lat,lng pattern in the URL
    result = _parseGenericLatLngPattern(trimmed);
    if (result != null) return result;

    return null;
  }

  /// Validates if the URL is a Google Maps URL
  static bool _isGoogleMapsUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('google.com/maps') ||
        lower.contains('goo.gl/maps') ||
        lower.contains('maps.app.goo.gl');
  }

  /// Parses ?q=lat,lng format
  /// Example: https://www.google.com/maps?q=12.9716,77.5946
  static LatLng? _parseQueryParam(String url) {
    try {
      final uri = Uri.parse(url);
      final query = uri.queryParameters['q'];
      if (query != null && query.isNotEmpty) {
        return _parseLatLngString(query);
      }

      // Also try 'query' parameter
      final query2 = uri.queryParameters['query'];
      if (query2 != null && query2.isNotEmpty) {
        return _parseLatLngString(query2);
      }
    } catch (_) {
      // Invalid URL, continue to next parser
    }
    return null;
  }

  /// Parses /@lat,lng,zoom format
  /// Example: https://www.google.com/maps/@12.9716,77.5946,15z
  static LatLng? _parseAtSignFormat(String url) {
    // Match pattern like /@12.9716,77.5946 or /@12.9716,77.5946,15z
    final regex = RegExp(r'/@(-?\d+\.?\d*),(-?\d+\.?\d*)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null) {
        if (_isValidCoordinate(lat, lng)) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Parses /dir/.../lat,lng format (directions)
  /// Example: https://www.google.com/maps/dir//12.9716,77.5946
  static LatLng? _parseDirectionsFormat(String url) {
    // Match the destination coordinates in directions URL
    // Pattern: /dir/.../lat,lng or /dir//lat,lng
    final regex = RegExp(r'/dir/(?:[^/]*/)?(-?\d+\.?\d*),(-?\d+\.?\d*)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null) {
        if (_isValidCoordinate(lat, lng)) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Generic pattern matcher for "lat,lng" anywhere in the URL
  /// This catches many variations as a fallback
  static LatLng? _parseGenericLatLngPattern(String url) {
    // Look for patterns like "12.9716,77.5946" in the URL
    // This regex looks for two decimal numbers separated by comma
    final regex = RegExp(r'(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)');
    final matches = regex.allMatches(url).toList();

    // Return the last match (usually the destination in directions URLs)
    // or the first match if there's only one
    if (matches.isNotEmpty) {
      final match = matches.last;
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null) {
        if (_isValidCoordinate(lat, lng)) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Parses a "lat,lng" string into LatLng
  static LatLng? _parseLatLngString(String value) {
    final parts = value.split(',');
    if (parts.length >= 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        if (_isValidCoordinate(lat, lng)) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Validates if coordinates are within valid range
  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Validates a Google Maps URL without parsing coordinates
  static bool isValidGoogleMapsUrl(String url) {
    if (url.isEmpty) return false;
    return _isGoogleMapsUrl(url);
  }
}
