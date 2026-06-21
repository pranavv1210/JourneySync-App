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
  final double visibility; // in km
  final List<String> alerts;
}

class WeatherService {
  Future<WeatherSnapshot?> fetchCurrentWeather({
    double? latitude,
    double? longitude,
  }) async {
    double lat;
    double lng;

    if (latitude != null && longitude != null) {
      lat = latitude;
      lng = longitude;
    } else {
      final position = await _resolvePosition();
      if (position == null) {
        // Return a default mock snapshot so that the UI never breaks
        return _mockWeather(28.6139, 77.2090, "New Delhi (Simulated)");
      }
      lat = position.latitude;
      lng = position.longitude;
    }

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'current': 'temperature_2m,weather_code,wind_speed_10m,visibility',
        'daily': 'sunrise,sunset,precipitation_probability_max',
        'temperature_unit': 'fahrenheit',
        'wind_speed_unit': 'mph',
        'timezone': 'auto',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _mockWeather(lat, lng, "Simulated");
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return _mockWeather(lat, lng, "Simulated");
      }

      final current = data['current'];
      final daily = data['daily'];
      if (current is! Map<String, dynamic>) {
        return _mockWeather(lat, lng, "Simulated");
      }

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 72.0;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
      // visibility is returned in meters, convert to km
      final visMeters = (current['visibility'] as num?)?.toDouble() ?? 10000.0;
      final vis = visMeters / 1000.0;

      int rainProb = 0;
      String sunriseStr = "06:00 AM";
      String sunsetStr = "07:00 PM";

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
      final alerts = _generateAlerts(temp, rainProb, wind, vis);

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
        alerts: alerts,
      );
    } catch (e) {
      debugPrint("Error fetching weather: $e. Using simulated weather.");
      return _mockWeather(lat, lng, "Simulated");
    }
  }

  String _formatTimeStr(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return "06:00 AM";
    try {
      final parsed = DateTime.parse(isoTime);
      return DateFormat('hh:mm a').format(parsed.toLocal());
    } catch (_) {
      // If parsing fails, try to extract from string
      final parts = isoTime.split('T');
      if (parts.length == 2) {
        return parts[1];
      }
      return isoTime;
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
      alerts.add(
        "Extreme Heat Warning: Keep hydrated and take frequent breaks.",
      );
    } else if (temp < 40) {
      alerts.add(
        "Cold Weather Warning: Possibility of icy roads. Ride with caution.",
      );
    }
    if (rainChance > 50) {
      alerts.add(
        "High Chance of Rain ($rainChance%): Wet roads ahead. Wear rain gear.",
      );
    }
    if (windSpeed > 20) {
      alerts.add(
        "High Wind Advisory ($windSpeed mph): Crosswinds could affect stability.",
      );
    }
    if (visibility < 5.0) {
      alerts.add(
        "Reduced Visibility Alert ($visibility km): Fog/haze. Turn on fog lights.",
      );
    }
    return alerts;
  }

  WeatherSnapshot _mockWeather(double lat, double lng, String tag) {
    // Generate deterministic mock weather based on latitude and current hour
    final hour = DateTime.now().hour;
    final baseTemp =
        70.0 + (lat.abs() % 15) + (hour > 12 ? (24 - hour) : hour) * 0.5;
    final rainProb = ((lat.abs() * 10).toInt() + hour) % 100;
    final wind = 5.0 + ((lng.abs() + hour) % 15);
    final vis = 8.0 + (hour % 5);
    final label = rainProb > 60 ? "Rain" : (rainProb > 30 ? "Cloudy" : "Clear");
    final alerts = _generateAlerts(baseTemp, rainProb, wind, vis);

    return WeatherSnapshot(
      displayText: '${baseTemp.round()}°F $label ($tag)',
      latitude: lat,
      longitude: lng,
      temperature: baseTemp,
      rainChance: rainProb,
      windSpeed: wind,
      sunrise: "05:48 AM",
      sunset: "07:12 PM",
      visibility: vis,
      alerts: alerts,
    );
  }

  Future<Position?> _resolvePosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
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
