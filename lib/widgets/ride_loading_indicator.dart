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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? AppColors.primary;
    final dotSize = widget.compact ? 7.0 : 10.0;
    final spacing = widget.compact ? 5.0 : 7.0;
    final label = widget.label;

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: (dotSize * 3) + (spacing * 2) + 16,
            height: widget.compact ? 18 : 26,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final phase = (_pulse.value + (index * 0.28)) % 1.0;
                    final scale = 0.72 + (0.48 * (1 - (phase - 0.5).abs() * 2));
                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : spacing),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary.withValues(
                              alpha: 0.46 + (0.48 * scale.clamp(0.0, 1.0)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.18),
                                blurRadius: widget.compact ? 6 : 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
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
