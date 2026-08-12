import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Premium glassmorphism card with blur effect, soft shadows, and rounded corners.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 20,
    this.opacity = 0.7,
    this.customColor,
    this.onTap,
    this.elevated = false,
    this.customBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final double blur;
  final double opacity;
  final Color? customColor;
  final VoidCallback? onTap;
  final bool elevated;
  final BoxBorder? customBorder;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.xxl;
    final bgColor = customColor ?? AppColors.surface;

    Widget card = Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? AppShadows.glass : AppShadows.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(radius),
              border:
                  customBorder ??
                  Border.all(color: Colors.white.withValues(alpha: 0.66)),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: AppColors.textPrimary),
                child: IconTheme.merge(
                  data: const IconThemeData(color: AppColors.textPrimary),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

/// Premium elevated card with shadow and subtle border.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.xxl;

    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.divider),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
