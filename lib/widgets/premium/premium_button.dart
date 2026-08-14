import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../ride_loading_indicator.dart';

/// Premium button with scale animation, glass effect, and gradient support.
/// Never uses default ElevatedButton — always custom.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.customIcon,
    this.trailing,
    this.variant = PremiumButtonVariant.primary,
    this.size = PremiumButtonSize.large,
    this.expand = true,
    this.loading = false,
    this.disabled = false,
    this.gradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? customIcon;
  final Widget? trailing;
  final PremiumButtonVariant variant;
  final PremiumButtonSize size;
  final bool expand;
  final bool loading;
  final bool disabled;
  final Gradient? gradient;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AppCurves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.disabled) return;
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _scaleController.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = widget.disabled || widget.loading;
    final isActive = widget.onPressed != null && !effectiveDisabled;

    final sizeConfig = _sizeConfig();
    final colors = _colors();

    Widget button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder:
          (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
      child: GestureDetector(
        onTap: isActive ? widget.onPressed : null,
        onTapDown: isActive ? _onTapDown : null,
        onTapUp: isActive ? _onTapUp : null,
        onTapCancel: isActive ? _onTapCancel : null,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          constraints:
              widget.expand
                  ? BoxConstraints(
                    minWidth: double.infinity,
                    minHeight: sizeConfig.height,
                  )
                  : BoxConstraints(minHeight: sizeConfig.height),
          padding: EdgeInsets.symmetric(
            horizontal: sizeConfig.hPadding,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            gradient: widget.gradient ?? colors.gradient,
            borderRadius: BorderRadius.circular(sizeConfig.radius),
            boxShadow:
                isActive && !_isPressed
                    ? [
                      BoxShadow(
                        color: colors.shadowColor,
                        blurRadius: sizeConfig.shadowBlur,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                _LoadingIndicator(color: colors.textColor)
              else ...[
                if (widget.customIcon != null) ...[
                  widget.customIcon!,
                  SizedBox(width: sizeConfig.iconGap),
                ] else if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: colors.textColor,
                    size: sizeConfig.iconSize,
                  ),
                  SizedBox(width: sizeConfig.iconGap),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: sizeConfig.fontSize,
                      fontWeight: FontWeight.w700,
                      color:
                          effectiveDisabled
                              ? colors.textColor.withValues(alpha: 0.72)
                              : colors.textColor,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.variant == PremiumButtonVariant.glass) {
      button = ClipRRect(
        borderRadius: BorderRadius.circular(sizeConfig.radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: button,
        ),
      );
    }

    return button;
  }

  _SizeConfig _sizeConfig() {
    switch (widget.size) {
      case PremiumButtonSize.small:
        return _SizeConfig(
          height: 40,
          hPadding: 16,
          radius: AppRadius.lg,
          fontSize: 13,
          iconSize: 16,
          iconGap: 6,
          shadowBlur: 12,
        );
      case PremiumButtonSize.medium:
        return _SizeConfig(
          height: 48,
          hPadding: 20,
          radius: AppRadius.xl,
          fontSize: 14,
          iconSize: 18,
          iconGap: 8,
          shadowBlur: 16,
        );
      case PremiumButtonSize.large:
        return _SizeConfig(
          height: 56,
          hPadding: 24,
          radius: AppRadius.xxl,
          fontSize: 16,
          iconSize: 20,
          iconGap: 8,
          shadowBlur: 20,
        );
    }
  }

  _ButtonColors _colors() {
    final disabled = widget.disabled || widget.loading;
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return _ButtonColors(
          gradient:
              disabled
                  ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.58),
                      AppColors.primaryDark.withValues(alpha: 0.58),
                    ],
                  )
                  : const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
          textColor: AppColors.textOnDark,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        );
      case PremiumButtonVariant.secondary:
        return _ButtonColors(
          gradient:
              disabled
                  ? LinearGradient(
                    colors: [
                      AppColors.forest.withValues(alpha: 0.15),
                      AppColors.forest.withValues(alpha: 0.15),
                    ],
                  )
                  : LinearGradient(
                    colors: [
                      AppColors.forest.withValues(alpha: 0.1),
                      AppColors.forest.withValues(alpha: 0.15),
                    ],
                  ),
          textColor:
              disabled
                  ? AppColors.forest.withValues(alpha: 0.4)
                  : AppColors.forest,
          shadowColor: AppColors.forest.withValues(alpha: 0.15),
        );
      case PremiumButtonVariant.outline:
        return _ButtonColors(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: disabled ? 0.5 : 1),
              Colors.white.withValues(alpha: disabled ? 0.5 : 1),
            ],
          ),
          textColor: disabled ? AppColors.textTertiary : AppColors.textPrimary,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        );
      case PremiumButtonVariant.glass:
        return _ButtonColors(
          gradient: LinearGradient(
            colors: [AppColors.glassBg, AppColors.glassBg],
          ),
          textColor:
              disabled
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.textPrimary,
          shadowColor: Colors.black.withValues(alpha: 0.06),
        );
      case PremiumButtonVariant.danger:
        return _ButtonColors(
          gradient:
              disabled
                  ? LinearGradient(
                    colors: [
                      AppColors.error.withValues(alpha: 0.4),
                      AppColors.emergency.withValues(alpha: 0.4),
                    ],
                  )
                  : const LinearGradient(
                    colors: [AppColors.emergency, AppColors.error],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
          textColor: AppColors.textOnDark,
          shadowColor: AppColors.error.withValues(alpha: 0.24),
        );
    }
  }
}

enum PremiumButtonVariant { primary, secondary, outline, glass, danger }

enum PremiumButtonSize { small, medium, large }

class _SizeConfig {
  const _SizeConfig({
    required this.height,
    required this.hPadding,
    required this.radius,
    required this.fontSize,
    required this.iconSize,
    required this.iconGap,
    required this.shadowBlur,
  });
  final double height;
  final double hPadding;
  final double radius;
  final double fontSize;
  final double iconSize;
  final double iconGap;
  final double shadowBlur;
}

class _ButtonColors {
  const _ButtonColors({
    required this.gradient,
    required this.textColor,
    required this.shadowColor,
  });
  final Gradient gradient;
  final Color textColor;
  final Color shadowColor;
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RideLoadingIndicator(compact: true, color: color);
  }
}
