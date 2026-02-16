import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF4EFEA),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Column(

                children: [

                  const SizedBox(height: 40),

                  /// LOGO BOX

                  Container(

                    width: 80,
                    height: 80,

                    decoration: BoxDecoration(

                      color: const Color(0xFFD97706).withOpacity(0.1),

                      borderRadius: BorderRadius.circular(20),

                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset("assets/logo.png"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// TITLE

                  const Text(
                    "JourneySync",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Coordinate your next ride.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// PHONE FIELD

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Mobile Number",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextField(

                    controller: phoneController,

                    keyboardType: TextInputType.phone,

                    decoration: InputDecoration(

                      hintText: "Enter phone number",

                      filled: true,

                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// CONTINUE BUTTON

                  SizedBox(

                    width: double.infinity,

                    child: ElevatedButton(

                      onPressed: () {

                        print(phoneController.text);

                      },

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFFD97706),

                        padding: const EdgeInsets.all(16),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      child: const Text(
                        "Continue",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                ],
              ),

              /// FOOTER

              const Text(
                "By continuing, you agree to Terms and Privacy Policy.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
