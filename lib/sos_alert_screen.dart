import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosAlertScreen extends StatefulWidget {
  const SosAlertScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  Map<String, dynamic>? ride;
  String loadError = "";
  String userPhone = "";
  String userId = "";
  String userName = "Rider";
  String userBike = "No bike added";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userPhone = prefs.getString("userPhone") ?? "";
      userId = prefs.getString("userId") ?? "";
      userName = prefs.getString("userName") ?? "Rider";
      userBike = prefs.getString("userBike") ?? "No bike added";

      final data =
          await supabase
              .from('rides')
              .select()
              .eq('id', widget.rideId)
              .maybeSingle();

      if (data == null) {
        if (!mounted) return;
        setState(() {
          loadError = "SOS data unavailable for this ride.";
          loading = false;
        });
        return;
      }

      await _hydrateAlertFallbackFromUser(data);
      if (!mounted) return;
      setState(() {
        ride = data;
        loadError = "";
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = "Could not load SOS details.";
        loading = false;
      });
    }
  }

  bool get isSelfAlert {
    final alertBy = ride?['alert_by']?.toString() ?? "";
    return alertBy.isNotEmpty && alertBy == userPhone;
  }

  String _alertName() {
    final name = ride?['alert_by_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return userName.trim().isEmpty ? "Rider" : userName.trim();
  }

  String _alertBike() {
    final bike = ride?['alert_by_bike']?.toString().trim();
    if (bike != null && bike.isNotEmpty) return bike;
    return userBike.trim().isEmpty ? "" : userBike.trim();
  }

  String _alertSince() {
    final raw = ride?['alert_at']?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return "Time unavailable";
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    final hours = diff.inHours;
    return "${hours}h ago";
  }

  String _coords() {
    final lat = ride?['alert_lat'] ?? ride?['lat'] ?? ride?['start_lat'];
    final lng = ride?['alert_lng'] ?? ride?['lng'] ?? ride?['start_lng'];
    if (lat == null || lng == null) return "Coordinates unavailable";
    return _toDms(lat, lng);
  }

  String _toDms(dynamic lat, dynamic lng) {
    double? latD =
        lat is num ? lat.toDouble() : double.tryParse(lat.toString());
    double? lngD =
        lng is num ? lng.toDouble() : double.tryParse(lng.toString());
    if (latD == null || lngD == null) return "Coordinates unavailable";
    String latDir = latD >= 0 ? "N" : "S";
    String lngDir = lngD >= 0 ? "E" : "W";
    latD = latD.abs();
    lngD = lngD.abs();
    String latStr = _dms(latD);
    String lngStr = _dms(lngD);
    return "$latDir $latStr  $lngDir $lngStr";
  }

  String _dms(double value) {
    final deg = value.floor();
    final minFloat = (value - deg) * 60;
    final min = minFloat.floor();
    final sec = ((minFloat - min) * 60);
    return "$deg deg ${min.toString().padLeft(2, '0')}.${sec.toStringAsFixed(0).padLeft(2, '0')}'";
  }

  String _alertValue(List<String> keys, {String fallback = "--"}) {
    for (final key in keys) {
      final value = ride?[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Future<void> _hydrateAlertFallbackFromUser(Map<String, dynamic> row) async {
    final hasAlertIdentity =
        (row['alert_by_name'] ?? '').toString().trim().isNotEmpty &&
        (row['alert_by_bike'] ?? '').toString().trim().isNotEmpty;
    if (hasAlertIdentity) return;

    final fallbackUserId =
        (row['alert_user_id'] ??
                row['creator_id'] ??
                row['user_id'] ??
                row['leader_id'])
            .toString()
            .trim();
    final targetUserId =
        fallbackUserId.isEmpty ? userId.trim() : fallbackUserId;
    if (targetUserId.isEmpty) return;

    try {
      final raw = await supabase
          .from('users')
          .select('id,name,bike,phone')
          .eq('id', targetUserId)
          .limit(1);
      final userRows = List<Map<String, dynamic>>.from(raw);
      if (userRows.isEmpty) return;
      final user = userRows.first;
      row['alert_by_name'] ??= user['name'];
      row['alert_by_bike'] ??= user['bike'];
      row['alert_by'] ??= user['phone'];
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFC72929);
    const primaryDark = Color(0xFF9B1C1C);
    const secondary = Color(0xFFD97706);
    const tertiary = Color(0xFF166534);
    const sand = Color(0xFFF8F6F6);
    const sandWarm = Color(0xFFEFECE9);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError.isNotEmpty) {
      return Scaffold(
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
      backgroundColor: sand,
      body: Stack(
        children: [
          Column(
            children: [
              _banner(primary),
              Expanded(
                child: Stack(
                  children: [
                    _mapLayer(tertiary, primary),
                    _floatingStats(primary, sandWarm, tertiary),
                    _mapControls(),
                  ],
                ),
              ),
              _bottomPanel(
                primary,
                primaryDark,
                secondary,
                tertiary,
                sandWarm,
                isSelfAlert,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(Color primary) {
    return Container(
      color: primary,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelfAlert ? "ALERT SENT" : "RIDER DOWN",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    isSelfAlert
                        ? "Help is on the way"
                        : "Signal detected ${_alertSince()}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _mapLayer(Color tertiary, Color primary) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: const Color(0xFFE6E3DD))),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.35,
          left: MediaQuery.of(context).size.width * 0.4,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(Icons.navigation, size: 16, color: tertiary),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: MediaQuery.of(context).size.width * 0.3,
          child: _sosMarker(primary),
        ),
      ],
    );
  }

  Widget _sosMarker(Color primary) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _pulseRing(primary),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: primary.withValues(alpha: 0.5), blurRadius: 16),
            ],
          ),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _pulseRing(Color primary) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: 1 - value,
          child: Transform.scale(
            scale: 3 * value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
      onEnd: () => setState(() {}),
    );
  }

  Widget _floatingStats(Color primary, Color sandWarm, Color tertiary) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sandWarm.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: primary, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TARGET COORDINATES",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _coords(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 28, color: Colors.grey.shade300),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "ELEVATION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _alertValue(const [
                    'alert_elevation',
                    'elevation',
                  ], fallback: '--'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapControls() {
    return Positioned(
      top: 90,
      right: 12,
      child: Column(
        children: [
          _mapControlButton(Icons.my_location),
          const SizedBox(height: 10),
          _mapControlButton(Icons.layers),
        ],
      ),
    );
  }

  Widget _mapControlButton(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12),
        ],
      ),
      child: Icon(icon, color: Colors.grey.shade700),
    );
  }

  Widget _bottomPanel(
    Color primary,
    Color primaryDark,
    Color secondary,
    Color tertiary,
    Color sandWarm,
    bool isSelf,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: sandWarm,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _alertName(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            isSelf ? "ALERT ACTIVE" : "NO MOVEMENT",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSelf
                              ? "You sent the alert"
                              : "Since ${_alertSince()}",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_alertBike().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _alertBike(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _alertValue(const [
                      'alert_distance',
                      'distance_km',
                    ], fallback: '--'),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    "Straight Line",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile(
                "Phone Bat",
                _alertValue(const ['alert_battery', 'battery'], fallback: '--'),
              ),
              const SizedBox(width: 10),
              _statTile(
                "Speed (mph)",
                _alertValue(const [
                  'alert_speed',
                  'speed_mph',
                  'speed',
                ], fallback: '--'),
              ),
              const SizedBox(width: 10),
              _statTile(
                "Signal",
                _alertValue(const ['alert_signal', 'signal'], fallback: '--'),
                highlight: tertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isSelf)
            Column(
              children: [
                _primaryButton(
                  label: "Navigate to Rider",
                  icon: Icons.near_me,
                  color: primary,
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _secondaryButton(
                        label: "Call Rider",
                        icon: Icons.call,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _outlinedButton(
                        label: "SOS Services",
                        icon: Icons.sos,
                        color: primary,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                _primaryButton(
                  label: "Cancel Alert",
                  icon: Icons.cancel,
                  color: primaryDark,
                  onTap: () async {
                    try {
                      await supabase
                          .from('rides')
                          .update({'alert_status': 'cleared'})
                          .eq('id', widget.rideId);
                    } catch (_) {
                      // If this column is not present in DB, keep UI usable.
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),
                _secondaryButton(
                  label: "Call Emergency Services",
                  icon: Icons.call,
                  onTap: () {},
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, {Color? highlight}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: highlight ?? Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, color: Colors.black87),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _outlinedButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
