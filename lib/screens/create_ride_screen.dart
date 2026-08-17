import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../services/app_navigation.dart';
import '../models/ride_route.dart';
import '../services/ride_service.dart';
import '../services/supabase_service.dart';
import 'ride_lobby_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({
    super.key,
    this.initialRideName,
    this.initialDestination,
    this.initialMaxRiders,
  });

  final String? initialRideName;
  final String? initialDestination;
  final int? initialMaxRiders;

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController rideNameController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController stopsController = TextEditingController();
  final RideService _rideService = RideService();
  final SupabaseService _supabaseService = SupabaseService();
  final MapController _mapController = MapController();
  bool isCreating = false;
  bool isResolvingDestination = false;
  bool isLoadingGarage = true;
  bool loadingCurrentLocation = true;
  String currentLocationLabel = 'Locating your current position...';
  String destinationPreviewLabel = 'Start typing to preview route on map';
  LatLng? currentLatLng;
  LatLng? destinationLatLng;
  List<Map<String, String>> garageBikes = const [];
  String selectedBikeId = '';
  final List<_DestinationSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _suppressSearchOnTextChange = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  static const LatLng _indiaFallback = LatLng(20.5937, 78.9629);
  double maxRiders = 15;

  @override
  void initState() {
    super.initState();
    rideNameController.text = widget.initialRideName ?? '';
    destinationController.text = widget.initialDestination ?? '';
    if (widget.initialMaxRiders != null) {
      maxRiders = widget.initialMaxRiders!.clamp(1, 25).toDouble();
    }
    destinationController.addListener(_onDestinationChanged);
    _loadCurrentLocation();
    _loadGarage();
    if (destinationController.text.trim().isNotEmpty) {
      _searchDestination(destinationController.text.trim());
    }
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
        destinationPreviewLabel = 'Start typing to preview route on map';
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
          currentLocationLabel = 'Location service disabled';
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
          currentLocationLabel = 'Location permission not granted';
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
        currentLocationLabel = 'Unable to fetch current location';
      });
    }
  }

  Future<void> _searchDestination(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return;

    final requestId = ++_searchRequestId;
    if (!mounted) return;
    setState(() => isResolvingDestination = true);

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '5',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)'},
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
        destinationPreviewLabel = 'Destination not found. Try another search';
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
        headers: {'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _latLngText(point);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _latLngText(point);
      final displayName = (decoded['display_name'] ?? '').toString().trim();
      if (displayName.isEmpty) return _latLngText(point);
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
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> createRide() async {
    if (isCreating) return;

    final rideName = rideNameController.text.trim();
    final destination = destinationController.text.trim();

    if (rideName.isEmpty) {
      showPremiumToast(
        context,
        'Enter ride name',
        type: PremiumToastType.error,
      );
      return;
    }

    if (destination.isEmpty) {
      showPremiumToast(
        context,
        'Enter destination',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => isCreating = true);

    final prefs = await SharedPreferences.getInstance();
    try {
      final creatorId = await _resolveCreatorId(prefs);
      if (creatorId.isEmpty) {
        throw Exception(
          'Profile session unavailable. Sign in again to create rides.',
        );
      }

      if (garageBikes.isEmpty || selectedBikeId.isEmpty) {
        throw Exception(
          'No vehicle found in garage. Add a vehicle before creating a ride.',
        );
      }
      final selectedBikeName = _bikeName(_selectedBike);
      await prefs.setString('userActiveBikeId', selectedBikeId);
      await prefs.setString('userBike', selectedBikeName);

      final startLocation = await _resolveStartLocation();
      final createdRide = await _rideService.createRide(
        creatorId: creatorId,
        title: rideName,
        startLocation: startLocation,
        endLocation: destination,
        scheduledStartTime: null,
        maxRiders: maxRiders.round(),
      );

      final routeStops = await _resolveStops(destination);
      await _rideService.saveRideRoute(
        rideId: createdRide.id,
        hostId: creatorId,
        startLabel: currentLocationLabel,
        endLabel: destination,
        stops: routeStops,
      );

      if (!mounted) return;
      showPremiumToast(
        context,
        'Ride created successfully',
        type: PremiumToastType.success,
      );
      unawaited(
        replaceWithAppRoute(
          context,
          RideLobbyScreen(
            rideId: createdRide.id,
            initialMaxRiders: maxRiders.round(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Failed to create ride: ${_createRideErrorMessage(error)}',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _buildFooterAction(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRideNameField(),
                    const SizedBox(height: 18),
                    _buildDestinationSection(),
                    const SizedBox(height: 18),
                    _buildVehicleSection(),
                    const SizedBox(height: 18),
                    _buildLogisticsSection(),
                    const SizedBox(height: 18),
                    _buildStopsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: JourneyHeader(
        surface: true,
        leading: JourneyBackButton(),
        title: 'Create Ride',
      ),
    );
  }

  Widget _buildFooterAction() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: AppColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: PremiumButton(
          label: isCreating ? 'Creating...' : 'Go Live',
          icon: isCreating ? null : Icons.arrow_forward_rounded,
          loading: isCreating,
          onPressed: isCreating ? null : createRide,
        ),
      ),
    );
  }

  Widget _buildRideNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIDE NAME',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.sm,
          ),
          child: TextField(
            controller: rideNameController,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.primary,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Sunday breakfast ride',
              hintStyle: AppTypography.titleMedium.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.route_outlined,
                color: AppColors.primary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RIDE ROUTE',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.forest.withValues(alpha: 0.8),
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
                      color: AppColors.primary,
                    ),
                  )
                else
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Auto Preview',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Current location
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.my_location, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loadingCurrentLocation
                      ? 'Detecting current location...'
                      : currentLocationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Map + search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.md,
          ),
          child: Column(
            children: [
              // Search field
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: destinationController,
                            cursorColor: AppColors.primary,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search destination',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder:
                              (_, __) =>
                                  Divider(height: 1, color: AppColors.divider),
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
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        suggestion.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.forest,
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
              // Map preview
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
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
                            userAgentPackageName: 'com.journeysync.app',
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
                                      color: AppColors.forest,
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
                                      color: AppColors.primary,
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
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
                        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Live Route Preview',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
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
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        destinationController.text.isEmpty
                            ? destinationPreviewLabel
                            : destinationPreviewLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

  Widget _buildStopsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROUTE STOPS',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.forest.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: stopsController,
          minLines: 2,
          maxLines: 4,
          cursorColor: AppColors.primary,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.forest,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Optional. Add one stop per line',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            helperText: 'Example: Fuel stop\nBreakfast point',
            helperStyle: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MAXIMUM RIDERS',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.forest.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Max Riders',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    maxRiders.round().toString(),
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
                  thumbColor: Colors.white,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: Slider(
                  min: 1,
                  max: 25,
                  divisions: 24,
                  value: maxRiders,
                  onChanged: (value) => setState(() => maxRiders = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadGarage() async {
    final prefs = await SharedPreferences.getInstance();
    var bikes = _decodeGaragePrefs(prefs.getStringList('garageBikes') ?? []);
    var activeBikeId = (prefs.getString('userActiveBikeId') ?? '').trim();
    var userId = (prefs.getString('userId') ?? '').trim();
    if (userId.isEmpty) {
      userId = await _resolveCreatorId(prefs);
    }

    if (userId.isNotEmpty) {
      try {
        final remote = await _supabaseService.fetchGarage(userId: userId);
        if (remote != null && remote.bikes.isNotEmpty) {
          bikes = remote.bikes;
          activeBikeId = remote.activeBikeId;
        }
      } catch (_) {}
    }

    if (activeBikeId.isEmpty ||
        !bikes.any((bike) => bike['id'] == activeBikeId)) {
      activeBikeId = bikes.isNotEmpty ? (bikes.first['id'] ?? '') : '';
    }

    if (!mounted) return;
    setState(() {
      garageBikes = bikes;
      selectedBikeId = activeBikeId;
      isLoadingGarage = false;
    });
  }

  List<Map<String, String>> _decodeGaragePrefs(List<String> rows) {
    return rows
        .map((row) {
          final parts = row.split('|');
          return <String, String>{
            'id': parts.isNotEmpty ? parts[0] : '',
            'brand': parts.length > 1 ? parts[1] : '',
            'model': parts.length > 2 ? parts[2] : '',
            'cc': parts.length > 3 ? parts[3] : '',
            'nickname': parts.length > 4 ? parts[4] : 'Motorcycle',
            'fuelType': parts.length > 5 ? parts[5] : 'Petrol',
            'imagePath': parts.length > 6 ? parts[6] : '',
          };
        })
        .where((bike) => (bike['id'] ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, String> get _selectedBike {
    return garageBikes.firstWhere(
      (bike) => bike['id'] == selectedBikeId,
      orElse: () => garageBikes.isNotEmpty ? garageBikes.first : const {},
    );
  }

  String _bikeName(Map<String, String> bike) {
    final brand = (bike['brand'] ?? '').trim();
    final model = (bike['model'] ?? '').trim();
    final nickname = (bike['nickname'] ?? '').trim();
    final name = '$brand $model'.trim();
    return name.isNotEmpty
        ? name
        : (nickname.isNotEmpty ? nickname : 'Motorcycle');
  }

  Future<String> _resolveCreatorId(SharedPreferences prefs) async {
    final cachedId = (prefs.getString('userId') ?? '').trim();
    if (cachedId.isNotEmpty) return cachedId;

    final row = await _supabaseService.fetchOrCreateCurrentUserProfile(
      cachedUserId: cachedId,
      cachedPhone: prefs.getString('userPhone') ?? '',
      cachedName: prefs.getString('userName') ?? 'Rider',
      cachedBike: prefs.getString('userBike') ?? 'No bike added',
    );
    final resolvedId =
        (row?['id'] ?? row?['auth_user_id'] ?? '').toString().trim();
    if (resolvedId.isNotEmpty) {
      await prefs.setString('userId', resolvedId);
    }
    return resolvedId;
  }

  Widget _buildVehicleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIDE VEHICLE',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.forest.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          child:
              isLoadingGarage
                  ? Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading garage',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                  : garageBikes.isEmpty
                  ? Row(
                    children: [
                      Icon(
                        Icons.two_wheeler_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No vehicle found in garage. Add a vehicle from Profile before creating a ride.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                  : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBikeId.isEmpty ? null : selectedBikeId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items:
                          garageBikes.map((bike) {
                            final id = bike['id'] ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.two_wheeler_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _bikeName(bike),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.forest,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedBikeId = value);
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Future<String> _resolveStartLocation() async {
    if (currentLocationLabel.isNotEmpty &&
        currentLocationLabel != 'Locating your current position...' &&
        currentLocationLabel != 'Location service disabled' &&
        currentLocationLabel != 'Location permission not granted' &&
        currentLocationLabel != 'Unable to fetch current location') {
      return currentLocationLabel;
    }
    if (currentLatLng != null) return _latLngText(currentLatLng!);
    return 'Current location';
  }

  Future<List<RouteStop>> _resolveStops(String destination) async {
    final lines = stopsController.text.trim();
    if (lines.isEmpty) return [];
    final parts =
        lines
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
    return parts.asMap().entries.map((entry) {
      return RouteStop(
        label: entry.value,
        latitude: null,
        longitude: null,
        order: entry.key,
      );
    }).toList();
  }

  String _createRideErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('RLS') || text.contains('row-level security')) {
      return 'Database permission issue. Check Supabase RLS policies.';
    }
    if (text.length > 100) return text.substring(0, 100);
    return text;
  }

  @override
  void dispose() {
    rideNameController.dispose();
    destinationController.dispose();
    stopsController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
}

class _DestinationSuggestion {
  const _DestinationSuggestion({required this.title, required this.point});
  final String title;
  final LatLng point;
}
