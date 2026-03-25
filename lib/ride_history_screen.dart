import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ride_service.dart';
import 'ride_lobby_screen.dart';
import 'ride_summary_screen.dart';
import 'live_ride_screen.dart';
import 'package:intl/intl.dart';

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
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : allRides.isEmpty
          ? const Center(child: Text("No rides found", style: TextStyle(color: forest, fontWeight: FontWeight.bold)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: allRides.length,
              itemBuilder: (context, index) {
                final ride = allRides[index];
                final title = ride.title.trim().isNotEmpty ? ride.title : "Ride";
                final destination = ride.endLocation.trim().isNotEmpty ? ride.endLocation : "Destination";
                final dateLabel = _formatDate(ride.createdAt);
                final statusLabel = _rideStatusLabel(ride);

                return InkWell(
                  onTap: () async {
                    if (statusLabel == 'Live') {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRideScreen(rideId: ride.id)));
                    } else if (ride.isCompleted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RideSummaryScreen(rideId: ride.id)));
                    } else {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RideLobbyScreen(rideId: ride.id)));
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
                      border: Border.all(color: sandDarker.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.route, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text("$destination - ${ride.participantCount} riders", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ride.isCompleted ? const Color(0xFF00C2CB).withValues(alpha: 0.12) : primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ride.isCompleted ? const Color(0xFF00C2CB) : primary)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(dateLabel, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
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
