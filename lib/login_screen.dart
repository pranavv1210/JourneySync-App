import 'package:flutter/material.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;

  String accessToken = "";

  String jwtToken = "";

  String verifiedPhone = "";

  final nameController = TextEditingController();

  final bikeController = TextEditingController();

  final phoneController = TextEditingController();

  final List<TextEditingController> otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool showOtp = false;

  final primary = const Color(0xFFDB7706);
  final forest = const Color(0xFF1E2D24);
  final sandText = const Color(0xFF4A3F35);
  final backgroundLight = const Color(0xFFF8F7F5);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompactHeight = size.height < 720;
    final isTightWidth = size.width < 360;
    final horizontalPad = isTightWidth ? 18.0 : 24.0;
    final sectionGap = isCompactHeight ? 22.0 : 28.0;
    final fieldGap = isCompactHeight ? 14.0 : 18.0;
    final titleSize = isCompactHeight ? 30.0 : 34.0;
    final subtitleSize = isCompactHeight ? 15.0 : 16.0;
    final bottomHeight = isCompactHeight ? 110.0 : 140.0;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      8,
                      horizontalPad,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleBlock(
                          titleSize: titleSize,
                          subtitleSize: subtitleSize,
                        ),
                        SizedBox(height: sectionGap),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child:
                              showOtp
                                  ? _otpForm(
                                    fieldGap: fieldGap,
                                    keyValue: "otp",
                                  )
                                  : _registrationForm(
                                    fieldGap: fieldGap,
                                    keyValue: "reg",
                                  ),
                        ),
                        const SizedBox(height: 24),
                        _primaryAction(),
                        const SizedBox(height: 20),
                        _legalText(),
                        SizedBox(height: sectionGap),
                      ],
                    ),
                  ),
                ),
                _bottomTexture(height: bottomHeight),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 6, color: forest),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    "assets/logo.png",
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "JourneySync",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: sandText,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Icon(Icons.help_outline, color: forest.withOpacity(0.6)),
        ],
      ),
    );
  }

  Widget _titleBlock({
    required double titleSize,
    required double subtitleSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: sandText,
              height: 1.05,
            ),
            children: [
              const TextSpan(text: "Adventure "),
              TextSpan(text: "Awaits", style: TextStyle(color: primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Enter your details to coordinate your next legendary ride.",
          style: TextStyle(
            fontSize: subtitleSize,
            height: 1.5,
            color: sandText.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _registrationForm({
    required double fieldGap,
    required String keyValue,
  }) {
    return Column(
      key: ValueKey(keyValue),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledField(
          label: "Full Name",
          icon: Icons.person,
          controller: nameController,
          hint: "John Doe",
          textInputType: TextInputType.name,
        ),
        SizedBox(height: fieldGap),
        _labeledField(
          label: "Bike Name",
          icon: Icons.two_wheeler,
          controller: bikeController,
          hint: "e.g. Desert Sled",
          textInputType: TextInputType.text,
        ),
        SizedBox(height: fieldGap),
        _labeledField(
          label: "Phone Number",
          icon: Icons.phone_iphone,
          controller: phoneController,
          hint: "+1 (555) 000-0000",
          textInputType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _otpForm({required double fieldGap, required String keyValue}) {
    return Column(
      key: ValueKey(keyValue),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Verification Code",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: forest,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "Resend Code",
                style: TextStyle(fontWeight: FontWeight.w700, color: primary),
              ),
            ),
          ],
        ),
        SizedBox(height: fieldGap - 8),
        Row(
          children: List.generate(6, (index) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                child: TextField(
                  controller: otpControllers[index],
                  focusNode: otpFocusNodes[index],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: forest.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      FocusScope.of(
                        context,
                      ).requestFocus(otpFocusNodes[index + 1]);
                    }
                    if (value.isEmpty && index > 0) {
                      FocusScope.of(
                        context,
                      ).requestFocus(otpFocusNodes[index - 1]);
                    }
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _labeledField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required TextInputType textInputType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: forest,
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: textInputType,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: sandText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: sandText.withOpacity(0.3),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: sandText.withOpacity(0.4)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: forest.withOpacity(0.1), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showOtp)
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  bikeController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill in all fields.")),
                );
                return;
              }
              setState(() => showOtp = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: primary.withOpacity(0.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Continue",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          )
        else
          PhoneLoginButton(
            borderRadius: 16,
            buttonColor: primary,
            label: "Continue",
            onSuccess: (access, jwt) {
              accessToken = access;
              jwtToken = jwt;
              getPhoneNumber();
            },
          ),
      ],
    );
  }

  Widget _legalText() {
    return Text(
      "By continuing, you agree to JourneySync's Terms of Service and Privacy Policy.",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        height: 1.5,
        color: sandText.withOpacity(0.5),
      ),
    );
  }

  Widget _bottomTexture({required double height}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset("assets/pattern.png", fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [backgroundLight.withOpacity(0), backgroundLight],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 4,
              width: 120,
              decoration: BoxDecoration(
                color: forest.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    bikeController.dispose();
    phoneController.dispose();
    for (final controller in otpControllers) {
      controller.dispose();
    }
    for (final node in otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// GET VERIFIED PHONE

  void getPhoneNumber() {
    PhoneEmail.getUserInfo(
      accessToken: accessToken,
      clientId: "12548171843307398404",

      onSuccess: (userData) async {
        verifiedPhone = userData.phoneNumber ?? "";

        await saveUser();
      },
    );
  }

  /// SAVE USER TO SUPABASE

  Future saveUser() async {
    final name = nameController.text.trim();

    final bike = bikeController.text.trim();

    /// SAVE LOCALLY

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("isLoggedIn", true);

    await prefs.setString("userName", name);

    await prefs.setString("userBike", bike);

    await prefs.setString("userPhone", verifiedPhone);

    String userId = "";

    /// SAVE TO SUPABASE

    try {
      final userRow =
          await supabase
              .from('users')
              .upsert({
                'phone': verifiedPhone,

                'name': name,

                'bike': bike,
              }, onConflict: 'phone')
              .select('id')
              .maybeSingle();
      userId = userRow?['id']?.toString() ?? "";
    } catch (_) {
      await supabase.from('users').upsert({
        'phone': verifiedPhone,
        'name': name,
        'bike': bike,
      });
      try {
        final existingUser =
            await supabase
                .from('users')
                .select('id')
                .eq('phone', verifiedPhone)
                .maybeSingle();
        userId = existingUser?['id']?.toString() ?? "";
      } catch (_) {}
    }

    if (_looksLikeUuid(userId)) {
      await prefs.setString("userId", userId);
    } else {
      await prefs.remove("userId");
    }

    /// GO HOME

    if (!mounted) return;
    Navigator.pushReplacement(
      context,

      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }
}
