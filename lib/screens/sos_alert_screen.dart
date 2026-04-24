import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';

class SosAlertScreen extends StatefulWidget {
  const SosAlertScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  bool loading = true;
  bool _useTerrainTiles = false;
  Map<String, dynamic>? ride;
  String loadError = "";
  String userPhone = "";
  String userId = "";
  String userName = "Rider";
  String userBike = "No bike added";
  String userAvatarUrl = "";
  Position? _currentPosition;

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
      userAvatarUrl = prefs.getString("userAvatarUrl") ?? "";

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
      await _loadCurrentPosition();

      if (!mounted) return;
      setState(() {
        ride = data;
        loadError = "";
        loading = false;
      });
      _fitMapToAlert();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = "Could not load SOS details.";
        loading = false;
      });
    }
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {}
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

  String _alertPhone() {
    final phone = ride?['alert_by']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return userPhone.trim();
  }

  String _alertAvatarUrl() {
    final avatar = ride?['alert_by_avatar_url']?.toString().trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    return isSelfAlert ? userAvatarUrl.trim() : "";
  }

  DateTime? _alertAt() {
    final candidates = [
      ride?['alert_at'],
      ride?['location_updated_at'],
      ride?['created_at'],
    ];
    for (final raw in candidates) {
      final parsed = DateTime.tryParse((raw ?? '').toString());
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  String _alertSince() {
    final parsed = _alertAt();
    if (parsed == null) return "just now";
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  String _signalDetectedLabel() {
    final parsed = _alertAt();
    if (parsed == null) return "Signal detected recently";
    final time =
        "${parsed.hour % 12 == 0 ? 12 : parsed.hour % 12}:${parsed.minute.toString().padLeft(2, '0')} ${parsed.hour >= 12 ? 'PM' : 'AM'}";
    return "Signal detected $_alertSince() • $time";
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  LatLng? _alertLatLng() {
    final lat = _toDouble(
      ride?['alert_lat'] ??
          ride?['current_lat'] ??
          ride?['lat'] ??
          ride?['start_lat'],
    );
    final lng = _toDouble(
      ride?['alert_lng'] ??
          ride?['current_lng'] ??
          ride?['lng'] ??
          ride?['start_lng'],
    );
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _coords() {
    final point = _alertLatLng();
    if (point == null) return "Waiting for live coordinates";
    return "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
  }

  String _elevationLabel() {
    final raw = _alertValue(const ['alert_elevation', 'elevation']);
    if (raw != null) return raw;
    return "Live";
  }

  String? _alertValue(List<String> keys) {
    for (final key in keys) {
      final value = ride?[key];
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _distanceLabel() {
    final current = _currentPosition;
    final target = _alertLatLng();
    if (current == null || target == null) return "Live";
    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      target.latitude,
      target.longitude,
    );
    if (meters < 1000) return "${meters.round()} m";
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  String _batteryLabel() {
    return _alertValue(const ['alert_battery', 'battery']) ?? "N/A";
  }

  String _speedLabel() {
    final speed = _toDouble(
      ride?['alert_speed'] ?? ride?['speed_kmh'] ?? ride?['speed'],
    );
    if (speed != null && speed >= 0) {
      return "${speed.round()} km/h";
    }
    final mps = _toDouble(ride?['current_speed_mps']);
    if (mps != null && mps >= 0) {
      return "${(mps * 3.6).round()} km/h";
    }
    return "0 km/h";
  }

  String _signalLabel() {
    return _alertValue(const ['alert_signal', 'signal']) ?? "Tracked";
  }

  Future<void> _hydrateAlertFallbackFromUser(Map<String, dynamic> row) async {
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
          .select(
            'id,name,bike,phone,avatar_url,current_lat,current_lng,current_speed_mps,location_updated_at',
          )
          .eq('id', targetUserId)
          .limit(1);
      final userRows = List<Map<String, dynamic>>.from(raw);
      if (userRows.isEmpty) return;
      final user = userRows.first;
      row['alert_by_name'] ??= user['name'];
      row['alert_by_bike'] ??= user['bike'];
      row['alert_by'] ??= user['phone'];
      row['alert_by_avatar_url'] ??= user['avatar_url'];
      row['alert_lat'] ??= user['current_lat'];
      row['alert_lng'] ??= user['current_lng'];
      row['current_lat'] ??= user['current_lat'];
      row['current_lng'] ??= user['current_lng'];
      row['current_speed_mps'] ??= user['current_speed_mps'];
      row['alert_at'] ??= user['location_updated_at'];
      row['location_updated_at'] ??= user['location_updated_at'];
    } catch (_) {}
  }

  void _fitMapToAlert() {
    final target = _alertLatLng();
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(target, 15.5);
    });
  }

  Future<void> _focusMyLocation() async {
    if (_currentPosition == null) {
      await _loadCurrentPosition();
    }
    final current = _currentPosition;
    if (current == null) {
      if (!mounted) return;
      showAppToast(
        context,
        'Your current location is unavailable.',
        type: AppToastType.error,
      );
      return;
    }
    _mapController.move(LatLng(current.latitude, current.longitude), 15.5);
  }

  void _focusRiderLocation() {
    final target = _alertLatLng();
    if (target == null) {
      showAppToast(
        context,
        'Rider location is not available yet.',
        type: AppToastType.error,
      );
      return;
    }
    _mapController.move(target, 16);
  }

  Future<void> _launchUri(Uri uri, String failureMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showAppToast(context, failureMessage, type: AppToastType.error);
    }
  }

  Future<void> _navigateToRider() async {
    final target = _alertLatLng();
    if (target == null) {
      showAppToast(
        context,
        'Rider coordinates are not available yet.',
        type: AppToastType.error,
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving',
    );
    await _launchUri(uri, 'Could not open navigation.');
  }

  Future<void> _callRider() async {
    final phone = _alertPhone();
    if (phone.isEmpty) {
      showAppToast(
        context,
        'Rider phone number is not available.',
        type: AppToastType.error,
      );
      return;
    }
    await _launchUri(
      Uri(scheme: 'tel', path: phone),
      'Could not start the call.',
    );
  }

  Future<void> _callEmergencyServices() async {
    await _launchUri(
      Uri(scheme: 'tel', path: '112'),
      'Could not contact emergency services.',
    );
  }

  Future<void> _cancelAlert() async {
    try {
      await supabase
          .from('rides')
          .update({'alert_status': 'cleared'})
          .eq('id', widget.rideId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFC72929);
    const dangerDark = Color(0xFF991B1B);
    const primary = Color(0xFFD46211);
    const forest = Color(0xFF1E3A2F);
    const background = Color(0xFFF8F7F6);
    const panel = Color(0xFFF4F0EB);

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(),
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
      body: Column(
        children: [
          _banner(danger, forest),
          Expanded(
            child: Stack(
              children: [
                _mapLayer(forest, danger),
                _floatingStats(primary, panel),
                _mapControls(primary),
              ],
            ),
          ),
          _bottomPanel(primary, danger, dangerDark, forest, panel, isSelfAlert),
        ],
      ),
    );
  }

  Widget _banner(Color danger, Color forest) {
    return Container(
      color: danger,
      padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelfAlert ? "Alert Active" : "Rider Down",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  isSelfAlert
                      ? "Emergency alert is live"
                      : _signalDetectedLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapLayer(Color forest, Color danger) {
    final target = _alertLatLng();
    final current = _currentPosition;
    final center =
        target ??
        (current != null
            ? LatLng(current.latitude, current.longitude)
            : const LatLng(12.9716, 77.5946));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: target != null ? 15.5 : 13,
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
        if (current != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(current.latitude, current.longitude),
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: forest, width: 2),
                  ),
                  child: Icon(Icons.navigation, color: forest, size: 18),
                ),
              ),
            ],
          ),
        if (target != null)
          MarkerLayer(
            markers: [
              Marker(
                point: target,
                width: 70,
                height: 70,
                child: _sosMarker(danger),
              ),
            ],
          ),
        if (current != null && target != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [LatLng(current.latitude, current.longitude), target],
                color: danger.withValues(alpha: 0.82),
                strokeWidth: 4,
              ),
            ],
          ),
      ],
    );
  }

  Widget _sosMarker(Color danger) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: danger.withValues(alpha: 0.45), blurRadius: 18),
            ],
          ),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 22),
        ),
      ],
    );
  }

  Widget _floatingStats(Color primary, Color panel) {
    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _topStatBlock("Target Coordinates", _coords())),
            Container(width: 1, height: 34, color: Colors.grey.shade300),
            const SizedBox(width: 14),
            _topStatBlock("Elevation", _elevationLabel(), alignEnd: true),
          ],
        ),
      ),
    );
  }

  Widget _topStatBlock(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _mapControls(Color primary) {
    return Positioned(
      right: 14,
      bottom: 22,
      child: Column(
        children: [
          _mapControlButton(Icons.my_location_rounded, onTap: _focusMyLocation),
          const SizedBox(height: 10),
          _mapControlButton(
            Icons.person_pin_circle_rounded,
            onTap: _focusRiderLocation,
          ),
          const SizedBox(height: 10),
          _mapControlButton(
            Icons.layers_rounded,
            onTap: () {
              setState(() {
                _useTerrainTiles = !_useTerrainTiles;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.grey.shade800),
        ),
      ),
    );
  }

  Widget _bottomPanel(
    Color primary,
    Color danger,
    Color dangerDark,
    Color forest,
    Color panel,
    bool isSelf,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _avatarCard(danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _alertName(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _statusChip(
                          isSelf ? "Alert Active" : "Needs Attention",
                          color: danger,
                        ),
                        Text(
                          isSelf
                              ? "You triggered this alert"
                              : "Updated ${_alertSince()}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
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
                    _distanceLabel(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    "From you",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile("Phone Battery", _batteryLabel()),
              const SizedBox(width: 10),
              _statTile("Speed", _speedLabel()),
              const SizedBox(width: 10),
              _statTile("Signal", _signalLabel(), highlight: forest),
            ],
          ),
          const SizedBox(height: 16),
          if (!isSelf) ...[
            _primaryButton(
              label: "Navigate to Rider",
              icon: Icons.near_me_rounded,
              color: danger,
              onTap: _navigateToRider,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _secondaryButton(
                    label: "Call Rider",
                    icon: Icons.call_rounded,
                    onTap: _callRider,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlinedButton(
                    label: "SOS Services",
                    icon: Icons.local_hospital_rounded,
                    color: danger,
                    onTap: _callEmergencyServices,
                  ),
                ),
              ],
            ),
          ] else ...[
            _primaryButton(
              label: "Cancel Alert",
              icon: Icons.cancel_rounded,
              color: dangerDark,
              onTap: _cancelAlert,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              label: "Call Emergency Services",
              icon: Icons.call_rounded,
              onTap: _callEmergencyServices,
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarCard(Color danger) {
    final avatar = _alertAvatarUrl();
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: danger.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child:
            avatar.isNotEmpty
                ? Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback(),
                )
                : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    final initial = _alertName().isEmpty ? 'R' : _alertName()[0].toUpperCase();
    return Container(
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _statusChip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, {Color? highlight}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: highlight ?? Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
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
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
