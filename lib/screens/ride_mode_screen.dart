import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_toast.dart';
import '../services/ride_service.dart';
import '../services/live_tracking_service.dart';
import '../services/supabase_service.dart';
import '../services/navigation_service.dart';
import '../models/live_location.dart';
import '../models/ride_member.dart';

class RideModeScreen extends StatefulWidget {
  const RideModeScreen({super.key, required this.rideId});
  final String rideId;

  @override
  State<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends State<RideModeScreen>
    with TickerProviderStateMixin {
  final RideService _rideService = RideService();
  final SupabaseService _supabaseService = SupabaseService();
  final LiveTrackingService _liveTrackingService = LiveTrackingService();
  final MapController _mapController = MapController();
  final Battery _battery = Battery();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _isOffline = false;
  bool _followingLeader = false;
  String _currentUserId = '';
  String _currentUserName = '';
  String? _leaderId;
  Map<String, dynamic>? _rideData;

  List<RideMember> _members = [];
  List<LiveLocation> _liveLocations = [];
  Position? _currentPosition;

  // SOS State
  Map<String, dynamic>? _activeAlert;
  RealtimeChannel? _alertChannel;

  // Ride Timer
  int _secondsElapsed = 0;
  Timer? _rideTimer;

  // Tracking & Offline Queue
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<LiveLocation>>? _liveLocationSubscription;
  Timer? _syncTimer;
  final List<Map<String, dynamic>> _offlineQueue = [];

  // Route Sync
  List<LatLng> _routePoints = [];
  RealtimeChannel? _routeChannel;

  @override
  void initState() {
    super.initState();
    _initRideMode();
    _setupAlertSubscription();
    _setupRouteSubscription();
  }

  Future<void> _initRideMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = (prefs.getString('userId') ?? '').trim();
      _currentUserName = (prefs.getString('userName') ?? 'Rider').trim();

      final ride = await _supabaseService.fetchRideById(widget.rideId);
      if (ride == null) throw Exception('Ride not found');

      _leaderId = ride['ride_leader_id'] ?? ride['creator_id'];
      _rideData = ride;
      final members = await _rideService.fetchRideMembers(widget.rideId);

      _startTimer();
      await _startLocationTracking();

      _liveLocationSubscription = _liveTrackingService
          .watchRideLocations(widget.rideId)
          .listen((locations) {
            if (!mounted) return;
            setState(() => _liveLocations = locations);
            _handleAutoCenterLogic(locations);
          });

      // Initial route fetch
      try {
        final routeData =
            await _supabase
                .from('ride_routes')
                .select()
                .eq('ride_id', widget.rideId)
                .maybeSingle();
        if (routeData != null) {
          _handleRouteUpdate(routeData);
        }
      } catch (_) {}

      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error: $e', type: AppToastType.error);
      Navigator.pop(context);
    }
  }

  void _setupAlertSubscription() {
    _alertChannel = _supabase.channel('ride_alerts:${widget.rideId}');
    _alertChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: widget.rideId,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() => _activeAlert = payload.newRecord);
            HapticFeedback.vibrate();
            Timer(const Duration(seconds: 8), () {
              if (mounted) setState(() => _activeAlert = null);
            });
          },
        )
        .subscribe();
  }

  void _handleAutoCenterLogic(List<LiveLocation> locations) {
    if (!_followingLeader || _leaderId == null) return;
    try {
      final leaderLoc = locations.firstWhere((l) => l.userId == _leaderId);
      _mapController.move(
        LatLng(leaderLoc.latitude, leaderLoc.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
  }

  void _startTimer() {
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  Future<void> _startLocationTracking() async {
    // Request background location permission for Android
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters for smoother tracking
      ),
    ).listen((position) {
      // Update position even when not mounted to continue background tracking
      _currentPosition = position;
      if (mounted) {
        setState(() {});
      }
    });
    _syncTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _syncPosition(),
    );
  }

  void _setupRouteSubscription() {
    _routeChannel = _supabase.channel('ride_routes:${widget.rideId}');
    _routeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_routes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: widget.rideId,
          ),
          callback: (payload) {
            if (!mounted) return;
            _handleRouteUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleRouteUpdate(Map<String, dynamic> data) {
    try {
      final List<dynamic>? pointsRaw = data['route_points'];
      if (pointsRaw != null) {
        final List<LatLng> points =
            pointsRaw
                .map(
                  (p) => LatLng(
                    (p['lat'] as num).toDouble(),
                    (p['lng'] as num).toDouble(),
                  ),
                )
                .toList();
        setState(() {
          _routePoints = points;
        });
        if (points.isNotEmpty) {
          showAppToast(context, "Route synchronized!", type: AppToastType.info);
        }
      }
    } catch (e) {
      debugPrint('Error parsing route: $e');
    }
  }

  Future<void> _syncPosition() async {
    if (_currentPosition == null) return;
    int? battery = 0;
    try {
      battery = await _battery.batteryLevel;
    } catch (_) {}

    final payload = {
      'ride_id': widget.rideId,
      'user_id': _currentUserId,
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'battery': '$battery%',
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('live_locations').upsert(payload);
      if (_isOffline) setState(() => _isOffline = false);
      _processOfflineQueue();
    } catch (e) {
      if (!_isOffline) setState(() => _isOffline = true);
      _offlineQueue.add(payload);
      if (_offlineQueue.length > 20) _offlineQueue.removeAt(0);
    }
  }

  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    final copy = List.from(_offlineQueue);
    _offlineQueue.clear();
    for (var p in copy) {
      try {
        await _supabase.from('live_locations').upsert(p);
      } catch (_) {
        _offlineQueue.add(p);
      }
    }
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    try {
      await _supabase.from('ride_alerts').insert({
        'ride_id': widget.rideId,
        'user_id': _currentUserId,
        'user_name': _currentUserName,
        'type': 'SOS',
      });
      if (mounted) {
        showAppToast(context, "SOS Alert Broadcasted!");
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          "Failed to send SOS: $e",
          type: AppToastType.error,
        );
      }
    }
  }

  /// Extracts destination coordinates from ride data
  /// Supports multiple field names for flexibility
  LatLng? _getDestinationCoordinates() {
    final ride = _rideData;
    if (ride == null) return null;

    // Try different possible field names for destination
    final destLocation =
        ride['end_location'] ?? ride['destination'] ?? ride['end_latlng'];
    if (destLocation == null) return null;

    // Handle string format "lat,lng"
    if (destLocation is String) {
      final parts = destLocation.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    }

    // Handle map format with lat/lng keys
    if (destLocation is Map) {
      final lat = (destLocation['lat'] ?? destLocation['latitude'])?.toDouble();
      final lng =
          (destLocation['lng'] ?? destLocation['longitude'])?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    // Try to get from route points if available (last point is destination)
    if (_routePoints.isNotEmpty) {
      return _routePoints.last;
    }

    return null;
  }

  /// Launches Google Maps navigation to the ride destination
  Future<void> _launchNavigation() async {
    final destination = _getDestinationCoordinates();
    if (destination == null) {
      if (mounted) {
        showAppToast(
          context,
          'Destination coordinates not available',
          type: AppToastType.error,
        );
      }
      return;
    }

    final ride = _rideData;
    final destinationName = ride?['title'] ?? ride?['name'] ?? 'Destination';

    await NavigationService.navigateToDestination(
      context,
      destination.latitude,
      destination.longitude,
      destinationName: destinationName.toString(),
    );
  }

  Future<void> _endRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Ride?'),
            content: const Text(
              'This will stop tracking and complete your journey.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                ),
                child: const Text('End Ride'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _rideService.finishRide(widget.rideId);
        await _liveTrackingService.clearLiveLocation(
          rideId: widget.rideId,
          userId: _currentUserId,
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        showAppToast(
          context,
          'Error ending ride: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    _syncTimer?.cancel();
    _positionSubscription?.cancel();
    _liveLocationSubscription?.cancel();
    _alertChannel?.unsubscribe();
    _routeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _currentPosition != null
                      ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                      : const LatLng(20.5, 78.9),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.journeysync',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFFD97706),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ..._liveLocations.map((loc) {
                    final member = _members.firstWhere(
                      (m) => m.userId == loc.userId,
                      orElse:
                          () => RideMember(
                            userId: loc.userId,
                            name: 'Rider',
                            bike: 'No bike added',
                            avatarUrl: '',
                            isHost: false,
                          ),
                    );
                    return Marker(
                      key: ValueKey(loc.userId),
                      point: LatLng(loc.latitude, loc.longitude),
                      width: 90,
                      height: 90,
                      child: SmoothMarker(
                        position: LatLng(loc.latitude, loc.longitude),
                        child: _MemberMarker(
                          member: member,
                          isCurrentUser: loc.userId == _currentUserId,
                          isLeader: loc.userId == _leaderId,
                          isStale: loc.isStale,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // SOS ALERT OVERLAY
          if (_activeAlert != null)
            Positioned.fill(
              child: Container(
                color: Colors.red.withValues(alpha: 0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "EMERGENCY ALERT",
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          "${_activeAlert!['user_name']} triggered SOS!",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // TOP HUD
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  _hudPill(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Color(0xFFFF6A00),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_secondsElapsed),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isOffline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _hudPill(
                        const Text(
                          "Reconnecting...",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // BOTTOM ACTIONS
          Positioned(
            left: 20,
            bottom: 40,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleBtn(Icons.my_location, Colors.blue, () {
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
                    }),
                    if (_leaderId != null && _leaderId != _currentUserId)
                      _hudPill(
                        GestureDetector(
                          onTap:
                              () => setState(
                                () => _followingLeader = !_followingLeader,
                              ),
                          child: Row(
                            children: [
                              Icon(
                                _followingLeader
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 16,
                                color:
                                    _followingLeader
                                        ? Colors.blue
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _followingLeader
                                    ? "Following Leader"
                                    : "Follow Leader",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _followingLeader
                                          ? Colors.blue
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        color: Colors.white,
                      ),
                    _circleBtn(
                      Icons.navigation,
                      const Color(0xFF4CAF50),
                      _launchNavigation,
                    ),
                    _circleBtn(Icons.warning, Colors.red, _triggerSOS),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedPress(
                    onPressed: _endRide,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A00),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "END RIDE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudPill(Widget child, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF1EEE9).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: child,
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return AnimatedPress(
      onPressed: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Icon(icon, color: color),
      ),
    );
  }

  String _formatDuration(int s) {
    return "${(s ~/ 3600).toString().padLeft(2, '0')}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}";
  }
}

// FEATURE 1: SMOOTH MARKER ANIMATION
class SmoothMarker extends StatefulWidget {
  final LatLng position;
  final Widget child;
  const SmoothMarker({required this.position, required this.child, super.key});
  @override
  State<SmoothMarker> createState() => _SmoothMarkerState();
}

class _SmoothMarkerState extends State<SmoothMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _latAnim;
  late Animation<double> _lngAnim;
  LatLng _prevPos = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _prevPos = widget.position;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _setupAnims();
  }

  void _setupAnims() {
    _latAnim = Tween<double>(
      begin: _prevPos.latitude,
      end: widget.position.latitude,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _lngAnim = Tween<double>(
      begin: _prevPos.longitude,
      end: widget.position.longitude,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(SmoothMarker old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position) {
      _prevPos = LatLng(_latAnim.value, _lngAnim.value);
      _setupAnims();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) =>
              Transform.translate(offset: Offset.zero, child: widget.child),
    );
  }
}

// FEATURE 5: MICRO-INTERACTIONS
class AnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  const AnimatedPress({
    required this.child,
    required this.onPressed,
    super.key,
  });
  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    super.initState();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onPressed();
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(scale: _c, child: widget.child),
    );
  }
}

class _MemberMarker extends StatelessWidget {
  final RideMember member;
  final bool isCurrentUser;
  final bool isLeader;
  final bool isStale;
  const _MemberMarker({
    required this.member,
    required this.isCurrentUser,
    required this.isLeader,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isLeader
                          ? Colors.amber
                          : (isCurrentUser
                              ? const Color(0xFFFF6A00)
                              : Colors.blue),
                  width: 3,
                ),
              ),
              child: _Avatar(member: member),
            ),
            if (isLeader)
              const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 24,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Text(
            isCurrentUser ? "You" : member.name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final RideMember member;
  const _Avatar({required this.member});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFFFE8D4),
      backgroundImage:
          member.avatarUrl.isNotEmpty ? NetworkImage(member.avatarUrl) : null,
      child:
          member.avatarUrl.isEmpty
              ? Text(
                member.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFF6A00),
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );
  }
}
