import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
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
  final MapController _mapController = MapController();

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
  Timer? _liveRefreshTimer;
  Position? _latestPosition;
  Position? _lastSyncedPosition;
  DateTime? _lastSyncedAt;
  bool _locationSyncInFlight = false;
  bool _isTrackingLocation = false;
  String _trackingStatus = "Starting GPS...";
  bool _useTerrainTiles = false;
  String? _chatTableName;

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
    _startLiveRefreshTimer();
    await _startLocationTracking();
  }

  void _startLiveRefreshTimer() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshLiveData();
    });
  }

  Future<void> _refreshLiveData() async {
    if (!mounted) return;
    try {
      final latestRide =
          await supabase
              .from('rides')
              .select()
              .eq('id', widget.rideId)
              .single();
      final refreshedMembers = await _loadMembers(latestRide);
      final unreadCount = await _loadChatCount();
      if (!mounted) return;
      setState(() {
        ride = latestRide;
        members = refreshedMembers;
        chatCount = unreadCount;
      });
    } catch (_) {}
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
    if (parsed == null) return "--";
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
          final activeRideId =
              (profile?['active_ride_id'] ?? '').toString().trim();
          final lat = _toDouble(profile?['current_lat']);
          final lng = _toDouble(profile?['current_lng']);
          final location =
              lat != null &&
                      lng != null &&
                      (activeRideId.isEmpty || activeRideId == widget.rideId)
                  ? _GeoPoint(lat: lat, lng: lng)
                  : null;
          return _LiveMember(
            id: id,
            name: name.trim().isEmpty ? 'Rider' : name.trim(),
            bike: bike.trim().isEmpty ? 'No bike added' : bike.trim(),
            avatarUrl: (profile?['avatar_url'] ?? '').toString().trim(),
            isLeader: id == hostId,
            location: location,
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
          .select(
            'id,name,bike,avatar_url,current_lat,current_lng,active_ride_id',
          )
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
            .select('id,name,bike,current_lat,current_lng,active_ride_id')
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
        _chatTableName = table;
        return rows.length;
      } on PostgrestException catch (error) {
        final code = (error.code ?? '').trim();
        if (code == '42P01' || code == '42703' || code == 'PGRST204') {
          continue;
        }
      } catch (_) {}
    }
    _chatTableName = null;
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
    if (current == null || destination == null) return "--";
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
    _liveRefreshTimer?.cancel();
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
    final destination = destinationPoint;
    final current = _latestPosition;
    _LiveMember? currentMember;
    for (final member in members) {
      if (member.id == currentUserId) {
        currentMember = member;
        break;
      }
    }
    final currentMemberLocation = currentMember?.location;
    final riderMarkers = _memberMarkers(primary, const Color(0xFF1B5E20));
    final center =
        current != null
            ? LatLng(current.latitude, current.longitude)
            : (currentMemberLocation != null
                ? LatLng(currentMemberLocation.lat, currentMemberLocation.lng)
                : (destination != null
                    ? LatLng(destination.lat, destination.lng)
                    : const LatLng(20.5937, 78.9629)));
    return Positioned.fill(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: (current != null || destination != null) ? 13 : 5,
          minZoom: 3,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate:
                _useTerrainTiles
                    ? 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.journeysync',
          ),
          if (destination != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(destination.lat, destination.lng),
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.deepOrange,
                    size: 32,
                  ),
                ),
              ],
            ),
          if (riderMarkers.isNotEmpty) MarkerLayer(markers: riderMarkers),
          if (current != null && destination != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    LatLng(current.latitude, current.longitude),
                    LatLng(destination.lat, destination.lng),
                  ],
                  color: primary.withOpacity(0.8),
                  strokeWidth: 4,
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Marker> _memberMarkers(Color primary, Color forest) {
    final markers = <Marker>[];
    for (final member in members) {
      final location = member.location;
      if (location == null) continue;
      markers.add(
        Marker(
          point: LatLng(location.lat, location.lng),
          width: 110,
          height: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: member.isLeader ? forest : primary,
                        width: member.isLeader ? 3 : 2,
                      ),
                    ),
                    child: _avatar(url: member.avatarUrl, radius: 20),
                  ),
                  if (member.isLeader)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: forest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  member.id == currentUserId ? 'You' : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return markers;
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
            onTap: _triggerSos,
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
              _toolButton(
                Icons.layers,
                primary,
                tooltip: 'Toggle map style',
                onTap: _toggleMapStyle,
              ),
              const SizedBox(height: 10),
              _toolButton(
                Icons.my_location,
                primary,
                tooltip: 'Focus my location',
                onTap: _focusOnCurrentLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolButton(
    IconData icon,
    Color primary, {
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: primary),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerSos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString("userPhone") ?? "";
      final name = prefs.getString("userName") ?? "Rider";
      final bike = prefs.getString("userBike") ?? "No bike added";

      try {
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
      } catch (_) {}

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SosAlertScreen(rideId: widget.rideId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not trigger SOS: $error')));
    }
  }

  void _toggleMapStyle() {
    setState(() {
      _useTerrainTiles = !_useTerrainTiles;
    });
  }

  void _focusOnCurrentLocation() {
    final current = _latestPosition;
    if (current == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location unavailable')),
      );
      return;
    }
    _mapController.move(LatLng(current.latitude, current.longitude), 15.5);
  }

  void _focusOnDestination() {
    final destination = destinationPoint;
    if (destination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination location unavailable')),
      );
      return;
    }
    _mapController.move(LatLng(destination.lat, destination.lng), 14.5);
  }

  Future<void> _openGroupChat() async {
    final table = _chatTableName;
    if (table == null) return;
    final controller = TextEditingController();
    var messages = await _loadGroupMessages(table);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Group Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 280,
                    child:
                        messages.isEmpty
                            ? const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            )
                            : ListView.builder(
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final mine = msg.userId == currentUserId;
                                return Align(
                                  alignment:
                                      mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          mine
                                              ? const Color(
                                                0xFFFF6A00,
                                              ).withOpacity(0.12)
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          mine
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mine
                                              ? 'You'
                                              : _memberName(msg.userId),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(msg.message),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Type message',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          final sent = await _sendGroupMessage(table, text);
                          if (!sent) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Could not send message'),
                              ),
                            );
                            return;
                          }
                          controller.clear();
                          messages = await _loadGroupMessages(table);
                          if (!ctx.mounted) return;
                          setLocalState(() {});
                          if (mounted) {
                            setState(() {
                              chatCount = messages.length;
                            });
                          }
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<List<_ChatMessage>> _loadGroupMessages(String table) async {
    try {
      final rows = await supabase
          .from(table)
          .select('id,user_id,message,created_at')
          .eq('ride_id', widget.rideId)
          .order('created_at');
      return rows
          .map(
            (row) => _ChatMessage(
              id: (row['id'] ?? '').toString(),
              userId: (row['user_id'] ?? '').toString().trim(),
              message: (row['message'] ?? '').toString(),
              createdAt: DateTime.tryParse(
                (row['created_at'] ?? '').toString(),
              ),
            ),
          )
          .where((m) => m.message.trim().isNotEmpty)
          .toList();
    } on PostgrestException catch (_) {
      _chatTableName = null;
      return <_ChatMessage>[];
    }
  }

  Future<bool> _sendGroupMessage(String table, String message) async {
    try {
      await supabase.from(table).insert({
        'ride_id': widget.rideId,
        'user_id': currentUserId,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  String _memberName(String userId) {
    for (final member in members) {
      if (member.id == userId) return member.name;
    }
    return 'Rider';
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
          InkWell(
            onTap: _focusOnDestination,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
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
                              'Next Stop',
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_distanceLabel()} away • ${_etaArrivalLabel()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
            ),
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
                        '+${_extraMemberCount()}',
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
              if (_chatTableName != null)
                TextButton(
                  onPressed: _openGroupChat,
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
                      const Text(
                        'Group Chat',
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
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Chat unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
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
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFF2F4F7),
          child: Icon(Icons.person_rounded, color: Colors.grey.shade500),
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
      backgroundColor: const Color(0xFFF2F4F7),
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: Colors.grey.shade500,
      ),
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
      if (mounted) {
        setState(() {
          _latestPosition = current;
        });
      } else {
        _latestPosition = current;
      }
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
        if (mounted) {
          setState(() {
            _latestPosition = position;
          });
        } else {
          _latestPosition = position;
        }
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
      var synced = false;
      if (currentUserId.isNotEmpty) {
        try {
          await supabase
              .from('users')
              .update({
                'current_lat': position.latitude,
                'current_lng': position.longitude,
                'current_speed_mps':
                    position.speed >= 0 ? position.speed : null,
                'current_heading':
                    position.heading >= 0 ? position.heading : null,
                'location_updated_at': now.toIso8601String(),
                'active_ride_id': widget.rideId,
              })
              .eq('id', currentUserId);
          synced = true;
        } on PostgrestException catch (error) {
          if (!_isMissingUserLocationColumns(error)) rethrow;
        }
      }

      if (!synced) {
        try {
          await supabase
              .from('rides')
              .update({
                'current_lat': position.latitude,
                'current_lng': position.longitude,
                'current_speed_mps':
                    position.speed >= 0 ? position.speed : null,
                'current_heading':
                    position.heading >= 0 ? position.heading : null,
                'location_updated_at': now.toIso8601String(),
              })
              .eq('id', widget.rideId);
          synced = true;
        } on PostgrestException catch (error) {
          if (!_isMissingRideLocationColumns(error)) rethrow;
        }
      }

      _lastSyncedPosition = position;
      _lastSyncedAt = now;
      if (!mounted) return;
      setState(() {
        _isTrackingLocation = true;
        _trackingStatus =
            synced ? 'Live location synced' : 'GPS active (cloud sync limited)';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTrackingLocation = false;
        _trackingStatus = _syncFailureLabel(error);
      });
    } finally {
      _locationSyncInFlight = false;
    }
  }

  String _syncFailureLabel(Object error) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      final message = error.message.toLowerCase();
      if (code == '42501' || message.contains('row-level security')) {
        return 'Sync blocked by DB policy';
      }
      if (code == '42703' || code == 'PGRST204') {
        return 'DB missing location columns';
      }
      if (code == '42P01') {
        return 'DB table missing';
      }
      return 'Location sync failed ($code)';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') || text.contains('timeout')) {
      return 'Network issue while syncing';
    }
    return 'Location sync failed';
  }

  bool _isMissingUserLocationColumns(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' ||
        message.contains('current_lat') ||
        message.contains('current_lng') ||
        message.contains('active_ride_id') ||
        message.contains('location_updated_at');
  }

  bool _isMissingRideLocationColumns(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' ||
        message.contains('current_lat') ||
        message.contains('current_lng') ||
        message.contains('current_speed_mps') ||
        message.contains('current_heading') ||
        message.contains('location_updated_at');
  }

  String _currentSpeedMph() {
    final speedMps = _latestPosition?.speed;
    if (speedMps == null || speedMps <= 0) return "--";
    return (speedMps * 2.23694).toStringAsFixed(0);
  }
}

class _LiveMember {
  const _LiveMember({
    required this.id,
    required this.name,
    required this.bike,
    required this.avatarUrl,
    required this.isLeader,
    this.location,
  });

  final String id;
  final String name;
  final String bike;
  final String avatarUrl;
  final bool isLeader;
  final _GeoPoint? location;
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.userId,
    required this.message,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String message;
  final DateTime? createdAt;
}

class _GeoPoint {
  const _GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}
