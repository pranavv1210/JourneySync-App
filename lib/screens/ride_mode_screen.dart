import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rider_location.dart';
import '../coordinators/active_ride_coordinator.dart';
import '../coordinators/realtime_coordinator.dart' hide unawaited;
import '../services/live_tracking_service.dart' hide unawaited;
import '../services/fuel_service.dart';
import '../services/group_ride_intelligence.dart';
import '../services/navigation_service.dart';
import '../services/notification_service.dart';
import '../services/ride_analytics_engine.dart';
import '../services/ride_engine_core.dart';
import '../services/ride_service.dart';
import '../services/supabase_service.dart';
import '../services/weather_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_dialog.dart';
import '../widgets/realtime_ride_hud.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/rider_marker.dart';
import '../widgets/ride_loading_indicator.dart';
import '../widgets/smooth_marker.dart';
import '../theme/app_theme.dart';
import '../models/presence_info.dart';
import '../models/ride_route.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideModeScreen — Production-Grade Live Rider Tracking
// ─────────────────────────────────────────────────────────────────────────────

class RideModeScreen extends StatefulWidget {
  const RideModeScreen({super.key, required this.rideId});
  final String rideId;

  @override
  State<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends State<RideModeScreen>
    with TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final RideService _rideService = RideService();
  final SupabaseService _supabaseService = SupabaseService();
  final LiveTrackingService _trackingService =
      ActiveRideCoordinator.instance.trackingService;
  final RealtimeCoordinator _realtimeCoordinator = RealtimeCoordinator.instance;
  final MapController _mapController = MapController();
  final Battery _battery = Battery();
  late final RideAnalyticsEngine _analyticsEngine;
  final WeatherService _weatherService = WeatherService();
  final FuelService _fuelService = FuelService();

  // ── User / Ride state ──────────────────────────────────────────────────────
  bool _loading = true;
  String _currentUserId = '';
  String _currentUserName = 'Rider';
  String _currentBikeName = 'No bike added';
  String _currentUserAvatarUrl = '';
  String? _leaderId;
  Map<String, dynamic>? _rideData;

  // ── Live locations ─────────────────────────────────────────────────────────
  List<RiderLocation> _riderLocations = [];
  StreamSubscription<List<RiderLocation>>? _locationStreamSub;

  // ── GPS / position ─────────────────────────────────────────────────────────
  Position? _currentPosition;
  StreamSubscription<Position>? _gpsStreamSub;

  // ── Connectivity ───────────────────────────────────────────────────────────
  bool _isOffline = false;

  // ── Follow leader mode ─────────────────────────────────────────────────────
  bool _followingLeader = false;
  bool _followMe = true;
  bool _fitGroupMode = false;
  bool _smartAutoMode = true;
  bool _programmaticCameraMove = false;
  DateTime _autoFollowResumeAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Telemetry V2 (Garmin-Level metrics) ────────────────────────────────────
  double _distanceTravelled = 0.0;
  double _currentSpeed = 0.0;
  double _avgSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _altitude = 0.0;
  String _gpsQuality = 'Weak';
  bool _isFallingBehind = false;
  Position? _prevPosition;

  // ── SOS ───────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _activeAlert;
  String _lastAlertKey = '';
  Timer? _alertDismissTimer;
  late AnimationController _sosPulseController;
  List<Map<String, String>> _emergencyContacts = const <Map<String, String>>[];

  // ── Ride timer ─────────────────────────────────────────────────────────────
  int _secondsElapsed = 0;
  Timer? _rideTimer;

  // ── Route sync ─────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  double? _destinationLat;
  double? _destinationLng;
  RideRoute? _rideRoute;
  WeatherSnapshot? _weatherSnapshot;
  DateTime? _lastWeatherAlertAt;
  bool _fuelSuggestionShown = false;
  bool _breakReminderShown = false;

  // ── Tracking active badge animation ───────────────────────────────────────
  late AnimationController _trackingPulse;

  // ── Interpolated positions cache (for smooth markers) ──────────────────────
  /// Maps userId → current smoothly-interpolated LatLng.
  /// Updated by SmoothMarker builders and used to track the animated position.
  final Map<String, LatLng> _interpolatedPositions = {};
  final RiderDistanceCache _distanceCache = RiderDistanceCache();
  final GroupRideIntelligence _groupIntelligence = GroupRideIntelligence();
  GroupRideSnapshot _groupSnapshot = const GroupRideSnapshot(
    riders: <GroupRiderSnapshot>[],
    leaderId: null,
    totalRiders: 0,
    trackingRiders: 0,
    averageSpeedKmh: 0,
    groupSpreadMeters: 0,
    healthRating: GroupHealthRating.needsAttention,
    healthScore: 0,
  );
  late AnimationController _markerFrameController;
  late AnimationController _cameraController;
  VoidCallback? _cameraTickListener;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _analyticsEngine = RideAnalyticsEngine(rideId: widget.rideId);

