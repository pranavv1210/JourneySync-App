import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = '';
  String userBike = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? '';
      userBike = prefs.getString('userBike') ?? '';
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userName');
    await prefs.remove('userBike');
    await prefs.remove('userPhone');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SizedBox()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFD46211);
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard', style: GoogleFonts.plusJakartaSans()),
        backgroundColor: primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName.isNotEmpty ? 'Ready to roll, $userName!' : 'Ready to roll!',
              style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              userBike.isNotEmpty ? 'Your ride: $userBike' : 'Tell us about your bike from settings',
              style: GoogleFonts.plusJakartaSans(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              child: Text('Sign out', style: GoogleFonts.plusJakartaSans()),
            ),
          ],
        ),
      ),
    );
  }
}
