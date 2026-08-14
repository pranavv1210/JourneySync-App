import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 24),
    this.safeArea = true,
    this.scrollable = true,
    this.backgroundColor = AppColors.background,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool safeArea;
  final bool scrollable;
  final Color backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor,
                  AppColors.surfaceAlt.withValues(alpha: 0.42),
                  backgroundColor,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -96,
          top: -72,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.035),
            ),
          ),
        ),
        Positioned(
          left: -120,
          bottom: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forest.withValues(alpha: 0.035),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: child,
            ),
          ),
        ),
      ],
    );
    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }
    if (safeArea) {
      content = SafeArea(child: content);
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

class JourneyHeader extends StatelessWidget {
  const JourneyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.centerTitle = false,
    this.surface = false,
    this.showEyebrow = false,
    this.showSubtitle = false,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;
  final bool centerTitle;
  final bool surface;
  final bool showEyebrow;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final text = LayoutBuilder(
      builder: (context, constraints) {
        final compactTitle = constraints.maxWidth < 330;
        final titleStyle =
            compactTitle
                ? AppTypography.headlineMedium.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                )
                : AppTypography.headlineLarge.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                );

        return Column(
          crossAxisAlignment:
              centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
          children: [
            if (showEyebrow && eyebrow != null) ...[
              Text(
                eyebrow!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              style: titleStyle,
            ),
            if (showSubtitle && subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );

    final content =
        leading == null && trailing == null
            ? text
            : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(child: text),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  trailing!,
                ],
              ],
            );

    if (!surface) return content;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: content,
    );
  }
}

class JourneyBackButton extends StatelessWidget {
  const JourneyBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onPressed ?? () => Navigator.maybePop(context),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.forest,
          ),
        ),
      ),
    );
  }
}

class JourneyHeroBand extends StatelessWidget {
  const JourneyHeroBand({
    super.key,
    required this.child,
    this.icon,
    this.color = AppColors.primary,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final IconData? icon;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: AppShadows.glass,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              icon ?? Icons.route_rounded,
              size: 112,
              color: color.withValues(alpha: 0.06),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
