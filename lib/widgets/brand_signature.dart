import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandSignature extends StatelessWidget {
  const BrandSignature({super.key});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final headlineSize = (52 / textScale).clamp(38.0, 52.0);

    return Semantics(
      container: true,
      label: 'Ride farther. Together. Crafted with care in Bengaluru, India.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 44, 4, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride farther.\nTogether.',
              style: AppTypography.style(
                fontSize: headlineSize,
                fontWeight: FontWeight.w800,
                height: 0.92,
                letterSpacing: -1.8,
              ).copyWith(color: AppColors.forest.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 24),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  'Crafted with',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 20,
                  semanticLabel: 'care',
                ),
                Text(
                  'in Bengaluru, India',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
