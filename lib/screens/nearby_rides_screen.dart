import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/realtime_coordinator.dart';
import '../models/ride_record.dart';
import '../widgets/app_toast.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/haptic_button.dart';
import '../services/ride_service.dart';
import '../widgets/ride_loading_indicator.dart';
import 'dart:ui' show ImageFilter;
import '../theme/app_theme.dart';
import '../services/weather_service.dart';

class NearbyRidesScreen extends StatefulWidget {
  const NearbyRidesScreen({super.key});

  @override
  State<NearbyRidesScreen> createState() => _NearbyRidesScreenState();
}

class _NearbyRidesScreenState extends State<NearbyRidesScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _emptyStateDelay = Duration(seconds: 12);

  final RideService _rideService = RideService();
  final RealtimeCoordinator _realtimeCoordinator = RealtimeCoordinator.instance;
  final WeatherService _weatherService = WeatherService();
  late final AnimationController _radarController;

  Timer? _emptyStateTimer;
  DateTime? _scanStartedAt;

  bool searching = true;
  bool joiningByCode = false;
  bool _showNoRidesFallback = false;
  String errorText = '';
  String currentUserId = '';
  String currentUserName = 'You';
  String currentUserAvatarUrl = '';
  String joiningRideId = '';
  List<NearbyRide> nearbyRides = <NearbyRide>[];
  WeatherSnapshot? _weatherSnapshot;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _realtimeCoordinator.addListener(_onRadarChanged);
    _loadNearbyRides();
    _loadWeather();
  }

  @override
  void dispose() {
    _emptyStateTimer?.cancel();
    _realtimeCoordinator.removeListener(_onRadarChanged);
    _realtimeCoordinator.stopRideRadar();
    _radarController.dispose();
    super.dispose();
  }

  void _onRadarChanged() {
    if (!mounted) return;
    final rides =
        _realtimeCoordinator.radarRides.map((ride) => ride.nearbyRide).toList();
    setState(() {
      nearbyRides = rides;
      searching = _realtimeCoordinator.radarLoading && rides.isEmpty;
      errorText = '';
      if (rides.isNotEmpty) {
        _showNoRidesFallback = false;
      }
    });
    if (rides.isEmpty &&
        !_realtimeCoordinator.radarLoading &&
        _realtimeCoordinator.radarError.isEmpty) {
      _startEmptyStateCountdown();
    }
  }

  Future<void> _loadNearbyRides() async {
    _emptyStateTimer?.cancel();
    _scanStartedAt = DateTime.now();
    if (!mounted) return;
    setState(() {
      searching = true;
      _showNoRidesFallback = false;
      errorText = '';
      joiningRideId = '';
      nearbyRides = <NearbyRide>[];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString('userId') ?? '').trim();
      if (userId.isEmpty) {
        throw Exception('Missing user session. Please login again.');
      }

      final userName = (prefs.getString('userName') ?? 'You').trim();
      final userAvatarUrl = (prefs.getString('userAvatarUrl') ?? '').trim();

      await _realtimeCoordinator.startRideRadar(
        profileId: userId,
        radiusKm: 25,
        requestPermissionIfNeeded: true,
      );
      final rides =
          _realtimeCoordinator.radarRides
              .map((ride) => ride.nearbyRide)
              .toList();
      if (!mounted) return;

      if (rides.isNotEmpty) {
        setState(() {
          currentUserId = userId;
          currentUserName = userName.isNotEmpty ? userName : 'You';
          currentUserAvatarUrl = userAvatarUrl;
          nearbyRides = rides;
          searching = false;
          _showNoRidesFallback = false;
        });
        return;
      }

      setState(() {
        currentUserId = userId;
        currentUserName = userName.isNotEmpty ? userName : 'You';
        currentUserAvatarUrl = userAvatarUrl;
        nearbyRides = <NearbyRide>[];
      });
      _startEmptyStateCountdown();
    } catch (error) {
      _emptyStateTimer?.cancel();
      if (!mounted) return;
      setState(() {
        errorText = _nearbyRidesFallbackMessage(error);
        searching = false;
        _showNoRidesFallback = false;
      });
    }
  }

  void _startEmptyStateCountdown() {
    final startedAt = _scanStartedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startedAt);
    final remaining =
        elapsed >= _emptyStateDelay
            ? Duration.zero
            : _emptyStateDelay - elapsed;

    _emptyStateTimer?.cancel();
    _emptyStateTimer = Timer(remaining, () {
      if (!mounted || nearbyRides.isNotEmpty || errorText.isNotEmpty) return;
      setState(() {
        searching = false;
        _showNoRidesFallback = true;
      });
    });
  }

  String _nearbyRidesFallbackMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('pgrst204') ||
        lower.contains('42703') ||
        (lower.contains('column rides.') && lower.contains('does not exist'))) {
      return 'Nearby rides are not available right now. Please try again in a moment.';
    }
    if (lower.contains('timeout') || lower.contains('socket')) {
      return 'Network issue while loading nearby rides. Please try again.';
    }
    if (lower.contains('permission') || lower.contains('location')) {
      return 'Location is required to find nearby rides. Enable location and try again.';
    }
    return 'Could not search nearby rides right now. Please try again.';
  }

  Future<void> _joinRide(NearbyRide ride) async {
    if (joiningRideId.isNotEmpty) return;
    if (ride.joined) return;

    setState(() {
      joiningRideId = ride.ride.id;
    });

    try {
      final status = await _rideService.requestJoinRide(
        rideId: ride.ride.id,
        userId: currentUserId,
      );

      if (!mounted) return;

      final message = switch (status) {
        JoinByCodeStatus.requested => 'Join request sent.',
        JoinByCodeStatus.joinedDirectly => 'Joined successfully.',
        JoinByCodeStatus.alreadyRequested => 'You already requested to join.',
        JoinByCodeStatus.alreadyJoined => 'You are already part of this ride.',
      };

      if (status == JoinByCodeStatus.joinedDirectly) {
        setState(() {
          nearbyRides =
              nearbyRides.map((existing) {
                if (existing.ride.id != ride.ride.id) return existing;
                return existing.copyWith(
                  joined: true,
                  ride: RideRecord(
                    id: existing.ride.id,
                    creatorId: existing.ride.creatorId,
                    title: existing.ride.title,
                    startLocation: existing.ride.startLocation,
                    endLocation: existing.ride.endLocation,
                    createdAt: existing.ride.createdAt,
                    participantCount: existing.ride.participantCount + 1,
                  ),
                );
              }).toList();
        });
      }

      showAppToast(context, message, type: AppToastType.success);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not join ride: $error',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          joiningRideId = '';
        });
      }
    }
  }

  Future<String> _resolveCurrentUserId() async {
    if (currentUserId.trim().isNotEmpty) {
      return currentUserId.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('userId') ?? '').trim();
  }

  Future<void> _showJoinByCodeDialog() async {
    final controller = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join with access code',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the code shared by your ride host.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Access code',
                      hintText: 'JS-0370',
                      prefixIcon: const Icon(Icons.key_rounded),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted:
                        (value) => Navigator.pop(context, value.trim()),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              () => Navigator.pop(
                                context,
                                controller.text.trim(),
                              ),
                          child: const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) {
      await _joinRideByCode(code.trim().toUpperCase());
    }
  }

  Future<void> _joinRideByCode(String rawCode) async {
    if (joiningByCode) return;
    final userId = await _resolveCurrentUserId();
    if (userId.isEmpty) {
      if (!mounted) return;
      showAppToast(
        context,
        'Missing user session. Please login again.',
        type: AppToastType.error,
      );
      return;
    }

    setState(() {
      joiningByCode = true;
      currentUserId = userId;
    });

    try {
      final result = await _rideService.joinRideByAccessCode(
        accessCode: rawCode,
        userId: userId,
      );
      if (!mounted) return;
      final message = switch (result.status) {
        JoinByCodeStatus.requested =>
          'Join request sent for "${result.rideTitle}".',
        JoinByCodeStatus.joinedDirectly =>
          'Joined "${result.rideTitle}" successfully.',
        JoinByCodeStatus.alreadyRequested =>
          'You already requested to join "${result.rideTitle}".',
        JoinByCodeStatus.alreadyJoined =>
          'You are already part of "${result.rideTitle}".',
      };
      showAppToast(context, message, type: AppToastType.success);
      await _loadNearbyRides();
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not join via code: $error',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          joiningByCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _content(AppColors.primary, AppColors.forest)),
    );
  }

  Widget _content(Color primary, Color forest) {
    final weatherWidget =
        _weatherSnapshot != null
            ? Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: GlassCard(
                onTap: _showWeatherDetailsBottomSheet,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: 16,
                opacity: 0.85,
                customColor: Colors.white,
                child: Row(
                  children: [
                    Icon(
                      _weatherIcon(_weatherSnapshot!.displayText),
                      color: primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _weatherSnapshot!.displayText,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: forest,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "WEATHER INTEL",
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  color: primary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (_weatherSnapshot!.alerts.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _weatherSnapshot!.alerts.first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 11,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              "Temp: ${_weatherSnapshot!.temperature.round()}°C  •  Rain: ${_weatherSnapshot!.rainChance}%  •  Wind: ${_weatherSnapshot!.windSpeed.round()} km/h",
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                color: forest.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: forest.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ],
                ),
              ),
            )
            : const SizedBox.shrink();

    if (searching || nearbyRides.isEmpty) {
      return Column(
        children: [
          _screenHeader(),
          weatherWidget,
          Expanded(
            child: _radarExperience(
              primary,
              forest,
              showFallback: _showNoRidesFallback,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _screenHeader(),
        weatherWidget,
        const SizedBox(height: 4),
        _radarSurface(primary, forest, nearbyRides),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text(
                '${nearbyRides.length} nearby ride${nearbyRides.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: forest,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _rideList(primary, forest)),
      ],
    );
  }

  Widget _screenHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: JourneyHeader(
        leading: const JourneyBackButton(),
        eyebrow: 'RIDE RADAR',
        title: 'Nearby Rides',
        subtitle: 'Discover public rides broadcasting near your location.',
        trailing: IconButton(
          onPressed: joiningByCode ? null : _showJoinByCodeDialog,
          tooltip: 'Join with access code',
          icon: const Icon(Icons.key_rounded, color: AppColors.forest),
        ),
      ),
    );
  }

  Widget _radarExperience(
    Color primary,
    Color forest, {
    required bool showFallback,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radarSurface(primary, forest, nearbyRides),
            const SizedBox(height: 18),
            _radarStatusChip(primary, forest),
            const SizedBox(height: 12),
            if (showFallback)
              Text(
                'No riders nearby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: forest,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              RideLoadingIndicator(
                label: 'Scanning for nearby rides...',
                compact: true,
                color: primary,
              ),
            if (showFallback) ...[
              const SizedBox(height: 8),
              Text(
                'Ask a host to create a ride and keep it live. Radar updates automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: forest.withValues(alpha: 0.68),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _radarSurface(Color primary, Color forest, List<NearbyRide> rides) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final nodes = _buildRadarNodes(rides);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, _) {
                        final sweepAngle = _radarController.value * 2 * math.pi;
                        return CustomPaint(
                          size: Size.square(size),
                          painter: _RadarPainter(
                            sweepAngle: sweepAngle,
                            primary: primary,
                          ),
                        );
                      },
                    ),
                    for (final node in nodes)
                      _RadarRideMarker(
                        ride: node.ride,
                        xFactor: node.xFactor,
                        yFactor: node.yFactor,
                        visible: rides.isNotEmpty,
                      ),
                    _RadarCenterMarker(avatarUrl: currentUserAvatarUrl),
                  ],
                );
              },
            ),
          ),
          if (rides.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nearby riders detected on radar',
              style: TextStyle(
                color: forest,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap Join Ride below to connect with one of them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: forest.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _radarStatusChip(Color primary, Color forest) {
    final connection = _realtimeCoordinator.connectionState;
    final message =
        _realtimeCoordinator.radarError.isNotEmpty
            ? _realtimeCoordinator.radarError
            : switch (connection) {
              RealtimeConnectionState.connected => 'Realtime radar active',
              RealtimeConnectionState.connecting => 'Connecting radar...',
              RealtimeConnectionState.syncing => 'Syncing radar...',
              RealtimeConnectionState.offline =>
                'Offline. Waiting for network.',
              RealtimeConnectionState.reconnecting =>
                'Reconnecting realtime radar...',
              RealtimeConnectionState.disconnected => 'Starting radar...',
            };
    final icon =
        connection == RealtimeConnectionState.connected
            ? Icons.radar_rounded
            : Icons.sync_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium.copyWith(
                color: forest,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_RadarNode> _buildRadarNodes(List<NearbyRide> rides) {
    if (rides.isEmpty) return const <_RadarNode>[];

    const ringFactors = <double>[0.28, 0.44, 0.6, 0.77];
    final nodes = <_RadarNode>[];
    for (int index = 0; index < rides.length; index++) {
      final ride = rides[index];
      final hash = ride.ride.id.hashCode.abs() + index * 53;
      final angle = ((hash % 360) / 180) * math.pi;
      final ring = ringFactors[hash % ringFactors.length];
      final x = 0.5 + math.cos(angle) * ring * 0.38;
      final y = 0.5 + math.sin(angle) * ring * 0.38;
      nodes.add(
        _RadarNode(
          ride: ride,
          xFactor: x.clamp(0.15, 0.85),
          yFactor: y.clamp(0.15, 0.85),
        ),
      );
    }
    return nodes;
  }

  String _estimateDuration(double? distanceKm) {
    if (distanceKm == null) return "35m";
    final mins = (distanceKm / 50.0 * 60).round();
    if (mins < 5) return "5m";
    if (mins < 60) return "${mins}m";
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? "${h}h" : "${h}h ${m}m";
  }

  Widget _rideList(Color primary, Color forest) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: nearbyRides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final ride = nearbyRides[index];
        final joining = joiningRideId == ride.ride.id;
        final distance = _distanceFor(ride.ride.id);
        final durationStr = _estimateDuration(distance);

        return GlassCard(
          padding: const EdgeInsets.all(18),
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ride.ride.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'LIVE',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Route: Start -> End
              Row(
                children: [
                  const Icon(
                    Icons.navigation_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ride.ride.startLocation} ➔ ${ride.ride.endLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Info grid (Distance, Members, Duration)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoChip(
                    Icons.location_on_outlined,
                    distance == null
                        ? '--'
                        : '${distance.toStringAsFixed(1)} km',
                    'Distance',
                  ),
                  _infoChip(
                    Icons.people_outline_rounded,
                    '${ride.ride.participantCount}',
                    'Riders',
                  ),
                  _infoChip(Icons.speed_outlined, durationStr, 'Est. Time'),
                ],
              ),
              const SizedBox(height: 16),
              // Divider
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),
              // Host and Bike details
              Row(
                children: [
                  _RadarAvatar(
                    avatarUrl: ride.hostAvatarUrl,
                    label: ride.hostName,
                    radius: 18,
                    borderColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.hostName,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ride.hostBike,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Join Button (Haptic)
              HapticButton(
                label: ride.joined ? 'Joined' : 'Join Ride',
                icon: ride.joined ? Icons.check_rounded : Icons.add_rounded,
                loading: joining,
                disabled: ride.joined,
                variant:
                    ride.joined
                        ? HapticButtonVariant.outline
                        : HapticButtonVariant.primary,
                onPressed: ride.joined ? null : () => _joinRide(ride),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  double? _distanceFor(String rideId) {
    for (final ride in _realtimeCoordinator.radarRides) {
      if (ride.nearbyRide.ride.id == rideId) return ride.distanceKm;
    }
    return null;
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;
    try {
      final weather = await _weatherService.fetchCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherSnapshot = weather;
        });
      }
    } catch (e) {
      debugPrint("Radar weather fetch failed: $e");
    }
  }

  void _showWeatherDetailsBottomSheet() {
    if (_weatherSnapshot == null) return;
    final w = _weatherSnapshot!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppShadows.lg,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WEATHER INTELLIGENCE",
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Current Conditions",
                                style: AppTypography.headlineMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _weatherIcon(w.displayText),
                            size: 36,
                            color: Colors.amber[700],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _weatherTelemetryItem(
                              icon: Icons.thermostat_rounded,
                              value: "${w.temperature.round()}°C",
                              label: "Temperature",
                              color: Colors.redAccent,
                            ),
                            _weatherTelemetryItem(
                              icon: Icons.umbrella_rounded,
                              value: "${w.rainChance}%",
                              label: "Rain Chance",
                              color: Colors.blueAccent,
                            ),
                            _weatherTelemetryItem(
                              icon: Icons.air_rounded,
                              value: "${w.windSpeed.round()} km/h",
                              label: "Wind Speed",
                              color: Colors.teal,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _weatherMiniCard(
                              icon: Icons.wb_twilight_rounded,
                              title: "Sunrise & Sunset",
                              subtitle: "Rise: ${w.sunrise}\nSet: ${w.sunset}",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _weatherMiniCard(
                              icon: Icons.visibility_rounded,
                              title: "Visibility",
                              subtitle: "${w.visibility.toStringAsFixed(1)} km",
                            ),
                          ),
                        ],
                      ),
                      if (w.alerts.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          "SAFETY ALERTS",
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.error,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...w.alerts.map(
                          (alert) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    alert,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _weatherTelemetryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _weatherMiniCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _weatherIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('rain') || lower.contains('shower')) {
      return Icons.umbrella_rounded;
    }
    if (lower.contains('snow') || lower.contains('ice')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('cloud') || lower.contains('overcast')) {
      return Icons.cloud_rounded;
    }
    if (lower.contains('storm') || lower.contains('thunder')) {
      return Icons.thunderstorm_rounded;
    }
    if (lower.contains('fog') || lower.contains('mist')) {
      return Icons.visibility_rounded;
    }
    return Icons.wb_sunny_rounded;
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.sweepAngle, required this.primary});

  final double sweepAngle;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint =
        Paint()
          ..color = primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint =
        Paint()
          ..color = primary.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }

    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: sweepAngle - 0.45,
            endAngle: sweepAngle,
            colors: [Colors.transparent, primary.withValues(alpha: 0.42)],
          ).createShader(sweepRect);
    canvas.drawArc(sweepRect, sweepAngle - 0.45, 0.45, true, sweepPaint);

    final pulsePaint =
        Paint()
          ..color = primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.16, pulsePaint);

    final dotPaint =
        Paint()
          ..color = primary
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.primary != primary;
  }
}

