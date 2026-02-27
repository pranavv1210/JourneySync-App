import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sos_alert_screen.dart';
import 'ride_summary_screen.dart';

class LiveRideScreen extends StatefulWidget {
  const LiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? ride;
  String userName = "Rider";
  String userBike = "No bike added";
  String currentUserId = "";
  List<_LiveMember> members = <_LiveMember>[];
  _GeoPoint? destinationPoint;
  int chatCount = 0;

  late final AnimationController pulseController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _latestPosition;
  Position? _lastSyncedPosition;
  DateTime? _lastSyncedAt;
  bool _locationSyncInFlight = false;
  bool _isTrackingLocation = false;
  String _trackingStatus = "Starting GPS...";

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString("userName") ?? "Rider";
    userBike = prefs.getString("userBike") ?? "No bike added";
    currentUserId = (prefs.getString("userId") ?? "").trim();
    final data =
        await supabase.from('rides').select().eq('id', widget.rideId).single();
    final loadedMembers = await _loadMembers(data);
    final resolvedDestination = await _resolveDestinationPoint(data);
    final unreadCount = await _loadChatCount();
    if (!mounted) return;
    setState(() {
      ride = data;
      members = loadedMembers;
      destinationPoint = resolvedDestination;
      chatCount = unreadCount;
      loading = false;
    });
    await _startLocationTracking();
  }

  String _rideTitle() {
    final name = (ride?['title'] ?? ride?['name'])?.toString().trim();
    return (name == null || name.isEmpty) ? "Live Ride" : name;
  }

  String _destinationFromRow(Map<String, dynamic> row) {
    return (row['end_location'] ?? row['destination'] ?? '').toString().trim();
  }

  String _destination() {
    final row = ride;
    if (row == null) return "Destination not set";
    final dest = _destinationFromRow(row);
    return dest.isEmpty ? "Destination not set" : dest;
  }

  String _rideTime() {
    final raw =
        ride?['started_at']?.toString() ?? ride?['created_at']?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return "—";
    final now = DateTime.now();
    final diff = now.difference(parsed);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }

  Future<List<_LiveMember>> _loadMembers(Map<String, dynamic> rideRow) async {
    final hostId = _hostIdFromRide(rideRow);
    final ids = <String>{};
    if (hostId.isNotEmpty) ids.add(hostId);

    try {
      final participantRows = await supabase
          .from('participants')
          .select('user_id')
          .eq('ride_id', widget.rideId);
      for (final row in participantRows) {
        final id = (row['user_id'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
    } catch (_) {}

    if (ids.isEmpty && currentUserId.isNotEmpty) {
      ids.add(currentUserId);
    }

    final profiles = await _loadUserProfiles(ids.toList());
    final result =
        ids.map((id) {
          final profile = profiles[id];
          final name =
              (profile?['name'] ?? (id == currentUserId ? userName : 'Rider'))
                  .toString();
          final bike =
              (profile?['bike'] ??
                      (id == currentUserId ? userBike : 'No bike added'))
                  .toString();
          return _LiveMember(
            id: id,
            name: name.trim().isEmpty ? 'Rider' : name.trim(),
            bike: bike.trim().isEmpty ? 'No bike added' : bike.trim(),
            avatarUrl: (profile?['avatar_url'] ?? '').toString().trim(),
            isLeader: id == hostId,
          );
        }).toList();

    result.sort((a, b) {
      if (a.isLeader && !b.isLeader) return -1;
      if (!a.isLeader && b.isLeader) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _loadUserProfiles(
    List<String> userIds,
  ) async {
    final ids = userIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final rows = await supabase
          .from('users')
          .select('id,name,bike,avatar_url')
          .inFilter('id', unique);
      return {
        for (final row in rows)
          (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(row),
      };
    } on PostgrestException catch (error) {
      final code = (error.code ?? '').trim();
      if (code == '42703' ||
          code == 'PGRST204' ||
          error.message.toLowerCase().contains('avatar_url')) {
        final rows = await supabase
            .from('users')
            .select('id,name,bike')
            .inFilter('id', unique);
        return {
          for (final row in rows)
            (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(row),
        };
      }
      rethrow;
    }
  }

  Future<int> _loadChatCount() async {
    const candidates = ['ride_messages', 'chat_messages', 'messages'];
    for (final table in candidates) {
      try {
        final rows = await supabase
            .from(table)
            .select('id')
            .eq('ride_id', widget.rideId);
        return rows.length;
      } on PostgrestException catch (error) {
        final code = (error.code ?? '').trim();
        if (code == '42P01' || code == '42703' || code == 'PGRST204') {
          continue;
        }
      } catch (_) {}
    }
    return 0;
  }

  Future<_GeoPoint?> _resolveDestinationPoint(Map<String, dynamic> row) async {
    final lat = _toDouble(row['end_lat'] ?? row['destination_lat']);
    final lng = _toDouble(row['end_lng'] ?? row['destination_lng']);
    if (lat != null && lng != null) return _GeoPoint(lat: lat, lng: lng);

    final destination = _destinationFromRow(row);
    final parsed = _tryParseLatLng(destination);
    if (parsed != null) return parsed;
    if (destination.length < 3) return null;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': destination,
        'format': 'jsonv2',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map<String, dynamic>) return null;
      final resolvedLat = double.tryParse((first['lat'] ?? '').toString());
      final resolvedLng = double.tryParse((first['lon'] ?? '').toString());
      if (resolvedLat == null || resolvedLng == null) return null;
      return _GeoPoint(lat: resolvedLat, lng: resolvedLng);
    } catch (_) {
      return null;
    }
  }

  String _hostIdFromRide(Map<String, dynamic> row) {
    return (row['creator_id'] ?? row['leader_id'] ?? row['user_id'] ?? '')
        .toString()
        .trim();
  }

  String _distanceLabel() {
    final current = _latestPosition;
    final destination = destinationPoint;
    if (current == null || destination == null) return "—";
    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.lat,
      destination.lng,
    );
    final miles = meters / 1609.344;
    return "${miles.toStringAsFixed(1)} mi";
  }

  String _etaArrivalLabel() {
    final current = _latestPosition;
    final destination = destinationPoint;
    if (current == null || destination == null) return "ETA unavailable";
    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.lat,
      destination.lng,
    );
    final speed = current.speed > 1 ? current.speed : 11.11;
    final etaSeconds = meters / speed;
    final arrival = DateTime.now().add(Duration(seconds: etaSeconds.round()));
    final hour12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
    final minute = arrival.minute.toString().padLeft(2, '0');
    final suffix = arrival.hour >= 12 ? 'PM' : 'AM';
    return "Est. arrival $hour12:$minute $suffix";
  }

  _GeoPoint? _tryParseLatLng(String text) {
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return _GeoPoint(lat: lat, lng: lng);
  }

  double? _toDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw.toString().trim());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF6A00);
    const forest = Color(0xFF1B5E20);
    const background = Color(0xFFF8F7F5);
    const warmSand = Color(0xFFF1EEE9);
    const danger = Color(0xFFDC2626);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          _mapBackground(primary),
          _riderMarkers(primary, forest),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _rideStatsHeader(primary, warmSand),
                const SizedBox(height: 10),
                _activeRideButton(forest),
                const SizedBox(height: 8),
                _locationStatusPill(forest),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _stopRideButton(danger),
                  ),
                ),
                const Spacer(),
                _navPrompt(forest),
                const SizedBox(height: 10),
                _fabRow(primary, danger),
                const SizedBox(height: 12),
                _bottomSheet(primary, warmSand, forest),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBackground(Color primary) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE6E3DD),
          image: DecorationImage(
            image: const AssetImage("assets/pattern.png"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.2),
              BlendMode.overlay,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(color: primary.withOpacity(0.9)),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: pulseController,
                builder: (_, __) {
                  final scale = 0.8 + (pulseController.value * 1.7);
                  final opacity = 0.5 * (1 - pulseController.value);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(opacity * 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: primary, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(Icons.navigation, color: primary, size: 32),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riderMarkers(Color primary, Color forest) {
    final visible = members.take(4).toList();
    return Positioned.fill(
      child: Stack(
        children: [
          ...visible.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            final top = _markerTop(index, member.isLeader);
            final left = _markerLeft(index, member.isLeader);
            if (member.isLeader) {
              return _leaderMarker(
                top: top,
                left: left,
                label: "${member.name} (Leader)",
                color: forest,
                avatarUrl: member.avatarUrl,
              );
            }
            return _marker(
              top: top,
              left: left,
              label: member.name,
              color: primary,
              avatarUrl: member.avatarUrl,
            );
          }),
          Positioned(
            top: 0.15 * MediaQuery.of(context).size.height,
            left: 0.8 * MediaQuery.of(context).size.width,
            child: Column(
              children: [
                Icon(Icons.place, size: 40, color: Colors.grey.shade700),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _destination(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _markerTop(int index, bool isLeader) {
    if (isLeader) return 0.25;
    const values = [0.30, 0.40, 0.33, 0.46];
    return values[index % values.length];
  }

  double _markerLeft(int index, bool isLeader) {
    if (isLeader) return 0.65;
    const values = [0.20, 0.34, 0.46, 0.28];
    return values[index % values.length];
  }

  Widget _marker({
    required double top,
    required double left,
    required String label,
    required Color color,
    required String avatarUrl,
  }) {
    return Positioned(
      top: top * MediaQuery.of(context).size.height,
      left: left * MediaQuery.of(context).size.width,
      child: Column(
        children: [
          Stack(
            children: [
              _avatar(url: avatarUrl, radius: 24),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(Icons.two_wheeler, size: 12, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderMarker({
    required double top,
    required double left,
    required String label,
    required Color color,
    required String avatarUrl,
  }) {
    return Positioned(
      top: top * MediaQuery.of(context).size.height,
      left: left * MediaQuery.of(context).size.width,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 4),
                ),
                child: _avatar(url: avatarUrl, radius: 28),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.star, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideStatsHeader(Color primary, Color warmSand) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: warmSand.withOpacity(0.9),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statBlock("Time", _rideTime()),
            _divider(),
            _statBlock("Dist", _distanceLabel()),
            _divider(),
            _statBlock(
              "MPH",
              _currentSpeedMph(),
              highlight: true,
              highlightColor: primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock(
    String label,
    String value, {
    bool highlight = false,
    Color? highlightColor,
  }) {
    final color =
        highlight ? (highlightColor ?? Colors.orange) : Colors.grey.shade700;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: highlight ? color.withOpacity(0.8) : Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: highlight ? color : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.grey.shade300,
    );
  }

  Widget _activeRideButton(Color forest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: forest,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(_rideTitle(), style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Icon(Icons.expand_more, size: 16, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _locationStatusPill(Color forest) {
    final accent = _isTrackingLocation ? forest : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTrackingLocation ? Icons.gps_fixed : Icons.gps_off,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            _trackingStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopRideButton(Color danger) {
    return TextButton.icon(
      onPressed: () async {
        await _stopLocationTracking();
        try {
          await supabase
              .from('rides')
              .update({
                'status': 'ended',
                'ended_at': DateTime.now().toIso8601String(),
              })
              .eq('id', widget.rideId);
        } catch (_) {
          await supabase
              .from('rides')
              .update({'status': 'ended'})
              .eq('id', widget.rideId);
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideSummaryScreen(rideId: widget.rideId),
          ),
        );
      },
      style: TextButton.styleFrom(
        backgroundColor: danger.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(Icons.pan_tool, color: danger, size: 16),
      label: Text(
        "Stop Ride",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: danger,
        ),
      ),
    );
  }

  Widget _navPrompt(Color forest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: forest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.turn_right, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            "Proceed toward ${_destination()} (${_distanceLabel()})",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabRow(Color primary, Color danger) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final phone = prefs.getString("userPhone") ?? "";
              final name = prefs.getString("userName") ?? "Rider";
              final bike = prefs.getString("userBike") ?? "No bike added";

              await supabase
                  .from('rides')
                  .update({
                    'alert_status': 'active',
                    'alert_by': phone,
                    'alert_by_name': name,
                    'alert_by_bike': bike,
                    'alert_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', widget.rideId);

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SosAlertScreen(rideId: widget.rideId),
                ),
              );
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: danger,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "SOS",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _toolButton(Icons.layers, primary),
              const SizedBox(height: 10),
              _toolButton(Icons.my_location, primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, Color primary) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: primary),
    );
  }

  Widget _bottomSheet(Color primary, Color warmSand, Color forest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: warmSand,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.flag, color: primary, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Next Stop",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _destination(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_distanceLabel()} away • ${_etaArrivalLabel()}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(Icons.mic, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ..._bottomStackAvatars(),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        "+${_extraMemberCount()}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      "Group Chat",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chatCount.toString(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _bottomStackAvatars() {
    final top = members.take(3).toList();
    if (top.isEmpty) {
      return [
        const CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage("assets/profile.png"),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (int i = 0; i < top.length; i++) {
      widgets.add(_avatar(url: top[i].avatarUrl, radius: 18));
      if (i < top.length - 1) {
        widgets.add(const SizedBox(width: 6));
      }
    }
    return widgets;
  }

  int _extraMemberCount() {
    final extra = members.length - 3;
    return extra > 0 ? extra : 0;
  }

  Widget _avatar({required String url, required double radius}) {
    final clean = url.trim();
    if (clean.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(clean),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: const AssetImage("assets/profile.png"),
    );
  }

  Future<void> _startLocationTracking() async {
    if (!mounted) return;
    setState(() {
      _trackingStatus = "Checking location...";
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _isTrackingLocation = false;
        _trackingStatus = "Location service disabled";
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _isTrackingLocation = false;
        _trackingStatus = "GPS permission denied";
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isTrackingLocation = true;
      _trackingStatus = "Sharing live location";
    });

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _syncLocationToRide(current);
    } catch (_) {}

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
      ),
    ).listen(
      (position) {
        _latestPosition = position;
        _syncLocationToRide(position);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isTrackingLocation = false;
          _trackingStatus = "GPS tracking unavailable";
        });
      },
    );
  }

  Future<void> _stopLocationTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTrackingLocation = false;
  }

  Future<void> _syncLocationToRide(Position position) async {
    if (_locationSyncInFlight) return;

    final now = DateTime.now();
    final lastPosition = _lastSyncedPosition;
    final lastSyncedAt = _lastSyncedAt;
    final movedEnough =
        lastPosition == null ||
        Geolocator.distanceBetween(
              lastPosition.latitude,
              lastPosition.longitude,
              position.latitude,
              position.longitude,
            ) >=
            15;
    final waitedEnough =
        lastSyncedAt == null || now.difference(lastSyncedAt).inSeconds >= 10;

    if (!movedEnough && !waitedEnough) return;

    _locationSyncInFlight = true;
    try {
      await supabase
          .from('rides')
          .update({
            'current_lat': position.latitude,
            'current_lng': position.longitude,
            'current_speed_mps': position.speed >= 0 ? position.speed : null,
            'current_heading': position.heading >= 0 ? position.heading : null,
            'location_updated_at': now.toIso8601String(),
          })
          .eq('id', widget.rideId);
      _lastSyncedPosition = position;
      _lastSyncedAt = now;
      if (!mounted) return;
      setState(() {
        _isTrackingLocation = true;
        _trackingStatus = "Live location synced";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trackingStatus = "Location sync failed";
      });
    } finally {
      _locationSyncInFlight = false;
    }
  }

  String _currentSpeedMph() {
    final speedMps = _latestPosition?.speed;
    if (speedMps == null || speedMps <= 0) return "—";
    return (speedMps * 2.23694).toStringAsFixed(0);
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(-50, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.65,
      size.width * 0.35,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width * 0.75,
      size.height * 0.2,
    );
    canvas.drawPath(path, paint);

    final dashPaint =
        Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final dashPath = Path();
    dashPath.moveTo(-50, size.height * 0.7);
    dashPath.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.65,
      size.width * 0.35,
      size.height * 0.5,
    );
    dashPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width * 0.75,
      size.height * 0.2,
    );

    const dashLength = 10.0;
    const gapLength = 8.0;
    for (final metric in dashPath.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        final segment = metric.extractPath(distance, next);
        canvas.drawPath(segment, dashPaint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LiveMember {
  const _LiveMember({
    required this.id,
    required this.name,
    required this.bike,
    required this.avatarUrl,
    required this.isLeader,
  });

  final String id;
  final String name;
  final String bike;
  final String avatarUrl;
  final bool isLeader;
}

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

