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

class RideNowScreen extends StatefulWidget {
  const RideNowScreen({super.key});

  @override
  State<RideNowScreen> createState() => _RideNowScreenState();
}

class _RideNowScreenState extends State<RideNowScreen> {
  final RideFlowService _rideFlowService = RideFlowService();
  final TextEditingController _destinationController = TextEditingController();
  bool _publicRide = true;
  bool _starting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _startRide() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final session = await _rideFlowService.resolveSession();
      final origin = await _rideFlowService.resolveCurrentLocation();
      final destination = _destinationController.text.trim();
      final title =
          _publicRide ? '${session.userName} is riding now' : 'Private ride';
      final ride = await _rideFlowService.createRide(
        title: title,
        startLocation: origin.coordinateLabel,
        endLocation: destination.isEmpty ? 'Open ride' : destination,
        rideVisibility: _publicRide ? 'public' : 'private',
        rideMode: 'instant',
        status: 'active',
        maxRiders: _publicRide ? 8 : 1,
      );
      await _rideFlowService.startRide(ride.id);
      await _rideFlowService.saveSimpleRoute(
        ride: ride,
        startLabel: origin.label,
        endLabel: destination.isEmpty ? 'Open ride' : destination,
      );
      if (!mounted) return;
      replaceWithAppRoute(context, RideModeScreen(rideId: ride.id));
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not start ride: $error',
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
            eyebrow: 'FAST START',
            title: 'Ride Now',
            subtitle:
                'Start immediately. Make it public if nearby riders can join.',
          ),
          const SizedBox(height: AppSpacing.xl),
          JourneyHeroBand(
            icon: Icons.flash_on_rounded,
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're one tap from going live.",
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Destination is optional for an open ride. Your current location becomes the start point.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const RideFlowMapPreview(
            title: 'Live start point',
            subtitle: 'Your ride starts from your current location.',
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            elevated: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('OPTIONAL DESTINATION'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    hintText: 'Where are you heading?',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _visibilityToggle(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PremiumButton(
            label: _starting ? 'Starting ride...' : 'Start Ride Now',
            icon: Icons.flash_on_rounded,
            loading: _starting,
            disabled: _starting,
            onPressed: _startRide,
          ),
        ],
      ),
    );
  }

  Widget _visibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _publicRide,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary.withValues(alpha: 0.32)
                  : AppColors.divider,
        ),
        onChanged: (value) => setState(() => _publicRide = value),
        title: Text(
          _publicRide ? 'Public radar ride' : 'Private instant ride',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          _publicRide
              ? 'Nearby riders can discover this ride and request to join.'
              : 'Only you can see this ride.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