class _RadarNode {
  const _RadarNode({
    required this.ride,
    required this.xFactor,
    required this.yFactor,
  });

  final NearbyRide ride;
  final double xFactor;
  final double yFactor;
}

class _RadarRideMarker extends StatelessWidget {
  const _RadarRideMarker({
    required this.ride,
    required this.xFactor,
    required this.yFactor,
    required this.visible,
  });

  final NearbyRide ride;
  final double xFactor;
  final double yFactor;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: Align(
        alignment: Alignment(xFactor * 2 - 1, yFactor * 2 - 1),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 320),
          scale: visible ? 1 : 0.7,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 320),
            opacity: visible ? 1 : 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RadarAvatar(
                  avatarUrl: ride.hostAvatarUrl,
                  label: ride.hostName,
                  radius: 23,
                  borderColor: Colors.white,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: Text(
                    ride.hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarCenterMarker extends StatelessWidget {
  const _RadarCenterMarker({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 19,
            child: Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: _RadarAvatar(
                avatarUrl: avatarUrl,
                label: 'You',
                radius: 31,
                borderColor: const Color(0xFFF7B267),
              ),
            ),
          ),
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: Text(
              'You',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarAvatar extends StatelessWidget {
  const _RadarAvatar({
    required this.avatarUrl,
    required this.label,
    required this.radius,
    required this.borderColor,
  });

  final String avatarUrl;
  final String label;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final clean = avatarUrl.trim();
    final initial =
        label.trim().isEmpty ? 'R' : label.trim().substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: clean.isNotEmpty ? NetworkImage(clean) : null,
        onBackgroundImageError: (_, __) {},
        child:
            clean.isEmpty
                ? SizedBox.expand(
                  child: Center(
                    child: Text(
                      initial,
                      textAlign: TextAlign.center,
                      strutStyle: StrutStyle(
                        fontSize: radius * 0.75,
                        height: 1,
                        forceStrutHeight: true,
                      ),
                      style: TextStyle(
                        color: const Color(0xFF8A3B08),
                        fontSize: radius * 0.75,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
