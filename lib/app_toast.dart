import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastType { info, success, error }

OverlayEntry? _activeToast;
Timer? _toastTimer;

void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final normalized = message.trim();
  if (normalized.isEmpty) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  _toastTimer?.cancel();
  _activeToast?.remove();

  _activeToast = OverlayEntry(
    builder: (context) {
      final colors = _toastColors(type);
      return Positioned(
        left: 16,
        right: 16,
        bottom: 92,
        child: IgnorePointer(
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(colors.icon, size: 18, color: colors.foreground),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        normalized,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(_activeToast!);
  _toastTimer = Timer(duration, dismissAppToast);
}

void dismissAppToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _activeToast?.remove();
  _activeToast = null;
}

class _ToastColors {
  const _ToastColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}

_ToastColors _toastColors(AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return const _ToastColors(
        background: Color(0xFFEFFAF3),
        border: Color(0xFFAFDFBF),
        foreground: Color(0xFF165C2B),
        icon: Icons.check_circle_outline_rounded,
      );
    case AppToastType.error:
      return const _ToastColors(
        background: Color(0xFFFEF2F2),
        border: Color(0xFFF5B4B4),
        foreground: Color(0xFF8A1C1C),
        icon: Icons.error_outline_rounded,
      );
    case AppToastType.info:
      return const _ToastColors(
        background: Color(0xFFF4EFEA),
        border: Color(0xFFE3D7CC),
        foreground: Color(0xFF3A2E26),
        icon: Icons.info_outline_rounded,
      );
  }
}
