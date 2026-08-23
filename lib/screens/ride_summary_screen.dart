import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports its own Path class (a list of LatLng), which shadows the
// dart:ui Path that CustomPainter draws with. Hiding it here is the same fix
// smooth_marker.dart already uses. Nothing in this file wants latlong2's Path.
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:ui' as ui;

import '../widgets/app_toast.dart';
import '../widgets/app_error_state.dart';
import '../widgets/journey_screen.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/ride_loading_indicator.dart';
import '../services/ride_analytics_engine.dart';
import '../theme/app_theme.dart';

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
  String loadError = '';
  String userName = 'Rider';
  String userBike = 'No bike added';
  String userId = '';
  List<_SummaryParticipant> participants = <_SummaryParticipant>[];
  RideAnalyticsSnapshot? analytics;

  /// Marks the share poster so it can be rasterised to a PNG. Only the subtree
  /// under this key is captured, so the dialog's buttons stay out of the image.
  final GlobalKey _posterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('userName') ?? 'Rider';
      userBike = prefs.getString('userBike') ?? 'No bike added';
      userId = prefs.getString('userId') ?? '';

      final data =
          await supabase
              .from('rides')
              .select()
              .eq('id', widget.rideId)
              .maybeSingle();

      if (data == null) {
        if (!mounted) return;
        setState(() {
          loadError = 'Ride details are not available.';
          loading = false;
        });
        return;
      }

      final fetchedParticipants = await _fetchParticipants(data);
      final fetchedAnalytics = await RideAnalyticsEngine.load(widget.rideId);
      if (!mounted) return;
      setState(() {
        ride = data;
        participants = fetchedParticipants;
        analytics = fetchedAnalytics;
        loadError = '';
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = 'Could not load ride summary.';
        loading = false;
      });
    }
  }

  String _rideName() {
    final name = (ride?['title'] ?? ride?['name'])?.toString().trim();
    return (name == null || name.isEmpty) ? 'Ride Completed' : name;
  }

  String _durationText() {
    final start = ride?['started_at']?.toString();
    final end = ride?['ended_at']?.toString();
    if (start == null || end == null) return '--';
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return '--';
    final diff = e.difference(s);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  String _metric(List<String> keys, String unit) {
    dynamic value;
    for (final key in keys) {
      value = ride?[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        break;
      }
    }
    if (value == null || value.toString().trim().isEmpty) return '--';
    return '$value $unit';
  }

  // ── Real ride stats ────────────────────────────────────────────────────────
  // Each of these prefers the analytics snapshot recorded during the ride. The
  // `rides` row carries distance_km / avg_speed_kmh / elevation_m columns that
  // the tracker never writes, so reading those first is what made the share
  // poster and the share text print "--" for a ride with a full GPS track.

  String _distanceText() {
    final data = analytics;
    if (data != null && data.distanceKm > 0) {
      return '${data.distanceKm.toStringAsFixed(1)} km';
    }
    return _metric(const ['distance_km', 'distance'], 'km');
  }

  String _avgSpeedText() {
    final data = analytics;
    if (data != null && data.averageSpeedKmh > 0) {
      return '${data.averageSpeedKmh.toStringAsFixed(1)} km/h';
    }
    return _metric(const ['avg_speed_kmh', 'avg_speed'], 'km/h');
  }

  String _topSpeedText() {
    final data = analytics;
    if (data != null && data.maxSpeedKmh > 0) {
      return '${data.maxSpeedKmh.toStringAsFixed(0)} km/h';
    }
    return _metric(const ['top_speed_kmh', 'top_speed'], 'km/h');
  }

  String _elevationText() {
    final data = analytics;
    if (data != null && data.elevationGainM > 0) {
      return '+${data.elevationGainM.toStringAsFixed(0)} m';
    }
    return _metric(const ['elevation_m', 'elevation'], 'm');
  }

  String _durationValue() {
    final data = analytics;
    if (data != null && data.durationSeconds > 0) {
      return RideAnalyticsEngine.durationText(data.durationSeconds);
    }
    return _durationText();
  }

  String _paceText() {
    final pace = analytics?.averagePaceMinPerKm ?? 0;
    if (pace <= 0 || pace.isNaN || pace.isInfinite) return '--';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    // 7.99 min/km must not render as "7:60".
    final carry = seconds == 60;
    return '${carry ? minutes + 1 : minutes}:'
        '${(carry ? 0 : seconds).toString().padLeft(2, '0')} /km';
  }

  /// Riders on this ride. Membership rows are the truth; the analytics member
  /// count is the fallback, and a solo ride still counts the rider themselves.
  int _riderCount() {
    if (participants.isNotEmpty) return participants.length;
    final counted = analytics?.memberCount ?? 0;
    return counted > 0 ? counted : 1;
  }

  /// Plain-language answer to "how did the ride go", assembled only from
  /// recorded numbers so it can never claim something the tracker did not
  /// actually measure.
  String _rideVerdict() {
    final data = analytics;
    if (data == null) {
      return 'This ride was logged, but no GPS track was recorded for it, so '
          'distance and speed are not available.';
    }

    final sentences = <String>[];
    final riders = _riderCount();
    sentences.add(
      riders <= 1
          ? 'You rode this one solo.'
          : 'You rode with ${riders - 1} other '
              '${riders == 2 ? 'rider' : 'riders'}.',
    );

    if (data.distanceKm > 0 && data.durationSeconds > 0) {
      sentences.add(
        'You covered ${data.distanceKm.toStringAsFixed(1)} km in '
        '${RideAnalyticsEngine.durationText(data.durationSeconds)}, averaging '
        '${data.averageSpeedKmh.toStringAsFixed(1)} km/h and topping out at '
        '${data.maxSpeedKmh.toStringAsFixed(0)} km/h.',
      );
    }

    if (data.durationSeconds > 0 && data.movingSeconds > 0) {
      final movingShare = (data.movingSeconds / data.durationSeconds * 100)
          .round()
          .clamp(0, 100);
      sentences.add(
        data.numberOfStops == 0
            ? 'You kept rolling for $movingShare% of the ride with no stops.'
            : 'You were moving $movingShare% of the ride across '
                '${data.numberOfStops} '
                '${data.numberOfStops == 1 ? 'stop' : 'stops'}.',
      );
    }

    if (data.elevationGainM >= 50) {
      sentences.add(
        'You climbed ${data.elevationGainM.toStringAsFixed(0)} m along the way.',
      );
    }

    if (data.sosEvents > 0) {
      sentences.add(
        '${data.sosEvents} SOS '
        '${data.sosEvents == 1 ? 'alert was' : 'alerts were'} raised during '
        'this ride.',
      );
    }

    return sentences.join(' ');
  }

  String _dateLabel() {
    final end =
        ride?['ended_at']?.toString() ?? ride?['created_at']?.toString();
    final e = end == null ? null : DateTime.tryParse(end);
    if (e == null) return '--';
    return '${_month(e.month)} ${e.day}';
  }

  String _month(int m) {
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
    return months[(m - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    // These were Color(0xFF0056B3) and Color(0xFF00C2CB) - a blue and a cyan
    // that appear nowhere else in JourneySync. The completion tick is now the
    // palette's green and the duration accent is forest, so the summary reads as
    // part of the app instead of as a stock template.
    const durationAccent = AppColors.forest;
    const completeGreen = AppColors.success;
    const background = AppColors.background;

    if (loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: RideLoadingIndicator(label: 'Building summary')),
      );
    }

    if (loadError.isNotEmpty) {
      return JourneyScreen(
        scrollable: false,
        child: AppErrorState(message: loadError, onRetry: _load),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: const JourneyHeader(
                surface: true,
                leading: JourneyBackButton(),
                eyebrow: 'RIDE COMPLETE',
                title: 'Ride Summary',
                subtitle: 'Distance, riders, route, and completion details.',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _header(completeGreen),
                    const SizedBox(height: 24),
                    _summaryCard(primary, durationAccent),
                    const SizedBox(height: 18),
                    _rideReportCard(),
                    if (analytics != null) ...[
                      const SizedBox(height: 18),
                      _scoreCard(primary),
                      const SizedBox(height: 18),
                      _insightsCard(),
                    ],
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
          ],
        ),
      ),
    );
  }

  Widget _header(Color accent) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ride Completed!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_rideName()} • ${_dateLabel()}',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(Color primary, Color durationAccent) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBlock(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: _durationValue(),
                  color: durationAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBlock(
                  icon: Icons.add_location_alt,
                  label: 'Distance',
                  value: _distanceText(),
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniMetric('Avg Speed', _avgSpeedText())),
              Expanded(child: _miniMetric('Top Speed', _topSpeedText())),
              Expanded(child: _miniMetric('Elevation', _elevationText())),
            ],
          ),
        ],
      ),
    );
  }

  /// Answers the two things the old summary could not: who was on the ride, and
  /// how it actually went. Every value here comes from the recorded snapshot.
  Widget _rideReportCard() {
    final data = analytics;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW THE RIDE WENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _rideVerdict(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
          if (data != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Colors.black12),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniMetric('Riders', '${_riderCount()}')),
                Expanded(child: _miniMetric('Joined', '${data.membersJoined}')),
                Expanded(child: _miniMetric('Left', '${data.membersLeft}')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _miniMetric('Avg Pace', _paceText())),
                Expanded(
                  child: _miniMetric(
                    'Stopped',
                    RideAnalyticsEngine.durationText(data.stoppedSeconds),
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    'Tracking',
                    '${data.trackingQualityScore}%',
                  ),
                ),
              ],
            ),
          ],
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
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _scoreCard(Color primary) {
    final data = analytics!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.12),
                  border: Border.all(color: primary.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    '${data.rideScore}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RideAnalyticsEngine.scoreLabelText(data.scoreLabel),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ride Health: ${RideAnalyticsEngine.healthLabelText(data.healthState)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'Moving',
                  RideAnalyticsEngine.durationText(data.movingSeconds),
                ),
              ),
              Expanded(child: _miniMetric('Stops', '${data.numberOfStops}')),
              Expanded(child: _miniMetric('Fuel', '${data.fuelStops}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniMetric('Weather', data.weatherSummary ?? '--'),
              ),
              Expanded(child: _miniMetric('Members', '${data.memberCount}')),
              Expanded(child: _miniMetric('SOS', '${data.sosEvents}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightsCard() {
    final data = analytics!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RIDE INSIGHTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          ...data.insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (data.achievements.isNotEmpty) ...[
            const Divider(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  data.achievements
                      .map(
                        (achievement) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            achievement,
                            style: const TextStyle(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeThumbnail() {
    final routePoints = analytics?.routePoints ?? [];
    final hasRoute = routePoints.length > 1;

    // Calculate map bounds
    LatLngBounds? bounds;
    List<LatLng> mapPoints = [];
    if (hasRoute) {
      mapPoints = routePoints.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
      bounds = LatLngBounds.fromPoints(mapPoints);
    }

    return Container(
      height: 150,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child:
                hasRoute
                    ? FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: bounds!,
                          padding: const EdgeInsets.all(20),
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.journeysync',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: mapPoints,
                              color: Colors.orange.shade700,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      ],
                    )
                    : Container(color: Colors.grey.shade300),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
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
                  style: const TextStyle(
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
    final dest =
        (ride?['end_location'] ?? ride?['destination'])?.toString().trim();
    return (dest == null || dest.isEmpty) ? 'Destination' : dest;
  }

  Widget _participants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'RODE WITH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${participants.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: const Text(
              'Participant data not available.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
        ...participants.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                _participantAvatar(item),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        item.bike,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isYou)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
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

  Widget _participantAvatar(_SummaryParticipant participant) {
    final avatar = participant.avatarUrl.trim();
    if (avatar.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatar),
        onBackgroundImageError: (_, __) {},
      );
    }

    final initial =
        participant.name.trim().isEmpty
            ? 'R'
            : participant.name.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.forest.withValues(alpha: 0.16),
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.forest,
        ),
      ),
    );
  }

  Future<List<_SummaryParticipant>> _fetchParticipants(
    Map<String, dynamic> rideRow,
  ) async {
    final fallback =
        <_SummaryParticipant>[
          _SummaryParticipant(
            id: userId.trim(),
            name: userName,
            bike: userBike,
            avatarUrl: '',
            isYou: true,
          ),
        ].where((p) => p.name.trim().isNotEmpty).toList();

    try {
      final rows = await supabase
          .from('ride_members')
          .select('member_id,status')
          .eq('ride_id', widget.rideId)
          .eq('status', 'approved');
      final userIds =
          List<Map<String, dynamic>>.from(rows)
              .map((row) => (row['member_id'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet();

      final creatorId =
          (rideRow['host_id'] ??
                  rideRow['profile_id'] ??
                  rideRow['creator_id'] ??
                  rideRow['user_id'] ??
                  '')
              .toString()
              .trim();
      if (creatorId.isNotEmpty) {
        userIds.add(creatorId);
      }
      if (userId.trim().isNotEmpty) {
        userIds.add(userId.trim());
      }

      if (userIds.isEmpty) {
        return fallback;
      }

      List<Map<String, dynamic>> userRows;
      try {
        final raw = await supabase
            .from('profiles')
            .select('id,name,bike,avatar_url')
            .inFilter('id', userIds.toList());
        userRows = List<Map<String, dynamic>>.from(raw);
      } on PostgrestException catch (error) {
        if (_isMissingAvatarColumn(error)) {
          final raw = await supabase
              .from('profiles')
              .select('id,name,bike')
              .inFilter('id', userIds.toList());
          userRows = List<Map<String, dynamic>>.from(raw);
        } else {
          rethrow;
        }
      }

      if (userRows.isEmpty) {
        return fallback;
      }

      final list =
          userRows.map((row) {
            final id = (row['id'] ?? '').toString().trim();
            final rowName = (row['name'] ?? '').toString().trim();
            final rowBike = (row['bike'] ?? '').toString().trim();
            final rowAvatar = (row['avatar_url'] ?? '').toString().trim();
            return _SummaryParticipant(
              id: id,
              name: rowName.isEmpty ? 'Rider' : rowName,
              bike: rowBike.isEmpty ? 'No bike added' : rowBike,
              avatarUrl: rowAvatar,
              isYou: id.isNotEmpty && id == userId.trim(),
            );
          }).toList();

      if (list.isEmpty) {
        return fallback;
      }
      return list;
    } catch (_) {
      return fallback;
    }
  }

  bool _isMissingAvatarColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' ||
        message.contains('avatar_url');
  }

  Widget _actions(Color primary) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareRideProgress,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary.withValues(alpha: 0.4)),
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text(
              'Share Ride Progress',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
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
              shadowColor: primary.withValues(alpha: 0.25),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View Full History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Renders the on-screen poster to a PNG and hands it to the OS share sheet.
  ///
  /// The poster is captured from the dialog while it is visible, so the render
  /// tree is guaranteed to be laid out and painted. The route is drawn by
  /// [_RouteTracePainter] rather than by a tile map, because map tiles load
  /// asynchronously and would have produced half-blank images.
  Future<void> _captureAndSharePoster() async {
    ui.Image? image;
    try {
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Poster is not ready yet.');
      }
      image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw Exception('Could not encode the poster.');
      }

      final dir = await getTemporaryDirectory();
      final safeName = _rideName()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final file = File(
        '${dir.path}/journeysync_${safeName.isEmpty ? 'ride' : safeName}.png',
      );
      // The offset/length form matters: `buffer.asUint8List()` with no arguments
      // returns the whole backing buffer, which can be larger than the encoded
      // PNG and would write trailing garbage into the file.
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: _shareSummaryText(),
          subject: '${_rideName()} on JourneySync',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not share the ride image: $error',
        type: AppToastType.error,
      );
    } finally {
      // Holds native memory until released, so it must go even on the error path.
      image?.dispose();
    }
  }

  Future<void> _shareRideProgress() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Only the boundary below is captured, so the dialog
                        // chrome and buttons never appear in the shared image.
                        RepaintBoundary(key: _posterKey, child: _sharePoster()),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  // Capture first: popping the dialog would
                                  // dispose the boundary being captured.
                                  await _captureAndSharePoster();
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                },
                                icon: const Icon(Icons.image_rounded, size: 16),
                                label: const Text(
                                  'Share image',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white54),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await SharePlus.instance.share(
                                      ShareParams(text: _shareSummaryText()),
                                    );
                                  } catch (error) {
                                    if (!mounted) return;
                                    showAppToast(
                                      context,
                                      'Could not open share sheet: $error',
                                      type: AppToastType.error,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.short_text_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Share text',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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

  /// The shareable card. Kept free of network images so it renders identically
  /// on screen and in the exported PNG.
  Widget _sharePoster() {
    final data = analytics;
    final trace =
        (data?.routePoints ?? const <Map<String, double>>[])
            .map((p) => (lat: p['lat'] ?? 0.0, lng: p['lng'] ?? 0.0))
            .toList();

    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.forestDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _rideName().toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: AppTypography.fontFamily,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_destinationLabel()} • ${_dateLabel()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // The recorded track, in brand orange.
          Container(
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child:
                trace.length > 1
                    ? CustomPaint(
                      // A CustomPaint with no child sizes itself to Size.zero
                      // unless told otherwise, which would paint nothing.
                      // Size.infinite resolves to the parent's constraints.
                      size: Size.infinite,
                      painter: _RouteTracePainter(
                        points: trace,
                        color: AppColors.primaryLight,
                      ),
                    )
                    : const Center(
                      child: Text(
                        'No GPS track recorded',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _posterStat('DISTANCE', _distanceText()),
              _posterStat('DURATION', _durationValue()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _posterStat('AVG SPEED', _avgSpeedText()),
              _posterStat('TOP SPEED', _topSpeedText()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _posterStat('RIDERS', '${_riderCount()}'),
              _posterStat(
                'RIDE SCORE',
                data == null ? '--' : '${data.rideScore}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Rider: $userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              const Text(
                'JOURNEYSYNC',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _posterStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _shareSummaryText() {
    final rideName = _rideName();
    final destination = _destinationLabel();
    final date = _dateLabel();
    // These used to read rides.distance_km / avg_speed_kmh / elevation_m -
    // columns the tracker never writes - so a shared ride printed "--" for
    // every number even when a full GPS track had been recorded.
    final duration = _durationValue();
    final distance = _distanceText();
    final avgSpeed = _avgSpeedText();
    final topSpeed = _topSpeedText();
    final elevation = _elevationText();
    final riders = _riderCount();
    final data = analytics;
    final score =
        data == null
            ? ''
            : '\nRide Score: ${data.rideScore} ${RideAnalyticsEngine.scoreLabelText(data.scoreLabel)}\nRide Health: ${RideAnalyticsEngine.healthLabelText(data.healthState)}';

    return '''
Ride Completed: $rideName
Date: $date
Destination: $destination

Duration: $duration
Distance: $distance
Avg Speed: $avgSpeed
Top Speed: $topSpeed
Elevation: $elevation
Rode With: $riders rider(s)
$score

Tracked on JourneySync.
#JourneySync #RideSummary #RideLife
''';
  }
}

class _SummaryParticipant {
  const _SummaryParticipant({
    required this.id,
    required this.name,
    required this.bike,
    required this.avatarUrl,
    required this.isYou,
  });

  final String id;
  final String name;
  final String bike;
  final String avatarUrl;
  final bool isYou;
}

/// Draws a recorded GPS track as a single orange line, scaled to fit.
///
/// The share poster deliberately does not use a tile map: tiles arrive over the
/// network, so a capture taken moments after the dialog opens could rasterise a
/// half-loaded or blank map. Painting the track directly means the exported PNG
/// always contains the route.
class _RouteTracePainter extends CustomPainter {
  const _RouteTracePainter({required this.points, required this.color});

  final List<({double lat, double lng})> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    const pad = 18.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0) return;

    // A degree of longitude is shorter than a degree of latitude away from the
    // equator. Correcting for that keeps the drawn shape recognisable as the
    // route rather than a stretched version of it.
    final latSpan = (maxLat - minLat).abs();
    final lngSpan =
        (maxLng - minLng).abs() * math.cos(minLat * math.pi / 180).abs();

    // A dead-straight or stationary track has zero span on one axis; the guard
    // keeps the scale finite so it renders as a line instead of vanishing.
    final span = math.max(math.max(latSpan, lngSpan), 1e-6);
    final scale = math.min(w, h) / span;

    final drawnW = lngSpan * scale;
    final drawnH = latSpan * scale;
    final offsetX = pad + (w - drawnW) / 2;
    final offsetY = pad + (h - drawnH) / 2;

    Offset project(({double lat, double lng}) p) {
      final x =
          (p.lng - minLng) * math.cos(minLat * math.pi / 180).abs() * scale;
      // Latitude grows northward but canvas y grows downward, so it is flipped.
      final y = drawnH - (p.lat - minLat) * scale;
      return Offset(offsetX + x, offsetY + y);
    }

    final first = project(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final p in points.skip(1)) {
      final o = project(p);
      path.lineTo(o.dx, o.dy);
    }

    // Soft under-stroke so the line reads clearly against the dark card.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.25),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Start and finish markers, so a loop is not mistaken for an out-and-back.
    canvas.drawCircle(
      project(points.first),
      4,
      Paint()..color = AppColors.success,
    );
    canvas.drawCircle(project(points.last), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteTracePainter old) =>
      old.points != points || old.color != color;
}
