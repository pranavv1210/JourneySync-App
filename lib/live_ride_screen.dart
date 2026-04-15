import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigation.dart';
import 'app_toast.dart';
import 'models/live_location.dart';
import 'models/ride_member.dart';
import 'models/ride_route.dart';
import 'ride_service.dart';
import 'ride_summary_screen.dart';
import 'services/live_tracking_service.dart';
import 'supabase_service.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/loading_skeleton.dart';

class LiveRideScreen extends StatefulWidget {
  const LiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  final RideService _rideService = RideService();
  final SupabaseService _supabaseService = SupabaseService();
  final LiveTrackingService _liveTrackingService = LiveTrackingService();
  final MapController _mapController = MapController();
  final Battery _battery = Battery();

  bool _loading = true;
  bool _finishingRide = false;
  String _errorText = '';
  String _currentUserId = '';
  Map<String, dynamic>? _ride;
  RideRoute? _rideRoute;
  List<RideMember> _members = <RideMember>[];
  List<LiveLocation> _liveLocations = <LiveLocation>[];
  Position? _currentPosition;
  Timer? _syncTimer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<LiveLocation>>? _liveLocationSubscription;
  LatLng? _lastMovementPoint;
  DateTime? _lastMovementAt;
  String _trackingStatus = 'Starting live location...';
  bool _centeredMap = false;

  static const Color _primary = Color(0xFFFF6A00);
  static const Color _forest = Color(0xFF1B5E20);
  static const Color _background = Color(0xFFF8F7F5);
  static const Color _warmSand = Color(0xFFF1EEE9);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = (prefs.getString('userId') ?? '').trim();
      if (_currentUserId.isEmpty) {
        throw Exception('Missing user session. Please login again.');
      }

      final ride = await _supabaseService.fetchRideById(widget.rideId);
      if (ride == null) {
        throw Exception('Ride not found.');
      }

      final results = await Future.wait<dynamic>([
        _rideService.fetchRideMembers(widget.rideId),
        _rideService.fetchRideRoute(widget.rideId),
      ]);

      _liveLocationSubscription = _liveTrackingService
          .watchRideLocations(widget.rideId)
          .listen((locations) {
            if (!mounted) return;
            setState(() {
              _liveLocations = locations;
            });
            _maybeCenterMap();
          });

      await _startLocationTracking();

