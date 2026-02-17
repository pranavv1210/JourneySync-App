import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ride_lobby_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController rideNameController = TextEditingController();
  final TextEditingController rideDescController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<void> createRide() async {
    final rideName = rideNameController.text.trim();
    final rideDesc = rideDescController.text.trim();
    final destination = destinationController.text.trim();

    if (rideName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter ride name")));
      return;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter destination")));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final leaderPhone = prefs.getString("userPhone") ?? "";
    String leaderId = prefs.getString("userId") ?? "";

    if (!_looksLikeUuid(leaderId) && _looksLikeUuid(leaderPhone)) {
      leaderId = leaderPhone;
    }

    if (!_looksLikeUuid(leaderId) && leaderPhone.isNotEmpty) {
      try {
        final userRow =
            await supabase
                .from('users')
                .select('id')
                .eq('phone', leaderPhone)
                .maybeSingle();
        leaderId = userRow?['id']?.toString() ?? "";
        if (_looksLikeUuid(leaderId)) {
          await prefs.setString("userId", leaderId);
        }
      } catch (_) {}
    }

    if (!_looksLikeUuid(leaderId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID missing. Please login again.")),
      );
      return;
    }

    final payload = <String, dynamic>{
      'name': rideName,
      'leader_id': leaderId,
      'status': 'waiting',
      'description': rideDesc,
      'destination': destination,
      'leader_phone': leaderPhone,
    };

    late final Map<String, dynamic> ride;
    try {
      ride = await supabase.from('rides').insert(payload).select().single();
    } catch (_) {
      payload.remove('leader_phone');
      ride = await supabase.from('rides').insert(payload).select().single();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Ride created successfully")));

    rideNameController.clear();
    rideDescController.clear();
    destinationController.clear();

    final rideId = ride['id']?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideLobbyScreen(rideId: rideId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFDA620B);
    const primaryDark = Color(0xFFB04D08);
    const background = Color(0xFFF8F7F5);
    const forest = Color(0xFF1E3A29);
    const neutralWarm = Color(0xFF8A817C);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(forest, neutralWarm),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textField(
                          label: "Ride Name",
                          controller: rideNameController,
                          hint: "Ride Name",
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 18),
                        _textField(
                          label: "Description (Optional)",
                          controller: rideDescController,
                          hint: "Description",
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        _destinationBlock(
                          forest: forest,
                          primary: primary,
                          neutralWarm: neutralWarm,
                          background: background,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _footerAction(primary, primaryDark, background),
        ],
      ),
    );
  }

  Widget _header(Color forest, Color neutralWarm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(fontWeight: FontWeight.w600, color: neutralWarm),
            ),
          ),
          Text(
            "New Ride",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: forest,
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color forest,
    required Color primary,
    required Color neutralWarm,
    required Color background,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: forest, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        hintStyle: TextStyle(color: neutralWarm),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _destinationBlock({
    required Color forest,
    required Color primary,
    required Color neutralWarm,
    required Color background,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DESTINATION",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: forest.withOpacity(0.8),
              ),
            ),
            Text(
              "Edit Route",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: destinationController,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: forest,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search location",
                          hintStyle: TextStyle(color: neutralWarm),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.asset(
                        "assets/pattern.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, forest.withOpacity(0.6)],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: primary, size: 36),
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Current Selection",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Text(
                      destinationController.text.isEmpty
                          ? "Select a destination"
                          : destinationController.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footerAction(Color primary, Color primaryDark, Color background) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [background.withOpacity(0), background],
          ),
        ),
        child: ElevatedButton(
          onPressed: createRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: primary.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Go Live",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    rideNameController.dispose();
    rideDescController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }
}
