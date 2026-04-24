import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_toast.dart';

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
      if (!mounted) return;
      setState(() {
        ride = data;
        participants = fetchedParticipants;
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
    const primary = Color(0xFFFF6A00);
    const secondaryBlue = Color(0xFF0056B3);
    const vibrantTeal = Color(0xFF00C2CB);
    const background = Color(0xFFF8F7F5);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError.isNotEmpty) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              loadError,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
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
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${_rideName()} • ${_dateLabel()}',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
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
                  label: 'Duration',
                  value: _durationText(),
                  color: secondaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBlock(
                  icon: Icons.add_location_alt,
                  label: 'Distance',
                  value: _metric(const ['distance_km', 'distance'], 'km'),
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
                  'Avg Speed',
                  _metric(const ['avg_speed_kmh', 'avg_speed'], 'km/h'),
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'Top Speed',
                  _metric(const ['top_speed_kmh', 'top_speed'], 'km/h'),
                ),
              ),
              Expanded(
                child: _miniMetric(
                  'Elevation',
                  _metric(const ['elevation_m', 'elevation'], 'm'),
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
          .from('participants')
          .select('user_id')
          .eq('ride_id', widget.rideId);
      final userIds =
          List<Map<String, dynamic>>.from(rows)
              .map((row) => (row['user_id'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet();

      final creatorId =
          (rideRow['creator_id'] ?? rideRow['user_id'] ?? rideRow['leader_id'])
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
            .from('users')
            .select('id,name,bike,avatar_url')
            .inFilter('id', userIds.toList());
        userRows = List<Map<String, dynamic>>.from(raw);
      } on PostgrestException catch (error) {
        if (_isMissingAvatarColumn(error)) {
          final raw = await supabase
              .from('users')
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
    try {
      final text = _shareSummaryText();
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not open share sheet: $error',
        type: AppToastType.error,
      );
    }
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
