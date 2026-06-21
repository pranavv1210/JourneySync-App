import 'package:flutter/material.dart';

import 'premium/premium_button.dart';

enum AppButtonVariant { primary, secondary, outline, glass }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.expand = true,
    this.loading = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? trailing;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return PremiumButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      trailing: trailing,
      variant: switch (variant) {
        AppButtonVariant.primary => PremiumButtonVariant.primary,
        AppButtonVariant.secondary => PremiumButtonVariant.secondary,
        AppButtonVariant.outline => PremiumButtonVariant.outline,
        AppButtonVariant.glass => PremiumButtonVariant.glass,
      },
      size: switch (size) {
        AppButtonSize.small => PremiumButtonSize.small,
        AppButtonSize.medium => PremiumButtonSize.medium,
        AppButtonSize.large => PremiumButtonSize.large,
      },
      expand: expand,
      loading: loading,
      disabled: disabled,
    );
  }
}
