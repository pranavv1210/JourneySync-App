import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ride_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final TextEditingController rideNameController = TextEditingController();
  final TextEditingController rideDescController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final RideService _rideService = RideService();
  bool isCreating = false;

  @override
  void initState() {
    super.initState();
    destinationController.addListener(_onDestinationChanged);
  }

  void _onDestinationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> createRide() async {
    if (isCreating) return;

    final rideName = rideNameController.text.trim();
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

    setState(() {
      isCreating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    try {
      final creatorId = prefs.getString("userId") ?? "";
      if (!_looksLikeUuid(creatorId)) {
        throw Exception("User session missing. Please login again.");
      }

      final startLocation = await _resolveStartLocation();
      await _rideService.createRide(
        creatorId: creatorId,
        title: rideName,
        startLocation: startLocation,
        endLocation: destination,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ride created successfully")),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to create ride: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isCreating = false;
        });
      }
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
          onPressed: isCreating ? null : createRide,
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
              if (isCreating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else ...[
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
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _resolveStartLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return "Unknown start";
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return "Unknown start";
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return "${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}";
    } catch (_) {
      return "Unknown start";
    }
  }

  @override
  void dispose() {
    destinationController.removeListener(_onDestinationChanged);
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
