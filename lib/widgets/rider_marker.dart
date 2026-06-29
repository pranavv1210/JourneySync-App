import 'package:flutter/material.dart';

import '../models/rider_location.dart';
import '../services/ride_engine_core.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CURRENT USER MARKER  — Pulsing blue dot with heading indicator
// ──────────────────────────────────────────────────────────────────────────────

/// Pulsing blue location dot with a directional heading arrow.
/// Used for the current user's own position on the map.
class CurrentUserMarker extends StatefulWidget {
  const CurrentUserMarker({
    super.key,
    required this.heading,
    this.isOffline = false,
    this.status,
  });

  /// GPS heading in degrees (0 = north). Null = no heading data.
  final double? heading;

  /// True when the sync connection is lost.
  final bool isOffline;
  final RiderLiveStatus? status;

  @override
  State<CurrentUserMarker> createState() => _CurrentUserMarkerState();
}

class _CurrentUserMarkerState extends State<CurrentUserMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _statusColor(
      widget.status ??
          (widget.isOffline ? RiderLiveStatus.offline : RiderLiveStatus.moving),
      fallback: const Color(0xFF2196F3),
    );
    final glowColor = dotColor.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring
            Container(
              width: 52 * _pulseAnim.value,
              height: 52 * _pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor,
              ),
            ),
            // Accuracy ring
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
            // Core dot
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // Heading arrow (if available)
            if (widget.heading != null)
              _SmoothHeadingRotation(
                heading: widget.heading!,
                child: CustomPaint(
                  size: const Size(52, 52),
                  painter: _HeadingArrowPainter(color: dotColor),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// LEADER MARKER  — Orange glow + crown icon + heading arrow
// ──────────────────────────────────────────────────────────────────────────────

/// Premium leader marker: orange glow + crown + premium badge + heading arrow + rider name.
class LeaderMarker extends StatefulWidget {
  const LeaderMarker({
    super.key,
    required this.location,
    this.isCurrentUser = false,
    this.status = RiderLiveStatus.leader,
    this.detailLabel,
  });

  final RiderLocation location;
  final bool isCurrentUser;
  final RiderLiveStatus status;
  final String? detailLabel;

  @override
  State<LeaderMarker> createState() => _LeaderMarkerState();
}

class _LeaderMarkerState extends State<LeaderMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderColor = _statusColor(
      widget.status,
      fallback: const Color(0xFFFF6A00),
    );
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Direction indicator (if heading is available)
                if (widget.location.heading != null)
                  _SmoothHeadingRotation(
                    heading: widget.location.heading!,
                    child: CustomPaint(
                      size: const Size(68, 68),
                      painter: _HeadingArrowPainter(color: leaderColor),
                    ),
                  ),
                // Glow ring
                Container(
                  width: 58 + (8 * _glowAnim.value),
                  height: 58 + (8 * _glowAnim.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: leaderColor.withValues(alpha: 0.2 * _glowAnim.value),
                  ),
                ),
                // Avatar circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF3E0),
                    border: Border.all(color: leaderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: leaderColor.withValues(
                          alpha: 0.4 * _glowAnim.value,
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _RiderAvatar(
                    name: widget.location.userName,
                    avatarUrl: widget.location.avatarUrl,
                  ),
                ),
                // Crown icon / Premium badge top
                Positioned(
                  top: -14,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: leaderColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text(
                              'LEADER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // "You" indicator for current user
                if (widget.isCurrentUser)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _NameLabel(
              name:
                  widget.detailLabel ??
                  (widget.isCurrentUser
                      ? 'You (Leader)'
                      : widget.location.userName),
              backgroundColor: leaderColor,
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// RIDER MARKER  — Standard rider with name label + heading indicator
// ──────────────────────────────────────────────────────────────────────────────

/// Standard rider marker with avatar, name, heading direction, and stale indicator.
class RiderMarker extends StatelessWidget {
  const RiderMarker({
    super.key,
    required this.location,
    this.isCurrentUser = false,
    this.status = RiderLiveStatus.moving,
    this.detailLabel,
  });

  final RiderLocation location;
  final bool isCurrentUser;
  final RiderLiveStatus status;
  final String? detailLabel;

  @override
  Widget build(BuildContext context) {
    final borderColor = _statusColor(
      status,
      fallback:
          isCurrentUser ? const Color(0xFFFF6A00) : const Color(0xFF2196F3),
    );
    final opacity =
        status == RiderLiveStatus.offline || location.isStale ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Direction indicator (if heading is available)
              if (location.heading != null)
                _SmoothHeadingRotation(
                  heading: location.heading!,
                  child: CustomPaint(
                    size: const Size(60, 60),
                    painter: _HeadingArrowPainter(color: borderColor),
                  ),
                ),
              // Avatar base
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFE8D4),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: _RiderAvatar(
                  name: location.userName,
                  avatarUrl: location.avatarUrl,
                ),
              ),
              // Stale indicator dot
              if (status == RiderLiveStatus.offline ||
                  status == RiderLiveStatus.background ||
                  location.isStale)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          status == RiderLiveStatus.background
                              ? Colors.amber.shade600
                              : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _NameLabel(
            name: detailLabel ?? (isCurrentUser ? 'You' : location.userName),
            backgroundColor: Colors.white,
            textColor: Colors.black87,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DESTINATION MARKER
// ──────────────────────────────────────────────────────────────────────────────

/// Premium destination pin marker.
class DestinationMarker extends StatelessWidget {
  const DestinationMarker({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6A00), Color(0xFFFF8C42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6A00).withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
        ),
        if (label != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A00),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        // Pin tail
        CustomPaint(size: const Size(12, 8), painter: _PinTailPainter()),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ──────────────────────────────────────────────────────────────────────────────

Color _statusColor(RiderLiveStatus status, {required Color fallback}) {
  return switch (status) {
    RiderLiveStatus.sos => Colors.red,
    RiderLiveStatus.offline => Colors.grey.shade500,
    RiderLiveStatus.background => Colors.amber.shade700,
    RiderLiveStatus.waiting => Colors.purple.shade400,
    RiderLiveStatus.stopped => Colors.blueGrey.shade500,
    RiderLiveStatus.leader => const Color(0xFFFF6A00),
    RiderLiveStatus.moving => fallback,
  };
}

class _SmoothHeadingRotation extends StatefulWidget {
  const _SmoothHeadingRotation({required this.heading, required this.child});

  final double heading;
  final Widget child;

  @override
  State<_SmoothHeadingRotation> createState() => _SmoothHeadingRotationState();
}

class _SmoothHeadingRotationState extends State<_SmoothHeadingRotation> {
  late double _turns;

  @override
  void initState() {
    super.initState();
    _turns = widget.heading / 360;
  }

  @override
  void didUpdateWidget(_SmoothHeadingRotation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentDegrees = _turns * 360;
    final delta = RideEngineCore.headingDelta(currentDegrees, widget.heading);
    _turns = (currentDegrees + delta) / 360;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: _turns,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
  }
}

class _RiderAvatar extends StatelessWidget {
  const _RiderAvatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: const Color(0xFFFFE8D4),
      backgroundImage:
          (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? NetworkImage(avatarUrl!)
              : null,
      child:
          (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFFFF6A00),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              )
              : null,
    );
  }
}

class _NameLabel extends StatelessWidget {
  const _NameLabel({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
  });

  final String name;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
        ],
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HeadingArrowPainter extends CustomPainter {
  const _HeadingArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Triangle pointing upward (0° = north) that wraps around the outer bounds
    final path =
        Path()
          ..moveTo(cx, cy - size.height * 0.5)
          ..lineTo(cx + size.width * 0.12, cy - size.height * 0.36)
          ..lineTo(cx - size.width * 0.12, cy - size.height * 0.36)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeadingArrowPainter old) => old.color != color;
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFFFF6A00)
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(size.width / 2, size.height)
          ..lineTo(0, 0)
          ..lineTo(size.width, 0)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter _) => false;
}
