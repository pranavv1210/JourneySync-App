import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.displayText,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.rainChance,
    required this.windSpeed,
    required this.sunset,
    required this.sunrise,
    required this.visibility,
    required this.alerts,
  });

  final String displayText;
  final double latitude;
  final double longitude;
  final double temperature;
  final int rainChance;
  final double windSpeed;
  final String sunset;
  final String sunrise;
  final double visibility;
  final List<String> alerts;
}

class WeatherService {
  Future<WeatherSnapshot?> fetchCurrentWeather({
    double? latitude,
    double? longitude,
  }) async {
    final position =
        latitude != null && longitude != null ? null : await _resolvePosition();
    final lat = latitude ?? position?.latitude;
    final lng = longitude ?? position?.longitude;
    if (lat == null || lng == null) return null;

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'current': 'temperature_2m,weather_code,wind_speed_10m,visibility',
        'daily': 'sunrise,sunset,precipitation_probability_max',
        'temperature_unit': 'fahrenheit',
        'wind_speed_unit': 'mph',
        'timezone': 'auto',
        'forecast_days': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final current = data['current'];
      if (current is! Map<String, dynamic>) return null;

      final daily = data['daily'];
      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 72.0;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final visMeters = (current['visibility'] as num?)?.toDouble() ?? 10000.0;
      final vis = visMeters / 1000.0;

      var rainProb = 0;
      var sunriseStr = '06:00 AM';
      var sunsetStr = '07:00 PM';
      if (daily is Map<String, dynamic>) {
        final probs = daily['precipitation_probability_max'] as List?;
        if (probs != null && probs.isNotEmpty) {
          rainProb = (probs.first as num?)?.toInt() ?? 0;
        }

        final sunrises = daily['sunrise'] as List?;
        if (sunrises != null && sunrises.isNotEmpty) {
          sunriseStr = _formatTimeStr(sunrises.first?.toString());
        }

        final sunsets = daily['sunset'] as List?;
        if (sunsets != null && sunsets.isNotEmpty) {
          sunsetStr = _formatTimeStr(sunsets.first?.toString());
        }
      }

      final label = _weatherLabel(weatherCode);
      return WeatherSnapshot(
        displayText: '${temp.round()}°F $label',
        latitude: lat,
        longitude: lng,
        temperature: temp,
        rainChance: rainProb,
        windSpeed: wind,
        sunrise: sunriseStr,
        sunset: sunsetStr,
        visibility: vis,
        alerts: _generateAlerts(temp, rainProb, wind, vis),
      );
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return null;
    }
  }

  String _formatTimeStr(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '06:00 AM';
    try {
      final parsed = DateTime.parse(isoTime);
      return DateFormat('hh:mm a').format(parsed.toLocal());
    } catch (_) {
      final parts = isoTime.split('T');
      return parts.length == 2 ? parts[1] : isoTime;
    }
  }

  List<String> _generateAlerts(
    double temp,
    int rainChance,
    double windSpeed,
    double visibility,
  ) {
    final alerts = <String>[];
    if (temp > 95) {
      alerts.add('Extreme heat warning. Hydrate and take breaks.');
    } else if (temp < 40) {
      alerts.add('Cold weather warning. Watch for low-grip roads.');
    }
    if (rainChance > 50) {
      alerts.add('High rain chance ($rainChance%). Wet roads possible.');
    }
    if (windSpeed > 20) {
      alerts.add('High wind advisory (${windSpeed.round()} mph).');
    }
    if (visibility < 5.0) {
      alerts.add('Reduced visibility (${visibility.toStringAsFixed(1)} km).');
    }
    return alerts;
  }

  Future<Position?> _resolvePosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        return Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }

  String _weatherLabel(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
      case 3:
        return 'Cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Storm';
      default:
        return 'Clear';
    }
  }
}
