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
  late final Animation<double> _pulse;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _sweep = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? AppColors.primary;
    final size = widget.compact ? 28.0 : 46.0;
    final label = widget.label;

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final glow = 0.65 + (0.35 * _pulse.value);
                return Transform.rotate(
                  angle: _sweep.value * 6.28318,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          primary.withValues(alpha: 0.04),
                          primary.withValues(alpha: glow),
                          AppColors.forest.withValues(alpha: 0.86),
                          primary.withValues(alpha: 0.04),
                        ],
                        stops: const [0, 0.36, 0.68, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.18),
                          blurRadius: widget.compact ? 10 : 18,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(widget.compact ? 3 : 5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: widget.compact ? 7 : 10,
                            height: widget.compact ? 7 : 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
