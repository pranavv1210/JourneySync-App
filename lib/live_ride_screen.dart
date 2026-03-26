import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_toast.dart';
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
  final Battery _battery = Battery();

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
  bool _isRefreshingLiveData = false;
  int _refreshTick = 0;
  bool _hasAutoCenteredOnUser = false;

  // Performance optimizations - caching
  final Map<String, Map<String, dynamic>> _cachedUserProfiles = {};
  DateTime? _lastMembersRefresh;
  bool _destinationResolved = false;

  Future<String?> _batteryPercentLabel() async {
    try {
      final level = await _battery.batteryLevel;
      return '$level%';
    } catch (_) {
      return null;
    }
  }

  String _signalStatusLabel() {
    if (!_isTrackingLocation) return 'GPS unavailable';
    return 'GPS active';
  }

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
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString("userName") ?? "Rider";
      userBike = prefs.getString("userBike") ?? "No bike added";
      currentUserId = (prefs.getString("userId") ?? "").trim();

      final data = await supabase
          .from('rides')
          .select()
          .eq('id', widget.rideId)
          .single()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() {
        ride = data;
        loading = false;
      });

      _startLiveRefreshTimer();
      _startLocationTracking();
      _loadSupplementalData(data);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      _startLiveRefreshTimer();
      _startLocationTracking();
    }
  }

  Future<void> _loadSupplementalData(Map<String, dynamic> rideRow) async {
    try {
      final loadedMembersFuture = _loadMembers(rideRow);
      final destinationFuture = _resolveDestinationPoint(rideRow);
      final chatCountFuture = _loadChatCount();
      final results = await Future.wait<dynamic>([
        loadedMembersFuture,
        destinationFuture,
        chatCountFuture,
      ]);
      if (!mounted) return;
      setState(() {
        members = results[0] as List<_LiveMember>;
        destinationPoint = results[1] as _GeoPoint?;
        chatCount = results[2] as int;
      });
    } catch (_) {}
  }

  void _startLiveRefreshTimer() {
    _liveRefreshTimer?.cancel();
    // Increased from 12 to 20 seconds to reduce API load
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshLiveData();
    });
  }

  Future<void> _refreshLiveData() async {
    if (!mounted || _isRefreshingLiveData) return;
    _isRefreshingLiveData = true;
    try {
      final latestRide = await supabase
          .from('rides')
          .select()
          .eq('id', widget.rideId)
          .single()
          .timeout(const Duration(seconds: 6));

      // Refresh members less frequently - every 60 seconds
      List<_LiveMember>? refreshedMembers;
      final now = DateTime.now();
      if (_lastMembersRefresh == null ||
          now.difference(_lastMembersRefresh!).inSeconds >= 60) {
        refreshedMembers = await _loadMembers(latestRide);
        _lastMembersRefresh = now;
      } else {
        refreshedMembers = members;
      }

      // Refresh chat count every 30 seconds
      final unreadCount =
          (_refreshTick % 2 == 0) ? await _loadChatCount() : chatCount;

      if (!mounted) return;
      setState(() {
        ride = latestRide;
        members = refreshedMembers ?? members;
        chatCount = unreadCount;
      });
      _refreshTick++;
    } catch (_) {
    } finally {
      _isRefreshingLiveData = false;
    }
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

    // Check cache first and filter out already cached IDs
    final notCached = <String>[];
    final result = <String, Map<String, dynamic>>{};

    for (final id in unique) {
      if (_cachedUserProfiles.containsKey(id)) {
        result[id] = _cachedUserProfiles[id]!;
      } else {
        notCached.add(id);
      }
    }

    // Only fetch IDs that aren't cached
    if (notCached.isEmpty) {
      return result;
    }

    try {
      final rows = await supabase
          .from('users')
          .select(
            'id,name,bike,avatar_url,current_lat,current_lng,active_ride_id',
          )
          .inFilter('id', notCached);

      for (final row in rows) {
        final id = (row['id'] ?? '').toString().trim();
        final data = Map<String, dynamic>.from(row);
        _cachedUserProfiles[id] = data;
        result[id] = data;
      }
      return result;
    } on PostgrestException catch (error) {
      final code = (error.code ?? '').trim();
      if (code == '42703' ||
          code == 'PGRST204' ||
          error.message.toLowerCase().contains('avatar_url')) {
        final rows = await supabase
            .from('users')
            .select('id,name,bike,current_lat,current_lng,active_ride_id')
            .inFilter('id', notCached);
        for (final row in rows) {
          final id = (row['id'] ?? '').toString().trim();
          final data = Map<String, dynamic>.from(row);
          _cachedUserProfiles[id] = data;
          result[id] = data;
        }
        return result;
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
    // If already resolved in this session, don't re-resolve
    if (_destinationResolved && destinationPoint != null) {
      return destinationPoint;
    }

    final lat = _toDouble(row['end_lat'] ?? row['destination_lat']);
    final lng = _toDouble(row['end_lng'] ?? row['destination_lng']);
    if (lat != null && lng != null) {
      _destinationResolved = true;
      return _GeoPoint(lat: lat, lng: lng);
    }

    final destination = _destinationFromRow(row);
    final parsed = _tryParseLatLng(destination);
    if (parsed != null) {
      _destinationResolved = true;
      return parsed;
    }
    if (destination.length < 3) {
      _destinationResolved = true;
      return null;
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': destination,
        'format': 'jsonv2',
        'limit': '1',
      });
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'JourneySync/1.0 (journeysync.app@gmail.com)',
            },
          )
          .timeout(const Duration(seconds: 3)); // Reduced from 4 to 3 seconds
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _destinationResolved = true;
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        _destinationResolved = true;
        return null;
      }
      final first = decoded.first;
      if (first is! Map<String, dynamic>) {
        _destinationResolved = true;
        return null;
      }
      final resolvedLat = double.tryParse((first['lat'] ?? '').toString());
      final resolvedLng = double.tryParse((first['lon'] ?? '').toString());
      if (resolvedLat == null || resolvedLng == null) {
        _destinationResolved = true;
        return null;
      }
      _destinationResolved = true;
      return _GeoPoint(lat: resolvedLat, lng: resolvedLng);
    } catch (_) {
      _destinationResolved = true;
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
    final kilometers = meters / 1000;
    return "${kilometers.toStringAsFixed(1)} km";
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
                const Spacer(),
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
                  color: primary.withValues(alpha: 0.8),
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
          child: _MemberMarkerWidget(
            member: member,
            currentUserId: currentUserId,
            isLeader: member.isLeader,
            primary: primary,
            forest: forest,
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
          color: warmSand.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
              "KM/H",
              _currentSpeedKmh(),
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
            color: highlight ? color.withValues(alpha: 0.8) : Colors.grey,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _editRideTitle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
              Text(
                _rideTitle(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more, size: 16, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationStatusPill(Color forest) {
    final accent = _isTrackingLocation ? forest : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
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
        backgroundColor: danger.withValues(alpha: 0.1),
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

  Widget _fabRow(Color primary, Color danger) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
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
              const SizedBox(height: 10),
              _stopRideButton(danger),
            ],
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
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: primary),
          ),
        ),
      ),
    );
  }

  Future<void> _editRideTitle() async {
    final controller = TextEditingController(text: _rideTitle());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ride name',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Ride title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) {
      controller.dispose();
      return;
    }

    final title = controller.text.trim();
    controller.dispose();
    if (title.isEmpty) return;

    try {
      await supabase
          .from('rides')
          .update({'title': title})
          .eq('id', widget.rideId);
    } catch (_) {
      await supabase
          .from('rides')
          .update({'name': title})
          .eq('id', widget.rideId);
    }

    if (!mounted) return;
    setState(() {
      ride = {...?ride, 'title': title, 'name': title};
    });
    showAppToast(context, 'Ride name updated', type: AppToastType.success);
  }

  Future<void> _triggerSos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString("userPhone") ?? "";
      final name = prefs.getString("userName") ?? "Rider";
      final bike = prefs.getString("userBike") ?? "No bike added";
      final avatarUrl = prefs.getString("userAvatarUrl") ?? "";
      final current = _latestPosition;
      final battery = await _batteryPercentLabel();

      try {
        await supabase
            .from('rides')
            .update({
              'alert_status': 'active',
              'alert_by': phone,
              'alert_by_name': name,
              'alert_by_bike': bike,
              'alert_by_avatar_url': avatarUrl,
              'alert_at': DateTime.now().toIso8601String(),
              'alert_lat': current?.latitude,
              'alert_lng': current?.longitude,
              'alert_speed':
                  current != null && current.speed >= 0
                      ? current.speed * 3.6
                      : null,
              'alert_signal': _signalStatusLabel(),
              'alert_battery': battery,
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
      showAppToast(
        context,
        'Could not trigger SOS: $error',
        type: AppToastType.error,
      );
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
      showAppToast(
        context,
        'Current location unavailable',
        type: AppToastType.error,
      );
      return;
    }
    _moveMapToCurrentPosition(current, zoom: 16.5);
  }

  void _moveMapToCurrentPosition(Position position, {double zoom = 16.5}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(position.latitude, position.longitude), zoom);
    });
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
                                              ).withValues(alpha: 0.12)
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
                            showAppToast(
                              ctx,
                              'Could not send message',
                              type: AppToastType.error,
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
    final hasDestinationPoint = destinationPoint != null;
    final extraMembers = _extraMemberCount();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: warmSand,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
          Padding(
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
                              color: primary.withValues(alpha: 0.15),
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
                        hasDestinationPoint
                            ? '${_distanceLabel()} away • ${_etaArrivalLabel()}'
                            : 'Location will appear when a destination is added',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  if (extraMembers > 0) ...[
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
                          '+$extraMembers',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      if (chatCount > 0) ...[
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
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
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
      // Update position without full rebuild
      _latestPosition = current;
      if (mounted) {
        setState(() {});
      }
      if (!_hasAutoCenteredOnUser) {
        _hasAutoCenteredOnUser = true;
        _moveMapToCurrentPosition(current);
      }
      await _syncLocationToRide(current);
    } catch (_) {}

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Increased from 12 to 15 meters
      ),
    ).listen(
      (position) {
        _latestPosition = position;
        // Only rebuild if map is visible (optimization)
        if (mounted) {
          // Use light rebuild for just map updates
          setState(() {});
        }
        if (!_hasAutoCenteredOnUser) {
          _hasAutoCenteredOnUser = true;
          _moveMapToCurrentPosition(position);
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
      final battery = await _batteryPercentLabel();
      final speedKmh = position.speed >= 0 ? position.speed * 3.6 : null;
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
                'battery': battery,
                'signal': _signalStatusLabel(),
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
                'battery': battery,
                'signal': _signalStatusLabel(),
                'location_updated_at': now.toIso8601String(),
                if ((ride?['alert_status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    'active') ...{
                  'alert_lat': position.latitude,
                  'alert_lng': position.longitude,
                  'alert_speed': speedKmh,
                  'alert_signal': _signalStatusLabel(),
                  'alert_battery': battery,
                  'alert_at': now.toIso8601String(),
                },
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
        _trackingStatus = synced ? 'Live location synced' : 'GPS active';
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
        message.contains('battery') ||
        message.contains('signal') ||
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
        message.contains('battery') ||
        message.contains('signal') ||
        message.contains('alert_lat') ||
        message.contains('alert_lng') ||
        message.contains('alert_speed') ||
        message.contains('alert_signal') ||
        message.contains('alert_battery') ||
        message.contains('alert_by_avatar_url') ||
        message.contains('location_updated_at');
  }

  String _currentSpeedKmh() {
    final speedMps = _latestPosition?.speed;
    if (speedMps == null || speedMps <= 0) return "--";
    return (speedMps * 3.6).toStringAsFixed(0);
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

class _MemberMarkerWidget extends StatelessWidget {
  const _MemberMarkerWidget({
    required this.member,
    required this.currentUserId,
    required this.isLeader,
    required this.primary,
    required this.forest,
  });

  final _LiveMember member;
  final String currentUserId;
  final bool isLeader;
  final Color primary;
  final Color forest;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLeader ? forest : primary,
                  width: isLeader ? 3 : 2,
                ),
              ),
              child: _MemberAvatar(
                avatarUrl: member.avatarUrl,
                name: member.name,
              ),
            ),
            if (isLeader)
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
                  child: const Icon(Icons.star, color: Colors.white, size: 9),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            member.id == currentUserId ? 'You' : member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.avatarUrl, required this.name});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarUrl.trim();
    if (avatar.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatar),
        onBackgroundImageError: (_, __) {},
      );
    }

    final initial =
        name.trim().isEmpty ? 'R' : name.trim().substring(0, 1).toUpperCase();
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
}
