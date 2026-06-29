import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../services/ride_engine_core.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SMOOTH MARKER — Animated lat/lng interpolation
// ──────────────────────────────────────────────────────────────────────────────

/// A wrapper that smoothly interpolates between old and new GPS coordinates.
///
/// Usage: wrap any marker child in [SmoothMarker]. When [position] changes,
/// the widget animates to the new position over 600 ms.
///
/// The [onPositionChanged] callback fires on every animation frame so that
/// the parent can update the [Marker.point] in the flutter_map layer.
class SmoothMarker extends StatefulWidget {
  const SmoothMarker({
    super.key,
    required this.position,
    required this.builder,
    this.heading,
    this.speed,
    this.updatedAt,
  });

  /// Current target GPS position (updated when rider moves).
  final LatLng position;
  final double? heading;
  final double? speed;
  final DateTime? updatedAt;

  /// Builder receives the interpolated [LatLng] for every animation frame.
  /// Use this to set [Marker.point] on the flutter_map Marker.
  final Widget Function(BuildContext context, LatLng interpolated) builder;

  @override
  State<SmoothMarker> createState() => _SmoothMarkerState();
}

class _SmoothMarkerState extends State<SmoothMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _latAnim;
  late Animation<double> _lngAnim;

  LatLng _fromPos = const LatLng(0, 0);
  LatLng _toPos = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _fromPos = widget.position;
    _toPos = widget.position;

    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration(widget.speed),
    );

    _setupAnimations(_fromPos, _toPos);
  }

  void _setupAnimations(LatLng from, LatLng to) {
    _latAnim = Tween<double>(
      begin: from.latitude,
      end: to.latitude,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _lngAnim = Tween<double>(
      begin: from.longitude,
      end: to.longitude,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(SmoothMarker old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position) {
      // Capture the current animated position as the new starting point.
      final current = _currentDisplayPosition();
      final drift = const Distance().as(
        LengthUnit.Meter,
        current,
        widget.position,
      );
      _fromPos =
          drift > RideEngineCore.driftTeleportThresholdMeters
              ? widget.position
              : current;
      _toPos = widget.position;
      _controller.duration = _animationDuration(widget.speed);
      _setupAnimations(_fromPos, _toPos);
      _controller.forward(from: 0);
    }
  }

  static Duration _animationDuration(double? speed) {
    final speedMps = speed ?? 0;
    if (speedMps > 8) return const Duration(milliseconds: 900);
    if (speedMps > 2) return const Duration(milliseconds: 1100);
    return const Duration(milliseconds: 700);
  }

  LatLng _currentDisplayPosition() {
    final base = LatLng(_latAnim.value, _lngAnim.value);
    final speed = widget.speed ?? 0;
    final heading = widget.heading;
    final updatedAt = widget.updatedAt;
    if (!_controller.isCompleted ||
        speed <= 0.2 ||
        heading == null ||
        updatedAt == null) {
      return base;
    }
    final elapsedSeconds =
        DateTime.now().difference(updatedAt).inMilliseconds / 1000.0;
    final predictionSeconds = elapsedSeconds.clamp(0.0, 5.0);
    return RideEngineCore.offset(base, speed * predictionSeconds, heading);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final interpolated = _currentDisplayPosition();
        return widget.builder(context, interpolated);
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// INTERPOLATED POSITION NOTIFIER
// ──────────────────────────────────────────────────────────────────────────────

/// Tracks the smoothly-interpolated position for a single rider.
/// Used by the map layer to get the per-frame animated LatLng.
class InterpolatedPosition extends ValueNotifier<LatLng> {
  InterpolatedPosition(super.value);
}

// ──────────────────────────────────────────────────────────────────────────────
// PRESS ANIMATION WRAPPER
// ──────────────────────────────────────────────────────────────────────────────

/// Adds a subtle scale-down press animation to any tappable widget.
class AnimatedPress extends StatefulWidget {
  const AnimatedPress({
    super.key,
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final VoidCallback onPressed;

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onPressed();
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(scale: _c, child: widget.child),
    );
  }
}
