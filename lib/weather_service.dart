import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.displayText,
    required this.latitude,
    required this.longitude,
  });

  final String displayText;
  final double latitude;
  final double longitude;
}

class WeatherService {
  Future<WeatherSnapshot?> fetchCurrentWeather() async {
    final position = await _resolvePosition();
    if (position == null) {
      return null;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      'current': 'temperature_2m,weather_code',
      'temperature_unit': 'fahrenheit',
      'timezone': 'auto',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final current = data['current'];
    if (current is! Map<String, dynamic>) {
      return null;
    }

    final temp = (current['temperature_2m'] as num?)?.round();
    final weatherCode = (current['weather_code'] as num?)?.toInt();
    if (temp == null || weatherCode == null) {
      return null;
    }

    return WeatherSnapshot(
      displayText: '${temp}F ${_weatherLabel(weatherCode)}',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<Position?> _resolvePosition() async {
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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
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
        return 'Weather';
    }
  }
}
