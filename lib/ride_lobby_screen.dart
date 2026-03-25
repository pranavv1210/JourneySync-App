import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_toast.dart';
import 'live_ride_screen.dart';

class RideLobbyScreen extends StatefulWidget {
  const RideLobbyScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideLobbyScreen> createState() => _RideLobbyScreenState();
}

class _RideLobbyScreenState extends State<RideLobbyScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? ride;
  String userName = "Rider";
  String userBike = "No bike added";
  String userPhone = "";
  String userAvatarUrl = "";
  String currentUserId = "";
  int maxRiders = 20;
  bool joinRequestFeatureAvailable = true;
  List<_LobbyMember> crew = <_LobbyMember>[];
  List<_LobbyRequest> pendingRequests = <_LobbyRequest>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString("userName") ?? "Rider";
    userBike = prefs.getString("userBike") ?? "No bike added";
    userPhone = prefs.getString("userPhone") ?? "";
    userAvatarUrl = prefs.getString("userAvatarUrl") ?? "";
    currentUserId = (prefs.getString("userId") ?? "").trim();

    final data =
        await supabase.from('rides').select().eq('id', widget.rideId).single();
    final resolvedMax =
        int.tryParse((data['max_riders'] ?? '').toString()) ?? 20;
    final safeMax = resolvedMax < 1 ? 20 : resolvedMax;

    final loadedCrew = await _fetchCrew(data);
    final loadedRequests = await _fetchPendingJoinRequests();

    setState(() {
      ride = data;
      maxRiders = safeMax;
      crew = loadedCrew;
      pendingRequests = loadedRequests;
      loading = false;
    });
  }

  Future<List<_LobbyMember>> _fetchCrew(Map<String, dynamic> rideRow) async {
    final ids = <String>{};
    final hostId = _hostIdFromRow(rideRow);
    if (hostId.isNotEmpty) ids.add(hostId);

    try {
      final participantRows = await supabase
          .from('participants')
          .select('user_id')
          .eq('ride_id', widget.rideId);
      for (final row in participantRows) {
        final userId = (row['user_id'] ?? '').toString().trim();
        if (userId.isNotEmpty) ids.add(userId);
      }
    } catch (_) {
      // Keep lobby usable even if participants table is unavailable.
    }

    if (ids.isEmpty && currentUserId.isNotEmpty) {
      ids.add(currentUserId);
    }

    final profiles = await _fetchUserProfiles(ids.toList());
    final members =
        ids.map((id) {
          final profile = profiles[id];
          return _LobbyMember(
            id: id,
            name:
                (profile?['name'] ?? (id == currentUserId ? userName : 'Rider'))
                    .toString(),
            bike:
                (profile?['bike'] ??
                        (id == currentUserId ? userBike : 'No bike added'))
                    .toString(),
            avatarUrl:
                ((profile?['avatar_url'] ?? '').toString().trim().isNotEmpty
                        ? (profile?['avatar_url'] ?? '').toString()
                        : (id == currentUserId ? userAvatarUrl : ''))
                    .toString(),
            isHost: id == hostId,
          );
        }).toList();

    members.sort((a, b) {
      if (a.isHost && !b.isHost) return -1;
      if (!a.isHost && b.isHost) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return members;
  }

  Future<List<_LobbyRequest>> _fetchPendingJoinRequests() async {
    try {
      final rows = await supabase
          .from('join_requests')
          .select('id,user_id,status,created_at')
          .eq('ride_id', widget.rideId)
          .eq('status', 'pending')
          .order('created_at');

      final userIds =
          rows
              .map((row) => (row['user_id'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      final profiles = await _fetchUserProfiles(userIds);

      joinRequestFeatureAvailable = true;
      return rows.map((row) {
        final id = (row['id'] ?? '').toString();
        final userId = (row['user_id'] ?? '').toString().trim();
        final profile = profiles[userId];
        return _LobbyRequest(
          id: id,
          userId: userId,
          name: (profile?['name'] ?? 'Rider').toString(),
          bike: (profile?['bike'] ?? 'No bike added').toString(),
          avatarUrl: (profile?['avatar_url'] ?? '').toString(),
        );
      }).toList();
    } on PostgrestException catch (error) {
      if (_isMissingJoinRequestSchema(error)) {
        joinRequestFeatureAvailable = false;
        return <_LobbyRequest>[];
      }
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUserProfiles(
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
      if (_isMissingAvatarColumn(error)) {
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

  String _hostIdFromRow(Map<String, dynamic> row) {
    return (row['creator_id'] ?? row['leader_id'] ?? row['user_id'] ?? '')
        .toString()
        .trim();
  }

  String _rideCode(String id) {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return "JS-0000";
    final tail =
        cleaned.length >= 4 ? cleaned.substring(cleaned.length - 4) : cleaned;
    return "JS-$tail";
  }

  String _rideTitle() {
    final name = (ride?['title'] ?? ride?['name'])?.toString().trim();
    return (name == null || name.isEmpty) ? "New Ride" : name;
  }

  String _destinationLabel() {
    final dest =
        (ride?['end_location'] ?? ride?['destination'])?.toString().trim();
    return (dest == null || dest.isEmpty) ? "Destination not set" : dest;
  }

  String _startLocationLabel() {
    final start =
        (ride?['start_location'] ?? ride?['start'])?.toString().trim();
    return (start == null || start.isEmpty) ? "Start not set" : start;
  }

  String _description() {
    final desc = (ride?['description'] ?? ride?['briefing'])?.toString().trim();
    return (desc == null || desc.isEmpty) ? "No briefing added yet." : desc;
  }

  String _timeLabel() {
    final status = (ride?['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'active' && status != 'live' && status != 'ended' && status != 'completed') {
      return "Pending Start";
    }
    final raw =
        ride?['start_time']?.toString() ??
        ride?['started_at']?.toString() ??
        ride?['created_at']?.toString();
    if (raw == null || raw.isEmpty) return "--:--";
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return "--:--";
    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? "PM" : "AM";
    return "$hour12:$minute $suffix";
  }

  String _routeStripLabel() {
    return "${_startLocationLabel()} -> ${_destinationLabel()}";
  }

  LatLng? _parseLatLng(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  LatLng _lobbyMapCenter() {
    final start = _parseLatLng(_startLocationLabel());
    if (start != null) return start;
    final end = _parseLatLng(_destinationLabel());
    if (end != null) return end;
    return const LatLng(20.5937, 78.9629);
  }

  String _dateLabel() {
    final raw =
        ride?['created_at']?.toString() ??
        ride?['started_at']?.toString() ??
        ride?['start_time']?.toString();
    if (raw == null || raw.isEmpty) return "Date not set";
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return "Date not set";
    final local = parsed.toLocal();
    return "${_month(local.month)} ${local.day}";
  }

  String _month(int m) {
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
    return months[(m - 1).clamp(0, 11)];
  }

  Future<void> _startRide() async {
    try {
      await supabase
          .from('rides')
          .update({
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.rideId);
    } catch (_) {
      await supabase
          .from('rides')
          .update({'status': 'active'})
          .eq('id', widget.rideId);
    }
    if (!mounted) return;
    showAppToast(context, "Ride started", type: AppToastType.success);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LiveRideScreen(rideId: widget.rideId)),
    );
  }

  Future<void> _approveJoinRequest(_LobbyRequest request) async {
    if (!joinRequestFeatureAvailable) {
      _showInfo("Join requests are not configured in database.");
      return;
    }
    try {
      await supabase
          .from('join_requests')
          .update({'status': 'approved'})
          .eq('id', request.id);
      try {
        await supabase.from('participants').insert({
          'ride_id': widget.rideId,
          'user_id': request.userId,
        });
      } on PostgrestException catch (error) {
        if ((error.code ?? '').trim() != '23505') rethrow;
      }
      await _reloadLobbyData();
    } catch (error) {
      _showInfo("Could not approve request: $error");
    }
  }

  Future<void> _rejectJoinRequest(_LobbyRequest request) async {
    if (!joinRequestFeatureAvailable) {
      _showInfo("Join requests are not configured in database.");
      return;
    }
    try {
      await supabase
          .from('join_requests')
          .update({'status': 'rejected'})
          .eq('id', request.id);
      await _reloadLobbyData();
    } catch (error) {
      _showInfo("Could not reject request: $error");
    }
  }

  Future<void> _reloadLobbyData() async {
    if (!mounted) return;
    setState(() => loading = true);
    await _loadData();
  }

  bool _isCurrentUserHost() {
    final hostId = _hostIdFromRow(ride ?? const <String, dynamic>{});
    return hostId.isNotEmpty && hostId == currentUserId;
  }

  Future<void> _copyAccessCode() async {
    final code = _rideCode(widget.rideId);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    showAppToast(context, "Code copied", type: AppToastType.success);
  }

  Future<void> _showInviteActions() async {
    final code = _rideCode(widget.rideId);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Riders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this access code. Riders can join from Nearby Active Rides -> key icon.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await _copyAccessCode();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy access code'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editBriefing() async {
    if (!_isCurrentUserHost()) {
      _showInfo('Only host can edit ride briefing.');
      return;
    }
    final initial =
        (ride?['description'] ?? ride?['briefing'] ?? '').toString().trim();
    final controller = TextEditingController(text: initial);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Ride Briefing'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 400,
            decoration: const InputDecoration(
              hintText: 'Add instructions for your group',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      controller.dispose();
      return;
    }

    final text = controller.text.trim();
    controller.dispose();
    try {
      try {
        await supabase
            .from('rides')
            .update({'description': text})
            .eq('id', widget.rideId);
      } on PostgrestException catch (error) {
        if (!_isMissingDescriptionColumn(error)) rethrow;
        await supabase
            .from('rides')
            .update({'briefing': text})
            .eq('id', widget.rideId);
      }
      await _reloadLobbyData();
      _showInfo('Ride briefing updated.');
    } catch (error) {
      _showInfo('Could not update briefing: $error');
    }
  }

  Future<void> _editRideDetailsDialog() async {
    if (!_isCurrentUserHost()) {
      _showInfo('Only host can edit ride details.');
      return;
    }
    final titleCtrl = TextEditingController(text: _rideTitle());
    final destCtrl = TextEditingController(text: _destinationLabel());
    final maxRidersCtrl = TextEditingController(text: (ride?['max_riders'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Ride Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Ride Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: destCtrl,
                  decoration: const InputDecoration(labelText: 'Destination'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxRidersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Riders (leave blank for unlimited)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final title = titleCtrl.text.trim();
    final dest = destCtrl.text.trim();
    final maxR = int.tryParse(maxRidersCtrl.text.trim());

    try {
      await supabase.from('rides').update({
        'title': title,
        'end_location': dest,
        'max_riders': maxR,
      }).eq('id', widget.rideId);
      await _reloadLobbyData();
      _showInfo('Ride details updated.');
    } catch (error) {
      try {
        await supabase.from('rides').update({
          'name': title,
          'destination': dest,
        }).eq('id', widget.rideId);
        await _reloadLobbyData();
        _showInfo('Ride details updated.');
      } catch (nested) {
        _showInfo('Could not update details: $error');
      }
    }
  }

  void _showInfo(String message) {
    if (!mounted) return;
    showAppToast(context, message, type: AppToastType.info);
  }

  bool _isMissingAvatarColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('avatar_url');
  }

  bool _isMissingJoinRequestSchema(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42P01' ||
        code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('join_requests');
  }

  bool _isMissingDescriptionColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('description');
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF26C0D);
    const primaryDark = Color(0xFFC05306);
    const background = Color(0xFFF8F7F5);
    const forest = Color(0xFF1F4A33);
    const sand = Color(0xFFE8E4DB);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _topBar(primary),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rideDetailsCard(primary, forest, sand),
                        const SizedBox(height: 16),
                        _joinCode(primary),
                        const SizedBox(height: 16),
                        _joinRequests(primary),
                        const SizedBox(height: 16),
                        _participants(primary, forest),
                        const SizedBox(height: 16),
                        _briefing(forest),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bottomActions(primary, primaryDark),
        ],
      ),
    );
  }

  Widget _topBar(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 24),
          ),
          Text(
            "LOBBY",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: primary,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, size: 24),
            onSelected: (value) async {
              switch (value) {
                case 'copy_code':
                  await _copyAccessCode();
                  break;
                case 'edit_briefing':
                  await _editBriefing();
                  break;
                case 'refresh':
                  await _reloadLobbyData();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'copy_code',
                    child: Text('Copy Access Code'),
                  ),
                  if (_isCurrentUserHost())
                    const PopupMenuItem(
                      value: 'edit_briefing',
                      child: Text('Edit Ride Briefing'),
                    ),
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                ],
          ),
        ],
      ),
    );
  }

  Widget _rideDetailsCard(Color primary, Color forest, Color sand) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _lobbyMapPreview(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    _badge(Icons.calendar_today, _dateLabel(), primary),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rideTitle(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeLabel(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.place,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _destinationLabel(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: sand.withValues(alpha: 0.6)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.route, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _routeStripLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: forest,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lobbyMapPreview() {
    final start = _parseLatLng(_startLocationLabel());
    final end = _parseLatLng(_destinationLabel());
    final center = start ?? end ?? _lobbyMapCenter();

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: (start != null || end != null) ? 12.5 : 5,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.journeysync',
        ),
        if (start != null || end != null)
          MarkerLayer(
            markers: [
              if (start != null)
                Marker(
                  point: start,
                  width: 34,
                  height: 34,
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
              if (end != null)
                Marker(
                  point: end,
                  width: 34,
                  height: 34,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.deepOrange,
                    size: 28,
                  ),
                ),
            ],
          ),
        if (start != null && end != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [start, end],
                strokeWidth: 4,
                color: Colors.deepOrange.withValues(alpha: 0.75),
              ),
            ],
          ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinCode(Color primary) {
    final code = _rideCode(widget.rideId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            "RIDE ACCESS CODE",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _copyAccessCode,
                tooltip: 'Copy access code',
                icon: const Icon(Icons.content_copy, size: 20),
                color: primary,
              ),
            ],
          ),
          Text(
            "Share this code with your riding group",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinRequests(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      "Join Requests",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${pendingRequests.length} Pending",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!joinRequestFeatureAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Text(
                "Join requests are not configured in database yet.",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (pendingRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Text(
                "No join requests yet.",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...pendingRequests.map((request) {
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    _avatar(url: request.avatarUrl, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            request.bike,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _rejectJoinRequest(request),
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.red.shade500,
                    ),
                    IconButton(
                      onPressed: () => _approveJoinRequest(request),
                      icon: const Icon(Icons.check, size: 18),
                      color: primary,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _participants(Color primary, Color forest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "The Crew",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              "${crew.length}/$maxRiders",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: crew.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            if (index == crew.length) return _inviteCard(primary);
            return _participantCard(
              member: crew[index],
              primary: primary,
              forest: forest,
            );
          },
        ),
      ],
    );
  }

  Widget _participantCard({
    required _LobbyMember member,
    required Color primary,
    required Color forest,
  }) {
    final isCurrent = member.id.isNotEmpty && member.id == currentUserId;
    final displayName = isCurrent ? "You" : member.name;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: member.isHost ? primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              _avatar(url: member.avatarUrl, radius: 28),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: forest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(displayName, style: TextStyle(fontWeight: FontWeight.w800)),
          Text(
            member.bike,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (member.isHost)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "HOST",
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _inviteCard(Color primary) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _showInviteActions,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.add, color: primary),
              ),
              const SizedBox(height: 8),
              Text(
                "Invite",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _briefing(Color forest) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isCurrentUserHost() ? _editBriefing : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: forest.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: forest.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info, color: forest),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ride Briefing",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (_isCurrentUserHost()) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Tap to add or edit briefing",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _description(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCurrentUserHost())
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomActions(Color primary, Color primaryDark) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: primary.withValues(alpha: 0.25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.two_wheeler, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      "START RIDE",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _editRideDetailsDialog,
              child: Text(
                "EDIT RIDE DETAILS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbyMember {
  const _LobbyMember({
    required this.id,
    required this.name,
    required this.bike,
    required this.avatarUrl,
    required this.isHost,
  });

  final String id;
  final String name;
  final String bike;
  final String avatarUrl;
  final bool isHost;
}

class _LobbyRequest {
  const _LobbyRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.bike,
    required this.avatarUrl,
  });

  final String id;
  final String userId;
  final String name;
  final String bike;
  final String avatarUrl;
}
