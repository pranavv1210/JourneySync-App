import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_ride_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  String name = "";
  String bike = "";
  String userPhone = "";
  String userId = "";

  bool loading = true;
  List<Map<String, dynamic>> recentRides = [];

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      name = prefs.getString("userName") ?? "Rider";

      bike = prefs.getString("userBike") ?? "No bike added";
      userPhone = prefs.getString("userPhone") ?? "";
      userId = prefs.getString("userId") ?? "";

      loading = false;
    });

    await loadRecentRides();
  }

  Future<void> loadRecentRides() async {
    final rideLeaderId = _resolveRideLeaderId();
    if (rideLeaderId == null) {
      setState(() {
        recentRides = [];
      });
      return;
    }
    List<dynamic> data = [];
    try {
      data = await supabase
          .from('rides')
          .select()
          .eq('leader_id', rideLeaderId)
          .eq('status', 'ended')
          .order('ended_at', ascending: false)
          .limit(5);
    } catch (_) {
      try {
        data = await supabase
            .from('rides')
            .select()
            .eq('leader_id', rideLeaderId)
            .eq('status', 'ended')
            .order('created_at', ascending: false)
            .limit(5);
      } catch (_) {
        data = [];
      }
    }
    setState(() {
      recentRides = List<Map<String, dynamic>>.from(data);
    });
  }

  String? _resolveRideLeaderId() {
    if (_looksLikeUuid(userId)) return userId;
    if (_looksLikeUuid(userPhone)) return userPhone;
    return null;
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD46211);
    const primaryDark = Color(0xFFB04E0A);

    const forest = Color(0xFF1E3A2F);
    const background = Color(0xFFF8F7F6);
    const sandDarker = Color(0xFFE8E4DE);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _statusBarMock(forest),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(primary, forest),
                        const SizedBox(height: 18),
                        _quickStatus(primary, forest, sandDarker, bike),
                        const SizedBox(height: 22),
                        _primaryActions(primary, primaryDark, forest),
                        const SizedBox(height: 22),
                        _recentJourneysSection(primary, forest, sandDarker),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(primary),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _centerRideButton(primary),
    );
  }

  Widget _statusBarMock(Color forest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "9:41",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: forest.withOpacity(0.8),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.signal_cellular_alt,
                size: 16,
                color: forest.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Icon(Icons.wifi, size: 16, color: forest.withOpacity(0.7)),
              const SizedBox(width: 6),
              Icon(
                Icons.battery_full,
                size: 16,
                color: forest.withOpacity(0.7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(Color primary, Color forest) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "WELCOME BACK",
              style: TextStyle(
                fontSize: 12,
                color: primary.withOpacity(0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Let's ride, $name.",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: forest,
              ),
            ),
          ],
        ),
        Stack(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage("assets/profile.png"),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickStatus(
    Color primary,
    Color forest,
    Color sandDarker,
    String bike,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statusCard(
            icon: Icons.wb_sunny,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: Colors.blue,
            title: "Weather",
            value: "72°F Clear",
            borderColor: sandDarker,
            textColor: forest,
          ),
          const SizedBox(width: 12),
          _statusCard(
            icon: Icons.two_wheeler,
            iconBg: primary.withOpacity(0.1),
            iconColor: primary,
            title: "My Bike",
            value: bike,
            borderColor: sandDarker,
            textColor: forest,
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryActions(Color primary, Color primaryDark, Color forest) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRideScreen()),
            );
          },
          child: Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [primary, primaryDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Create Ride",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Plan a route and invite friends",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 150,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: forest.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0.06,
                  child: Image.asset(
                    "assets/pattern.png",
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(Icons.near_me, color: primary, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Nearby Active Rides",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "No nearby rides found",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recentJourneysSection(Color primary, Color forest, Color sandDarker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Journeys",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: forest,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "View All",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        if (recentRides.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sandDarker.withOpacity(0.6)),
            ),
            child: Center(
              child: Text(
                "No recent journeys yet",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          Column(
            children:
                recentRides.map((ride) {
                  final name = (ride['name'] ?? "Ride").toString();
                  final destination =
                      (ride['destination'] ?? "Destination").toString();
                  final endedAt =
                      ride['ended_at']?.toString() ??
                      ride['created_at']?.toString();
                  final dateLabel = _formatDate(endedAt);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sandDarker.withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.route, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
      ],
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return "—";
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return "—";
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
    return "${months[(parsed.month - 1).clamp(0, 11)]} ${parsed.day}";
  }

  Widget _bottomNav(Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(
            icon: Icons.home,
            label: "Home",
            active: true,
            onTap: () {},
            primary: primary,
          ),
          _navItem(
            icon: Icons.map,
            label: "Map",
            active: false,
            onTap: () {},
            primary: primary,
          ),
          const SizedBox(width: 46),
          _navItem(
            icon: Icons.garage,
            label: "Garage",
            active: false,
            onTap: () {},
            primary: primary,
          ),
          _navItem(
            icon: Icons.settings,
            label: "Settings",
            active: false,
            onTap: () {},
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? primary : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerRideButton(Color primary) {
    return FloatingActionButton(
      backgroundColor: primary,
      elevation: 8,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateRideScreen()),
        );
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.navigation, color: Colors.white, size: 28),
    );
  }
}
