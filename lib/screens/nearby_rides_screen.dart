import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coordinators/realtime_coordinator.dart';
import '../models/ride_record.dart';
import '../services/app_navigation.dart';
import '../widgets/app_toast.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/haptic_button.dart';
import '../services/ride_service.dart';
import '../widgets/ride_loading_indicator.dart';
import 'dart:ui' show ImageFilter;
import '../theme/app_theme.dart';
import '../services/weather_service.dart';
import 'ride_lobby_screen.dart';
import 'ride_mode_screen.dart';

class NearbyRidesScreen extends StatefulWidget {
  const NearbyRidesScreen({super.key});

  @override
  State<NearbyRidesScreen> createState() => _NearbyRidesScreenState();
}

class _NearbyRidesScreenState extends State<NearbyRidesScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _emptyStateDelay = Duration(seconds: 12);

  /// Design diameter of the radar. The rendered diameter shrinks on narrow
  /// screens; every other radar dimension is derived from it by [_RadarLayout].
  static const double _radarDiameter = 300;

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

  /// Rides this rider has asked to join and that are awaiting host approval.
  /// Tracked locally so the sheet/blip reflect the request immediately instead
  /// of waiting for the next radar refresh.
  final Set<String> _pendingRideIds = <String>{};
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

      var userName = (prefs.getString('userName') ?? '').trim();
      var userAvatarUrl = (prefs.getString('userAvatarUrl') ?? '').trim();

      // The cached session predates avatar caching on some installs, so pull the
      // profile straight from Supabase rather than falling back to an initial.
      if (userAvatarUrl.isEmpty || userName.isEmpty) {
        final profile = await _rideService.fetchProfileSummary(userId);
        if (profile != null) {
          if (userAvatarUrl.isEmpty && profile.avatarUrl.isNotEmpty) {
            userAvatarUrl = profile.avatarUrl;
            await prefs.setString('userAvatarUrl', userAvatarUrl);
          }
          if (userName.isEmpty && profile.name.isNotEmpty) {
            userName = profile.name;
            await prefs.setString('userName', userName);
          }
        }
      }

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

  /// Opens the host's own ride from its radar blip: the live map if it is
  /// already running, otherwise the lobby.
  Future<void> _openOwnRide(NearbyRide ride) async {
    final rideId = ride.ride.id.trim();
    if (rideId.isEmpty) return;
    await pushAppRoute<void>(
      context,
      ride.ride.isActive
          ? RideModeScreen(rideId: rideId)
          : RideLobbyScreen(rideId: rideId),
    );
    if (!mounted) return;
    // Membership or status may have changed while the host was in there.
    await _loadNearbyRides();
  }

  Future<void> _joinRide(NearbyRide ride) async {
    if (joiningRideId.isNotEmpty) return;
    if (ride.joined) return;

    final rideId = ride.ride.id.trim();
    if (rideId.isEmpty) {
      showAppToast(
        context,
        'This ride is no longer available.',
        type: AppToastType.error,
      );
      return;
    }

    // The radar can be tapped before the session finished loading, so make sure
    // we have an id rather than sending an empty one to Supabase.
    final userId = await _resolveCurrentUserId();
    if (!mounted) return;
    if (userId.isEmpty) {
      showAppToast(
        context,
        'Missing user session. Please login again.',
        type: AppToastType.error,
      );
      return;
    }

    setState(() {
      joiningRideId = rideId;
      currentUserId = userId;
    });

    try {
      final status = await _rideService.requestJoinRide(
        rideId: rideId,
        userId: userId,
      );

      if (!mounted) return;

      final message = switch (status) {
        JoinByCodeStatus.requested =>
          'Join request sent. The host will approve it shortly.',
        JoinByCodeStatus.joinedDirectly => 'Joined successfully.',
        JoinByCodeStatus.alreadyRequested =>
          'Your join request is already waiting for host approval.',
        JoinByCodeStatus.alreadyJoined => 'You are already part of this ride.',
      };

      final joinedNow =
          status == JoinByCodeStatus.joinedDirectly ||
          status == JoinByCodeStatus.alreadyJoined;

      setState(() {
        if (joinedNow) {
          _pendingRideIds.remove(rideId);
          nearbyRides =
              nearbyRides.map((existing) {
                if (existing.ride.id != rideId) return existing;
                return existing.copyWith(
                  joined: true,
                  ride: existing.ride.copyWith(
                    participantCount:
                        status == JoinByCodeStatus.joinedDirectly
                            ? existing.ride.participantCount + 1
                            : existing.ride.participantCount,
                  ),
                );
              }).toList();
        } else {
          _pendingRideIds.add(rideId);
        }
      });

      showAppToast(context, message, type: AppToastType.success);
      if (joinedNow) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        await pushAppRoute<void>(
          context,
          ride.ride.isActive
              ? RideModeScreen(rideId: rideId)
              : RideLobbyScreen(rideId: rideId),
        );
        if (mounted) await _loadNearbyRides();
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, _joinErrorMessage(error), type: AppToastType.error);
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
                      fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
    if (!mounted) return;
    if (userId.isEmpty) {
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
      final joinedNow =
          result.status == JoinByCodeStatus.joinedDirectly ||
          result.status == JoinByCodeStatus.alreadyJoined;
      if (joinedNow) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        final status = result.rideStatus.trim().toLowerCase();
        await pushAppRoute<void>(
          context,
          status == 'active' || status == 'started' || status == 'live'
              ? RideModeScreen(rideId: result.rideId)
              : RideLobbyScreen(rideId: result.rideId),
        );
      }
      await _loadNearbyRides();
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, _joinErrorMessage(error), type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          joiningByCode = false;
        });
      }
    }
  }

  String _joinErrorMessage(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    // Only report a specific cause when we can actually identify one - the old
    // catch-all matched every Postgrest error and hid real problems behind
    // "try again after sync", which is not something a rider can act on.
    if (lower.contains('login again') || lower.contains('user session')) {
      return 'Missing user session. Please login again.';
    }
    if (lower.contains('own ride')) {
      return 'This is your own ride.';
    }
    // Messages RideService raises deliberately for a rider to read. They are
    // already phrased for the toast, so pass them through instead of flattening
    // them into the generic fallback below.
    if (lower.contains('no ride found for code') ||
        lower.contains('already finished') ||
        lower.contains('valid code like')) {
      return _stripExceptionPrefix(text);
    }
    if (lower.contains('no longer available') || lower.contains('not found')) {
      return 'This ride is no longer available.';
    }
    if (lower.contains('42501') ||
        lower.contains('row-level security') ||
        lower.contains('permission denied')) {
      return 'You do not have permission to join this ride.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeout') ||
        lower.contains('clientexception') ||
        lower.contains('connection')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Could not join this ride. Please try again.';
  }

  /// `Exception('...').toString()` prefixes the message with "Exception: ".
  String _stripExceptionPrefix(String text) {
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
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
        const SizedBox(height: 8),
        _radarStatusChip(primary, forest),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            '${nearbyRides.length} nearby ride${nearbyRides.length == 1 ? '' : 's'} found on radar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: forest,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _screenHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: JourneyHeader(
        surface: true,
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
                  fontWeight: FontWeight.w700,
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
            width: _radarDiameter,
            height: _radarDiameter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rawSize = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                // An unbounded parent would make this infinite, and every
                // dimension in _RadarLayout scales off it - one non-finite value
                // here is enough to fling blips off the rings. Fall back to the
                // design diameter instead.
                final size =
                    (rawSize.isFinite && rawSize > 0)
                        ? rawSize
                        : _radarDiameter;
                final layout = _RadarLayout(size);
                final nodes = _buildRadarNodes(rides, layout);
                final centre = size / 2;
                // The Stack must be exactly square: a narrow screen makes the
                // available box shorter than it is tall, and a non-square Stack
                // would centre the painted circle somewhere other than
                // (centre, centre), pushing every blip off the rings.
                return Center(
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, _) {
                            final sweepAngle =
                                _radarController.value * 2 * math.pi;
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
                          Positioned(
                            left: centre + node.dx - layout.blipWidth / 2,
                            top: centre + node.dy - layout.blipHeight / 2,
                            width: layout.blipWidth,
                            height: layout.blipHeight,
                            child: _RadarRideMarker(
                              ride: node.ride,
                              layout: layout,
                              visible: rides.isNotEmpty,
                              pending: _pendingRideIds.contains(
                                node.ride.ride.id,
                              ),
                              onTap: () => _showRidePreview(node.ride),
                            ),
                          ),
                        _RadarCenterMarker(
                          avatarUrl: currentUserAvatarUrl,
                          label: currentUserName,
                          layout: layout,
                        ),
                      ],
                    ),
                  ),
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
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a rider on the radar to view ride details.',
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Places each nearby ride on the radar as a polar offset from the centre.
  ///
  /// The radial distance is bounded on both sides by [_RadarLayout] so the whole
  /// marker - photo and name - always renders inside the outer radar ring and
  /// never lands on the centre "You" marker.
  ///
  /// Every offset is finally clamped to [_RadarLayout.maxBlipDistance]. That
  /// clamp is the actual containment guarantee: it holds whatever the ring and
  /// clearance arithmetic above it produces, including when a degenerate layout
  /// makes an intermediate value non-finite. A blip that lands outside the rings
  /// - as one did, over the weather card - is the single worst failure this
  /// widget can have, so it is worth proving rather than deriving.
  List<_RadarNode> _buildRadarNodes(
    List<NearbyRide> rides,
    _RadarLayout layout,
  ) {
    if (rides.isEmpty) return const <_RadarNode>[];

    const goldenAngle = 2.399963229728653;
    const ringFactors = <double>[0.0, 0.52, 1.0];
    final maxDistance = layout.maxBlipDistance;
    final minGap = layout.blipWidth * 0.9;

    Offset positionFor(double angle, double ring) {
      final sine = math.sin(angle);
      final minDistance = layout.minBlipDistance(sine);
      var distance = minDistance + (maxDistance - minDistance) * ring;
      // Guards the whole chain at once: a non-finite or over-long distance
      // becomes the largest radius that still fits the marker inside the rings.
      if (!distance.isFinite || distance > maxDistance) distance = maxDistance;
      if (distance < 0) distance = 0;
      return Offset(math.cos(angle) * distance, sine * distance);
    }

    final placed = <Offset>[];
    final nodes = <_RadarNode>[];
    for (final ride in rides) {
      // Derived from the ride id so a blip keeps its spot across refreshes.
      final hash = ride.ride.id.hashCode.abs();
      var angle = ((hash % 997) / 997) * 2 * math.pi;
      final ringSeed = (hash ~/ 997) % ringFactors.length;

      // Two ride ids can hash to the same spot, and a narrow radar squeezes the
      // usable band - walk the golden angle across all three rings and take the
      // first slot that clears the blips already placed, or the roomiest one.
      var bestOffset = positionFor(angle, ringFactors[ringSeed]);
      var bestClearance = double.negativeInfinity;
      for (var attempt = 0; attempt < 36; attempt++) {
        final ring =
            ringFactors[(ringSeed + attempt ~/ 12) % ringFactors.length];
        final candidate = positionFor(angle, ring);
        final clearance =
            placed.isEmpty
                ? double.infinity
                : placed
                    .map((other) => (other - candidate).distance)
                    .reduce(math.min);
        if (clearance > bestClearance) {
          bestClearance = clearance;
          bestOffset = candidate;
        }
        if (clearance >= minGap) break;
        angle = (angle + goldenAngle) % (2 * math.pi);
      }

      placed.add(bestOffset);
      nodes.add(_RadarNode(ride: ride, dx: bestOffset.dx, dy: bestOffset.dy));
    }
    return nodes;
  }

  String _estimateDuration(double? distanceKm) {
    if (distanceKm == null) return "--";
    final mins = (distanceKm / 50.0 * 60).round();
    if (mins < 5) return "5m";
    if (mins < 60) return "${mins}m";
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? "${h}h" : "${h}h ${m}m";
  }

  Future<void> _showRidePreview(NearbyRide ride) async {
    // Resolve against the live list so a blip tapped right after a join/refresh
    // reflects current membership instead of the captured value.
    final current = nearbyRides.firstWhere(
      (candidate) => candidate.ride.id == ride.ride.id,
      orElse: () => ride,
    );
    final joining = joiningRideId == current.ride.id;
    final pending = _pendingRideIds.contains(current.ride.id);
    final isLive = current.ride.isActive;
    final badgeLabel = isLive ? 'LIVE' : 'SCHEDULED';
    final badgeColor = isLive ? AppColors.success : AppColors.primary;

    final String buttonLabel;
    if (current.isOwnRide) {
      // A host tapping their own blip wants the ride, not a join request. Their
      // ride is on the radar as confirmation it is broadcasting, so the action
      // has to go somewhere useful rather than sitting disabled on "Joined".
      buttonLabel = isLive ? 'Open live ride' : 'Open ride lobby';
    } else if (current.joined) {
      buttonLabel = isLive ? 'Open live ride' : 'Open ride lobby';
    } else if (pending) {
      buttonLabel = 'Request sent';
    } else {
      buttonLabel = 'Join Ride';
    }
    final buttonLocked = !current.isOwnRide && pending;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _RadarAvatar(
                          avatarUrl: current.hostAvatarUrl,
                          label: current.hostName,
                          radius: 24,
                          borderColor: AppColors.primary.withValues(
                            alpha: 0.32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.ride.title.trim().isEmpty
                                    ? 'Nearby ride'
                                    : current.ride.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Hosted by ${current.hostName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeLabel,
                            style: AppTypography.labelSmall.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _previewRow(
                      Icons.navigation_rounded,
                      'Destination',
                      current.ride.endLocation.trim().isEmpty
                          ? 'Destination pending'
                          : current.ride.endLocation,
                    ),
                    _previewRow(
                      Icons.people_alt_rounded,
                      'Riders',
                      '${current.ride.participantCount}',
                    ),
                    _previewRow(
                      Icons.two_wheeler_rounded,
                      'Bike',
                      current.hostBike.trim().isEmpty
                          ? 'Not added'
                          : current.hostBike,
                    ),
                    const SizedBox(height: 18),
                    HapticButton(
                      label: buttonLabel,
                      icon:
                          current.isOwnRide
                              ? Icons.arrow_forward_rounded
                              : current.joined
                              ? Icons.arrow_forward_rounded
                              : pending
                              ? Icons.hourglass_top_rounded
                              : Icons.add_rounded,
                      loading: joining,
                      disabled: buttonLocked,
                      variant:
                          buttonLocked
                              ? HapticButtonVariant.outline
                              : HapticButtonVariant.primary,
                      onPressed:
                          buttonLocked
                              ? null
                              : () async {
                                Navigator.pop(sheetContext);
                                if (current.isOwnRide) {
                                  await _openOwnRide(current);
                                  return;
                                }
                                if (current.joined) {
                                  await pushAppRoute<void>(
                                    context,
                                    isLive
                                        ? RideModeScreen(
                                          rideId: current.ride.id,
                                        )
                                        : RideLobbyScreen(
                                          rideId: current.ride.id,
                                        ),
                                  );
                                  if (mounted) await _loadNearbyRides();
                                  return;
                                }
                                await _joinRide(current);
                              },
                    ),
                    if (pending && !current.joined) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Waiting for the host to approve your request.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
                        fontWeight: FontWeight.w700,
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
  const _RadarNode({required this.ride, required this.dx, required this.dy});

  final NearbyRide ride;

  /// Offset in logical pixels from the centre of the radar.
  final double dx;
  final double dy;
}

/// Every radar dimension derives from the rendered diameter, so the layout stays
/// geometrically similar at any size. That similarity is what carries the
/// containment guarantees - no marker outside the outer ring, no marker on top of
/// the centre avatar - from the 300px design width down to the narrowest phone.
class _RadarLayout {
  _RadarLayout(this.size)
    : scale = size / _NearbyRidesScreenState._radarDiameter;

  final double size;
  final double scale;

  double get radius => size / 2;

  // A blip is a profile photo above a single-line name.
  double get blipAvatarRadius => 17 * scale;
  double get blipBorderWidth => 2 * scale;
  double get blipGap => 4 * scale;
  double get blipLabelHeight => 14 * scale;
  double get blipLabelFontSize => 11 * scale;
  double get blipWidth => 62 * scale;
  double get blipHeight =>
      (blipAvatarRadius + blipBorderWidth) * 2 + blipGap + blipLabelHeight;

  /// Bounding-circle radius of the blip box, measured from its centre.
  double get blipReach {
    final halfWidth = blipWidth / 2;
    final halfHeight = blipHeight / 2;
    return math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
  }

  // The centre "You" marker.
  double get centreBox => 112 * scale;
  double get centreRingTop => 19 * scale;
  double get centreRingBox => 74 * scale;
  double get centreRingPadding => 4 * scale;
  double get centreAvatarRadius => 31 * scale;
  double get centreLabelTop => 95 * scale;
  double get centreLabelInset => 14 * scale;
  double get centreLabelFontSize => 13 * scale;

  /// How far the centre marker reaches from the radar centre: its avatar ring in
  /// every direction, and further downward where its name label sits.
  double get centreAvatarReach => 37 * scale;
  double get centreLabelReach => 55 * scale;

  /// Furthest a blip centre may sit from the radar centre while its whole box
  /// stays inside the outer ring.
  double get maxBlipDistance => math.max(0.0, radius - blipReach - 3 * scale);

  /// Nearest a blip centre may sit to the radar centre without touching the
  /// centre marker. [sine] is sin(angle); screen y grows downward, so a positive
  /// value points at the centre marker's name label and needs more room.
  double minBlipDistance(double sine) {
    final clearance =
        centreAvatarReach +
        (sine > 0 ? (centreLabelReach - centreAvatarReach) * sine : 0.0);
    return math.min(maxBlipDistance, clearance + blipReach + 5 * scale);
  }
}

class _RadarRideMarker extends StatelessWidget {
  const _RadarRideMarker({
    required this.ride,
    required this.layout,
    required this.visible,
    required this.pending,
    required this.onTap,
  });

  final NearbyRide ride;
  final _RadarLayout layout;
  final bool visible;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Own rides get the app's forest tone so the host can pick their own ride
    // out at a glance without reading the label.
    final ringColor =
        ride.isOwnRide
            ? AppColors.forest
            : ride.joined
            ? const Color(0xFF2E9E5B)
            : pending
            ? const Color(0xFFF2A93B)
            : const Color(0xFFFF8A1C);

    // A host already knows their own name; the ride's name is the useful label
    // on their own blip, and it is what confirms the ride is broadcasting.
    final rideTitle = ride.ride.title.trim();
    final label =
        ride.isOwnRide
            ? (rideTitle.isEmpty ? 'Your ride' : rideTitle)
            : (ride.hostName.trim().isEmpty ? 'Rider' : ride.hostName.trim());

    // The parent Positioned already fixes this marker's box, so the layout only
    // has to fill it - no fractional translation, which is what used to push
    // markers half a radar-width off target.
    return GestureDetector(
      onTap: visible ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 320),
        scale: visible ? 1 : 0.7,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 320),
          opacity: visible ? 1 : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RadarAvatar(
                avatarUrl: ride.hostAvatarUrl,
                label: ride.hostName,
                radius: layout.blipAvatarRadius,
                borderWidth: layout.blipBorderWidth,
                borderColor: ringColor,
              ),
              SizedBox(height: layout.blipGap),
              SizedBox(
                height: layout.blipLabelHeight,
                width: layout.blipWidth,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  // The radar is a fixed-geometry diagram whose containment is
                  // guaranteed by _RadarLayout, so the label must not grow with
                  // the system font scale and push glyphs past the outer ring.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: const Color(0xFF14342B),
                    fontSize: layout.blipLabelFontSize,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Color(0xCCFFFFFF), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarCenterMarker extends StatelessWidget {
  const _RadarCenterMarker({
    required this.avatarUrl,
    required this.label,
    required this.layout,
  });

  final String avatarUrl;
  final String label;
  final _RadarLayout layout;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    // Keep it short so the centre label never widens past the inner ring.
    final firstName =
        trimmed.isEmpty ? 'You' : trimmed.split(RegExp(r'\s+')).first;

    return SizedBox(
      width: layout.centreBox,
      height: layout.centreBox,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: layout.centreRingTop,
            child: Container(
              width: layout.centreRingBox,
              height: layout.centreRingBox,
              padding: EdgeInsets.all(layout.centreRingPadding),
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
                label: firstName,
                radius: layout.centreAvatarRadius,
                borderWidth: layout.blipBorderWidth,
                borderColor: const Color(0xFFF7B267),
              ),
            ),
          ),
          Positioned(
            top: layout.centreLabelTop,
            left: layout.centreLabelInset,
            right: layout.centreLabelInset,
            child: Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: const Color(0xFF14342B),
                fontSize: layout.centreLabelFontSize,
                height: 1.2,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(color: Color(0xCCFFFFFF), blurRadius: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular profile photo that degrades gracefully: it shows the rider's
/// initial while the image loads and keeps showing it if the download fails,
/// so a broken avatar URL never leaves an empty white disc on the radar.
class _RadarAvatar extends StatelessWidget {
  const _RadarAvatar({
    required this.avatarUrl,
    required this.label,
    required this.radius,
    required this.borderColor,
    this.borderWidth = 2,
  });

  final String avatarUrl;
  final String label;
  final double radius;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final clean = avatarUrl.trim();
    final trimmedLabel = label.trim();
    final initial =
        trimmedLabel.isEmpty ? 'R' : trimmedLabel.substring(0, 1).toUpperCase();
    final diameter = radius * 2;

    final fallback = Container(
      width: diameter,
      height: diameter,
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        strutStyle: StrutStyle(
          fontSize: radius * 0.75,
          height: 1,
          forceStrutHeight: true,
        ),
        style: TextStyle(
          color: const Color(0xFF8A3B08),
          fontSize: radius * 0.75,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: diameter + borderWidth * 2,
      height: diameter + borderWidth * 2,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child:
            clean.isEmpty
                ? fallback
                : Image.network(
                  clean,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => fallback,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return fallback;
                  },
                ),
      ),
    );
  }
}
