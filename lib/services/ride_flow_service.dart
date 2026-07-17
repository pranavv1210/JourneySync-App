import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_record.dart';
import '../models/ride_route.dart';
import 'ride_service.dart';
import 'supabase_service.dart';

class RideFlowSession {
  const RideFlowSession({
    required this.userId,
    required this.userName,
    required this.userBike,
  });

  final String userId;
  final String userName;
  final String userBike;
}

class RideFlowLocation {
  const RideFlowLocation({required this.label, this.latitude, this.longitude});

  final String label;
  final double? latitude;
  final double? longitude;

  String get coordinateLabel {
    if (latitude == null || longitude == null) return label;
    return '${latitude!.toStringAsFixed(6)},${longitude!.toStringAsFixed(6)}';
  }
}

class RideFlowService {
  RideFlowService({RideService? rideService, SupabaseService? supabaseService})
    : _rideService = rideService ?? RideService(),
      _supabaseService = supabaseService ?? SupabaseService();

  final RideService _rideService;
  final SupabaseService _supabaseService;

  Future<RideFlowSession> resolveSession() async {
    final prefs = await SharedPreferences.getInstance();
    var userId = (prefs.getString('userId') ?? '').trim();
    final userName = (prefs.getString('userName') ?? 'Rider').trim();
    final userBike = (prefs.getString('userBike') ?? 'No bike added').trim();

    if (userId.isEmpty) {
      final row = await _supabaseService.fetchOrCreateCurrentUserProfile(
        cachedUserId: userId,
        cachedPhone: prefs.getString('userPhone') ?? '',
        cachedName: userName.isEmpty ? 'Rider' : userName,
        cachedBike: userBike.isEmpty ? 'No bike added' : userBike,
      );
      userId = (row?['id'] ?? row?['auth_user_id'] ?? '').toString().trim();
      if (userId.isNotEmpty) {
        await prefs.setString('userId', userId);
      }
    }

    if (userId.isEmpty) {
      throw Exception('Profile session unavailable. Sign in again.');
    }

    return RideFlowSession(
      userId: userId,
      userName: userName.isEmpty ? 'Rider' : userName,
      userBike: userBike.isEmpty ? 'No bike added' : userBike,
    );
  }

  Future<RideFlowLocation> resolveCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const RideFlowLocation(label: 'Current location unavailable');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const RideFlowLocation(label: 'Location permission not granted');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return RideFlowLocation(
      label:
          '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<RideRecord> createRide({
    required String title,
    required String startLocation,
    required String endLocation,
    required String rideVisibility,
    required String rideMode,
    required String status,
    DateTime? scheduledStartTime,
    int? maxRiders,
  }) async {
    final session = await resolveSession();
    return _rideService.createRide(
      creatorId: session.userId,
      title: title,
      startLocation: startLocation,
      endLocation: endLocation,
      scheduledStartTime: scheduledStartTime,
      maxRiders: maxRiders,
      rideVisibility: rideVisibility,
      rideMode: rideMode,
      status: status,
    );
  }

  Future<void> saveSimpleRoute({
    required RideRecord ride,
    required String startLabel,
    required String endLabel,
  }) async {
    final session = await resolveSession();
    await _rideService.saveRideRoute(
      rideId: ride.id,
      hostId: session.userId,
      startLabel: startLabel,
      endLabel: endLabel,
      stops: [
        RouteStop(label: startLabel, order: 0),
        RouteStop(label: endLabel, order: 1),
      ],
    );
  }

  Future<void> startRide(String rideId) => _rideService.startRide(rideId);
}
