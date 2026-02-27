import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_ride_screen.dart';
import 'map_screen.dart';
import 'nearby_rides_screen.dart';
import 'ride_service.dart';
import 'settings_screen.dart';
import 'supabase_service.dart';
import 'weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final RideService _rideService = RideService();
  final WeatherService _weatherService = WeatherService();

  String name = "Rider";
  String bike = "No bike added";
  String userPhone = "";
  String userId = "";
  String loadError = "";
  String weatherText = "Weather unavailable";

  bool loading = true;
  List<RideRecord> recentRides = [];
  List<RideRecord> nearbyRides = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) {
      return;
    }
    setState(() {
      loading = true;
      loadError = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString('userId') ?? '';
      final cachedPhone = prefs.getString('userPhone') ?? '';
      final cachedName = prefs.getString('userName') ?? 'Rider';
      final cachedBike = prefs.getString('userBike') ?? 'No bike added';

      var resolvedId = cachedUserId.trim();
      var resolvedPhone = cachedPhone.trim();
      var resolvedName = cachedName.trim();
      var resolvedBike = cachedBike.trim();
      var profileErrorText = '';
      var fetchedRecent = <RideRecord>[];
      var fetchedNearby = <RideRecord>[];
      var weatherValue = weatherText;
      var fetchedProfileFromServer = false;

      Map<String, dynamic>? userRow;
      if (cachedUserId.trim().isNotEmpty) {
        try {
          userRow = await _supabaseService.fetchUserById(cachedUserId);
          fetchedProfileFromServer = userRow != null;
        } catch (error) {
          profileErrorText = _humanizeLoadError(error);
        }
      }
      if (userRow == null && cachedPhone.trim().isNotEmpty) {
        try {
          userRow = await _supabaseService.fetchUserByPhone(cachedPhone);
          fetchedProfileFromServer = userRow != null;
        } catch (error) {
          if (profileErrorText.isEmpty) {
            profileErrorText = _humanizeLoadError(error);
          }
        }
      }

      resolvedId = (userRow?['id'] ?? resolvedId).toString().trim();
      resolvedPhone = (userRow?['phone'] ?? resolvedPhone).toString().trim();
      resolvedName = (userRow?['name'] ?? resolvedName).toString().trim();
      resolvedBike = (userRow?['bike'] ?? resolvedBike).toString().trim();

      if (resolvedId.isNotEmpty) {
        await prefs.setString('userId', resolvedId);
      }
      if (resolvedPhone.isNotEmpty) {
        await prefs.setString('userPhone', resolvedPhone);
      }
      await prefs.setString(
        'userName',
        resolvedName.isNotEmpty ? resolvedName : 'Rider',
      );
      await prefs.setString(
        'userBike',
        resolvedBike.isNotEmpty ? resolvedBike : 'No bike added',
      );

      if (resolvedId.isNotEmpty) {
        try {
          fetchedRecent = await _rideService.fetchRecentRides(resolvedId);
          fetchedNearby = await _rideService.fetchNearbyRides(resolvedId);
        } catch (error) {
          // Keep home usable even if ride list fetch fails.
          debugPrint("Home ride fetch failed: $error");
        }
      }
      try {
        final weather = await _weatherService.fetchCurrentWeather();
        if (weather != null && weather.displayText.trim().isNotEmpty) {
          weatherValue = weather.displayText.trim();
        }
      } catch (error) {
        debugPrint("Weather fetch failed: $error");
      }

      if (!mounted) {
        return;
      }
      setState(() {
        name = resolvedName.isNotEmpty ? resolvedName : 'Rider';
        bike = resolvedBike.isNotEmpty ? resolvedBike : 'No bike added';
        userId = resolvedId;
        userPhone = resolvedPhone;
        recentRides = fetchedRecent;
        nearbyRides = fetchedNearby;
        weatherText = weatherValue;
        loadError =
            !fetchedProfileFromServer && profileErrorText.isNotEmpty
                ? profileErrorText
                : "";
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        loadError = _humanizeLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loadError.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loadError,
                                    style: TextStyle(
                                      color: forest,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _header(primary, forest),
                        const SizedBox(height: 18),
                        _quickStatus(
                          primary,
                          forest,
                          sandDarker,
                          weatherText,
                          bike,
                        ),
                        const SizedBox(height: 22),
                        _primaryActions(
                          primary,
                          primaryDark,
                          forest,
                          nearbyRides,
                        ),
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

  String _humanizeLoadError(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      final message = error.message.toLowerCase();
      if (code == '42501' || message.contains('row-level security')) {
        return 'Supabase RLS is blocking reads. Add SELECT policy for users/rides.';
      }
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socket') || raw.contains('timeout')) {
      return 'Network issue while loading data. Showing cached profile.';
    }
    return 'Failed to load latest data. Showing cached profile.';
  }

  Widget _header(Color primary, Color forest) {
    return Column(
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
          "Let's ride, $name",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: forest,
          ),
        ),
      ],
    );
  }

  Widget _quickStatus(
    Color primary,
    Color forest,
    Color sandDarker,
    String weather,
    String bike,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statusCard(
            icon: Icons.wb_sunny,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: Colors.blue,
            title: "Weather",
            value: weather,
            borderColor: sandDarker,
            textColor: forest,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusCard(
            icon: Icons.two_wheeler,
            iconBg: primary.withOpacity(0.1),
            iconColor: primary,
            title: "My Bike",
            value: bike,
            borderColor: sandDarker,
            textColor: forest,
          ),
        ),
      ],
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
          Expanded(
            child: Column(
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
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActions(
    Color primary,
    Color primaryDark,
    Color forest,
    List<RideRecord> nearby,
  ) {
    final nearbySubtitle =
        nearby.isEmpty
            ? "No nearby rides"
            : "${nearby.length} ride(s) found nearby";

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRideScreen()),
            );
            await _loadHomeData();
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      "https://images.unsplash.com/photo-1558980664-10ea9b4b3bd3?auto=format&fit=crop&w=1200&q=80",
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Image.network(
                          "https://images.unsplash.com/photo-1558980394-4c7c9299fe96?auto=format&fit=crop&w=1200&q=80",
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: primaryDark.withOpacity(0.45),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.two_wheeler,
                                size: 68,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          primary.withOpacity(0.82),
                          primaryDark.withOpacity(0.88),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
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
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyRidesScreen()),
            );
            await _loadHomeData();
          },
          child: Container(
            height: 190,
            width: double.infinity,
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
                  right: -26,
                  bottom: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  right: 38,
                  bottom: 22,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withOpacity(0.08),
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
                    const SizedBox(height: 16),
                    Text(
                      "Nearby Active Rides",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nearbySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (nearby.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9F5E5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 8, color: Color(0xFF2FA865)),
                          SizedBox(width: 6),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2FA865),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
                "No recent rides",
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
                  final title =
                      ride.title.trim().isNotEmpty ? ride.title : "Ride";
                  final destination =
                      ride.endLocation.trim().isNotEmpty
                          ? ride.endLocation
                          : "Destination";
                  final dateLabel = _formatDate(ride.createdAt);
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
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$destination - ${ride.participantCount} riders",
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

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
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
    return "${months[(date.month - 1).clamp(0, 11)]} ${date.day}";
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
            icon: Icons.route_outlined,
            label: "Rides",
            active: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyRidesScreen()),
              );
            },
            primary: primary,
          ),
          const SizedBox(width: 46),
          _navItem(
            icon: Icons.map,
            label: "Map",
            active: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
            primary: primary,
          ),
          _navItem(
            icon: Icons.person_outline,
            label: "Profile",
            active: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
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
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateRideScreen()),
        );
        await _loadHomeData();
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
    );
  }
}
