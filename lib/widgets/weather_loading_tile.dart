import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WeatherLoadingTile extends StatefulWidget {
  const WeatherLoadingTile({
    super.key,
    this.compact = false,
    this.animated = true,
  });

  final bool compact;
  final bool animated;

  @override
  State<WeatherLoadingTile> createState() => _WeatherLoadingTileState();
}

class _WeatherLoadingTileState extends State<WeatherLoadingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 46.0 : 52.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        widget.compact ? AppRadius.md : AppRadius.lg,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child:
            widget.animated
                ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WeatherLoadingPainter(_controller.value),
                    );
                  },
                )
                : const CustomPaint(painter: _WeatherLoadingPainter(0.18)),
      ),
    );
  }
}

class _WeatherLoadingPainter extends CustomPainter {
  const _WeatherLoadingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEFF6FF);
    canvas.drawRect(Offset.zero & size, bg);

    final sun = Paint()..color = const Color(0xFFFFB020).withValues(alpha: 0.9);
    final sunCenter = Offset(size.width * 0.28, size.height * 0.32);
    canvas.drawCircle(sunCenter, size.width * 0.13, sun);

    final rayPaint =
        Paint()
          ..color = const Color(0xFFFFB020).withValues(alpha: 0.55)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = (math.pi * 2 * i / 8) + progress * math.pi * 2;
      final start =
          sunCenter +
          Offset(math.cos(angle), math.sin(angle)) * size.width * 0.18;
      final end =
          sunCenter +
          Offset(math.cos(angle), math.sin(angle)) * size.width * 0.24;
      canvas.drawLine(start, end, rayPaint);
    }

    final shift = (progress * size.width * 0.32) - size.width * 0.16;
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final shadowPaint =
        Paint()..color = const Color(0xFFBFD7EA).withValues(alpha: 0.55);
    final baseX = size.width * 0.45 + shift;
    final baseY = size.height * 0.57;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          baseX - size.width * 0.20,
          baseY,
          size.width * 0.52,
          size.height * 0.15,
        ),
        Radius.circular(size.height),
      ),
      shadowPaint,
    );
    canvas.drawCircle(Offset(baseX, baseY), size.width * 0.16, cloudPaint);
    canvas.drawCircle(
      Offset(baseX + size.width * 0.16, baseY - size.height * 0.03),
      size.width * 0.19,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(baseX + size.width * 0.32, baseY + size.height * 0.02),
      size.width * 0.13,
      cloudPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          baseX - size.width * 0.08,
          baseY,
          size.width * 0.48,
          size.height * 0.18,
        ),
        Radius.circular(size.height),
      ),
      cloudPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeatherLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
