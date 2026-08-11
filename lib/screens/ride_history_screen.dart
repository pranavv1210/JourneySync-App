import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_navigation.dart';
import '../services/ride_service.dart';
import '../theme/app_theme.dart';
import '../models/ride_record.dart';
import 'ride_lobby_screen.dart';
import 'ride_summary_screen.dart';
import 'ride_mode_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/premium/glass_card.dart';
import 'dart:ui' as ui;

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final RideService _rideService = RideService();
  bool loading = true;
  List<RideRecord> allRides = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) return;
      final rides = await _rideService.fetchRecentRides(userId, limit: 100);
      if (!mounted) return;
      setState(() => allRides = rides);
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return "Unknown date";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (selected == today) {
      return "Today, ${DateFormat('h:mm a').format(dateTime)}";
    } else if (selected == today.add(const Duration(days: 1))) {
      return "Tomorrow, ${DateFormat('h:mm a').format(dateTime)}";
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  String _rideStatusLabel(RideRecord ride) {
    if (ride.isCompleted) return 'Completed';
    final st = ride.status.trim().toLowerCase();
    if (st == 'active' || st == 'live') return 'Live';
    if (st == 'cancelled') return 'Cancelled';
    return 'Scheduled';
  }

  ({Color bg, Color fg}) _rideStatusColors(String statusLabel) {
    final normalized = statusLabel.trim().toLowerCase();
    if (normalized == 'live') {
      return (
        bg: const Color(0xFF2FA865).withValues(alpha: 0.14),
        fg: const Color(0xFF2FA865),
      );
    }
    if (normalized == 'scheduled') {
      return (
        bg: const Color(0xFFF5A524).withValues(alpha: 0.16),
        fg: const Color(0xFFD88300),
      );
    }
    if (normalized == 'completed') {
      return (
        bg: const Color(0xFF00C2CB).withValues(alpha: 0.12),
        fg: const Color(0xFF00A8B0),
      );
    }
    return (
      bg: const Color(0xFFF26C0D).withValues(alpha: 0.12),
      fg: const Color(0xFFF26C0D),
    );
  }

  Widget _ridePreviewTile({required Color primary, required Color forest}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFFFF3E8), primary.withValues(alpha: 0.16)],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _RidePreviewPainter(
                  lineColor: forest.withValues(alpha: 0.5),
                  accentColor: primary,
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 10,
            child: _mapPin(primary.withValues(alpha: 0.9)),
          ),
          Positioned(
            right: 8,
            bottom: 10,
            child: _mapPin(forest.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _mapPin(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
        ],
      ),
    );
  }

  void _showReplayDialog(BuildContext context, String title) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Replay',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) {
        return _ReplayRouteDialog(title: title);
      },
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF26C0D);
    const background = Color(0xFFF8F7F5);
    const forest = Color(0xFF1F4A33);
    const sandDarker = Color(0xFFDED0BC);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Ride History',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: forest,
          ),
        ),
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
        leading: Builder(
          builder:
              (context) => GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sandDarker.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: forest,
                    size: 16,
                  ),
                ),
              ),
        ),
        centerTitle: true,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : allRides.isEmpty
              ? const EmptyStateCard(
                title: 'No journeys yet',
                message: 'Finished and scheduled rides will appear here.',
                icon: Icons.history_rounded,
                foreground: forest,
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: allRides.length,
                itemBuilder: (context, index) {
                  final ride = allRides[index];
                  final title =
                      ride.title.trim().isNotEmpty ? ride.title : "Ride";
                  final destination =
                      ride.endLocation.trim().isNotEmpty
                          ? ride.endLocation
                          : "Destination";
                  final dateLabel = _formatDate(ride.createdAt);
                  final statusLabel = _rideStatusLabel(ride);
                  final statusColors = _rideStatusColors(statusLabel);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ridePreviewTile(
                                primary: primary,
                                forest: forest,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: forest,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$destination • ${ride.participantCount} riders",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    dateLabel,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColors.bg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: statusColors.fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.black12,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // View details
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: forest,
                                  textStyle: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () async {
                                  if (statusLabel == 'Live') {
                                    await Navigator.push(
                                      context,
                                      buildAppRoute(
                                        RideModeScreen(rideId: ride.id),
                                      ),
                                    );
                                  } else if (ride.isCompleted) {
                                    await Navigator.push(
                                      context,
                                      buildAppRoute(
                                        RideSummaryScreen(rideId: ride.id),
                                      ),
                                    );
                                  } else {
                                    await Navigator.push(
                                      context,
                                      buildAppRoute(
                                        RideLobbyScreen(rideId: ride.id),
                                      ),
                                    );
                                  }
                                  _loadHistory();
                                },
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  statusLabel == 'Live'
                                      ? 'Join Live Ride'
                                      : ride.isCompleted
                                      ? 'View Summary'
                                      : 'Open Lobby',
                                ),
                              ),

                              // Replay Route button (visible if completed)
                              if (ride.isCompleted)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: primary),
                                    foregroundColor: primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed:
                                      () => _showReplayDialog(context, title),
                                  icon: const Icon(
                                    Icons.replay_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Replay Route'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _RidePreviewPainter extends CustomPainter {
  const _RidePreviewPainter({
    required this.lineColor,
    required this.accentColor,
  });

  final Color lineColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1;
    for (double dx = 10; dx < size.width; dx += 16) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (double dy = 10; dy < size.height; dy += 16) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final path =
        Path()
          ..moveTo(size.width * 0.18, size.height * 0.28)
          ..cubicTo(
            size.width * 0.28,
            size.height * 0.16,
            size.width * 0.42,
            size.height * 0.72,
            size.width * 0.56,
            size.height * 0.52,
          )
          ..cubicTo(
            size.width * 0.67,
            size.height * 0.38,
            size.width * 0.76,
            size.height * 0.74,
            size.width * 0.82,
            size.height * 0.7,
          );

    final baseRoutePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, baseRoutePaint);

    final accentPaint =
        Paint()
          ..color = accentColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _RidePreviewPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.accentColor != accentColor;
  }
}

