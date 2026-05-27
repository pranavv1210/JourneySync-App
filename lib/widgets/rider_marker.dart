import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/rider_location.dart';

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
  });

  /// GPS heading in degrees (0 = north). Null = no heading data.
  final double? heading;

  /// True when the sync connection is lost.
  final bool isOffline;

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
    final dotColor =
        widget.isOffline ? const Color(0xFFFF6A00) : const Color(0xFF2196F3);
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
              Transform.rotate(
                angle: widget.heading! * math.pi / 180,
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
// LEADER MARKER  — Orange glow + crown icon
// ──────────────────────────────────────────────────────────────────────────────

/// Premium leader marker: orange glow + crown + rider name.
class LeaderMarker extends StatefulWidget {
  const LeaderMarker({
    super.key,
    required this.location,
    this.isCurrentUser = false,
  });

  final RiderLocation location;
  final bool isCurrentUser;

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
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Glow ring
                Positioned(
                  top: -4,
                  child: Container(
                    width: 60 + (8 * _glowAnim.value),
                    height: 60 + (8 * _glowAnim.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFF6A00,
                      ).withValues(alpha: 0.2 * _glowAnim.value),
                    ),
                  ),
                ),
                // Avatar circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF3E0),
                    border: Border.all(
                      color: const Color(0xFFFF6A00),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFF6A00,
                        ).withValues(alpha: 0.4 * _glowAnim.value),
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
                // Crown icon
                Positioned(
                  top: -14,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6A00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
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
                  widget.isCurrentUser
                      ? 'You (Leader)'
                      : widget.location.userName,
              backgroundColor: const Color(0xFFFF6A00),
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// RIDER MARKER  — Standard rider with name label
// ──────────────────────────────────────────────────────────────────────────────

/// Standard rider marker with avatar, name, and stale indicator.
class RiderMarker extends StatelessWidget {
  const RiderMarker({
    super.key,
    required this.location,
    this.isCurrentUser = false,
  });

  final RiderLocation location;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isCurrentUser ? const Color(0xFFFF6A00) : const Color(0xFF2196F3);
    final opacity = location.isStale ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
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
              if (location.isStale)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _NameLabel(
            name: isCurrentUser ? 'You' : location.userName,
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

    // Triangle pointing upward (0° = north)
    final path =
        Path()
          ..moveTo(cx, cy - size.height * 0.45)
          ..lineTo(cx + size.width * 0.15, cy - size.height * 0.1)
          ..lineTo(cx - size.width * 0.15, cy - size.height * 0.1)
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
