import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_navigation.dart';
import '../services/ride_service.dart';
import '../models/ride_record.dart';
import 'ride_lobby_screen.dart';
import 'ride_summary_screen.dart';
import 'live_ride_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/empty_state_card.dart';

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

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF26C0D);
    const background = Color(0xFFF8F7F5);
    const forest = Color(0xFF1F4A33);
    const sandDarker = Color(0xFFDED0BC);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: background,
        foregroundColor: forest,
        elevation: 0,
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

                  return InkWell(
                    onTap: () async {
                      if (statusLabel == 'Live') {
                        await Navigator.push(
                          context,
                          buildAppRoute(LiveRideScreen(rideId: ride.id)),
                        );
                      } else if (ride.isCompleted) {
                        await Navigator.push(
                          context,
                          buildAppRoute(RideSummaryScreen(rideId: ride.id)),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          buildAppRoute(RideLobbyScreen(rideId: ride.id)),
                        );
                      }
                      _loadHistory();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sandDarker.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          _ridePreviewTile(primary: primary, forest: forest),
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$destination - ${ride.participantCount} riders",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: statusColors.fg,
                                    ),
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
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
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