class _ReplayRouteDialog extends StatefulWidget {
  const _ReplayRouteDialog({required this.title});
  final String title;

  @override
  State<_ReplayRouteDialog> createState() => _ReplayRouteDialogState();
}

class _ReplayRouteDialogState extends State<_ReplayRouteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _playing = false);
            }
          })
          ..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Replaying: ${widget.title}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Simulated Animated Map Replay Box
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ReplayRoutePainter(
                              progress: _animController.value,
                              lineColor: const Color(0xFFFF6A00),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Replay speed: 10x',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, _) {
                            final pct = (_animController.value * 100).toInt();
                            return Text(
                              '$pct%',
                              style: const TextStyle(
                                color: Color(0xFFFF6A00),
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return Slider(
                          value: _animController.value.clamp(0.0, 1.0),
                          activeColor: const Color(0xFFFF6A00),
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            _animController.value = value;
                            if (_playing) _animController.forward();
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: () {
                              _animController.reset();
                              _animController.forward();
                              setState(() => _playing = true);
                            },
                            child: const Text('Restart'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() => _playing = !_playing);
                              if (_playing) {
                                _animController.forward();
                              } else {
                                _animController.stop();
                              }
                            },
                            icon: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 16,
                            ),
                            label: Text(_playing ? 'Pause' : 'Resume'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplayRoutePainter extends CustomPainter {
  const _ReplayRoutePainter({required this.progress, required this.lineColor});
  final double progress;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid lines
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..strokeWidth = 1;
    for (double dx = 10; dx < size.width; dx += 16) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (double dy = 10; dy < size.height; dy += 16) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final path =
        Path()
          ..moveTo(size.width * 0.15, size.height * 0.3)
          ..cubicTo(
            size.width * 0.3,
            size.height * 0.1,
            size.width * 0.45,
            size.height * 0.8,
            size.width * 0.6,
            size.height * 0.5,
          )
          ..cubicTo(
            size.width * 0.7,
            size.height * 0.3,
            size.width * 0.8,
            size.height * 0.8,
            size.width * 0.85,
            size.height * 0.7,
          );

    // Compute progress path
    final pathMetrics = path.computeMetrics();
    final progressPath = Path();
    for (final metric in pathMetrics) {
      final extract = metric.extractPath(0.0, metric.length * progress);
      progressPath.addPath(extract, Offset.zero);
    }

    // Draw route path
    final routePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(progressPath, routePaint);

    // Draw dots
    final startPinPaint = Paint()..color = Colors.green;
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.3),
      5,
      startPinPaint,
    );

    if (progress > 0.0) {
      final currentMetric = path.computeMetrics().firstOrNull;
      if (currentMetric != null) {
        final pos =
            currentMetric
                .getTangentForOffset(currentMetric.length * progress)
                ?.position;
        if (pos != null) {
          final riderPaint = Paint()..color = const ui.Color(0xFF2196F3);
          canvas.drawCircle(pos, 6, riderPaint);

          final glowPaint =
              Paint()
                ..color = const ui.Color(0xFF2196F3).withValues(alpha: 0.3);
          canvas.drawCircle(pos, 12 * progress, glowPaint);
        }
      }
    }

    final speedPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    final speedPath = Path()..moveTo(size.width * 0.12, size.height * 0.88);
    for (var i = 1; i <= 12; i++) {
      final x = size.width * (0.12 + i * 0.065);
      final wave = math.sin(i * 0.9) * 10;
      final y = size.height * 0.88 - wave - (i / 12) * 12;
      speedPath.lineTo(x, y);
    }
    final metrics = speedPath.computeMetrics();
    final drawn = Path();
    for (final metric in metrics) {
      drawn.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }
    canvas.drawPath(drawn, speedPaint);
  }

  @override
  bool shouldRepaint(covariant _ReplayRoutePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor;
  }
}
