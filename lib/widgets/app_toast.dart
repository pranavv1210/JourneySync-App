import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppToastType { info, success, error, warning }

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

  // Remove immediately without animation if a new toast is shown
  if (_activeToast != null) {
    _activeToast!.remove();
    _activeToast = null;
  }

  _activeToast = OverlayEntry(
    builder:
        (context) => _PremiumToastOverlay(
          message: normalized,
          type: type,
          duration: duration,
        ),
  );

  overlay.insert(_activeToast!);
  _toastTimer = Timer(duration, dismissAppToast);
}

void dismissAppToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  if (_activeToast != null) {
    _activeToast!.remove();
    _activeToast = null;
  }
}

class _PremiumToastOverlay extends StatefulWidget {
  const _PremiumToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
  });

  final String message;
  final AppToastType type;
  final Duration duration;

  @override
  State<_PremiumToastOverlay> createState() => _PremiumToastOverlayState();
}

class _PremiumToastOverlayState extends State<_PremiumToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    );
    _slideAnimation = Tween<double>(begin: -80.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeInOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeInOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      top: 60,
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder:
              (context, child) => Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(opacity: _fadeAnimation.value, child: child),
              ),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: dismissAppToast,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: config.bgColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: config.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: config.iconBgColor,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              config.icon,
                              color: config.iconColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: config.textColor,
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
            ),
          ),
        ),
      ),
    );
  }

  _ToastConfig _config() {
    switch (widget.type) {
      case AppToastType.success:
        return _ToastConfig(
          bgColor: const Color(0xFFEFFAF3),
          borderColor: const Color(0xFFAFDFBF).withValues(alpha: 0.5),
          textColor: const Color(0xFF165C2B),
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF2FA865),
          iconBgColor: const Color(0xFF2FA865).withValues(alpha: 0.12),
        );
      case AppToastType.error:
        return _ToastConfig(
          bgColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFF5B4B4).withValues(alpha: 0.5),
          textColor: const Color(0xFF8A1C1C),
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.12),
        );
      case AppToastType.warning:
        return _ToastConfig(
          bgColor: const Color(0xFFFFF8E8),
          borderColor: const Color(0xFFF5D896).withValues(alpha: 0.5),
          textColor: const Color(0xFF7C5E00),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF5A524),
          iconBgColor: const Color(0xFFF5A524).withValues(alpha: 0.12),
        );
      case AppToastType.info:
        return _ToastConfig(
          bgColor: const Color(0xFFF4EFEA),
          borderColor: const Color(0xFFE3D7CC).withValues(alpha: 0.5),
          textColor: const Color(0xFF3A2E26),
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFFD46211),
          iconBgColor: const Color(0xFFD46211).withValues(alpha: 0.12),
        );
    }
  }
}

class _ToastConfig {
  const _ToastConfig({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
}
