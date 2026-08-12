import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<void> showLegalDocumentDialog({
  required BuildContext context,
  required String title,
  required String content,
  TextStyle? contentStyle,
  TextStyle? titleStyle,
  Color? actionColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        title: Text(title, style: titleStyle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              content,
              style:
                  contentStyle ??
                  AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: actionColor ?? Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
}
