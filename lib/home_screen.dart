import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_toast.dart';
import 'app_navigation.dart';
import 'create_ride_screen.dart';
import 'map_screen.dart';
import 'nearby_rides_screen.dart';
import 'ride_service.dart';
import 'settings_screen.dart';
import 'supabase_service.dart';
import 'weather_service.dart';
import 'ride_history_screen.dart';
import 'ride_lobby_screen.dart';
import 'ride_summary_screen.dart';
import 'live_ride_screen.dart';
import 'widgets/empty_state_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final SupabaseService _supabaseService = SupabaseService();
  final RideService _rideService = RideService();
  final WeatherService _weatherService = WeatherService();

  String name = "Rider";
  String bike = "No bike added";
  String userPhone = "";
  String userId = "";
  String loadError = "";
  String weatherText = "Weather unavailable";

  bool loading = false;
  bool refreshingHome = false;
  String rideActionLoadingId = '';
  List<RideRecord> recentRides = [];
  List<RideRecord> nearbyRides = [];

  @override
  void initState() {
    super.initState();
    _hydrateFromCache();
    _loadHomeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadHomeData();
  }

  Future<void> _loadHomeData({bool showBlockingLoader = false}) async {
    if (!mounted) {
      return;
    }
    if (showBlockingLoader) {
      setState(() {
        loading = true;
        loadError = "";
      });
    } else {
      setState(() {
        refreshingHome = true;
        loadError = "";
      });
    }

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
      var weatherValue = 'Weather unavailable';
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

      Future<List<RideRecord>>? recentFuture;
      Future<List<NearbyRide>>? nearbyFuture;
      if (resolvedId.isNotEmpty) {
        recentFuture = _rideService.fetchRecentRides(resolvedId, limit: 3);
        nearbyFuture = _rideService.searchNearbyRides(resolvedId);
      }
      final weatherFuture = _weatherService.fetchCurrentWeather();

      if (recentFuture != null && nearbyFuture != null) {
        try {
          fetchedRecent = await recentFuture;
          final nearby = await nearbyFuture;
          fetchedNearby = nearby.map((item) => item.ride).toList();
        } catch (error) {
          // Keep home usable even if ride list fetch fails.
          debugPrint("Home ride fetch failed: $error");
        }
      }
      try {
        final weather = await weatherFuture;
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
          refreshingHome = false;
        });
      }
    }
  }

  Future<void> _hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = (prefs.getString('userId') ?? '').trim();
      userPhone = (prefs.getString('userPhone') ?? '').trim();
      name = (prefs.getString('userName') ?? 'Rider').trim();
      bike = (prefs.getString('userBike') ?? 'No bike added').trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD46211);
    const primaryDark = Color(0xFFB04E0A);

    const forest = Color(0xFF1E3A2F);
    const background = Color(0xFFF8F7F6);
    const sandDarker = Color(0xFFE8E4DE);

    if (loading && recentRides.isEmpty && nearbyRides.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (refreshingHome)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (loadError.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.2),
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
            color: primary.withValues(alpha: 0.8),
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
            iconBg: primary.withValues(alpha: 0.1),
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
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            ? "No nearby rides right now"
            : "${nearby.length} ride(s) found nearby";

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              buildAppRoute(const CreateRideScreen()),
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
                  color: primary.withValues(alpha: 0.25),
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
                              color: primaryDark.withValues(alpha: 0.45),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.two_wheeler,
                                size: 68,
                                color: Colors.white.withValues(alpha: 0.35),
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
                          primary.withValues(alpha: 0.82),
                          primaryDark.withValues(alpha: 0.88),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
              buildAppRoute(const NearbyRidesScreen()),
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
                  color: forest.withValues(alpha: 0.06),
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
                      color: primary.withValues(alpha: 0.06),
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
                      color: primary.withValues(alpha: 0.08),
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
                        color: primary.withValues(alpha: 0.1),
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
              onPressed: () {
                Navigator.push(
                  context,
                  buildAppRoute(const RideHistoryScreen()),
                );
              },
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sandDarker.withValues(alpha: 0.6)),
            ),
            child: EmptyStateCard(
              title: 'No journeys yet',
              message: 'Create a ride to start tracking your group route.',
              icon: Icons.route_outlined,
              foreground: forest,
            ),
          )
        else
          Column(
            children:
                recentRides.take(3).map((ride) {
                  final title =
                      ride.title.trim().isNotEmpty ? ride.title : "Ride";
                  final destination =
                      ride.endLocation.trim().isNotEmpty
                          ? ride.endLocation
                          : "Destination";
                  final dateLabel = _formatDate(ride.createdAt);
                  final isBusy = rideActionLoadingId == ride.id;
                  final canDelete = ride.isScheduled || ride.isCompleted;
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
                      await _loadHomeData();
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
                          _ridePreviewTile(
                            primary: primary,
                            forest: forest,
                            ride: ride,
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isBusy)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primary,
                                  ),
                                )
                              else if (canDelete)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _confirmPermanentDeleteRide(
                                        ride,
                                        primary,
                                      );
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        if (canDelete)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete Permanently'),
                                          ),
                                      ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
      ],
    );
  }

  String _rideStatusLabel(RideRecord ride) {
    final raw = ride.status.trim().toLowerCase();
    if (ride.isCompleted) return 'Completed';
    if (raw == 'active' || raw == 'live') return 'Live';
    if (raw == 'scheduled' || raw == 'pending') return 'Scheduled';
    if (raw.isEmpty) return 'Scheduled';
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
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

  Future<void> _confirmPermanentDeleteRide(
    RideRecord ride,
    Color primary,
  ) async {
    if (!ride.isScheduled && !ride.isCompleted) {
      showAppToast(
        context,
        'Only scheduled/completed rides can be deleted.',
        type: AppToastType.error,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Ride?'),
            content: const Text(
              'This will permanently delete this ride for everyone and remove it from Supabase.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    await _runRideAction(
      rideId: ride.id,
      action: () async {
        await _rideService.deleteRideAsCreator(
          rideId: ride.id,
          creatorId: userId,
        );
      },
      successMessage: 'Ride deleted.',
      failureMessage: 'Could not delete ride.',
      primary: primary,
    );
  }

  Future<void> _runRideAction({
    required String rideId,
    required Future<void> Function() action,
    required String successMessage,
    required String failureMessage,
    required Color primary,
  }) async {
    if (rideActionLoadingId.isNotEmpty) return;
    setState(() {
      rideActionLoadingId = rideId;
    });
    try {
      await action();
      if (!mounted) return;
      showAppToast(context, successMessage, type: AppToastType.success);
      await _loadHomeData();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        '$failureMessage ${_rideActionError(error)}',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          rideActionLoadingId = '';
        });
      }
    }
  }

  String _rideActionError(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      if (code == '42501') {
        return 'RLS policy is blocking this action.';
      }
      if (code == 'PGRST204' || code == '42703') {
        return 'Missing required table column in Supabase schema.';
      }
    }
    final text = error.toString();
    return text.length > 120 ? text.substring(0, 120) : text;
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

  Widget _ridePreviewTile({
    required Color primary,
    required Color forest,
    required RideRecord ride,
  }) {
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

  Widget _bottomNav(Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Navigator.push(context, buildAppRoute(const NearbyRidesScreen()));
            },
            primary: primary,
          ),
          const SizedBox(width: 46),
          _navItem(
            icon: Icons.map,
            label: "Map",
            active: false,
            onTap: () {
              Navigator.push(context, buildAppRoute(const MapScreen()));
            },
            primary: primary,
          ),
          _navItem(
            icon: Icons.person_outline,
            label: "Profile",
            active: false,
            onTap: () {
              Navigator.push(context, buildAppRoute(const SettingsScreen()));
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
        await Navigator.push(context, buildAppRoute(const CreateRideScreen()));
        await _loadHomeData();
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
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
