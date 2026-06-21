import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rider_location.dart';
import '../coordinators/active_ride_coordinator.dart';
import '../coordinators/realtime_coordinator.dart';
import '../services/live_tracking_service.dart';
import '../services/navigation_service.dart';
import '../services/ride_service.dart';
import '../services/supabase_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/rider_marker.dart';
import '../widgets/ride_loading_indicator.dart';
import '../widgets/smooth_marker.dart';

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

  // ── SOS ───────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _activeAlert;
  String _lastAlertKey = '';
  Timer? _alertDismissTimer;

  // ── Ride timer ─────────────────────────────────────────────────────────────
  int _secondsElapsed = 0;
  Timer? _rideTimer;

  // ── Route sync ─────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  double? _destinationLat;
  double? _destinationLng;

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
    setState(() {
      _riderLocations = locations;
      _isOffline = nowOffline;
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
    setState(() => _activeAlert = alert);
    _alertDismissTimer?.cancel();
    _alertDismissTimer = Timer(const Duration(seconds: 10), () {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('End Ride?'),
            content: const Text(
              'This will stop tracking and complete your journey.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('End Ride'),
              ),
            ],
          ),
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

          // ── BOTTOM ACTIONS ────────────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: _buildBottomActions(),
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

  Widget _buildSOSOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _activeAlert = null),
        child: Container(
          color: Colors.red.withValues(alpha: 0.25),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 4,
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
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EMERGENCY ALERT',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_activeAlert!['user_name'] ?? 'A rider'} triggered SOS!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap anywhere to dismiss',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final hasLeader = _leaderId != null && _leaderId != _currentUserId;
    final hasDest = _getDestinationCoords() != null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // My location button
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

            // Follow leader button
            if (hasLeader)
              _HUDPill(
                child: GestureDetector(
                  onTap:
                      () =>
                          setState(() => _followingLeader = !_followingLeader),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _followingLeader
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 14,
                        color:
                            _followingLeader
                                ? const Color(0xFF2196F3)
                                : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _followingLeader ? 'Following Leader' : 'Follow Leader',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              _followingLeader
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Navigation button
            _CircleButton(
              icon: Icons.navigation_rounded,
              color: hasDest ? const Color(0xFF4CAF50) : Colors.grey,
              onTap: hasDest ? _launchNavigation : null,
            ),

            // SOS button
            _CircleButton(
              icon: Icons.warning_rounded,
              color: Colors.red,
              onTap: _triggerSOS,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // End Ride button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: AnimatedPress(
            onPressed: _endRide,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6A00), Color(0xFFFF8C42)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'END RIDE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