      if (!mounted) return;
      setState(() {
        _ride = ride;
        _members = results[0] as List<RideMember>;
        _rideRoute = results[1] as RideRoute?;
        _loading = false;
      });
      _maybeCenterMap();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startLocationTracking() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() {
        _trackingStatus = 'Location service disabled';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _trackingStatus = 'Location permission denied';
      });
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _updateCurrentPosition(current);
      await _syncCurrentPosition();
    } catch (_) {}

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        _updateCurrentPosition(position);
        _maybeCenterMap();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _trackingStatus = 'GPS tracking unavailable';
        });
      },
    );

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncCurrentPosition();
    });
  }

  void _updateCurrentPosition(Position position) {
    final nextPoint = LatLng(position.latitude, position.longitude);
    final lastPoint = _lastMovementPoint;
    final now = DateTime.now();
    final movedEnough =
        lastPoint == null ||
        Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              nextPoint.latitude,
              nextPoint.longitude,
            ) >
            15;

    if (movedEnough) {
      _lastMovementPoint = nextPoint;
      _lastMovementAt = now;
    } else {
      _lastMovementAt ??= now;
    }

    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _trackingStatus = 'Sharing live location';
    });
  }

  Future<void> _syncCurrentPosition() async {
    final position = _currentPosition;
    if (position == null || _currentUserId.isEmpty) return;
    try {
      final batteryLevel = await _safeBatteryPercent();
      await _liveTrackingService.syncLocation(
        rideId: widget.rideId,
        userId: _currentUserId,
        position: position,
        battery: batteryLevel,
        signal: 'GPS active',
      );
      if (!mounted) return;
      setState(() {
        _trackingStatus = 'Live location synced';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _trackingStatus = 'Sync issue: ${_compactError(error)}';
      });
    }
  }

  Future<String?> _safeBatteryPercent() async {
    try {
      final level = await _battery.batteryLevel;
      return '$level%';
    } catch (_) {
      return null;
    }
  }

  Future<void> _leaveRide() async {
    if (_currentUserId.isEmpty) return;
    try {
      await _rideService.leaveRide(
        rideId: widget.rideId,
        userId: _currentUserId,
      );
      await _liveTrackingService.clearLiveLocation(
        rideId: widget.rideId,
        userId: _currentUserId,
      );
      if (!mounted) return;
      showAppToast(context, 'You left the ride.', type: AppToastType.success);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not leave ride: ${_compactError(error)}',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _finishRide() async {
    if (_finishingRide) return;
    setState(() {
      _finishingRide = true;
    });
    try {
      await Supabase.instance.client
          .from('rides')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.rideId);
      if (!mounted) return;
      replaceWithAppRoute(context, RideSummaryScreen(rideId: widget.rideId));
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not finish ride: ${_compactError(error)}',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _finishingRide = false;
        });
      }
    }
  }

  bool get _isCurrentUserHost {
    final ride = _ride;
    if (ride == null) return false;
    final hostId =
        (ride['host_id'] ??
                ride['creator_id'] ??
                ride['user_id'] ??
                ride['leader_id'] ??
                '')
            .toString()
            .trim();
    return hostId.isNotEmpty && hostId == _currentUserId;
  }

  String get _rideTitle {
    final ride = _ride;
    if (ride == null) return 'Live Ride';
    return ((ride['title'] ?? ride['name'] ?? 'Live Ride').toString().trim())
            .isEmpty
        ? 'Live Ride'
        : (ride['title'] ?? ride['name'] ?? 'Live Ride').toString().trim();
  }

  String get _rideDestination {
    final ride = _ride;
    if (ride == null) return 'Destination not set';
    final destination =
        (ride['end_location'] ?? ride['destination'] ?? '').toString().trim();
    return destination.isEmpty ? 'Destination not set' : destination;
  }

  LatLng? get _startPoint {
    final ride = _ride;
    if (ride == null) return null;
    return _parseLatLng(
      (ride['start_location'] ?? ride['start'] ?? '').toString(),
    );
  }

  List<LatLng> get _routePolyline {
    final points = <LatLng>[];
    if (_startPoint != null) {
      points.add(_startPoint!);
    }
    final route = _rideRoute;
    if (route != null) {
      for (final stop in route.stops) {
        points.add(LatLng(stop.latitude, stop.longitude));
      }
    }
    return points;
  }

  String get _safetyMessage {
    final staleLocations =
        _liveLocations.where((location) => location.isStale).toList();
    if (staleLocations.isNotEmpty) {
      final staleUser = staleLocations.first.userId;
      final staleMember = _members.where(
        (member) => member.userId == staleUser,
      );
      final name = staleMember.isEmpty ? 'A rider' : staleMember.first.name;
      return '$name appears stationary for 5+ minutes';
    }

    final lastMovementAt = _lastMovementAt;
    if (lastMovementAt != null &&
        DateTime.now().difference(lastMovementAt) >=
            const Duration(minutes: 5)) {
      return 'You appear stationary for 5+ minutes';
    }

    return '';
  }

  void _maybeCenterMap() {
    if (_centeredMap) return;
    final center = _preferredCenter;
    if (center == null) return;
    _centeredMap = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(center, 13);
    });
  }

  LatLng? get _preferredCenter {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    if (_liveLocations.isNotEmpty) {
      return LatLng(
        _liveLocations.first.latitude,
        _liveLocations.first.longitude,
      );
    }
    if (_routePolyline.isNotEmpty) {
      return _routePolyline.first;
    }
    return const LatLng(20.5937, 78.9629);
  }

  LatLng? _parseLatLng(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _compactError(Object error) {
    final text = error.toString();
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _positionSubscription?.cancel();
    _liveLocationSubscription?.cancel();
    _liveTrackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                LoadingSkeleton(height: 58, radius: 20),
                SizedBox(height: 14),
                Expanded(
                  child: LoadingSkeleton(height: double.infinity, radius: 28),
                ),
                SizedBox(height: 14),
                LoadingSkeleton(height: 220, radius: 28),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorText.isNotEmpty) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: EmptyStateCard(
            title: 'Live ride unavailable',
            message: _errorText,
            icon: Icons.error_outline_rounded,
            foreground: _forest,
            action: FilledButton(
              onPressed: _bootstrap,
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Retry'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: _buildTopBar(),
                ),
                if (_safetyMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _buildSafetyBanner(),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _buildBottomPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final routePoints = _routePolyline;
    final liveMarkers =
        _liveLocations.map((location) {
          RideMember? member;
          for (final item in _members) {
            if (item.userId == location.userId) {
              member = item;
              break;
            }
          }
          return Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 94,
            height: 76,
            child: _MemberMarker(
              member: member,
              isCurrentUser: location.userId == _currentUserId,
              isStale: location.isStale,
            ),
          );
        }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _preferredCenter ?? const LatLng(20.5937, 78.9629),
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.journeysync',
        ),
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 5,
                color: _primary.withValues(alpha: 0.75),
              ),
            ],
          ),
        if (_startPoint != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _startPoint!,
                width: 34,
                height: 34,
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: _forest,
                  size: 30,
                ),
              ),
            ],
          ),
        if (routePoints.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: routePoints.last,
                width: 36,
                height: 36,
                child: const Icon(
                  Icons.location_on_rounded,
                  color: _primary,
                  size: 32,
                ),
              ),
            ],
          ),
        if (liveMarkers.isNotEmpty) MarkerLayer(markers: liveMarkers),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warmSand.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: _forest,
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rideTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _trackingStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _forest.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_members.length} riders',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _safetyMessage,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final routeStops = _rideRoute?.stops ?? const <RouteStop>[];
    final locationByUser = {
      for (final location in _liveLocations) location.userId: location,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _warmSand,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoMetric(
                  label: 'Next Stop',
                  value: _rideDestination,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoMetric(
                  label: 'Ride State',
                  value: _safetyMessage.isEmpty ? 'All moving' : 'Safety alert',
                  color:
                      _safetyMessage.isEmpty
                          ? _forest
                          : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          if (routeStops.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Route Stops',
              style: TextStyle(
                color: _forest,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: routeStops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final stop = routeStops[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stop.label,
                      style: TextStyle(
                        color: _forest,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Riders',
            style: TextStyle(
              color: _forest,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            const EmptyStateCard(
              title: 'No active rides yet',
              message: 'Ride members will appear here once the group joins.',
              icon: Icons.groups_2_outlined,
              foreground: _forest,
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final liveLocation = locationByUser[member.userId];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _AvatarPill(member: member),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.userId == _currentUserId
                                    ? 'You'
                                    : member.name,
                                style: TextStyle(
                                  color: _forest,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                member.bike,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          liveLocation == null
                              ? 'Offline'
                              : liveLocation.isStale
                              ? 'Idle'
                              : 'Live',
                          style: TextStyle(
                            color:
                                liveLocation == null || liveLocation.isStale
                                    ? const Color(0xFFD97706)
                                    : _forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _leaveRide,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: BorderSide(color: _forest.withValues(alpha: 0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Leave Ride',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_isCurrentUserHost) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _finishingRide ? null : _finishRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        _finishingRide
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Finish Ride',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoMetric extends StatelessWidget {
  const _InfoMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPill extends StatelessWidget {
  const _AvatarPill({required this.member});

  final RideMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl.trim();
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    final initial =
        member.name.trim().isEmpty ? 'R' : member.name.trim().substring(0, 1);
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFFFE8D4),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFFF6A00),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MemberMarker extends StatelessWidget {
  const _MemberMarker({
    required this.member,
    required this.isCurrentUser,
    required this.isStale,
  });

  final RideMember? member;
  final bool isCurrentUser;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isStale ? const Color(0xFFD97706) : const Color(0xFFFF6A00),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _AvatarPill(
            member:
                member ??
                const RideMember(
                  userId: '',
                  name: 'Rider',
                  bike: 'No bike added',
                  avatarUrl: '',
                  isHost: false,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isCurrentUser ? 'You' : (member?.name ?? 'Rider'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
