import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_navigation.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import 'create_ride_screen.dart';
import 'nearby_essentials_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherSnapshot? _weather;
  bool _loadingWeather = true;

  static const List<_Destination> _destinations = [
    _Destination(
      name: 'Nandi Hills',
      subtitle: 'Sunrise bends and breakfast runs',
      distance: '61 km',
      image:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Sunrise_at_Nandi_Hills.jpg/960px-Sunrise_at_Nandi_Hills.jpg',
      description:
          'A classic early-morning ride with flowing roads, hill views, and fast breakfast stops near the top.',
      mapQuery: 'Nandi Hills Karnataka',
    ),
    _Destination(
      name: 'Mysore',
      subtitle: 'Fast highway touring',
      distance: '145 km',
      image:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Mysore_Palace_Morning.jpg/960px-Mysore_Palace_Morning.jpg',
      description:
          'A smooth day ride with wide highways, food stops, and a relaxed city finish.',
      mapQuery: 'Mysore Karnataka',
    ),
    _Destination(
      name: 'Skandagiri',
      subtitle: 'Compact hill escape',
      distance: '62 km',
      image:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Skandagiri.jpg/960px-Skandagiri.jpg',
      description:
          'Short, scenic, and best for early starts when the weather is clear.',
      mapQuery: 'Skandagiri Karnataka',
    ),
    _Destination(
      name: 'Chikkamagaluru',
      subtitle: 'Coffee estate touring',
      distance: '243 km',
      image:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/Chikmagalur%2C_India._%287793316622%29.jpg/960px-Chikmagalur%2C_India._%287793316622%29.jpg',
      description:
          'A weekend-grade route with estates, mountain air, and winding sections.',
      mapQuery: 'Chikkamagaluru Karnataka',
    ),
    _Destination(
      name: 'Ooty',
      subtitle: 'Hairpins and cold air',
      distance: '270 km',
      image:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/Ooty_lake.jpg/960px-Ooty_lake.jpg',
      description:
          'A longer hill ride with cool weather, elevation changes, and technical climbs.',
      mapQuery: 'Ooty Tamil Nadu',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final weather = await _weatherService.fetchCurrentWeather();
    if (!mounted) return;
    setState(() {
      _weather = weather;
      _loadingWeather = false;
    });
  }

  int get _rideScore {
    final weather = _weather;
    if (weather == null) return 72;
    var score = 92;
    score -= (weather.rainChance * 0.45).round();
    if (weather.windSpeed > 18) score -= 14;
    if (weather.temperature > 92 || weather.temperature < 45) score -= 12;
    if (weather.visibility < 5) score -= 10;
    return score.clamp(42, 98);
  }

  String get _recommendation {
    final weather = _weather;
    if (weather == null) return 'Checking ride conditions';
    if (weather.rainChance >= 60) return 'Rain expected. Keep rides short.';
    if (weather.windSpeed > 18) return 'Windy conditions. Ride steady.';
    if (weather.temperature > 92) return 'Hot day. Hydrate often.';
    if (weather.alerts.isNotEmpty) return weather.alerts.first;
    return 'Perfect riding weather';
  }

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showWeatherDetails() {
    final weather = _weather;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ride Conditions',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _detailRow('Ride score', '$_rideScore/100'),
                _detailRow('Weather', weather?.displayText ?? 'Unavailable'),
                _detailRow('Rain', '${weather?.rainChance ?? 0}%'),
                _detailRow('Wind', '${weather?.windSpeed.round() ?? 0} mph'),
                _detailRow(
                  'Visibility',
                  '${weather?.visibility.round() ?? 0} km',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showDestination(_Destination destination) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Image.network(
                    destination.image,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destination.name,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      destination.distance,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  destination.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMaps(destination.mapQuery),
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Navigate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            () => Navigator.push(
                              context,
                              buildAppRoute(const CreateRideScreen()),
                            ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Ride'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Explore',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _conditionsCard(),
          const SizedBox(height: 24),
          _sectionTitle('Popular Destinations'),
          const SizedBox(height: 12),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder:
                  (context, index) => _destinationCard(_destinations[index]),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Nearby Essentials'),
          const SizedBox(height: 12),
          _essentialsRow(),
          const SizedBox(height: 24),
          _comingSoonCard(),
        ],
      ),
    );
  }

  Widget _conditionsCard() {
    return GlassCard(
      onTap: _showWeatherDetails,
      padding: const EdgeInsets.all(20),
      elevated: true,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loadingWeather
                      ? 'Loading conditions'
                      : '$_rideScore Ride Score',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _weather?.displayText ?? 'Weather unavailable',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _recommendation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Text(
      value.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.primary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _destinationCard(_Destination destination) {
    return GestureDetector(
      onTap: () => _showDestination(destination),
      child: SizedBox(
        width: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(destination.image, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${destination.distance} - ${destination.subtitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _essentialsRow() {
    return Row(
      children: [
        _essentialButton(EssentialType.fuel),
        const SizedBox(width: 12),
        _essentialButton(EssentialType.cafes),
        const SizedBox(width: 12),
        _essentialButton(EssentialType.mechanics),
      ],
    );
  }

  Widget _essentialButton(EssentialType type) {
    return Expanded(
      child: GlassCard(
        onTap:
            () => Navigator.push(
              context,
              buildAppRoute(NearbyEssentialsScreen(type: type)),
            ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(type.icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              type == EssentialType.fuel
                  ? 'Fuel'
                  : type == EssentialType.cafes
                  ? 'Cafes'
                  : 'Mechanics',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comingSoonCard() {
    const items = [
      (Icons.star_rounded, 'Featured Routes'),
      (Icons.landscape_rounded, 'Hidden Gems'),
      (Icons.photo_camera_rounded, 'Scenic Viewpoints'),
      (Icons.groups_rounded, 'Rider Community'),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        runSpacing: 12,
        spacing: 12,
        children:
            items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      item.$2,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.name,
    required this.subtitle,
    required this.distance,
    required this.image,
    required this.description,
    required this.mapQuery,
  });

  final String name;
  final String subtitle;
  final String distance;
  final String image;
  final String description;
  final String mapQuery;
}
