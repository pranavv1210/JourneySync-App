import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/journey_screen.dart';

class SetupErrorScreen extends StatelessWidget {
  const SetupErrorScreen({super.key, required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return JourneyScreen(
      scrollable: false,
      child: JourneyHeroBand(
        icon: Icons.build_circle_outlined,
        color: AppColors.error,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const JourneyHeader(
              eyebrow: 'CONFIGURATION',
              title: 'App setup required',
              subtitle:
                  'Required app configuration is missing or invalid. Update the build-time configuration and rebuild.',
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.divider),
              ),
              child: SingleChildScrollView(
                child: Text(
                  errorMessage,
                  style: AppTypography.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Optional override:\nflutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Close',
              icon: Icons.close_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ),
      ),
    );
  }
}
