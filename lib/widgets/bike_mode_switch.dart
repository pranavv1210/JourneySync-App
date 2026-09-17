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
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.value ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BikeModeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _direction = widget.value ? 1 : -1;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.animateTo(
      widget.value ? 1 : 0,
      duration: Duration(milliseconds: reduceMotion ? 80 : 280),
      curve: const Cubic(0.23, 1, 0.32, 1),
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
      container: true,
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
          width: 60,
          height: 48,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(54, 32),
                  painter: _BikeSwitchPainter(
                    progress: _controller.value,
                    direction: _direction,
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
  const _BikeSwitchPainter({
    required this.progress,
    required this.direction,
    required this.busy,
  });

  final double progress;
  final int direction;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final background =
        Color.lerp(const Color(0xFFAAA9A5), AppColors.primary, progress)!;
    canvas.drawRRect(track, Paint()..color = background);

    final thumbRadius = 12.5;
    final center = Offset(
      thumbRadius + 3 + (size.width - (thumbRadius + 3) * 2) * progress,
      size.height / 2,
    );
    final activity = (progress * (1 - progress) * 4).clamp(0.0, 1.0);

    if (activity > 0.02) {
      final linePaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * activity)
            ..strokeWidth = 1.25
            ..strokeCap = StrokeCap.round;
      final trailStart = direction > 0 ? center.dx - 18 : center.dx + 10;
      final trailEnd = direction > 0 ? center.dx - 12 : center.dx + 16;
      canvas.drawLine(
        Offset(trailStart, center.dy - 4),
        Offset(trailEnd, center.dy - 4),
        linePaint,
      );
      canvas.drawLine(
        Offset(trailStart + (direction > 0 ? 2 : -2), center.dy + 3),
        Offset(trailEnd, center.dy + 3),
        linePaint,
      );
    }

    canvas.drawCircle(
      center.translate(0, 1.5),
      thumbRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(center, thumbRadius, Paint()..color = Colors.white);

    if (activity > 0.02) {
      _paintMotorcycle(canvas, center, activity, progress);
    }

    if (busy) {
      canvas.drawRRect(
        track,
        Paint()..color = Colors.white.withValues(alpha: 0.32),
      );
    }
  }

  void _paintMotorcycle(
    Canvas canvas,
    Offset center,
    double opacity,
    double active,
  ) {
    final dark = Color.lerp(
      AppColors.textSecondary,
      AppColors.primaryDark,
      active,
    )!.withValues(alpha: opacity);
    final accent = AppColors.primary.withValues(alpha: opacity);
    final line =
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(center.dx, center.dy - 0.5);
    canvas.drawCircle(const Offset(-6, 4), 2.8, line);
    canvas.drawCircle(const Offset(6, 4), 2.8, line);
    canvas.drawOval(
      const Rect.fromLTWH(-3.5, -1.5, 7, 4.5),
      Paint()..color = accent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-6, 4)
        ..lineTo(-2.5, 0)
        ..lineTo(2.5, 2)
        ..lineTo(6, 4)
        ..moveTo(2.5, 2)
        ..lineTo(4.7, -3.2)
        ..lineTo(7.5, -3.2)
        ..moveTo(-4, -2.2)
        ..lineTo(0, -2.2),
      line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BikeSwitchPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.busy != busy;
  }
}
