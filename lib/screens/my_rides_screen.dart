import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/active_ride_coordinator.dart';
import '../models/ride_record.dart';
import '../services/app_navigation.dart';
import '../services/ride_analytics_engine.dart';
import '../services/ride_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_main_bottom_nav.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/ride_loading_indicator.dart';
import 'ride_lobby_screen.dart';
import 'ride_mode_screen.dart';
import 'ride_summary_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final RideService _rideService = RideService();
  bool _loading = true;
  List<RideRecord> _rides = const <RideRecord>[];
  double _totalDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isEmpty) return;
      final rides = await _rideService.fetchRecentRides(userId, limit: 80);
      final historyIds =
          rides
              .where((ride) => ride.isCompleted)
              .map((ride) => ride.id)
              .toSet();
      final stats =
          historyIds.isEmpty
              ? null
              : await RideAnalyticsEngine.aggregateProfileStatsForRideIds(
                historyIds,
              );
      final activeSnapshot = ActiveRideCoordinator.instance.snapshot;
      if (activeSnapshot.hasActiveRide &&
          !rides.any((ride) => ride.id == activeSnapshot.rideId)) {
        await ActiveRideCoordinator.instance.clear();
      }
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _totalDistanceKm = stats?.totalDistanceKm ?? 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RideRecord> get _activeRides =>
      _rides.where((ride) => ride.isActive).toList(growable: false);

  List<RideRecord> get _upcomingRides => _rides
      .where(
        (ride) =>
            !ride.isActive &&
            !ride.isCompleted &&
            ride.status.trim().toLowerCase() != 'cancelled',
      )
      .toList(growable: false);

  List<RideRecord> get _history =>
      _rides.where((ride) => ride.isCompleted).toList(growable: false);

  double get _totalDistance => _totalDistanceKm;

  Future<void> _openRide(RideRecord ride) async {
    if (ride.isActive) {
      await Navigator.push(
        context,
        buildAppRoute(RideModeScreen(rideId: ride.id)),
      );
    } else if (ride.isCompleted) {
      await Navigator.push(
        context,
        buildAppRoute(RideSummaryScreen(rideId: ride.id)),
      );
    } else {
      await Navigator.push(
        context,
        buildAppRoute(RideLobbyScreen(rideId: ride.id)),
      );
    }
  }

  Future<void> _openActiveRide(String rideId) async {
    if (rideId.isEmpty) return;
    if (!_rides.any((ride) => ride.id == rideId)) {
      await ActiveRideCoordinator.instance.clear();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This ride is no longer available.')),
      );
      return;
    }
    await Navigator.push(
      context,
      buildAppRoute(RideModeScreen(rideId: rideId)),
    );
    await _loadRides();
  }

  @override
  Widget build(BuildContext context) {
    final activeSnapshot = ActiveRideCoordinator.instance.snapshot;
    return Scaffold(
      backgroundColor: AppColors.background,
      body:
          _loading
              ? const Center(
                child: RideLoadingIndicator(label: 'Loading rides'),
              )
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadRides,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      120 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      const JourneyHeader(
                        surface: true,
                        leading: JourneyBackButton(),
                        title: 'My Rides',
                      ),
                      const SizedBox(height: 16),
                      _statsCard(),
                      const SizedBox(height: 18),
                      _section(
                        'Active Ride',
                        activeSnapshot.hasActiveRide
                            ? [
                              _resumeCard(
                                'Active ride',
                                activeSnapshot.status.name.toUpperCase(),
                                activeSnapshot.rideId,
                              ),
                            ]
                            : _activeRides.map(_rideCard).toList(),
                        emptyTitle: 'No active ride',
                        emptyMessage:
                            'Live rides you are tracking will appear here.',
                        icon: Icons.navigation_rounded,
                      ),
                      _section(
                        'Upcoming Rides',
                        _upcomingRides.take(4).map(_rideCard).toList(),
                        emptyTitle: 'No upcoming rides',
                        emptyMessage:
                            'Scheduled and joined rides will appear here.',
                        icon: Icons.event_available_rounded,
                      ),
                      _section(
                        'Ride History',
                        _history.take(5).map(_rideCard).toList(),
                        emptyTitle: 'No completed rides',
                        emptyMessage:
                            'Finished rides and summaries will appear here.',
                        icon: Icons.history_rounded,
                      ),
                      _section(
                        'Saved Routes',
                        const <Widget>[],
                        emptyTitle: 'No saved routes',
                        emptyMessage:
                            'Routes saved from completed rides will appear here.',
                        icon: Icons.bookmark_border_rounded,
                      ),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: const AppMainBottomNav(currentTab: AppMainTab.rides),
    );
  }

  Widget _statsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      elevated: true,
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              'Total',
              _rides.length.toString(),
              Icons.two_wheeler_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statTile(
              'Completed',
              _history.length.toString(),
              Icons.flag_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statTile(
              'Distance',
              '${_totalDistance.toStringAsFixed(0)} km',
              Icons.route_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<Widget> children, {
    required String emptyTitle,
    required String emptyMessage,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            EmptyStateCard(
              title: emptyTitle,
              message: emptyMessage,
              icon: icon,
              foreground: AppColors.forest,
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _resumeCard(String title, String subtitle, String rideId) {
    return GlassCard(
      onTap: rideId.isEmpty ? null : () => _openActiveRide(rideId),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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

  Widget _rideCard(RideRecord ride) {
    final title = ride.title.trim().isEmpty ? 'Ride' : ride.title.trim();
    final destination =
        ride.endLocation.trim().isEmpty
            ? 'Destination pending'
            : ride.endLocation;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _openRide(ride),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                ride.isCompleted
                    ? Icons.flag_rounded
                    : ride.isActive
                    ? Icons.navigation_rounded
                    : Icons.event_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
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
      ),
    );
  }
}
