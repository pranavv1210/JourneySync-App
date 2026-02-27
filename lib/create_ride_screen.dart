import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ride_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController rideNameController = TextEditingController();
  final TextEditingController rideDescController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final RideService _rideService = RideService();
  final MapController _mapController = MapController();
  bool isCreating = false;
  bool isResolvingDestination = false;
  bool loadingCurrentLocation = true;
  String currentLocationLabel = "Locating your current position...";
  String destinationPreviewLabel = "Start typing to preview route on map";
  LatLng? currentLatLng;
  LatLng? destinationLatLng;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  static const LatLng _indiaFallback = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    destinationController.addListener(_onDestinationChanged);
    _loadCurrentLocation();
  }

  void _onDestinationChanged() {
    _searchDebounce?.cancel();
    final query = destinationController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        destinationLatLng = null;
        destinationPreviewLabel = "Start typing to preview route on map";
        isResolvingDestination = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 550), () {
      _searchDestination(query);
    });

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          loadingCurrentLocation = false;
          currentLocationLabel = "Location service disabled";
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          loadingCurrentLocation = false;
          currentLocationLabel = "Location permission not granted";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final resolved = LatLng(position.latitude, position.longitude);
      final label = await _reverseGeocode(resolved);

      if (!mounted) return;
      setState(() {
        currentLatLng = resolved;
        loadingCurrentLocation = false;
        currentLocationLabel = label;
      });
      _moveMapTo(resolved, zoom: 14);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingCurrentLocation = false;
        currentLocationLabel = "Unable to fetch current location";
      });
    }
  }

  Future<void> _searchDestination(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return;

    final requestId = ++_searchRequestId;
    if (!mounted) return;
    setState(() {
      isResolvingDestination = true;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
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
        throw Exception('Could not resolve destination');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        throw Exception('No matching destination found');
      }

      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('Invalid destination response');
      }
      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lon = double.tryParse((first['lon'] ?? '').toString());
      final displayName = (first['display_name'] ?? '').toString().trim();
      if (lat == null || lon == null) {
        throw Exception('Location coordinates missing');
      }

      if (!mounted || requestId != _searchRequestId) return;
      final resolved = LatLng(lat, lon);
      setState(() {
        destinationLatLng = resolved;
        destinationPreviewLabel =
            displayName.isNotEmpty ? displayName : trimmed;
        isResolvingDestination = false;
      });
      _moveMapTo(resolved, zoom: 14.5);
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        isResolvingDestination = false;
        destinationPreviewLabel = "Destination not found. Try another search";
      });
    }
  }

  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _latLngText(point);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _latLngText(point);
      }
      final displayName = (decoded['display_name'] ?? '').toString().trim();
      if (displayName.isEmpty) {
        return _latLngText(point);
      }
      return displayName;
    } catch (_) {
      return _latLngText(point);
    }
  }

  void _moveMapTo(LatLng point, {double zoom = 14}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(point, zoom);
      } catch (_) {}
    });
  }

  String _latLngText(LatLng point) {
    return "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
  }

  Future<void> createRide() async {
    if (isCreating) return;

    final rideName = rideNameController.text.trim();
    final destination = destinationController.text.trim();

    if (rideName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter ride name")));
      return;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter destination")));
      return;
    }

    setState(() {
      isCreating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    try {
      final creatorId = prefs.getString("userId") ?? "";
      if (!_looksLikeUuid(creatorId)) {
        throw Exception("User session missing. Please login again.");
      }

      final startLocation = await _resolveStartLocation();
      await _rideService.createRide(
        creatorId: creatorId,
        title: rideName,
        startLocation: startLocation,
        endLocation: destination,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ride created successfully")),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to create ride: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFDA620B);
    const primaryDark = Color(0xFFB04D08);
    const background = Color(0xFFF8F7F5);
    const forest = Color(0xFF1E3A29);
    const neutralWarm = Color(0xFF8A817C);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(forest, neutralWarm),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textField(
                          label: "Ride Name",
                          controller: rideNameController,
                          hint: "Ride Name",
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 18),
                        _textField(
                          label: "Description (Optional)",
                          controller: rideDescController,
                          hint: "Description",
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        _destinationBlock(
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _footerAction(primary, primaryDark, background),
        ],
      ),
    );
  }

  Widget _header(Color forest, Color neutralWarm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.w600, color: neutralWarm),
            ),
          ),
          Text(
            "New Ride",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: forest,
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color forest,
    required Color primary,
    required Color neutralWarm,
    required Color background,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: forest, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        hintStyle: TextStyle(color: neutralWarm),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _destinationBlock({
    required Color forest,
    required Color primary,
    required Color neutralWarm,
    required Color background,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "RIDE ROUTE",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: forest.withOpacity(0.8),
              ),
            ),
            Row(
              children: [
                if (isResolvingDestination)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                else
                  Icon(Icons.auto_awesome, size: 14, color: primary),
                const SizedBox(width: 6),
                Text(
                  "Auto Preview",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Icon(Icons.my_location, color: primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loadingCurrentLocation
                      ? "Detecting current location..."
                      : currentLocationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: destinationController,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: forest,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search location",
                          hintStyle: TextStyle(color: neutralWarm),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: currentLatLng ?? _indiaFallback,
                          initialZoom: currentLatLng != null ? 13 : 5,
                          minZoom: 3,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.journeysync',
                          ),
                          if (currentLatLng != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: currentLatLng!,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: forest,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (destinationLatLng != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: destinationLatLng!,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primary,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (currentLatLng != null && destinationLatLng != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [currentLatLng!, destinationLatLng!],
                                  color: primary.withOpacity(0.7),
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Live Route Preview",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        destinationController.text.isEmpty
                            ? destinationPreviewLabel
                            : destinationPreviewLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footerAction(Color primary, Color primaryDark, Color background) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background.withOpacity(0), background],
          ),
        ),
        child: ElevatedButton(
          onPressed: isCreating ? null : createRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: primary.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCreating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else ...[
                Text(
                  "Go Live",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _resolveStartLocation() async {
    final cached = currentLatLng;
    if (cached != null) {
      return "${cached.latitude.toStringAsFixed(6)},${cached.longitude.toStringAsFixed(6)}";
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return "Unknown start";
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return "Unknown start";
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return "${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}";
    } catch (_) {
      return "Unknown start";
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    destinationController.removeListener(_onDestinationChanged);
    rideNameController.dispose();
    rideDescController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }
}
