import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_record.dart';
import '../widgets/app_toast.dart';
import '../services/ride_service.dart';
import '../widgets/empty_state_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final RideService _rideService = RideService();
  final MapController _mapController = MapController();

  bool loading = true;
  String errorText = '';
  String currentUserId = '';
  String joiningRideId = '';
  LatLng? currentLocation;
  List<NearbyRide> nearbyRides = <NearbyRide>[];
  NearbyRide? selectedRide;

  static const LatLng fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _loadRadarData();
  }

  Future<void> _loadRadarData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorText = '';
      joiningRideId = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isEmpty) {
        throw Exception('Missing user session. Please login again.');
      }

      LatLng? resolvedLocation;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        resolvedLocation = LatLng(position.latitude, position.longitude);
      } catch (_) {}

      final rides = await _rideService.searchNearbyRides(
        userId,
        requestPermissionIfNeeded: true,
        maxDistanceKm: 15,
      );

      if (!mounted) return;
      setState(() {
        currentUserId = userId;
        currentLocation = resolvedLocation;
        nearbyRides = rides;
        selectedRide = _resolveSelectedRide(rides);
        loading = false;
      });

      final center = _initialCenter;
      _mapController.move(center, _initialZoom);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = _mapFallbackMessage(error);
        loading = false;
      });
    }
  }

  NearbyRide? _resolveSelectedRide(List<NearbyRide> rides) {
    final current = selectedRide;
    if (current == null) return rides.isNotEmpty ? rides.first : null;
    for (final ride in rides) {
      if (ride.ride.id == current.ride.id) return ride;
    }
    return rides.isNotEmpty ? rides.first : null;
  }

  String _mapFallbackMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('location')) {
      return 'Location access is needed to show nearby live rides.';
    }
    if (text.contains('timeout') || text.contains('socket')) {
      return 'Network issue while loading nearby rides.';
    }
    return 'Could not load nearby live rides right now.';
  }

  LatLng get _initialCenter {
    if (currentLocation != null) return currentLocation!;
    final first =
        nearbyRides.isNotEmpty ? _rideStartPoint(nearbyRides.first) : null;
    return first ?? fallbackCenter;
  }

  double get _initialZoom {
    if (currentLocation != null) return 13;
    if (nearbyRides.isNotEmpty) return 11;
    return 5;
  }

  LatLng? _rideStartPoint(NearbyRide ride) {
    final text = ride.ride.startLocation.trim();
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  String _distanceFromMe(NearbyRide ride) {
    final me = currentLocation;
    final start = _rideStartPoint(ride);
    if (me == null || start == null) return 'Distance unavailable';
    final meters = Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      start.latitude,
      start.longitude,
    );
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _joinRide(NearbyRide ride) async {
    if (joiningRideId.isNotEmpty || ride.joined) return;
    setState(() {
      joiningRideId = ride.ride.id;
    });
    try {
      await _rideService.joinRide(rideId: ride.ride.id, userId: currentUserId);
      if (!mounted) return;
      showAppToast(
        context,
        'Ride joined successfully',
        type: AppToastType.success,
      );
      await _loadRadarData();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not join ride: $error',
        type: AppToastType.error,
      );
      setState(() {
        joiningRideId = '';
      });
    }
  }

  void _focusMyLocation() {
    final location = currentLocation;
    if (location == null) return;
    _mapController.move(location, 15);
  }

  void _focusRide(NearbyRide ride) {
    final point = _rideStartPoint(ride);
    if (point == null) return;
    _mapController.move(point, 14.5);
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F7F6);
    const forest = Color(0xFF1E3A2F);
    const primary = Color(0xFFD46211);
    final selected = selectedRide;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Nearby Live Radar'),
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loading ? null : _loadRadarData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 3,
                maxZoom: 18,
                onTap: (_, __) {
                  setState(() {
                    selectedRide = null;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.journeysync',
                ),
                MarkerLayer(markers: _buildRideMarkers(primary)),
                MarkerLayer(markers: _buildMyLocationMarker(forest)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _statusBanner(primary, forest),
          ),
          Positioned(
            right: 12,
            bottom: 260,
            child: FloatingActionButton.small(
              onPressed: _focusMyLocation,
              heroTag: 'focus-my-location',
              backgroundColor: Colors.white,
              foregroundColor: forest,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _rideInfoCard(selected, forest, primary),
            )
          else
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _ridesTray(primary, forest),
            ),
          if (loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  List<Marker> _buildRideMarkers(Color primary) {
    final markers = <Marker>[];
    for (final ride in nearbyRides) {
      final point = _rideStartPoint(ride);
      if (point == null) continue;
      markers.add(
        Marker(
          point: point,
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedRide = ride;
              });
              _focusRide(ride);
            },
            child: Container(
              decoration: BoxDecoration(
                color: ride.joined ? const Color(0xFF2FA865) : primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                ride.joined ? Icons.check : Icons.directions_bike,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  List<Marker> _buildMyLocationMarker(Color forest) {
    final location = currentLocation;
    if (location == null) return <Marker>[];
    return <Marker>[
      Marker(
        point: location,
        width: 42,
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            color: forest,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ];
  }

  Widget _statusBanner(Color primary, Color forest) {
    final message =
        errorText.isNotEmpty
            ? errorText
            : nearbyRides.isEmpty
            ? 'No live rides near you right now.'
            : '${nearbyRides.length} live ride(s) within radar range';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: forest.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            errorText.isNotEmpty ? Icons.error_outline : Icons.radar_rounded,
            color: errorText.isNotEmpty ? Colors.red : primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: forest.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideInfoCard(NearbyRide ride, Color forest, Color primary) {
    final joining = joiningRideId == ride.ride.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: forest.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.ride.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_distanceFromMe(ride)} • Host: ${ride.hostName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (ride.joined || joining) ? null : () => _joinRide(ride),
              style: ElevatedButton.styleFrom(
                backgroundColor: ride.joined ? Colors.grey.shade300 : primary,
                foregroundColor: ride.joined ? Colors.black54 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child:
                  joining
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        ride.joined ? 'Joined Ride' : 'Join Ride',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ridesTray(Color primary, Color forest) {
    if (nearbyRides.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: forest.withValues(alpha: 0.1)),
        ),
        child: EmptyStateCard(
          title: 'No riders nearby',
          message: 'Ask your group to start a ride and come online.',
          icon: Icons.map_outlined,
          foreground: forest,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: forest.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap any ride marker to view details and join',
            style: TextStyle(
              color: forest.withValues(alpha: 0.74),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
