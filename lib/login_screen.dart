import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final bikeController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    bikeController.dispose();
    super.dispose();
  }

  Future<void> saveAndContinue() async {

    final name = nameController.text.trim();
    final bike = bikeController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter name and phone"),
        ),
      );

      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', name);
    await prefs.setString('userBike', bike);
    await prefs.setString('userPhone', phone);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    const primary = Color(0xFFDB7706);
    const forest = Color(0xFF1E3A2F);

    return Scaffold(

      backgroundColor: const Color(0xFFF8F7F5),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Column(

                children: [

                  const SizedBox(height: 20),

                  /// LOGO

                  Container(

                    width: 80,
                    height: 80,

                    decoration: BoxDecoration(

                      color: primary.withOpacity(0.1),

                      borderRadius: BorderRadius.circular(20),

                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset("assets/logo.png"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "JourneySync",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: forest,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text("Coordinate your next ride."),

                  const SizedBox(height: 20),

                  /// NAME

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: "Full Name",
                      filled: true,
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// BIKE

                  TextField(
                    controller: bikeController,
                    decoration: const InputDecoration(
                      hintText: "Bike Model",
                      filled: true,
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// PHONE

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "Phone Number",
                      filled: true,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// CONTINUE BUTTON

                  SizedBox(

                    width: double.infinity,

                    child: ElevatedButton(

                      onPressed: saveAndContinue,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.all(16),
                      ),

                      child: const Text("Continue"),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// EMAIL LOGIN BUTTON

                  SizedBox(

                    width: double.infinity,

                    child: OutlinedButton(

                      onPressed: saveAndContinue,

                      child: const Text("Log in with Email"),

                    ),

                  ),

                ],
              ),

              const Padding(

                padding: EdgeInsets.only(bottom: 20),

                child: Text(
                  "By continuing, you agree to Terms and Privacy Policy.",
                ),

              )

            ],
          ),
        ),
      ),
    );
  }
}
