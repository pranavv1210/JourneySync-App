import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_toast.dart';
import '../services/app_navigation.dart';
import 'create_ride_screen.dart';
import 'explore_screen.dart';
import 'my_rides_screen.dart';
import 'nearby_rides_screen.dart';
import '../services/ride_service.dart';
import 'settings_screen.dart';
import '../services/supabase_service.dart';
import '../services/weather_service.dart';
import 'ride_history_screen.dart';
import 'ride_lobby_screen.dart';
import 'ride_summary_screen.dart';
import 'ride_mode_screen.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/ride_loading_indicator.dart';
import '../models/ride_record.dart';
import '../coordinators/active_ride_coordinator.dart';
import '../coordinators/notification_coordinator.dart';
import 'notification_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final SupabaseService _supabaseService = SupabaseService();
  final RideService _rideService = RideService();
  final WeatherService _weatherService = WeatherService();

  String name = 'Rider';
  String bike = 'No bike added';
  String userPhone = '';
  String userId = '';
  String loadError = '';
  String weatherText = 'Weather unavailable';

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
    if (!mounted) return;
    setState(() {
      if (showBlockingLoader) {
        loading = true;
      } else {
        refreshingHome = true;
      }
      loadError = '';
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
      var weatherValue = 'Weather unavailable';
      var fetchedProfileFromServer = false;

      Map<String, dynamic>? userRow;
      try {
        userRow = await _loadProfileWithRetry(
          cachedUserId: cachedUserId,
          cachedPhone: cachedPhone,
          cachedName: cachedName,
          cachedBike: cachedBike,
        );
        fetchedProfileFromServer = userRow != null;
        if (userRow == null) {
          profileErrorText =
              'Please sign in again. No active profile session was found.';
        }
      } catch (error, stackTrace) {
        _logProfileLoadError(error, stackTrace);
        profileErrorText = _humanizeLoadError(error);
      }

      resolvedId = (userRow?['id'] ?? resolvedId).toString().trim();
      resolvedPhone = (userRow?['phone'] ?? resolvedPhone).toString().trim();
      resolvedName = (userRow?['name'] ?? resolvedName).toString().trim();
      resolvedBike = (userRow?['bike'] ?? resolvedBike).toString().trim();
      final resolvedAvatarUrl =
          (userRow?['avatar_url'] ?? prefs.getString('userAvatarUrl') ?? '')
              .toString()
              .trim();

      if (resolvedId.isNotEmpty) {
        await prefs.setString('userId', resolvedId);
        unawaited(NotificationCoordinator.instance.start(resolvedId));
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
      if (resolvedAvatarUrl.isNotEmpty) {
        await prefs.setString('userAvatarUrl', resolvedAvatarUrl);
      }

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
          debugPrint('Home ride fetch failed: $error');
        }
      }
      try {
        final weather = await weatherFuture;
        if (weather != null && weather.displayText.trim().isNotEmpty) {
          weatherValue = weather.displayText.trim();
        }
      } catch (error) {
        debugPrint('Weather fetch failed: $error');
      }

      if (!mounted) return;
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
                : '';
      });
    } catch (error, stackTrace) {
      _logProfileLoadError(error, stackTrace);
      if (!mounted) return;
      setState(() => loadError = _humanizeLoadError(error));
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

  Future<Map<String, dynamic>?> _loadProfileWithRetry({
    required String cachedUserId,
    required String cachedPhone,
    required String cachedName,
    required String cachedBike,
  }) async {
    Future<Map<String, dynamic>?> load() {
      return _supabaseService.fetchOrCreateCurrentUserProfile(
        cachedUserId: cachedUserId,
        cachedPhone: cachedPhone,
        cachedName: cachedName,
        cachedBike: cachedBike,
      );
    }

    try {
      return await load().timeout(const Duration(seconds: 15));
    } on TimeoutException catch (error, stackTrace) {
      _logProfileLoadError(error, stackTrace);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return load().timeout(const Duration(seconds: 15));
    }
  }

  void _logProfileLoadError(Object error, StackTrace stackTrace) {
    debugPrint('PROFILE LOAD ERROR: $error');
    debugPrint(stackTrace.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (loading && recentRides.isEmpty && nearbyRides.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const RideLoadingIndicator(label: 'Loading your rides')],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loadError.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loadError,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.forest,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildHeader(),
                        const SizedBox(height: 14),
                        _buildRideCommandCard(),
                        const SizedBox(height: 20),
                        _buildQuickStatus(),
                        const SizedBox(height: 24),
                        _buildPrimaryActions(),
                        const SizedBox(height: 16),
                        _buildResumeRideCard(),
                        const SizedBox(height: 24),
                        _buildRecentJourneys(),
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
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCenterRideButton(),
    );
  }

  String _humanizeLoadError(Object error) {
    if (error is TimeoutException) {
      return 'Offline Mode. Using cached profile.';
    }
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      final message = error.message.toLowerCase();
      if (code == 'PGRST116') {
        return 'Creating your profile...';
      }
      if (code == '42501' || message.contains('row-level security')) {
        return 'Supabase RLS is blocking profile reads. Add own-profile SELECT/INSERT/UPDATE policies.';
      }
      if (code == '401' ||
          code == '403' ||
          code == 'PGRST301' ||
          message.contains('jwt') ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        return 'Please sign in again.';
      }
      if (code == '42P01' || message.contains('does not exist')) {
        return 'Profile table is missing in Supabase.';
      }
      return 'Could not load profile from Supabase: ${error.message}';
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('socket') || raw.contains('timeout')) {
      return 'Offline Mode. Using cached profile.';
    }
    if (raw.contains('no active profile session') ||
        raw.contains('session expired')) {
      return 'Please sign in again.';
    }
    return 'Could not load profile from Supabase.';
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Let's ride, $name",
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedBuilder(
          animation: NotificationCoordinator.instance,
          builder: (context, _) {
            final unread = NotificationCoordinator.instance.unreadCount;
            return GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    buildAppRoute(const NotificationCenterScreen()),
                  ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: AppShadows.sm,
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unread > 9 ? '9+' : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRideCommandCard() {
    final activeSnapshot = ActiveRideCoordinator.instance.snapshot;
    final hasActiveRide = activeSnapshot.hasActiveRide;
    return PremiumCard(
      onTap:
          hasActiveRide
              ? () => Navigator.push(
                context,
                buildAppRoute(RideModeScreen(rideId: activeSnapshot.rideId)),
              )
              : () => Navigator.push(
                context,
                buildAppRoute(const NearbyRidesScreen()),
              ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              hasActiveRide ? Icons.play_arrow_rounded : Icons.radar_rounded,
              color: AppColors.forest,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActiveRide ? 'Resume live ride' : 'Find riders nearby',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasActiveRide
                      ? 'Return to tracking, group status, and route sync.'
                      : 'Open Ride Radar to discover active group rides.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatus() {
    return Row(
      children: [
        Expanded(
          child: PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        weatherText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.two_wheeler_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Bike',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        bike,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    final nearbySubtitle =
        nearbyRides.isEmpty
            ? 'No nearby rides right now'
            : '${nearbyRides.length} ride(s) found nearby';

    return Column(
      children: [
        // Create Ride Card
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
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: AppShadows.primary,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1558980664-10ea9b4b3bd3?auto=format&fit=crop&w=1200&q=80',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: AppColors.primaryDark.withValues(
                              alpha: 0.45,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.two_wheeler,
                              size: 68,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.82),
                          AppColors.primaryDark.withValues(alpha: 0.88),
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
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create Ride',
                        style: AppTypography.headlineMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plan a route and invite friends',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white70,
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
        // Nearby Rides Card
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: AppShadows.lg,
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
                      color: AppColors.primary.withValues(alpha: 0.06),
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
                      color: AppColors.primary.withValues(alpha: 0.08),
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.near_me_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nearby Active Rides',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nearbySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (nearbyRides.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success,
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

  Widget _buildResumeRideCard() {
    return AnimatedBuilder(
      animation: ActiveRideCoordinator.instance,
      builder: (context, _) {
        final snapshot = ActiveRideCoordinator.instance.snapshot;
        if (!snapshot.hasActiveRide ||
            snapshot.status == ActiveRideStatus.completed) {
          return const SizedBox.shrink();
        }
        return PremiumCard(
          onTap: () async {
            await Navigator.push(
              context,
              buildAppRoute(RideModeScreen(rideId: snapshot.rideId)),
            );
            await _loadHomeData();
          },
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderColor: AppColors.primary.withValues(alpha: 0.18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resume Ride',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your live session is still available.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentJourneys() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Journeys',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.forest,
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
                'View All',
                style: AppTypography.buttonMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (recentRides.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: EmptyStateCard(
              title: 'No journeys yet',
              message: 'Create a ride to start tracking your group route.',
              icon: Icons.route_outlined,
              foreground: AppColors.forest,
            ),
          )
        else
          Column(
            children:
                recentRides.take(3).map((ride) {
                  final title =
                      ride.title.trim().isNotEmpty ? ride.title : 'Ride';
                  final destination =
                      ride.endLocation.trim().isNotEmpty
                          ? ride.endLocation
                          : 'Destination';
                  final dateLabel = _formatDate(ride.createdAt);
                  final isBusy = rideActionLoadingId == ride.id;
                  final canDelete = ride.isScheduled || ride.isCompleted;
                  final statusLabel = _rideStatusLabel(ride);
                  final statusColors = _rideStatusColors(statusLabel);
                  return InkWell(
                    onTap: () async {
                      if (ride.isActive) {
                        await Navigator.push(
                          context,
                          buildAppRoute(RideModeScreen(rideId: ride.id)),
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
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: PremiumCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _buildRidePreviewTile(ride: ride),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$destination - ${ride.participantCount} riders',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
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
                                    style: AppTypography.labelSmall.copyWith(
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
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isBusy)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              else if (canDelete)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: AppColors.textTertiary,
                                    size: 18,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _confirmPermanentDeleteRide(ride);
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
        bg: AppColors.success.withValues(alpha: 0.14),
        fg: AppColors.success,
      );
    }
    if (normalized == 'scheduled') {
      return (
        bg: AppColors.warning.withValues(alpha: 0.16),
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
      bg: AppColors.primary.withValues(alpha: 0.12),
      fg: AppColors.primary,
    );
  }

  Future<void> _confirmPermanentDeleteRide(RideRecord ride) async {
    if (!ride.isScheduled && !ride.isCompleted) {
      showPremiumToast(
        context,
        'Only scheduled/completed rides can be deleted.',
        type: PremiumToastType.error,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Ride?', style: AppTypography.headlineSmall),
            content: const Text(
              'This will permanently delete this ride for everyone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: AppTypography.buttonMedium),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
    );
  }

  Future<void> _runRideAction({
    required String rideId,
    required Future<void> Function() action,
    required String successMessage,
    required String failureMessage,
  }) async {
    if (rideActionLoadingId.isNotEmpty) return;
    setState(() => rideActionLoadingId = rideId);
    try {
      await action();
      if (!mounted) return;
      showPremiumToast(context, successMessage, type: PremiumToastType.success);
      await _loadHomeData();
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        '$failureMessage ${_rideActionError(error)}',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => rideActionLoadingId = '');
    }
  }

  String _rideActionError(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      if (code == '42501') return 'RLS policy is blocking this action.';
      if (code == 'PGRST204' || code == '42703') {
        return 'Missing required table column in Supabase schema.';
      }
    }
    final text = error.toString();
    return text.length > 120 ? text.substring(0, 120) : text;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day}';
  }

  Widget _buildRidePreviewTile({required RideRecord ride}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF3E8),
            AppColors.primary.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: CustomPaint(
                painter: _RidePreviewPainter(
                  lineColor: AppColors.forest.withValues(alpha: 0.5),
                  accentColor: AppColors.primary,
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 10,
            child: _mapPin(AppColors.primary.withValues(alpha: 0.9)),
          ),
          Positioned(
            right: 8,
            bottom: 10,
            child: _mapPin(AppColors.forest.withValues(alpha: 0.9)),
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

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
          _navItem(icon: Icons.home_rounded, label: 'Home', active: true),
          _navItem(
            icon: Icons.explore_outlined,
            label: 'Explore',
            active: false,
            onTap: () {
              Navigator.push(context, buildAppRoute(const ExploreScreen()));
            },
          ),
          const SizedBox(width: 46),
          _navItem(
            icon: Icons.two_wheeler_rounded,
            label: 'My Rides',
            active: false,
            onTap: () {
              Navigator.push(context, buildAppRoute(const MyRidesScreen()));
            },
          ),
          _navItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            active: false,
            onTap: () {
              Navigator.push(context, buildAppRoute(const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? AppColors.primary : AppColors.textTertiary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterRideButton() {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      elevation: 8,
      onPressed: _showCreateRideSheet,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
    );
  }

  Future<void> _showCreateRideSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Ride',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _createOption(
                  context,
                  value: 'instant',
                  icon: Icons.flash_on_rounded,
                  title: 'Instant Ride',
                  subtitle: 'Start a solo live ride with one tap setup.',
                ),
                _createOption(
                  context,
                  value: 'scheduled',
                  icon: Icons.event_rounded,
                  title: 'Plan Group Ride',
                  subtitle: 'Plan route details before going live.',
                ),
                _createOption(
                  context,
                  value: 'private',
                  icon: Icons.lock_outline_rounded,
                  title: 'Private Ride',
                  subtitle: 'Create a smaller invite-only ride.',
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final screen = switch (selected) {
      'instant' => const CreateRideScreen(
        initialRideName: 'Instant solo ride',
        initialMaxRiders: 1,
      ),
      'private' => const CreateRideScreen(
        initialRideName: 'Private ride',
        initialMaxRiders: 6,
      ),
      _ => const CreateRideScreen(),
    };
    await Navigator.push(context, buildAppRoute(screen));
    await _loadHomeData();
  }

  Widget _createOption(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
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
