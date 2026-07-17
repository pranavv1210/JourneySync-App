import 'package:flutter/material.dart';

import '../services/app_navigation.dart';
import '../services/ride_flow_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_toast.dart';
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
        title: 'Solo exploration',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                'Explore Solo',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A private ride journal for navigation, SOS, stats, achievements, and memories.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              GlassCard(
                elevated: true,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _destinationController,
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
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Spacer(),
        Text(
          'PRIVATE JOURNAL',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.forest,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
