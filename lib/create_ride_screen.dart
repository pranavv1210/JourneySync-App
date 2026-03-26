import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_toast.dart';
import 'ride_service.dart';
import 'ride_lobby_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController rideNameController = TextEditingController();
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
  final List<_DestinationSuggestion> _suggestions = <_DestinationSuggestion>[];
  bool _showSuggestions = false;
  bool _suppressSearchOnTextChange = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  static const LatLng _indiaFallback = LatLng(20.5937, 78.9629);
  double maxRiders = 15;

  @override
  void initState() {
    super.initState();
    destinationController.addListener(_onDestinationChanged);
    _loadCurrentLocation();
  }

  void _onDestinationChanged() {
    if (_suppressSearchOnTextChange) {
      _suppressSearchOnTextChange = false;
      return;
    }

    _searchDebounce?.cancel();
    final query = destinationController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        destinationLatLng = null;
        destinationPreviewLabel = "Start typing to preview route on map";
        isResolvingDestination = false;
        _suggestions.clear();
        _showSuggestions = false;
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
        'limit': '5',
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

      final parsedSuggestions = <_DestinationSuggestion>[];
      for (final item in decoded.take(5)) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse((item['lat'] ?? '').toString());
        final lon = double.tryParse((item['lon'] ?? '').toString());
        final displayName = (item['display_name'] ?? '').toString().trim();
        if (lat == null || lon == null || displayName.isEmpty) continue;
        parsedSuggestions.add(
          _DestinationSuggestion(title: displayName, point: LatLng(lat, lon)),
        );
      }
      if (parsedSuggestions.isEmpty) {
        throw Exception('No matching destination found');
      }

      if (!mounted || requestId != _searchRequestId) return;
      final top = parsedSuggestions.first;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(parsedSuggestions);
        _showSuggestions = true;
        destinationLatLng = top.point;
        destinationPreviewLabel = top.title;
        isResolvingDestination = false;
      });
      _moveMapTo(top.point, zoom: 14.5);
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        isResolvingDestination = false;
        destinationPreviewLabel = "Destination not found. Try another search";
        _suggestions.clear();
        _showSuggestions = false;
      });
    }
  }

  void _selectSuggestion(_DestinationSuggestion suggestion) {
    _searchDebounce?.cancel();
    _suppressSearchOnTextChange = true;
    destinationController.text = suggestion.title;
    destinationController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.title.length),
    );
    setState(() {
      destinationLatLng = suggestion.point;
      destinationPreviewLabel = suggestion.title;
      _showSuggestions = false;
      _suggestions.clear();
    });
    _moveMapTo(suggestion.point, zoom: 14.5);
    FocusScope.of(context).unfocus();
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
      showAppToast(context, "Enter ride name", type: AppToastType.error);
      return;
    }

    if (destination.isEmpty) {
      showAppToast(context, "Enter destination", type: AppToastType.error);
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
      final createdRide = await _rideService.createRide(
        creatorId: creatorId,
        title: rideName,
        startLocation: startLocation,
        endLocation: destination,
        scheduledStartTime: null,
        maxRiders: maxRiders.round(),
      );

      if (!mounted) return;
      showAppToast(
        context,
        "Ride created successfully",
        type: AppToastType.success,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => RideLobbyScreen(
                rideId: createdRide.id,
                initialMaxRiders: maxRiders.round(),
              ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        "Failed to create ride: ${_createRideErrorMessage(error)}",
        type: AppToastType.error,
      );
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
                        const SizedBox(height: 24),
                        _destinationBlock(
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                        ),
                        const SizedBox(height: 20),
                        _logisticsSection(
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
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
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
                color: forest.withValues(alpha: 0.8),
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
            border: Border.all(color: primary.withValues(alpha: 0.18)),
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
                color: primary.withValues(alpha: 0.08),
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
                child: Column(
                  children: [
                    Row(
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
                    if (_showSuggestions && _suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 170),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return InkWell(
                              onTap: () => _selectSuggestion(suggestion),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        suggestion.title,
                                        maxLines: 2,
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
                            );
                          },
                        ),
                      ),
                    ],
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
                          if (currentLatLng != null &&
                              destinationLatLng != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [currentLatLng!, destinationLatLng!],
                                  color: primary.withValues(alpha: 0.7),
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
                            Colors.black.withValues(alpha: 0.12),
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
                        color: Colors.black.withValues(alpha: 0.5),
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
                        color: Colors.black.withValues(alpha: 0.45),
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
            colors: [background.withValues(alpha: 0), background],
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
            shadowColor: primary.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _logisticsSection({
    required Color forest,
    required Color primary,
    required Color neutralWarm,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "MAXIMUM RIDERS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: forest.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups_rounded, color: primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Max Riders",
                        style: TextStyle(
                          color: forest,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    maxRiders.round().toString(),
                    style: TextStyle(
                      color: primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primary,
                  inactiveTrackColor: primary.withValues(alpha: 0.18),
                  thumbColor: Colors.white,
                  overlayColor: primary.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: Slider(
                  min: 1,
                  max: 25,
                  divisions: 24,
                  value: maxRiders,
                  onChanged: (value) {
                    setState(() {
                      maxRiders = value;
                    });
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    "Solo",
                    style: TextStyle(
                      color: neutralWarm,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Unlimited",
                    style: TextStyle(
                      color: neutralWarm,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
    destinationController.dispose();
    super.dispose();
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }

  String _createRideErrorMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('end_location') && lower.contains('pgrst204')) {
      return 'Server schema mismatch detected, but app fallback should handle it. Please retry once.';
    }
    if (lower.contains('creator_id') && lower.contains('pgrst204')) {
      return 'Server DB mismatch: rides.creator_id is missing from Supabase schema cache. Add the column or use user_id and reload schema cache.';
    }
    if (lower.contains('rls')) {
      return 'Supabase RLS blocked ride creation. Add INSERT/SELECT policy for rides.';
    }
    return text;
  }
}

class _DestinationSuggestion {
  const _DestinationSuggestion({required this.title, required this.point});

  final String title;
  final LatLng point;
}
