import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mirrors the interactive Ride Mode story shown on the JourneySync landing
/// page while remaining compact enough for the mobile home screen.
class RideModeBehaviorPreview extends StatefulWidget {
  const RideModeBehaviorPreview({super.key, required this.enabled});

  final bool enabled;

  @override
  State<RideModeBehaviorPreview> createState() =>
      _RideModeBehaviorPreviewState();
}

class _RideModeBehaviorPreviewState extends State<RideModeBehaviorPreview>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 380);
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!widget.enabled) _ringController.repeat();
  }

  @override
  void didUpdateWidget(covariant RideModeBehaviorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _ringController.stop();
      _ringController.value = 0;
    } else {
      _ringController.repeat();
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? const Duration(milliseconds: 80) : _duration;
    final curve = reduceMotion ? Curves.linear : const Cubic(0.23, 1, 0.32, 1);

    if (reduceMotion && _ringController.isAnimating) {
      _ringController.stop();
    } else if (!reduceMotion &&
        !widget.enabled &&
        !_ringController.isAnimating) {
      _ringController.repeat();
    }

    return Semantics(
      container: true,
      label:
          widget.enabled
              ? 'Ride Mode behavior. Incoming call is declined and the riding reply is ready.'
              : 'Ride Mode behavior. Incoming call rings normally and the riding reply is paused.',
      child: Column(
        children: [
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.9)),
          const SizedBox(height: 14),
          _CallPreview(
            enabled: widget.enabled,
            ringController: _ringController,
            reduceMotion: reduceMotion,
            duration: duration,
            curve: curve,
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: curve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: _OutcomeCard(
              key: ValueKey(widget.enabled),
              enabled: widget.enabled,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSlide(
            duration: duration,
            curve: curve,
            offset: widget.enabled ? Offset.zero : const Offset(0, 0.06),
            child: AnimatedOpacity(
              duration: duration,
              curve: curve,
              opacity: widget.enabled ? 1 : 0.48,
              child: _ReplyPreview(enabled: widget.enabled),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallPreview extends StatelessWidget {
  const _CallPreview({
    required this.enabled,
    required this.ringController,
    required this.reduceMotion,
    required this.duration,
    required this.curve,
  });

  final bool enabled;
  final AnimationController ringController;
  final bool reduceMotion;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AnimatedScale(
            duration: duration,
            curve: curve,
            scale: enabled ? 0.92 : 1,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE1ECE8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.forest),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming call',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  'Weekend Crew',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                AnimatedSwitcher(
                  duration: duration,
                  child: Text(
                    enabled
                        ? 'Checking your Ride Mode rules...'
                        : 'Your phone is ringing',
                    key: ValueKey(enabled),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: duration,
            curve: curve,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  enabled ? const Color(0xFFE65045) : const Color(0xFF2E936C),
              shape: BoxShape.circle,
            ),
            child: AnimatedRotation(
              turns: enabled ? 0.375 : 0,
              duration: duration,
              curve: curve,
              child:
                  reduceMotion || enabled
                      ? const Icon(
                        Icons.phone_rounded,
                        color: Colors.white,
                        size: 22,
                      )
                      : AnimatedBuilder(
                        animation: ringController,
                        builder: (context, child) {
                          final phase = ringController.value;
                          final ringing = phase < 0.4;
                          final angle =
                              ringing
                                  ? math.sin(phase * math.pi * 10) * 0.12
                                  : 0.0;
                          return Transform.rotate(angle: angle, child: child);
                        },
                        child: const Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.forest : const Color(0xFFECE9E3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled
                ? Icons.do_not_disturb_on_rounded
                : Icons.notifications_active_rounded,
            color: const Color(0xFFFFA454),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Call handled' : 'Normal call behavior',
                  style: AppTypography.labelMedium.copyWith(
                    color: enabled ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'The call is declined unless this caller matches one of your exceptions.'
                      : 'JourneySync steps back. Your phone rings and no riding reply is prepared.',
                  style: AppTypography.bodySmall.copyWith(
                    color:
                        enabled
                            ? Colors.white.withValues(alpha: 0.88)
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Riding reply ready' : 'Riding reply paused',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.forest,
                  ),
                ),
                Text(
                  "I'm riding and can't take your call. I'll get back to you when I stop.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color:
                  enabled
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              enabled ? 'READY' : 'PAUSED',
              style: AppTypography.labelSmall.copyWith(
                color: enabled ? AppColors.primaryDark : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
