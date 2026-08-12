import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ride_loading_indicator.dart';

/// Premium button with haptic feedback, scale animation, gradient accents,
/// and comprehensive states (loading, disabled, pressed).
///
/// - Haptic feedback on press (light impact)
/// - Scale animation (0.97 on press)
/// - Gradient background
/// - Loading state with shimmer
/// - Disabled state with reduced opacity
/// - 300ms easeInOutCubic transitions
class HapticButton extends StatefulWidget {
  const HapticButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.size = HapticButtonSize.medium,
    this.variant = HapticButtonVariant.primary,
    this.loading = false,
    this.disabled = false,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final HapticButtonSize size;
  final HapticButtonVariant variant;
  final bool loading;
  final bool disabled;
  final bool haptic;

  @override
  State<HapticButton> createState() => _HapticButtonState();
}

class _HapticButtonState extends State<HapticButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_canTap) _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (_canTap) {
      if (widget.haptic) HapticFeedback.lightImpact();
      widget.onPressed?.call();
    }
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  bool get _canTap =>
      widget.onPressed != null && !widget.loading && !widget.disabled;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(widget.variant);
    final height =
        widget.size == HapticButtonSize.small
            ? 40.0
            : widget.size == HapticButtonSize.medium
            ? 52.0
            : 60.0;
    final hPadding = widget.size == HapticButtonSize.small ? 16.0 : 24.0;
    final fontSize = widget.size == HapticButtonSize.small ? 13.0 : 15.0;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.disabled ? 0.5 : 1.0,
              child: Container(
                width: widget.expand ? double.infinity : null,
                height: height,
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                decoration: BoxDecoration(
                  gradient: spec.gradient,
                  borderRadius: BorderRadius.circular(14),
                  border: spec.border,
                  boxShadow: spec.shadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: RideLoadingIndicator(
                          compact: true,
                          color: spec.textColor,
                        ),
                      )
                    else ...[
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: spec.textColor, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: spec.textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: fontSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _HapticButtonSpec _specFor(HapticButtonVariant variant) {
    return switch (variant) {
      HapticButtonVariant.primary => _HapticButtonSpec(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        textColor: AppColors.textOnDark,
        shadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      HapticButtonVariant.glass => _HapticButtonSpec(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.7),
          ],
        ),
        textColor: AppColors.forest,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      HapticButtonVariant.danger => _HapticButtonSpec(
        gradient: const LinearGradient(
          colors: [AppColors.emergency, AppColors.error],
        ),
        textColor: AppColors.textOnDark,
        shadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      HapticButtonVariant.outline => _HapticButtonSpec(
        gradient: const LinearGradient(
          colors: [Colors.transparent, Colors.transparent],
        ),
        textColor: AppColors.forest,
        border: Border.all(
          color: AppColors.forest.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
    };
  }
}

// ── Supporting Types ──────────────────────────────────────────────────────────

enum HapticButtonSize { small, medium, large }

enum HapticButtonVariant { primary, glass, danger, outline }

class _HapticButtonSpec {
  const _HapticButtonSpec({
    required this.gradient,
    required this.textColor,
    this.border,
    this.shadow = const [],
  });
  final LinearGradient gradient;
  final Color textColor;
  final BoxBorder? border;
  final List<BoxShadow> shadow;
}
