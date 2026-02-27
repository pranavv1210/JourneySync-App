import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
            avatarUrl: (profile?['avatar_url'] ?? '').toString(),
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
    final raw =
        ride?['start_time']?.toString() ??
        ride?['started_at']?.toString() ??
        ride?['created_at']?.toString();
    if (raw == null || raw.isEmpty) return "--:--";
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return "--:--";
    final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? "PM" : "AM";
    return "$hour12:$minute $suffix";
  }

  String _routeStripLabel() {
    return "${_startLocationLabel()} -> ${_destinationLabel()}";
  }

  String _dateLabel() {
    final raw = ride?['created_at']?.toString();
    if (raw == null || raw.isEmpty) return "Date not set";
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return "Date not set";
    return "${_month(parsed.month)} ${parsed.day}";
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Ride started")));
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
            ),
          ),
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 24),
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
            color: Colors.black.withOpacity(0.08),
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
                  child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
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
                    const SizedBox(width: 8),
                    _badge(Icons.wb_sunny, "—", forest),
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
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeLabel(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.place,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _destinationLabel(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
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
              border: Border(top: BorderSide(color: sand.withOpacity(0.6))),
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

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
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
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            "RIDE ACCESS CODE",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: primary.withOpacity(0.8),
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
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Code copied")));
                },
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
                    color: primary.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.04),
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
      backgroundImage: const AssetImage("assets/profile.png"),
    );
  }

  Widget _inviteCard(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
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
    );
  }

  Widget _briefing(Color forest) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: forest.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: forest.withOpacity(0.1)),
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
        ],
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
          color: Colors.white.withOpacity(0.9),
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
                  shadowColor: primary.withOpacity(0.25),
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
              onPressed: () {
                Navigator.pop(context);
              },
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
