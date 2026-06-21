import 'package:flutter/material.dart';

import 'app_empty_state.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: 'Something needs attention',
      message: message,
      icon: Icons.error_outline_rounded,
      actionLabel: onRetry == null ? null : 'Try Again',
      onAction: onRetry,
    );
  }
}
