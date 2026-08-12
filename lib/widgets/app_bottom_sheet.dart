import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxxl),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.88),
                border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
                boxShadow: AppShadows.lg,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      Flexible(child: builder(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
