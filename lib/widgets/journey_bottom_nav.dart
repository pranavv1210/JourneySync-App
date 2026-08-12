import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class JourneyBottomNavDestination {
  const JourneyBottomNavDestination({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
}

class JourneyBottomNav extends StatelessWidget {
  const JourneyBottomNav({
    super.key,
    required this.destinations,
    required this.onCreate,
  });

  final List<JourneyBottomNavDestination> destinations;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 12 + bottom),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 74,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.64),
                    ),
                    boxShadow: AppShadows.glass,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavItem(destination: destinations[0]),
                      _NavItem(destination: destinations[1]),
                      const SizedBox(width: 78),
                      _NavItem(destination: destinations[2]),
                      _NavItem(destination: destinations[3]),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: -24, child: _CreateRideButton(onPressed: onCreate)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination});

  final JourneyBottomNavDestination destination;

  @override
  Widget build(BuildContext context) {
    final active = destination.active;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: destination.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color:
                active
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.08 : 1,
                duration: AppDurations.fast,
                child: Icon(
                  destination.icon,
                  size: 21,
                  color: active ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: active ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRideButton extends StatefulWidget {
  const _CreateRideButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CreateRideButton> createState() => _CreateRideButtonState();
}

class _CreateRideButtonState extends State<_CreateRideButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: AppDurations.fast,
        curve: AppCurves.easeOutCubic,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: AppShadows.primary,
          ),
          child: const Icon(
            Icons.add_road_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