    _trackingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _markerFrameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    ActiveRideCoordinator.instance.addListener(_onActiveRideSnapshotChanged);
    _realtimeCoordinator.addListener(_onRealtimeChanged);
    _initRideMode();
  }

  Future<void> _initRideMode() async {
    try {
      // ── Load user prefs ──────────────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = (prefs.getString('userId') ?? '').trim();
      _currentUserName = (prefs.getString('userName') ?? 'Rider').trim();
      _currentUserAvatarUrl = (prefs.getString('userAvatarUrl') ?? '').trim();
      _currentBikeName =
          (prefs.getString('userBike') ?? 'No bike added').trim();
      _emergencyContacts = _decodeEmergencyContacts(
        prefs.getStringList('emergencyContacts') ?? const <String>[],
      );

      // ── Fetch ride data ──────────────────────────────────────────────────
      final ride = await _supabaseService.fetchRideById(widget.rideId);
      if (ride == null) throw Exception('Ride not found');

      _leaderId =
          (ride['host_id'] ??
                  ride['profile_id'] ??
                  ride['creator_id'] ??
                  ride['user_id'] ??
                  '')
              .toString()
              .trim();
      _rideData = ride;

      // ── Start timer ──────────────────────────────────────────────────────
      _startRideTimer();

      // ── Start GPS position stream (local, for UI position dot) ───────────
      await _startLocalGpsStream();
      await _primeRideWeather();
      await _analyticsEngine.start(weather: _weatherSnapshot);

      // ── Start enriched sync via LiveTrackingService ──────────────────────
      _trackingService.batteryLevelProvider = _getBatteryLevel;
      await _trackingService.startSyncing(
        rideId: widget.rideId,
        userId: _currentUserId,
        userName: _currentUserName,
        bikeName: _currentBikeName,
        isLeader: _leaderId == _currentUserId,
      );
      await ActiveRideCoordinator.instance.attachRide(
        rideId: widget.rideId,
        profileId: _currentUserId,
        profileName: _currentUserName,
        bikeName: _currentBikeName,
        startTracking: false,
      );

      // ── Subscribe to incoming rider positions ────────────────────────────
      _locationStreamSub = _trackingService
          .watchRideLocations(widget.rideId)
          .listen(_onRiderLocationsUpdate);

      // ── Fetch initial route ───────────────────────────────────────────────
      try {
        final routeData = await _rideService.fetchRideRouteMap(widget.rideId);
        if (routeData != null) _onRouteUpdate(routeData);
      } catch (_) {}

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Error starting ride: $e',
        type: AppToastType.error,
      );
      Navigator.pop(context);
    }
  }

  // ── GPS stream (local display only — tracking service handles upload) ──────
  Future<void> _startLocalGpsStream() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    _gpsStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      _currentPosition = pos;
      final speedKmh = pos.speed >= 0 ? pos.speed * 3.6 : 0.0;

      if (_prevPosition != null) {
        final distMeters = Geolocator.distanceBetween(
          _prevPosition!.latitude,
          _prevPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        _distanceTravelled += distMeters / 1000.0;
      }

      _currentSpeed = speedKmh;
      if (speedKmh > _maxSpeed) {
        _maxSpeed = speedKmh;
      }

      _avgSpeed =
          _secondsElapsed > 0
              ? (_distanceTravelled / (_secondsElapsed / 3600.0))
              : 0.0;
      _altitude = pos.altitude;

      if (pos.accuracy <= 10) {
        _gpsQuality = 'Strong';
      } else if (pos.accuracy <= 30) {
        _gpsQuality = 'Medium';
      } else {
        _gpsQuality = 'Weak';
      }

      _analyticsEngine.recordPosition(pos);
      _maybeShowRideIntelligencePrompts(pos);
      _prevPosition = pos;
      if (mounted) setState(() {});
    });
  }

  Future<void> _primeRideWeather() async {
    try {
      _weatherSnapshot = await _weatherService.fetchCurrentWeather(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      final weather = _weatherSnapshot;
      if (weather != null && weather.alerts.isNotEmpty && mounted) {
        _lastWeatherAlertAt = DateTime.now();
        showAppToast(context, weather.alerts.first, type: AppToastType.info);
      }
    } catch (_) {}
  }

  void _maybeShowRideIntelligencePrompts(Position position) {
    final weather = _weatherSnapshot;
    if (weather != null &&
        weather.alerts.isNotEmpty &&
        (_lastWeatherAlertAt == null ||
            DateTime.now().difference(_lastWeatherAlertAt!) >
                const Duration(minutes: 45))) {
      _lastWeatherAlertAt = DateTime.now();
      showAppToast(context, weather.alerts.first, type: AppToastType.info);
    }

    if (!_breakReminderShown &&
        (_secondsElapsed >= 7200 || _distanceTravelled >= 150)) {
      _breakReminderShown = true;
      showAppToast(
        context,
        'Consider taking a short break.',
        type: AppToastType.info,
      );
    }

    final hasFuelStop = (_rideRoute?.stops ?? <RouteStop>[]).any(
      (stop) => stop.label.toLowerCase().contains('fuel'),
    );
    if (!_fuelSuggestionShown && !hasFuelStop && _distanceTravelled >= 80) {
      _fuelSuggestionShown = true;
      _showFuelSuggestion(position).ignore();
    }
  }

  Future<void> _showFuelSuggestion(Position position) async {
    try {
      final stations = await _fuelService.fetchNearbyFuelStations(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted || stations.isEmpty) return;
      final nearest = stations.first;
      if (nearest.distanceKm <= 8) {
        showAppToast(
          context,
          'Fuel nearby: ${nearest.name} (${nearest.distanceKm.toStringAsFixed(1)} km).',
          type: AppToastType.info,
        );
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALLBACKS
  // ─────────────────────────────────────────────────────────────────────────

  void _onRiderLocationsUpdate(List<RiderLocation> locations) {
    if (!mounted) return;

    // Check our own offline status from the service.
    final nowOffline = _trackingService.isOffline;

    final snapshot = _groupIntelligence.update(
      locations: locations,
      leaderId: _leaderId,
      currentUserId: _currentUserId,
      destination: _getDestinationCoords(),
      sosRiderId: _activeSosRiderId(),
    );
    final leaderDistances =
        _leaderId == null
            ? const <String, double>{}
            : _distanceCache.update(locations: locations, leaderId: _leaderId!);

    // Calculate falling behind status (>2 km from leader)
    bool isFallingBehind = false;
    if (_leaderId != null && _leaderId != _currentUserId) {
      final cachedDistance = leaderDistances[_currentUserId];
      isFallingBehind = cachedDistance != null && cachedDistance > 2000;
    }

    setState(() {
      _riderLocations = locations;
      _isOffline = nowOffline;
      _isFallingBehind = isFallingBehind;
      _groupSnapshot = snapshot;
    });

    _analyticsEngine.recordGroupSnapshot(snapshot);
    _handleGroupAlerts(snapshot);
    _driveCamera(locations);
  }

  void _onRealtimeChanged() {
    if (!mounted) return;
    final state = _realtimeCoordinator.connectionState;
    setState(() {
      _isOffline =
          _trackingService.isOffline ||
          state == RealtimeConnectionState.offline ||
          state == RealtimeConnectionState.reconnecting;
    });
  }

  void _onActiveRideSnapshotChanged() {
    if (!mounted) return;
    final snapshot = ActiveRideCoordinator.instance.snapshot;
    if (snapshot.locations.isNotEmpty) {
      _onRiderLocationsUpdate(snapshot.locations);
    }

    final alert = snapshot.lastAlert;
    if (alert != null) {
      final key = '${alert['id'] ?? ''}:${alert['created_at'] ?? ''}';
      if (key != _lastAlertKey) {
        _lastAlertKey = key;
        _onSosAlert(alert);
      }
    }

    final route = snapshot.route;
    if (route != null) {
      if (_rideRoute != null && route.stops.length > _rideRoute!.stops.length) {
        final newStop = route.stops.last;
        String stopName = newStop.label;
        if (newStop.label.contains(':')) {
          stopName = newStop.label.split(':').sublist(1).join(':').trim();
        }
        showAppToast(
          context,
          "New Pit Stop: $stopName",
          type: AppToastType.success,
        );
      }
      _rideRoute = route;

      final stopsWithCoords =
          route.stops
              .where((stop) => stop.latitude != null && stop.longitude != null)
              .toList();
      final destination =
          stopsWithCoords.isNotEmpty ? stopsWithCoords.last : null;
      _onRouteUpdate({
        'destination_lat': destination?.latitude,
        'destination_lng': destination?.longitude,
        'route_points':
            stopsWithCoords
                .map((stop) => {'lat': stop.latitude, 'lng': stop.longitude})
                .toList(),
      });
    }
  }

  void _driveCamera(List<RiderLocation> locations) {
    if (DateTime.now().isBefore(_autoFollowResumeAt)) return;
    if (_smartAutoMode) {
      if (_groupSnapshot.groupSpreadMeters > 1200 && locations.length > 1) {
        _fitRiders(locations);
        return;
      }
      final leader = _groupSnapshot.leader;
      if (leader != null && leader.speedKmh > 20) {
        _animateCamera(
          center: LatLng(leader.location.latitude, leader.location.longitude),
          zoom: math.max(_mapController.camera.zoom, 15),
          bearing: leader.location.heading,
        );
        return;
      }
    }
    if (_fitGroupMode && locations.length > 1) {
      _fitRiders(locations);
      return;
    }
    if (_followingLeader && _leaderId != null) {
      final leader = locations.where((l) => l.userId == _leaderId).firstOrNull;
      if (leader != null) {
        _animateCamera(
          center: LatLng(leader.latitude, leader.longitude),
          zoom: math.max(_mapController.camera.zoom, 15),
          bearing: leader.heading,
        );
      }
      return;
    }
    if (_followMe && _currentPosition != null) {
      _animateCamera(
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: math.max(_mapController.camera.zoom, 15),
        bearing:
            _currentPosition!.heading >= 0 ? _currentPosition!.heading : null,
      );
    }
  }

  void _handleGroupAlerts(GroupRideSnapshot snapshot) {
    if (_leaderId != _currentUserId) return;
    final alerts = _groupIntelligence.detectAlerts(snapshot);
    for (final alert in alerts.take(2)) {
      showAppToast(
        context,
        alert.message,
        type:
            alert.type == GroupAlertType.reconnected ||
                    alert.type == GroupAlertType.resumed
                ? AppToastType.success
                : AppToastType.info,
      );
    }
  }

  void _fitRiders(List<RiderLocation> locations) {
    final points = locations
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList(growable: false);
    if (points.length < 2) return;

    final fitted = CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.fromLTRB(64, 120, 64, 260),
      maxZoom: 15.5,
      minZoom: 5,
    ).fit(_mapController.camera);
    _animateCamera(center: fitted.center, zoom: fitted.zoom);
  }

  void _animateCamera({
    required LatLng center,
    required double zoom,
    double? bearing,
  }) {
    final camera = _mapController.camera;
    final startCenter = camera.center;
    final startZoom = camera.zoom;
    final startBearing = camera.rotation;
    final targetBearing =
        bearing == null
            ? startBearing
            : startBearing + RideEngineCore.headingDelta(startBearing, bearing);
    final distance = const Distance().as(LengthUnit.Meter, startCenter, center);
    if (distance < 2 &&
        (startZoom - zoom).abs() < 0.02 &&
        (startBearing - targetBearing).abs() < 0.5) {
      return;
    }

    final oldListener = _cameraTickListener;
    if (oldListener != null) {
      _cameraController.removeListener(oldListener);
      _cameraTickListener = null;
    }
    _cameraController.stop();
    _cameraController.reset();
    void tick() {
      final t = Curves.easeOutCubic.transform(_cameraController.value);
      final nextCenter = LatLng(
        ui.lerpDouble(startCenter.latitude, center.latitude, t)!,
        ui.lerpDouble(startCenter.longitude, center.longitude, t)!,
      );
      final nextZoom = ui.lerpDouble(startZoom, zoom, t)!;
      final nextBearing = ui.lerpDouble(startBearing, targetBearing, t)!;
      _programmaticCameraMove = true;
      _mapController.moveAndRotate(
        nextCenter,
        nextZoom.clamp(4.0, 18.0),
        nextBearing % 360,
      );
      _programmaticCameraMove = false;
    }

    _cameraTickListener = tick;
    _cameraController
      ..addListener(tick)
      ..forward().whenCompleteOrCancel(() {
        _cameraController.removeListener(tick);
        if (_cameraTickListener == tick) {
          _cameraTickListener = null;
        }
      });
  }

  void _onSosAlert(Map<String, dynamic> alert) {
    if (!mounted) return;
    HapticFeedback.vibrate();
    Future.delayed(
      const Duration(milliseconds: 300),
      () => HapticFeedback.vibrate(),
    );
    Future.delayed(
      const Duration(milliseconds: 600),
      () => HapticFeedback.vibrate(),
    );
    setState(() => _activeAlert = alert);
    _alertDismissTimer?.cancel();
    _alertDismissTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _activeAlert = null);
    });
  }

  void _onRouteUpdate(Map<String, dynamic> data) {
    try {
      final destLat = (data['destination_lat'] as num?)?.toDouble();
      final destLng = (data['destination_lng'] as num?)?.toDouble();

      if (destLat != null && destLng != null) {
        _destinationLat = destLat;
        _destinationLng = destLng;
      }

      final List<dynamic>? pointsRaw = data['route_points'];
      if (pointsRaw != null && pointsRaw.isNotEmpty) {
        _routePoints =
            pointsRaw
                .map(
                  (p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ),
                )
                .toList();
      }
      _analyticsEngine.recordRouteStops(
        _rideRoute?.stops ?? const <RouteStop>[],
      );

      final hasRoute =
          _routePoints.isNotEmpty || (destLat != null && destLng != null);
      setState(() {});

      if (hasRoute && mounted) {
        showAppToast(context, 'Route synchronized!', type: AppToastType.info);
      }
    } catch (e) {
      debugPrint('[RideMode] Route parse error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _startRideTimer() {
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  Future<int?> _getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<void> _triggerSOS() async {
    unawaited(HapticFeedback.heavyImpact());
    try {
      _trackingService.setEmergencySync(true);
      _analyticsEngine.recordSos();
      await _realtimeCoordinator.triggerSOS(
        rideId: widget.rideId,
        profileId: _currentUserId,
        profileName: _currentUserName,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      await _realtimeCoordinator.updateMyPresence(
        profileId: _currentUserId,
        status: RiderPresenceStatus.sos,
        currentRideId: widget.rideId,
      );
      if (mounted) showAppToast(context, 'SOS Alert Sent!');
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Could not send SOS. Please try again.',
          type: AppToastType.error,
        );
      }
    }
  }

  void _showRidersSheet() {
    final riders = [..._riderLocations];
    if (!riders.any((rider) => rider.userId == _currentUserId) &&
        _currentPosition != null) {
      riders.insert(
        0,
        RiderLocation(
          userId: _currentUserId,
          rideId: widget.rideId,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          updatedAt: DateTime.now(),
          userName: _currentUserName,
          bikeName: _currentBikeName,
          isLeader: _leaderId == _currentUserId,
          heading:
              _currentPosition!.heading >= 0 ? _currentPosition!.heading : null,
          speed: _currentSpeed / 3.6,
          avatarUrl: _currentUserAvatarUrl,
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Live Riders',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (riders.isEmpty)
                      Text(
                        'No riders are broadcasting yet.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      ...riders.map((rider) {
                        final isYou = rider.userId == _currentUserId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage:
                                rider.avatarUrl?.trim().isNotEmpty == true
                                    ? NetworkImage(rider.avatarUrl!.trim())
                                    : null,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            child:
                                rider.avatarUrl?.trim().isNotEmpty == true
                                    ? null
                                    : Text(
                                      (isYou
                                              ? 'Y'
                                              : rider.userName.trim().isEmpty
                                              ? 'R'
                                              : rider.userName.trim()[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                          ),
                          title: Text(
                            isYou ? 'You' : rider.userName,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            rider.bikeName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.my_location_rounded),
                            color: AppColors.primary,
                            onPressed: () {
                              Navigator.pop(context);
                              _animateCamera(
                                center: LatLng(rider.latitude, rider.longitude),
                                zoom: 16,
                                bearing: rider.heading,
                              );
                            },
                          ),
                        );
                      }),
                    if (riders.length > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _fitGroupMode = true;
                              _followMe = false;
                              _followingLeader = false;
                              _smartAutoMode = false;
                            });
                            _fitRiders(riders);
                          },
                          icon: const Icon(Icons.groups_rounded),
                          label: const Text('Fit all riders on map'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  LatLng? _getDestinationCoords() {
    if (_destinationLat != null && _destinationLng != null) {
      return LatLng(_destinationLat!, _destinationLng!);
    }
    final ride = _rideData;
    if (ride == null) return null;
    final dest = ride['end_location'] ?? ride['destination'];
    if (dest is String) {
      final parts = dest.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }
    if (_routePoints.isNotEmpty) return _routePoints.last;
    return null;
  }

  Future<void> _addPitStop(
    String type,
    String name,
    double lat,
    double lng,
  ) async {
    if (_rideData == null) return;

    final currentStops = _rideRoute?.stops ?? <RouteStop>[];

    final newStop = RouteStop(
      label: "$type: $name",
      latitude: lat,
      longitude: lng,
      order: currentStops.length + 1,
    );

    final updatedStops = [...currentStops, newStop];

    try {
      final startLabel = _rideData?['start_location']?.toString() ?? "Start";
      final endLabel = _rideData?['end_location']?.toString() ?? "Destination";

      await _supabaseService.saveRideRoute(
        rideId: widget.rideId,
        hostId: _leaderId ?? _currentUserId,
        startLabel: startLabel,
        endLabel: endLabel,
        stops: updatedStops,
      );

      // Trigger local state update
      await ActiveRideCoordinator.instance.refreshRoute();

      if (mounted) {
        showAppToast(
          context,
          "Pit stop added: $name",
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          "Failed to add pit stop: $e",
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _launchNavigation() async {
    final dest = _getDestinationCoords();
    if (dest == null) {
      if (mounted) {
        showAppToast(
          context,
          'Destination not available',
          type: AppToastType.error,
        );
      }
      return;
    }
    final name = _rideData?['title'] ?? _rideData?['name'] ?? 'Destination';
    await NavigationService.navigateToDestination(
      context,
      dest.latitude,
      dest.longitude,
      destinationName: name.toString(),
    );
  }

  Future<void> _endRide() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'End Ride?',
      message: 'This will stop tracking and complete your journey.',
      confirmLabel: 'End Ride',
      cancelLabel: 'Cancel',
      destructive: true,
    );

    if (confirmed != true) return;

    try {
      final destination =
          (_rideData?['end_location'] ?? _rideData?['destination'] ?? '')
              .toString();
      final analytics = await _analyticsEngine.complete(
        destination: destination,
      );
      await _trackingService.stopSyncing();
      await _rideService.finishRide(widget.rideId);
      await _trackingService.clearLiveLocation(
        rideId: widget.rideId,
        userId: _currentUserId,
      );
      await ActiveRideCoordinator.instance.markCompleted();
      NotificationService.instance
          .showLocal(
            title: 'Ride summary ready',
            body:
                'Ride Score: ${analytics.rideScore} ${RideAnalyticsEngine.scoreLabelText(analytics.scoreLabel)}',
          )
          .ignore();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error ending ride: $e', type: AppToastType.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _rideTimer?.cancel();
    _alertDismissTimer?.cancel();
    _trackingPulse.dispose();
    _markerFrameController.dispose();
    _cameraController.dispose();
    _sosPulseController.dispose();
    _locationStreamSub?.cancel();
    _gpsStreamSub?.cancel();
    ActiveRideCoordinator.instance.removeListener(_onActiveRideSnapshotChanged);
    _realtimeCoordinator.removeListener(_onRealtimeChanged);
    _distanceCache.clear();
    _groupIntelligence.clear();
    // Note: _trackingService.dispose() is NOT called here because the user
    // might minimize the app and come back. Call stopSyncing() + clearLiveLocation()
    // only on intentional ride end. The service auto-reconnects.
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: RideLoadingIndicator(
            label: 'Starting live ride...',
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── MAP LAYER ────────────────────────────────────────────────────
          _buildMap(),

          // ── SOS OVERLAY ──────────────────────────────────────────────────
          if (_activeAlert != null) _buildSOSOverlay(),

          // ── TOP HUD ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopHUD(),
                AnimatedBuilder(
                  animation: _realtimeCoordinator,
                  builder:
                      (context, _) => ConnectionStatusBar(
                        state:
                            _isOffline
                                ? RealtimeConnectionState.reconnecting
                                : _realtimeCoordinator.connectionState,
                      ),
                ),
              ],
            ),
          ),

          // ── FALLING BEHIND WARNING ────────────────────────────────────────
          if (_isFallingBehind)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "YOU'RE FALLING BEHIND",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Leader is more than 2 km ahead. Increase speed.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── FLOATING MAP CONTROLS ─────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 116,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleButton(
                  icon: Icons.my_location_rounded,
                  color: Colors.blue,
                  onTap: () {
                    if (_currentPosition != null) {
                      _animateCamera(
                        center: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                        bearing:
                            _currentPosition!.heading >= 0
                                ? _currentPosition!.heading
                                : null,
                      );
                    }
                    setState(() {
                      _followMe = true;
                      _followingLeader = false;
                      _fitGroupMode = false;
                      _smartAutoMode = false;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _CircleButton(
                  icon: Icons.auto_awesome_rounded,
                  color:
                      _riderLocations.isNotEmpty
                          ? const Color(0xFF0F766E)
                          : Colors.grey,
                  onTap:
                      _riderLocations.isNotEmpty
                          ? () {
                            setState(() {
                              _smartAutoMode = true;
                              _followMe = false;
                              _followingLeader = false;
                              _fitGroupMode = false;
                            });
                            _driveCamera(_riderLocations);
                          }
                          : null,
                ),
                const SizedBox(height: 12),
                _CircleButton(
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF6D28D9),
                  onTap: _showRidersSheet,
                ),
                const SizedBox(height: 12),
                _CircleButton(
                  icon: Icons.navigation_rounded,
                  color:
                      _getDestinationCoords() != null
                          ? const Color(0xFF4CAF50)
                          : Colors.grey,
                  onTap:
                      _getDestinationCoords() != null
                          ? _launchNavigation
                          : null,
                ),
                const SizedBox(height: 12),
                _CircleButton(
                  icon: Icons.warning_rounded,
                  color: Colors.red,
                  onTap: _triggerSOS,
                ),
              ],
            ),
          ),

          // ── REALTIME HUD ──────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RealtimeRideHUD(
              riderLocations: _riderLocations,
              groupSnapshot: _groupSnapshot,
              currentUserId: _currentUserId,
              leaderId: _leaderId,
              secondsElapsed: _secondsElapsed,
              distanceTravelled: _distanceTravelled,
              currentSpeed: _currentSpeed,
              avgSpeed: _avgSpeed,
              maxSpeed: _maxSpeed,
              altitude: _altitude,
              gpsQuality: _gpsQuality,
              isOffline: _isOffline,
              followingLeader: _followingLeader,
              onFollowLeaderToggled: (val) {
                setState(() {
                  _followingLeader = val;
                  _followMe = !val;
                  _fitGroupMode = false;
                  _smartAutoMode = false;
                });
              },
              onEndRide: _endRide,
              currentLatitude: _currentPosition?.latitude,
              currentLongitude: _currentPosition?.longitude,
              pitStops: _rideRoute?.stops ?? <RouteStop>[],
              onAddPitStop: _addPitStop,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final initialCenter =
        _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(20.5, 78.9);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 15.0,
        onPositionChanged: (_, hasGesture) {
          if (!hasGesture || _programmaticCameraMove) return;
          _autoFollowResumeAt = DateTime.now().add(const Duration(seconds: 20));
          if (_followMe ||
              _followingLeader ||
              _fitGroupMode ||
              _smartAutoMode) {
            setState(() {
              _followMe = false;
              _followingLeader = false;
              _fitGroupMode = false;
              _smartAutoMode = false;
            });
          }
        },
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.journeysync.app',
        ),
        // Route polyline
        PolylineLayer(polylines: _buildPolylines()),
        PolylineLayer(polylines: _buildTrailPolylines()),
        // Markers
        AnimatedBuilder(
          animation: _markerFrameController,
          builder: (context, _) => _buildMarkerLayer(),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    if (_routePoints.isNotEmpty) {
      final splitIndex = _nearestRoutePointIndex();
      final completed =
          splitIndex > 0 ? _routePoints.take(splitIndex + 1).toList() : null;
      final upcoming = _routePoints.skip(math.max(0, splitIndex)).toList();

      if (completed != null && completed.length > 1) {
        polylines.add(
          Polyline(
            points: completed,
            strokeWidth: 4.0,
            color: const Color(0xFF64748B).withValues(alpha: 0.36),
          ),
        );
      }
      if (upcoming.length > 1) {
        polylines.add(
          Polyline(
            points: upcoming,
            strokeWidth: 5.0,
            color: const Color(0xFFD97706),
            borderColor: const Color(0xFFFF6A00).withValues(alpha: 0.28),
            borderStrokeWidth: 2,
          ),
        );
      }
    } else if (_destinationLat != null &&
        _destinationLng != null &&
        _currentPosition != null) {
      // Fallback straight line to destination
      polylines.add(
        Polyline(
          points: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(_destinationLat!, _destinationLng!),
          ],
          strokeWidth: 4.0,
          color: const Color(0xFFD97706).withValues(alpha: 0.7),
        ),
      );
    }

    return polylines;
  }

  List<Polyline> _buildTrailPolylines() {
    final polylines = <Polyline>[];
    for (final rider in _groupSnapshot.riders) {
      final trail = rider.trail;
      if (trail.length < 2) continue;
      final isLeader =
          rider.location.userId == _leaderId || rider.location.isLeader;
      polylines.add(
        Polyline(
          points: trail,
          strokeWidth: isLeader ? 4 : 3,
          color: (isLeader ? const Color(0xFFFF6A00) : const Color(0xFF2563EB))
              .withValues(alpha: 0.28),
        ),
      );
    }
    return polylines;
  }

  int _nearestRoutePointIndex() {
    if (_routePoints.isEmpty || _currentPosition == null) return 0;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    final current = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
    for (var i = 0; i < _routePoints.length; i++) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        current,
        _routePoints[i],
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  Widget _buildMarkerLayer() {
    final markers = <Marker>[];

    // ── Destination marker ───────────────────────────────────────────────
    if (_destinationLat != null && _destinationLng != null) {
      markers.add(
        Marker(
          key: const ValueKey('destination'),
          point: LatLng(_destinationLat!, _destinationLng!),
          width: 60,
          height: 80,
          child: DestinationMarker(
            label: (_rideData?['title'] ?? 'Destination').toString(),
          ),
        ),
      );
    }

    // ── Pit stop markers ──────────────────────────────────────────────────
    if (_rideRoute != null) {
      for (final stop in _rideRoute!.stops) {
        if (stop.latitude != null && stop.longitude != null) {
          final isDest =
              _destinationLat != null &&
              _destinationLng != null &&
              (stop.latitude! - _destinationLat!).abs() < 0.0001 &&
              (stop.longitude! - _destinationLng!).abs() < 0.0001;
          if (isDest) continue;

          String type = 'tea';
          String name = stop.label;
          if (stop.label.contains(':')) {
            final parts = stop.label.split(':');
            type = parts[0].trim().toLowerCase();
            name = parts.sublist(1).join(':').trim();
          }

          IconData icon = Icons.local_cafe_rounded;
          Color color = Colors.brown;
          if (type == 'tea') {
            icon = Icons.local_cafe_rounded;
            color = Colors.brown;
          } else if (type == 'fuel') {
            icon = Icons.local_gas_station_rounded;
            color = Colors.amber.shade700;
          } else if (type == 'food') {
            icon = Icons.restaurant_rounded;
            color = Colors.red;
          } else if (type == 'rest') {
            icon = Icons.airline_seat_flat_rounded;
            color = Colors.blue;
          }

          markers.add(
            Marker(
              key: ValueKey('pitstop_${stop.order}_${stop.latitude}'),
              point: LatLng(stop.latitude!, stop.longitude!),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  showAppToast(
                    context,
                    "${type.toUpperCase()} Stop: $name",
                    type: AppToastType.info,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Center(child: Icon(icon, color: color, size: 20)),
                ),
              ),
            ),
          );
        }
      }
    }

    // ── Current user marker (always show, from GPS stream) ────────────────
    if (_currentPosition != null) {
      // Only show separate current-user dot if they're NOT in the live list yet
      final inLiveList = _riderLocations.any((l) => l.userId == _currentUserId);
      if (!inLiveList) {
        markers.add(
          Marker(
            key: ValueKey('current_user_dot_$_currentUserId'),
            point: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            width: 86,
            height: 104,
            child: RiderMarker(
              location: RiderLocation(
                userId: _currentUserId,
                rideId: widget.rideId,
                latitude: _currentPosition!.latitude,
                longitude: _currentPosition!.longitude,
                updatedAt: DateTime.now(),
                userName: _currentUserName,
                bikeName: _currentBikeName,
                isLeader: _leaderId == _currentUserId,
                heading:
                    _currentPosition!.heading >= 0
                        ? _currentPosition!.heading
                        : null,
                speed: _currentSpeed / 3.6,
                avatarUrl: _currentUserAvatarUrl,
              ),
              isCurrentUser: true,
              status:
                  _isOffline
                      ? RiderLiveStatus.offline
                      : _currentSpeed > 1
                      ? RiderLiveStatus.moving
                      : RiderLiveStatus.stopped,
              detailLabel: 'You',
            ),
          ),
        );
      }
    }

    // ── Live rider markers ─────────────────────────────────────────────────
    for (final loc in _riderLocations) {
      final isCurrentUser = loc.userId == _currentUserId;
      final isLeader = loc.userId == _leaderId || loc.isLeader;
      final status = RideEngineCore.statusFor(
        loc,
        isLeader: isLeader,
        hasSos: _isSosRider(loc.userId),
      );

      markers.add(
        _buildAnimatedRiderMarker(
          location: loc,
          isCurrentUser: isCurrentUser,
          isLeader: isLeader,
          status: status,
        ),
      );
    }

    return MarkerLayer(markers: markers);
  }

  /// Builds a single rider marker that uses SmoothMarker for interpolation.
  ///
  /// Because flutter_map requires [Marker.point] to be set at construction
  /// time, we use a StatefulWidget approach: the SmoothMarker's builder
  /// callback receives the interpolated LatLng and we update our cache.
  /// The outer Marker.point is set to the *current interpolated* position
  /// stored in [_interpolatedPositions] so the marker renders at the right
  /// place without rebuilding the entire map.
  Marker _buildAnimatedRiderMarker({
    required RiderLocation location,
    required bool isCurrentUser,
    required bool isLeader,
    required RiderLiveStatus status,
  }) {
    // Use the latest known interpolated position for the marker's point,
    // falling back to the raw GPS position for new riders.
    final displayPos =
        _interpolatedPositions[location.userId] ??
        LatLng(location.latitude, location.longitude);

    return Marker(
      key: ValueKey('rider_${location.userId}'),
      point: displayPos,
      width: isLeader ? 100 : 80,
      height: isLeader ? 120 : 100,
      child: _AnimatedRiderMarkerWidget(
        location: location,
        isCurrentUser: isCurrentUser,
        isLeader: isLeader,
        status: status,
        detailLabel: _markerLabelFor(location.userId),
        onPositionUpdate: (interpolated) {
          // Store the interpolated position so future [Marker.point] is correct.
          _interpolatedPositions[location.userId] = interpolated;
        },
      ),
    );
  }

  bool _isSosRider(String userId) {
    final alertProfileId = _activeSosRiderId();
    return alertProfileId.isNotEmpty && alertProfileId == userId;
  }

  String _activeSosRiderId() {
    return (_activeAlert?['profile_id'] ?? _activeAlert?['user_id'] ?? '')
        .toString()
        .trim();
  }

  String? _markerLabelFor(String userId) {
    final rider = _groupSnapshot.riderFor(userId);
    if (rider == null) return null;
    final name =
        userId == _currentUserId ? 'You' : rider.location.userName.trim();
    if (rider.location.userId == _leaderId || rider.location.isLeader) {
      return '$name • Leader';
    }
    final distance = GroupRideIntelligence.formatDistance(
      rider.distanceFromLeaderMeters,
    );
    final relation =
        rider.leaderRelation == 'with group'
            ? 'with group'
            : '${rider.leaderRelation} $distance';
    return '$name • $relation';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HUD WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopHUD() {
    final liveCount = _riderLocations.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HUDPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  color: Color(0xFFFF6A00),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE RIDE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),

          // Live riders count + tracking dot
          _HUDPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _trackingPulse,
                  builder:
                      (context, _) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0xFF4CAF50),
                            const Color(0xFF81C784),
                            _trackingPulse.value,
                          ),
                        ),
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$liveCount LIVE',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOfflineBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Reconnecting… GPS cached locally',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return 'Just now';
    }
  }

  List<Map<String, String>> _decodeEmergencyContacts(List<String> rows) {
    return rows
        .map((row) {
          final parts = row.split('|');
          return {
            'name': parts.isNotEmpty ? parts[0] : '',
            'phone': parts.length > 1 ? parts[1] : '',
            'relation': parts.length > 2 ? parts[2] : 'Emergency',
          };
        })
        .where((contact) => (contact['phone'] ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _callNumber(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return;
    final url = Uri(scheme: 'tel', path: normalized);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      showAppToast(
        context,
        'Cannot launch phone dialer.',
        type: AppToastType.error,
      );
    }
  }

  Widget _buildSOSOverlay() {
    final riderName = (_activeAlert!['user_name'] ?? 'Rider').toString();
    final lat = (_activeAlert!['latitude'] as num?)?.toDouble();
    final lng = (_activeAlert!['longitude'] as num?)?.toDouble();
    final timeStr = (_activeAlert!['created_at'] ?? '').toString();
    final time = _formatTime(timeStr);

    double? distance;
    if (lat != null && lng != null && _currentPosition != null) {
      distance =
          Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lng,
          ) /
          1000.0;
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _sosPulseController,
        builder: (context, _) {
          final pulseVal = _sosPulseController.value;
          return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Color.lerp(
                Colors.black.withValues(alpha: 0.75),
                Colors.red.withValues(alpha: 0.4),
                pulseVal,
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color:
                          Color.lerp(
                            Colors.red.shade700,
                            Colors.red.shade400,
                            pulseVal,
                          )!,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3 * pulseVal),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emergency_rounded,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'CRITICAL SOS ALERT',
                        style: TextStyle(
                          color: Colors.red,
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$riderName needs emergency assistance!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSOSDetailRow(
                              'Location',
                              lat != null && lng != null
                                  ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                  : 'Unknown',
                            ),
                            if (distance != null)
                              _buildSOSDetailRow(
                                'Distance Away',
                                '${distance.toStringAsFixed(2)} km',
                              ),
                            _buildSOSDetailRow('Time Triggered', time),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_emergencyContacts.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Emergency contacts',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._emergencyContacts.take(2).map((contact) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact['name'] ?? 'Emergency contact',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: AppTypography.fontFamily,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${contact['relation'] ?? 'Emergency'}  ${contact['phone'] ?? ''}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.62,
                                          ),
                                          fontFamily: AppTypography.fontFamily,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      () => _callNumber(contact['phone'] ?? ''),
                                  icon: const Icon(Icons.call_rounded),
                                  color: Colors.greenAccent,
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _SOSActionButton(
                              label: 'Emergency',
                              icon: Icons.phone_rounded,
                              color: Colors.blue,
                              onTap: () => _callNumber('112'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SOSActionButton(
                              label: 'Google Maps',
                              icon: Icons.map_rounded,
                              color: Colors.green,
                              onTap: () async {
                                if (lat != null && lng != null) {
                                  final url = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (!context.mounted) return;
                                    showAppToast(
                                      context,
                                      'Cannot launch Google Maps.',
                                      type: AppToastType.error,
                                    );
                                  }
                                } else {
                                  if (!context.mounted) return;
                                  showAppToast(
                                    context,
                                    'Location data unavailable.',
                                    type: AppToastType.error,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _activeAlert = null);
                          },
                          child: const Text(
                            'Acknowledge / Dismiss',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSOSDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  // ignore: unused_element
  String _formatDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${sec.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED RIDER MARKER WIDGET
// Internal stateful widget that wraps SmoothMarker + premium marker widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedRiderMarkerWidget extends StatefulWidget {
  const _AnimatedRiderMarkerWidget({
    required this.location,
    required this.isCurrentUser,
    required this.isLeader,
    required this.status,
    required this.detailLabel,
    required this.onPositionUpdate,
  });

  final RiderLocation location;
  final bool isCurrentUser;
  final bool isLeader;
  final RiderLiveStatus status;
  final String? detailLabel;
  final void Function(LatLng interpolated) onPositionUpdate;

  @override
  State<_AnimatedRiderMarkerWidget> createState() =>
      _AnimatedRiderMarkerWidgetState();
}

class _AnimatedRiderMarkerWidgetState
    extends State<_AnimatedRiderMarkerWidget> {
  @override
  Widget build(BuildContext context) {
    final targetPos = LatLng(
      widget.location.latitude,
      widget.location.longitude,
    );

    return SmoothMarker(
      position: targetPos,
      heading: widget.location.heading,
      speed: widget.location.speed,
      updatedAt: widget.location.updatedAt,
      builder: (context, interpolated) {
        // Notify parent of new animated position so Marker.point stays in sync.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onPositionUpdate(interpolated);
        });

        return widget.isLeader
            ? LeaderMarker(
              location: widget.location,
              isCurrentUser: widget.isCurrentUser,
              status: widget.status,
              detailLabel: widget.detailLabel,
            )
            : widget.isCurrentUser
            ? CurrentUserMarker(
              heading: widget.location.heading,
              isOffline: false,
              status: widget.status,
            )
            : RiderMarker(
              location: widget.location,
              isCurrentUser: widget.isCurrentUser,
              status: widget.status,
              detailLabel: widget.detailLabel,
            );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD PILL WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _HUDPill extends StatelessWidget {
  const _HUDPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEE9).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      onPressed: onTap ?? () {},
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white : Colors.grey.shade100,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: onTap != null ? color : Colors.grey.shade400),
      ),
    );
  }
}

class _SOSActionButton extends StatelessWidget {
  const _SOSActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
