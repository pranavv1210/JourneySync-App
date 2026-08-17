import 'dart:async';
import 'package:flutter/material.dart';

import '../screens/explore_screen.dart';
import '../screens/explore_solo_screen.dart';
import '../screens/my_rides_screen.dart';
import '../screens/plan_together_screen.dart';
import '../screens/ride_now_screen.dart';
import '../screens/settings_screen.dart';
import '../services/app_navigation.dart';
import '../services/feedback_prompt_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'journey_bottom_nav.dart';

enum AppMainTab { home, explore, rides }

class AppMainBottomNav extends StatelessWidget {
  const AppMainBottomNav({super.key, required this.currentTab});

  final AppMainTab currentTab;

  Future<void> _record(String feature) {
    return FeedbackPromptService.instance.recordFeatureUse(feature);
  }

  void _goHome(BuildContext context) {
    if (currentTab == AppMainTab.home) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goExplore(BuildContext context) {
    if (currentTab == AppMainTab.explore) return;
    _record('explore');
    Navigator.of(context).pushReplacement(buildAppRoute(const ExploreScreen()));
  }

  void _goRides(BuildContext context) {
    if (currentTab == AppMainTab.rides) return;
    _record('my_rides');
    Navigator.of(context).pushReplacement(buildAppRoute(const MyRidesScreen()));
  }

  Future<void> _showCreateRideSheet(BuildContext context) async {
    unawaited(_record('ride_launcher'));
    final selected = await showAppBottomSheet<String>(
      context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do you want to do?',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _CreateOption(
              value: 'ride_now',
              icon: Icons.flash_on_rounded,
              title: 'Ride Now',
              subtitle: 'Start instantly. Nearby riders can join if public.',
            ),
            _CreateOption(
              value: 'plan_together',
              icon: Icons.event_rounded,
              title: 'Plan Together',
              subtitle: 'Schedule, invite, and organize with your crew.',
            ),
            _CreateOption(
              value: 'explore_solo',
              icon: Icons.landscape_rounded,
              title: 'Explore Solo',
              subtitle: 'Private navigation, stats, and memories.',
            ),
          ],
        );
      },
    );
    if (selected == null || !context.mounted) return;
    unawaited(_record(selected));
    final screen = switch (selected) {
      'ride_now' => const RideNowScreen(),
      'plan_together' => const PlanTogetherScreen(),
      'explore_solo' => const ExploreSoloScreen(),
      _ => const RideNowScreen(),
    };
    await Navigator.of(context).push(buildAppRoute(screen));
  }

  @override
  Widget build(BuildContext context) {
    return JourneyBottomNav(
      onCreate: () => _showCreateRideSheet(context),
      destinations: [
        JourneyBottomNavDestination(
          icon: Icons.home_rounded,
          label: 'Home',
          active: currentTab == AppMainTab.home,
          onTap: () => _goHome(context),
        ),
        JourneyBottomNavDestination(
          icon: Icons.explore_outlined,
          label: 'Explore',
          active: currentTab == AppMainTab.explore,
          onTap: () => _goExplore(context),
        ),
        JourneyBottomNavDestination(
          icon: Icons.two_wheeler_rounded,
          label: 'Rides',
          active: currentTab == AppMainTab.rides,
          onTap: () => _goRides(context),
        ),
        JourneyBottomNavDestination(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          onTap:
              () => Navigator.of(
                context,
              ).pushReplacement(buildAppRoute(const SettingsScreen())),
        ),
      ],
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.pop(context, value),
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: AppSpacing.lg),
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
                  const SizedBox(height: 2),
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
      ),
    );
  }
}
