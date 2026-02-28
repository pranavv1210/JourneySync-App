import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'ride_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final RideService _rideService = RideService();

  bool loading = true;
  String errorText = "";
  List<_RidePin> ridePins = <_RidePin>[];
  _RidePin? selectedPin;
  LatLng? currentLocation;
  StreamSubscription<List<RideRecord>>? _ridesSubscription;
  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};
  int _pinBuildRequestId = 0;

  static const LatLng fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _ridesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadCurrentLocation();
    await _startRideStream();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Keep map usable even when location fails.
    }
  }

  Future<void> _startRideStream() async {
    await _ridesSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      loading = true;
      errorText = "";
    });

    _ridesSubscription = _rideService.watchRides().listen(
      (rides) async {
        final requestId = ++_pinBuildRequestId;
        final pins = await _buildRidePins(rides);
        if (!mounted || requestId != _pinBuildRequestId) return;
        setState(() {
          ridePins = pins;
          selectedPin = _resolveSelectedPin(pins);
          errorText = "";
          loading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          errorText = "Could not load rides for map.";
          loading = false;
        });
      },
    );
  }

  Future<List<_RidePin>> _buildRidePins(List<RideRecord> rides) async {
    final pins = <_RidePin>[];
    for (final ride in rides) {
      final point = await _resolveRidePoint(ride);
      if (point == null) {
        continue;
      }

      pins.add(
        _RidePin(
          id: ride.id,
          title: ride.title,
          destination: ride.endLocation,
          point: point,
        ),
      );
    }
    return pins;
  }

  Future<LatLng?> _resolveRidePoint(RideRecord ride) async {
    final fromStart = _parseCoordinatePair(ride.startLocation);
    if (fromStart != null) return fromStart;

    final fromEnd = _parseCoordinatePair(ride.endLocation);
    if (fromEnd != null) return fromEnd;

    final startAddress = ride.startLocation.trim();
    if (startAddress.isNotEmpty) {
      final geocodedStart = await _geocodeAddress(startAddress);
      if (geocodedStart != null) return geocodedStart;
    }

    final endAddress = ride.endLocation.trim();
    if (endAddress.isNotEmpty) {
      final geocodedEnd = await _geocodeAddress(endAddress);
      if (geocodedEnd != null) return geocodedEnd;
    }

    return null;
  }

  Future<LatLng?> _geocodeAddress(String rawAddress) async {
    final address = rawAddress.trim();
    if (address.isEmpty) return null;
    if (_geocodeCache.containsKey(address)) {
      return _geocodeCache[address];
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'jsonv2',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _geocodeCache[address] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        _geocodeCache[address] = null;
        return null;
      }

      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        _geocodeCache[address] = null;
        return null;
      }

      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lng = double.tryParse((first['lon'] ?? '').toString());
      if (lat == null || lng == null) {
        _geocodeCache[address] = null;
        return null;
      }

      final point = LatLng(lat, lng);
      _geocodeCache[address] = point;
      return point;
    } catch (_) {
      _geocodeCache[address] = null;
      return null;
    }
  }

  _RidePin? _resolveSelectedPin(List<_RidePin> pins) {
    final currentSelected = selectedPin;
    if (currentSelected == null) {
      return null;
    }
    for (final pin in pins) {
      if (pin.id == currentSelected.id) {
        return pin;
      }
    }
    return null;
  }

  LatLng? _parseCoordinatePair(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final lat = double.tryParse(match.group(1) ?? "");
    final lng = double.tryParse(match.group(2) ?? "");
    if (lat == null || lng == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  LatLng get _initialCenter {
    final location = currentLocation;
    if (location != null) return location;
    if (ridePins.isNotEmpty) return ridePins.first.point;
    return fallbackCenter;
  }

  double get _initialZoom {
    if (currentLocation != null || ridePins.isNotEmpty) return 12;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8F7F6);
    const forest = Color(0xFF1E3A2F);
    const primary = Color(0xFFD46211);
    final selected = selectedPin;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text("Ride Map"),
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loading ? null : _initialize,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 3,
                maxZoom: 18,
                onTap: (_, __) {
                  if (selectedPin == null) return;
                  setState(() {
                    selectedPin = null;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.journeysync',
                ),
                MarkerLayer(markers: _buildRideMarkers(primary)),
                MarkerLayer(markers: _buildUserLocationMarker(forest)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _statusBanner(primary, forest),
          ),
          if (selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _rideInfoCard(selected, forest, primary),
            ),
          if (loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  List<Marker> _buildRideMarkers(Color primary) {
    return ridePins.map((pin) {
      return Marker(
        point: pin.point,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedPin = pin;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: primary,
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
            child: const Icon(
              Icons.directions_bike,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildUserLocationMarker(Color forest) {
    final location = currentLocation;
    if (location == null) {
      return <Marker>[];
    }

    return <Marker>[
      Marker(
        point: location,
        width: 40,
        height: 40,
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
          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
        ),
      ),
    ];
  }

  Widget _statusBanner(Color primary, Color forest) {
    final message =
        errorText.isNotEmpty
            ? errorText
            : ridePins.isEmpty
            ? "No ride markers yet."
            : "${ridePins.length} ride(s) on map";
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
            errorText.isNotEmpty ? Icons.error_outline : Icons.map_outlined,
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

  Widget _rideInfoCard(_RidePin pin, Color forest, Color primary) {
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
            pin.title,
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
            pin.destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: forest.withValues(alpha: 0.68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "RIDE",
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${pin.point.latitude.toStringAsFixed(5)}, ${pin.point.longitude.toStringAsFixed(5)}",
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: forest.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RidePin {
  const _RidePin({
    required this.id,
    required this.title,
    required this.destination,
    required this.point,
  });

  final String id;
  final String title;
  final String destination;
  final LatLng point;
}
