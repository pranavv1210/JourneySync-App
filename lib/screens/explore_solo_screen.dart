import 'package:flutter/material.dart';

import '../services/app_navigation.dart';
import '../services/ride_flow_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
import '../widgets/journey_screen.dart';
import '../widgets/ride_flow_map_preview.dart';
import 'ride_mode_screen.dart';

class ExploreSoloScreen extends StatefulWidget {
  const ExploreSoloScreen({super.key});

  @override
  State<ExploreSoloScreen> createState() => _ExploreSoloScreenState();
}

class _ExploreSoloScreenState extends State<ExploreSoloScreen> {
  final RideFlowService _rideFlowService = RideFlowService();
  final TextEditingController _destinationController = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _startSoloRide() async {
    if (_starting) return;
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      showPremiumToast(
        context,
        'Add a destination for your solo ride.',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => _starting = true);
    try {
      final origin = await _rideFlowService.resolveCurrentLocation();
      final ride = await _rideFlowService.createRide(
        title: destination,
        startLocation: origin.coordinateLabel,
        endLocation: destination,
        rideVisibility: 'private',
        rideMode: 'solo',
        status: 'active',
        maxRiders: 1,
      );
      await _rideFlowService.startRide(ride.id);
      await _rideFlowService.saveSimpleRoute(
        ride: ride,
        startLabel: origin.label,
        endLabel: destination,
      );
      if (!mounted) return;
      replaceWithAppRoute(context, RideModeScreen(rideId: ride.id));
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not start solo ride: $error',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return JourneyScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyHeader(
            surface: true,
            leading: JourneyBackButton(),
            eyebrow: 'PRIVATE RIDE',
            title: 'Explore Solo',
            subtitle:
                'A private ride journal for navigation, SOS, stats, achievements, and memories.',
          ),
          const SizedBox(height: AppSpacing.xl),
          JourneyHeroBand(
            icon: Icons.landscape_rounded,
            color: AppColors.forest,
            child: Text(
              'Pick a destination and ride at your own pace. This route stays off public radar.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const RideFlowMapPreview(
            title: 'Private route preview',
            subtitle:
                'Your solo ride stays private while navigation and stats remain active.',
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            elevated: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _destinationController,
                  cursorColor: AppColors.primary,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Destination',
                    prefixIcon: Icon(Icons.landscape_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _soloPromise(
                  Icons.visibility_off_rounded,
                  'Never appears on public radar',
                ),
                _soloPromise(
                  Icons.query_stats_rounded,
                  'Records distance, duration, and ride stats',
                ),
                _soloPromise(
                  Icons.sos_rounded,
                  'Keeps emergency SOS available',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PremiumButton(
            label: _starting ? 'Starting solo ride...' : 'Start Solo Ride',
            icon: Icons.navigation_rounded,
            loading: _starting,
            disabled: _starting,
            onPressed: _startSoloRide,
          ),
        ],
      ),
    );
  }

  Widget _soloPromise(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.forest, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
