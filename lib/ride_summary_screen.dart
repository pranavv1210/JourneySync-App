import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RideSummaryScreen extends StatefulWidget {
  const RideSummaryScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? ride;
  String userName = "Rider";
  String userBike = "No bike added";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString("userName") ?? "Rider";
    userBike = prefs.getString("userBike") ?? "No bike added";
    final data =
        await supabase.from('rides').select().eq('id', widget.rideId).single();
    setState(() {
      ride = data;
      loading = false;
    });
  }

  String _rideName() {
    final name = ride?['name']?.toString().trim();
    return (name == null || name.isEmpty) ? "Ride Completed" : name;
  }

  String _durationText() {
    final start = ride?['started_at']?.toString();
    final end = ride?['ended_at']?.toString();
    if (start == null || end == null) return "—";
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return "—";
    final diff = e.difference(s);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return "${h}h ${m}m";
  }

  String _metric(String key, String unit) {
    final value = ride?[key];
    if (value == null) return "—";
    return "$value $unit";
  }

  String _dateLabel() {
    final end =
        ride?['ended_at']?.toString() ?? ride?['created_at']?.toString();
    final e = end == null ? null : DateTime.tryParse(end);
    if (e == null) return "—";
    return "${_month(e.month)} ${e.day}";
  }

  String _month(int m) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF6A00);
    const secondaryBlue = Color(0xFF0056B3);
    const vibrantTeal = Color(0xFF00C2CB);
    const background = Color(0xFFF8F7F5);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _header(vibrantTeal),
              const SizedBox(height: 24),
              _summaryCard(primary, secondaryBlue),
              const SizedBox(height: 18),
              _routeThumbnail(),
              const SizedBox(height: 18),
              _participants(),
              const SizedBox(height: 20),
              _actions(primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color vibrantTeal) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: vibrantTeal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: vibrantTeal,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: vibrantTeal.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Ride Completed!",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          _rideName(),
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _summaryCard(Color primary, Color secondaryBlue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBlock(
                  icon: Icons.timer,
                  label: "Duration",
                  value: _durationText(),
                  color: secondaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBlock(
                  icon: Icons.add_location_alt,
                  label: "Distance",
                  value: _metric('distance_km', 'km'),
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  "Avg Speed",
                  _metric('avg_speed_kmh', 'km/h'),
                ),
              ),
              Expanded(
                child: _miniMetric(
                  "Top Speed",
                  _metric('top_speed_kmh', 'km/h'),
                ),
              ),
              Expanded(
                child: _miniMetric("Elevation", _metric('elevation_m', 'm')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _routeThumbnail() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Row(
              children: [
                const Icon(Icons.place, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  _destinationLabel(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _destinationLabel() {
    final dest = ride?['destination']?.toString().trim();
    return (dest == null || dest.isEmpty) ? "Destination" : dest;
  }

  Widget _participants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RODE WITH",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage("assets/profile.png"),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      userBike,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C2CB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Finished",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00C2CB),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(Color primary) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 6,
              shadowColor: primary.withOpacity(0.25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "View Full History",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
