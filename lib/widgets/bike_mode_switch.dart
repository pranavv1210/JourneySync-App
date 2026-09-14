import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class BikeModeSwitch extends StatefulWidget {
  const BikeModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  State<BikeModeSwitch> createState() => _BikeModeSwitchState();
}

class _BikeModeSwitchState extends State<BikeModeSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: widget.value ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BikeModeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.animateTo(
      widget.value ? 1 : 0,
      duration: Duration(milliseconds: reduceMotion ? 80 : 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.busy) return;
    HapticFeedback.selectionClick();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.value,
      label: 'Bike Mode',
      hint:
          widget.value
              ? 'Double tap to turn off call handling'
              : 'Double tap to tell callers you are riding',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: SizedBox(
          width: 78,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(72, 36),
                  painter: _BikeSwitchPainter(
                    progress: _controller.value,
                    busy: widget.busy,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BikeSwitchPainter extends CustomPainter {
  const _BikeSwitchPainter({required this.progress, required this.busy});

  final double progress;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final background =
        Color.lerp(
          AppColors.textTertiary.withValues(alpha: 0.16),
          AppColors.primary.withValues(alpha: 0.18),
          progress,
        )!;
    canvas.drawRRect(track, Paint()..color = background);
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color =
            Color.lerp(
              AppColors.divider,
              AppColors.primary.withValues(alpha: 0.42),
              progress,
            )!,
    );

    final eased = Curves.easeOutCubic.transform(progress);
    final center = Offset(20 + (size.width - 40) * eased, size.height / 2);
    if (progress > 0.08) {
      final linePaint =
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.42 * progress)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
      final lineEnd = center.dx - 13;
      canvas.drawLine(
        Offset(math.max(8, lineEnd - 8), center.dy - 4),
        Offset(lineEnd, center.dy - 4),
        linePaint,
      );
      canvas.drawLine(
        Offset(math.max(10, lineEnd - 6), center.dy + 3),
        Offset(lineEnd, center.dy + 3),
        linePaint,
      );
    }

    canvas.save();
    canvas.translate(
      center.dx,
      center.dy + (math.sin(progress * math.pi) * -1.2),
    );
    _paintBike(canvas, progress);
    canvas.restore();

    if (progress < 0.72) {
      final stopOpacity = 1 - (progress / 0.72);
      canvas.drawLine(
        Offset(size.width - 12, 11),
        Offset(size.width - 12, 25),
        Paint()
          ..color = AppColors.textTertiary.withValues(alpha: stopOpacity * 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    if (busy) {
      canvas.drawRRect(
        track,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
  }

  void _paintBike(Canvas canvas, double active) {
    final color =
        Color.lerp(AppColors.textTertiary, AppColors.primary, active)!;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(-7, 5), 4, paint);
    canvas.drawCircle(const Offset(7, 5), 4, paint);
    final frame =
        Path()
          ..moveTo(-7, 5)
          ..lineTo(-2, -2)
          ..lineTo(3, 5)
          ..lineTo(-7, 5)
          ..moveTo(-2, -2)
          ..lineTo(5, -2)
          ..lineTo(7, 5)
          ..moveTo(3, 5)
          ..lineTo(7, -4)
          ..lineTo(10, -4)
          ..moveTo(-4, -3)
          ..lineTo(0, -3);
    canvas.drawPath(frame, paint);
  }

  @override
  bool shouldRepaint(covariant _BikeSwitchPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.busy != busy;
  }
}
