import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/ride_loading_indicator.dart';

enum EssentialType {
  fuel('Fuel Stations', Icons.local_gas_station_rounded, 'amenity', 'fuel'),
  cafes('Cafes', Icons.local_cafe_rounded, 'amenity', 'cafe'),
  mechanics('Mechanics', Icons.build_rounded, 'shop', 'car_repair');

  const EssentialType(this.title, this.icon, this.osmKey, this.osmValue);

  final String title;
  final IconData icon;
  final String osmKey;
  final String osmValue;
}

class NearbyEssentialsScreen extends StatefulWidget {
  const NearbyEssentialsScreen({super.key, required this.type});

  final EssentialType type;

  @override
  State<NearbyEssentialsScreen> createState() => _NearbyEssentialsScreenState();
}

class _NearbyEssentialsScreenState extends State<NearbyEssentialsScreen> {
  bool _loading = true;
  String _error = '';
  List<_EssentialPlace> _places = const <_EssentialPlace>[];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final origin = await _resolvePosition();
      final lat = origin?.latitude ?? 12.9716;
      final lng = origin?.longitude ?? 77.5946;
      final query =
          '[out:json][timeout:6];node["${widget.type.osmKey}"="${widget.type.osmValue}"](around:9000,$lat,$lng);out body;';
      final uri = Uri.https('overpass-api.de', '/api/interpreter', {
        'data': query,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('OpenStreetMap search is unavailable.');
      }
      final data = jsonDecode(response.body);
      final elements = data is Map<String, dynamic> ? data['elements'] : null;
      if (elements is! List) {
        throw Exception('No nearby places found.');
      }
      final places = <_EssentialPlace>[];
      for (final element in elements) {
        if (element is! Map<String, dynamic>) continue;
        final placeLat = (element['lat'] as num?)?.toDouble();
        final placeLng = (element['lon'] as num?)?.toDouble();
        if (placeLat == null || placeLng == null) continue;
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final name =
            (tags['name'] ?? tags['brand'] ?? widget.type.title).toString();
        final distance =
            Geolocator.distanceBetween(lat, lng, placeLat, placeLng) / 1000;
        places.add(
          _EssentialPlace(
            name: name,
            subtitle:
                (tags['addr:street'] ?? tags['operator'] ?? 'Nearby')
                    .toString(),
            lat: placeLat,
            lng: placeLng,
            distanceKm: distance,
          ),
        );
      }
      places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      if (!mounted) return;
      setState(() => _places = places.take(8).toList(growable: false));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not load nearby ${widget.type.title}.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position?> _resolvePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _navigate(_EssentialPlace place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body:
          _loading
              ? const Center(child: RideLoadingIndicator(label: 'Searching'))
              : _error.isNotEmpty
              ? JourneyScreen(
                scrollable: false,
                child: EmptyStateCard(
                  title: widget.type.title,
                  message: _error,
                  icon: widget.type.icon,
                  foreground: AppColors.forest,
                ),
              )
              : SafeArea(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: _places.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return JourneyHeader(
                        surface: true,
                        leading: const JourneyBackButton(),
                        title: widget.type.title,
                      );
                    }
                    final place = _places[index - 1];
                    return GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              widget.type.icon,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${place.distanceKm.toStringAsFixed(1)} km - ${place.subtitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _navigate(place),
                            icon: const Icon(Icons.navigation_rounded),
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class _EssentialPlace {
  const _EssentialPlace({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  final String name;
  final String subtitle;
  final double lat;
  final double lng;
  final double distanceKm;
}
