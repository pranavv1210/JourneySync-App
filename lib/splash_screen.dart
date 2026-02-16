import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    /// START LOADING ANIMATION
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Navigate after 3 seconds
    _navigateToLogin();
  }

  void _navigateToLogin() async {

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF4EFEA),

      body: Stack(

        children: [

          /// BACKGROUND BLOBS

          Positioned(
            top: 150,
            left: 80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: 150,
            right: 80,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          /// MAIN CONTENT

          Center(

            child: Column(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                /// LOGO

                Container(

                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(

                    color: const Color(0xFFD97706),

                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.4),
                        blurRadius: 20,
                      )
                    ],
                  ),

                  child: Image.asset(
                    "assets/logo.png",
                    width: 80,
                  ),
                ),

                const SizedBox(height: 30),

                /// APP NAME

                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Journey",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF2F2F2F),
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: "Sync",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFF26C0D),
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// GRADIENT LINE

                Container(
                  width: 50,
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFD97706),
                        Color(0xFF1B5E20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                /// TAGLINE

                Text(
                  "Ride Together. Ride Safe.",
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF2F2F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 40),

                /// LOADING BAR

                Container(
                  width: 100,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: AnimatedBuilder(

                    animation: controller,

                    builder: (_, __) {

                      return FractionallySizedBox(

                        alignment: Alignment.centerLeft,

                        widthFactor: controller.value,

                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 15),

                /// VERSION

                Text(
                  "v1.0.2 Beta",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey,
                    fontSize: 12,
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
}
