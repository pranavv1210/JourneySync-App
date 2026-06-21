import 'dart:async';
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
import '../coordinators/realtime_coordinator.dart';
import '../services/live_tracking_service.dart';
import '../services/navigation_service.dart';
import '../services/ride_service.dart';
import '../services/supabase_service.dart';
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

  // ── User / Ride state ──────────────────────────────────────────────────────
  bool _loading = true;
  String _currentUserId = '';
  String _currentUserName = 'Rider';
  String _currentBikeName = 'No bike added';
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

  // ── Ride timer ─────────────────────────────────────────────────────────────
  int _secondsElapsed = 0;
  Timer? _rideTimer;

  // ── Route sync ─────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  double? _destinationLat;
  double? _destinationLng;
  RideRoute? _rideRoute;

  // ── Tracking active badge animation ───────────────────────────────────────
  late AnimationController _trackingPulse;

  // ── Interpolated positions cache (for smooth markers) ──────────────────────
  /// Maps userId → current smoothly-interpolated LatLng.
  /// Updated by SmoothMarker builders and used to track the animated position.
  final Map<String, LatLng> _interpolatedPositions = {};

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _trackingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

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
      _currentBikeName =
          (prefs.getString('userBike') ?? 'No bike added').trim();

      // ── Fetch ride data ──────────────────────────────────────────────────
      final ride = await _supabaseService.fetchRideById(widget.rideId);
      if (ride == null) throw Exception('Ride not found');

      _leaderId = (ride['host_id'] ?? '').toString().trim();
      _rideData = ride;

      // ── Start timer ──────────────────────────────────────────────────────
      _startRideTimer();

      // ── Start GPS position stream (local, for UI position dot) ───────────
      await _startLocalGpsStream();

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

      _prevPosition = pos;
      if (mounted) setState(() {});
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALLBACKS
  // ─────────────────────────────────────────────────────────────────────────

  void _onRiderLocationsUpdate(List<RiderLocation> locations) {
    if (!mounted) return;

    // Check our own offline status from the service.
    final nowOffline = _trackingService.isOffline;

    // Calculate falling behind status (>2 km from leader)
    bool isFallingBehind = false;
    if (_leaderId != null && _leaderId != _currentUserId) {
      RiderLocation? leader;
      for (final loc in locations) {
        if (loc.userId == _leaderId) {
          leader = loc;
          break;
        }
      }
      if (leader != null) {
        double dist = 0.0;
        if (_currentPosition != null) {
          dist =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                leader.latitude,
                leader.longitude,
              ) /
              1000.0;
        } else {
          RiderLocation? me;
          for (final loc in locations) {
            if (loc.userId == _currentUserId) {
              me = loc;
              break;
            }
          }
          if (me != null) {
            dist =
                Geolocator.distanceBetween(
                  me.latitude,
                  me.longitude,
                  leader.latitude,
                  leader.longitude,
                ) /
                1000.0;
          }
        }
        isFallingBehind = dist > 2.0;
      }
    }

    setState(() {
      _riderLocations = locations;
      _isOffline = nowOffline;
      _isFallingBehind = isFallingBehind;
    });

    _handleFollowLeader(locations);
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

  void _handleFollowLeader(List<RiderLocation> locations) {
    if (!_followingLeader || _leaderId == null) return;
    try {
      final leader = locations.firstWhere((l) => l.userId == _leaderId);
      _mapController.move(
        LatLng(leader.latitude, leader.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
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
    HapticFeedback.heavyImpact();
    try {
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
          'Failed to send SOS: $e',
          type: AppToastType.error,
        );
      }
    }
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
      await _trackingService.stopSyncing();
      await _rideService.finishRide(widget.rideId);
      await _trackingService.clearLiveLocation(
        rideId: widget.rideId,
        userId: _currentUserId,
      );
      await ActiveRideCoordinator.instance.markCompleted();
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
    _sosPulseController.dispose();
    _locationStreamSub?.cancel();
    _gpsStreamSub?.cancel();
    ActiveRideCoordinator.instance.removeListener(_onActiveRideSnapshotChanged);
    _realtimeCoordinator.removeListener(_onRealtimeChanged);
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
        backgroundColor: Color(0xFFF4EFEA),
        body: Center(
          child: RideLoadingIndicator(
            label: 'Starting Ride…',
            color: Color(0xFFFF6A00),
          ),
        ),
      );
    }

    return Scaffold(
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
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Proxima Nova',
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Leader is more than 2 km ahead. Increase speed.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Proxima Nova',
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
                      _mapController.move(
                        LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        15,
                      );
                    }
                    setState(() => _followingLeader = false);
                  },
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
                setState(() => _followingLeader = val);
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
      options: MapOptions(initialCenter: initialCenter, initialZoom: 15.0),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.journeysync',
        ),
        // Route polyline
        PolylineLayer(polylines: _buildPolylines()),
        // Markers
        _buildMarkerLayer(),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _routePoints,
          strokeWidth: 5.0,
          color: const Color(0xFFD97706),
          borderColor: const Color(0xFFFF6A00).withValues(alpha: 0.3),
          borderStrokeWidth: 2,
        ),
      );
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
            width: 60,
            height: 60,
            child: CurrentUserMarker(
              heading:
                  _currentPosition!.heading >= 0
                      ? _currentPosition!.heading
                      : null,
              isOffline: _isOffline,
            ),
          ),
        );
      }
    }

    // ── Live rider markers ─────────────────────────────────────────────────
    for (final loc in _riderLocations) {
      final isCurrentUser = loc.userId == _currentUserId;
      final isLeader = loc.userId == _leaderId || loc.isLeader;

      markers.add(
        _buildAnimatedRiderMarker(
          location: loc,
          isCurrentUser: isCurrentUser,
          isLeader: isLeader,
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
        onPositionUpdate: (interpolated) {
          // Store the interpolated position so future [Marker.point] is correct.
          _interpolatedPositions[location.userId] = interpolated;
        },
      ),
    );
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
          // Timer pill
          _HUDPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_rounded,
                  color: Color(0xFFFF6A00),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_secondsElapsed),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
                          fontFamily: 'Proxima Nova',
                          fontWeight: FontWeight.w900,
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
                          fontFamily: 'Proxima Nova',
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
                      Row(
                        children: [
                          Expanded(
                            child: _SOSActionButton(
                              label: 'Call Rider',
                              icon: Icons.phone_rounded,
                              color: Colors.blue,
                              onTap: () async {
                                final url = Uri.parse('tel:112');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                } else {
                                  if (!context.mounted) return;
                                  showAppToast(
                                    context,
                                    'Cannot launch phone dialer.',
                                    type: AppToastType.error,
                                  );
                                }
                              },
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
                              fontFamily: 'Proxima Nova',
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
              fontFamily: 'Proxima Nova',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Proxima Nova',
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
    required this.onPositionUpdate,
  });

  final RiderLocation location;
  final bool isCurrentUser;
  final bool isLeader;
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
      builder: (context, interpolated) {
        // Notify parent of new animated position so Marker.point stays in sync.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onPositionUpdate(interpolated);
        });

        return widget.isLeader
            ? LeaderMarker(
              location: widget.location,
              isCurrentUser: widget.isCurrentUser,
            )
            : widget.isCurrentUser
            ? CurrentUserMarker(
              heading: widget.location.heading,
              isOffline: false,
            )
            : RiderMarker(
              location: widget.location,
              isCurrentUser: widget.isCurrentUser,
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
            fontFamily: 'Proxima Nova',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
