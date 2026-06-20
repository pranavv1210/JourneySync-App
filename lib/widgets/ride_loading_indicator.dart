import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RideLoadingIndicator extends StatefulWidget {
  const RideLoadingIndicator({
    super.key,
    this.label,
    this.compact = false,
    this.color,
  });

  final String? label;
  final bool compact;
  final Color? color;

  @override
  State<RideLoadingIndicator> createState() => _RideLoadingIndicatorState();
}

class _RideLoadingIndicatorState extends State<RideLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;
  late final Animation<double> _tilt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);
    _position = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.easeInOutCubic,
    );
    _tilt = Tween<double>(begin: -0.05, end: 0.05).animate(_position);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? AppColors.primary;
    final width = widget.compact ? 56.0 : 132.0;
    final trackHeight = widget.compact ? 3.0 : 4.0;
    final bikeSize = widget.compact ? 18.0 : 28.0;
    final label = widget.label;

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: widget.compact ? 24 : 38,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final left = (width - bikeSize) * _position.value;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: widget.compact ? 5 : 7,
                      child: Container(
                        height: trackHeight,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      bottom: widget.compact ? 8 : 12,
                      child: Transform.rotate(
                        angle: _tilt.value,
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          size: bikeSize,
                          color: primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: widget.compact ? 5 : 7,
                      child: Container(
                        width: left + (bikeSize / 2),
                        height: trackHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, AppColors.forest],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (label != null && label.trim().isNotEmpty) ...[
            SizedBox(height: widget.compact ? 6 : 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: (widget.compact
                      ? AppTypography.caption
                      : AppTypography.bodyMedium)
                  .copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
