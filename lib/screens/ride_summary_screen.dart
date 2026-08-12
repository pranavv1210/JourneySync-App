import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    const secondaryBlue = Color(0xFF0056B3);
    const vibrantTeal = Color(0xFF00C2CB);
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
                    _header(vibrantTeal),
                    const SizedBox(height: 24),
                    _summaryCard(primary, secondaryBlue),
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

  Widget _header(Color vibrantTeal) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: vibrantTeal.withValues(alpha: 0.1),
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
                    color: vibrantTeal.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ride Completed!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
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

  Widget _summaryCard(Color primary, Color secondaryBlue) {
    final data = analytics;
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
                  value:
                      data == null
                          ? _durationText()
                          : RideAnalyticsEngine.durationText(
                            data.durationSeconds,
                          ),
                  color: secondaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBlock(
                  icon: Icons.add_location_alt,
                  label: 'Distance',
                  value:
                      data == null
                          ? _metric(const ['distance_km', 'distance'], 'km')
                          : '${data.distanceKm.toStringAsFixed(1)} km',
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
              Expanded(
                child: _miniMetric(
                  'Avg Speed',
                  data == null
                      ? _metric(const ['avg_speed_kmh', 'avg_speed'], 'km/h')
                      : '${data.averageSpeedKmh.toStringAsFixed(1)} km/h',
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'Top Speed',
                  data == null
                      ? _metric(const ['top_speed_kmh', 'top_speed'], 'km/h')
                      : '${data.maxSpeedKmh.toStringAsFixed(0)} km/h',
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'Elevation',
                  data == null
                      ? _metric(const ['elevation_m', 'elevation'], 'm')
                      : '+${data.elevationGainM.toStringAsFixed(0)} m',
                ),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
            fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w900,
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
              fontWeight: FontWeight.w900,
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
                    color: Color(0xFFFF6A00),
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
                            color: const Color(
                              0xFF00C2CB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            achievement,
                            style: const TextStyle(
                              color: Color(0xFF00A8B0),
                              fontWeight: FontWeight.w800,
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
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.grey.shade300)),
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
                fontWeight: FontWeight.w800,
                color: Colors.grey,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00C2CB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${participants.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00C2CB),
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
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
                      color: const Color(0xFF00C2CB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00C2CB),
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
      backgroundColor: const Color(0xFF00C2CB).withValues(alpha: 0.16),
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF00C2CB),
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
                fontWeight: FontWeight.w800,
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
                    fontWeight: FontWeight.w800,
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

  Future<void> _shareRideProgress() async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) {
        final rideName = _rideName();
        final destination = _destinationLabel();
        final date = _dateLabel();
        final duration = _durationText();
        final distance = _metric(const ['distance_km', 'distance'], 'km');
        final avgSpeed = _metric(const ['avg_speed_kmh', 'avg_speed'], 'km/h');
        final topSpeed = _metric(const ['top_speed_kmh', 'top_speed'], 'km/h');

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card Header
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: Color(0xFFFF6A00),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'JOURNEYSYNC SHARE POSTER',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Poster Graphic
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
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
                                rideName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Destination: $destination • $date',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Stats grid inside poster
                              Row(
                                children: [
                                  _posterStat('DISTANCE', distance),
                                  _posterStat('DURATION', duration),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _posterStat('AVG SPEED', avgSpeed),
                                  _posterStat('TOP SPEED', topSpeed),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Branding
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rider: $userName',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Text(
                                    'JOURNEYSYNC V2',
                                    style: TextStyle(
                                      color: Color(0xFFFF6A00),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Share Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const ui.Color(0xFFFF6A00),
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
                                    final text = _shareSummaryText();
                                    await SharePlus.instance.share(
                                      ShareParams(text: text),
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
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text(
                                  'Share Text',
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
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  showAppToast(
                                    context,
                                    'Poster image copied to clipboard!',
                                    type: AppToastType.info,
                                  );
                                },
                                icon: const Icon(
                                  Icons.save_alt_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Save Card',
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
    final duration = _durationText();
    final distance = _metric(const ['distance_km', 'distance'], 'km');
    final avgSpeed = _metric(const ['avg_speed_kmh', 'avg_speed'], 'km/h');
    final topSpeed = _metric(const ['top_speed_kmh', 'top_speed'], 'km/h');
    final elevation = _metric(const ['elevation_m', 'elevation'], 'm');
    final riders = participants.isEmpty ? 1 : participants.length;
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
