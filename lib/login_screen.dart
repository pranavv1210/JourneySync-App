import 'package:flutter/material.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

enum AuthMode { newAccount, existingAccount }

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
  bool isSubmitting = false;

  final nameController = TextEditingController();

  final bikeController = TextEditingController();

  AuthMode authMode = AuthMode.existingAccount;
  bool showPhoneVerification = false;

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
                        _accountModeToggle(),
                        const SizedBox(height: 16),
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
                              _showPhoneVerificationStep
                                  ? _phoneVerificationStep(
                                    fieldGap: fieldGap,
                                    keyValue:
                                        "phone_email_${authMode.name}_${verifiedPhone.isNotEmpty}",
                                  )
                                  : _registrationForm(
                                    fieldGap: fieldGap,
                                    keyValue: "reg_${authMode.name}",
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
    final subtitle =
        authMode == AuthMode.newAccount
            ? "Create your profile once, then verify your phone to get started."
            : "Already have an account? Verify your phone and continue instantly.";

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
          subtitle,
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

  Widget _accountModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: forest.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeOption(
              label: "Existing Account",
              selected: authMode == AuthMode.existingAccount,
              onTap: () => _switchAuthMode(AuthMode.existingAccount),
            ),
          ),
          Expanded(
            child: _modeOption(
              label: "New Account",
              selected: authMode == AuthMode.newAccount,
              onTap: () => _switchAuthMode(AuthMode.newAccount),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? forest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: selected ? Colors.white : sandText.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  void _switchAuthMode(AuthMode mode) {
    if (authMode == mode) return;
    setState(() {
      authMode = mode;
      showPhoneVerification = mode == AuthMode.existingAccount;
      verifiedPhone = "";
      accessToken = "";
      jwtToken = "";
    });
  }

  bool get _showPhoneVerificationStep =>
      authMode == AuthMode.existingAccount || showPhoneVerification;

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
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: forest.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Register once, then returning logins only need phone verification (+91).",
                  style: TextStyle(
                    fontSize: 12,
                    color: sandText.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneVerificationStep({
    required double fieldGap,
    required String keyValue,
  }) {
    final helpText =
        authMode == AuthMode.existingAccount
            ? "Verify your mobile number to fetch your profile from JourneySync."
            : "Tap the button below, complete Phone.Email verification, and use an Indian mobile number (+91).";

    return Column(
      key: ValueKey(keyValue),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "VERIFY PHONE",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: forest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helpText,
          style: TextStyle(
            fontSize: 13,
            color: sandText.withOpacity(0.75),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        SizedBox(height: fieldGap),
        if (verifiedPhone.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Verified: $verifiedPhone",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
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
        if (!_showPhoneVerificationStep)
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  bikeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill name and bike.")),
                );
                return;
              }
              setState(() => showPhoneVerification = true);
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
        else if (verifiedPhone.isNotEmpty)
          ElevatedButton(
            onPressed: isSubmitting ? null : _completeSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: primary.withOpacity(0.2),
            ),
            child:
                isSubmitting
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          authMode == AuthMode.existingAccount
                              ? "Fetch Account"
                              : "Continue to Home",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
          )
        else
          PhoneLoginButton(
            borderRadius: 16,
            buttonColor: primary,
            label:
                authMode == AuthMode.existingAccount
                    ? "Login with Number (+91)"
                    : "Verify Phone (+91)",
            onSuccess: (access, jwt) {
              accessToken = access;
              jwtToken = jwt;
              getPhoneNumber();
            },
            onFailure: (message) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Phone.Email login failed: $message")),
              );
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
    super.dispose();
  }

  /// GET VERIFIED PHONE

  void getPhoneNumber() {
    if (accessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing access token. Try again.")),
      );
      return;
    }

    PhoneEmail.getUserInfo(
      accessToken: accessToken,
      clientId: PhoneEmail().clientId,
      onSuccess: (userData) async {
        final countryCode = (userData.countryCode ?? "").trim();
        final phoneNumber = (userData.phoneNumber ?? "").trim();
        final normalizedIndian = _normalizeIndianPhone(
          countryCode: countryCode,
          phoneNumber: phoneNumber,
        );

        if (normalizedIndian == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Please verify using an Indian mobile number (+91).",
              ),
            ),
          );
          return;
        }

        setState(() {
          verifiedPhone = normalizedIndian;
        });

        await _completeSignIn();
      },
    );
  }

  Future<void> _completeSignIn() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      if (authMode == AuthMode.existingAccount) {
        await _signInExistingUser();
      } else {
        await _registerNewUser();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not continue: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _registerNewUser() async {
    final name = nameController.text.trim();
    final bike = bikeController.text.trim();
    final userId = await _upsertUser(name: name, bike: bike);
    await _saveLocalSession(name: name, bike: bike, userId: userId);
  }

  Future<void> _signInExistingUser() async {
    final user = await _fetchUserByPhone();
    await _saveLocalSession(
      name: user.name,
      bike: user.bike,
      userId: user.userId,
    );
  }

  Future<String> _upsertUser({
    required String name,
    required String bike,
  }) async {
    String userId = "";

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
      try {
        await supabase.from('users').upsert({
          'phone': verifiedPhone,
          'name': name,
          'bike': bike,
        });
      } catch (_) {
        throw Exception("Failed to save user profile.");
      }
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

    return userId;
  }

  Future<_ExistingUser> _fetchUserByPhone() async {
    Map<String, dynamic>? userRow;
    try {
      userRow =
          await supabase
              .from('users')
              .select('id,name,bike')
              .eq('phone', verifiedPhone)
              .maybeSingle();
    } catch (_) {
      throw Exception("Could not fetch your account. Try again.");
    }

    if (userRow == null) {
      throw Exception(
        "No account found for this number. Switch to New Account to register.",
      );
    }

    final name = (userRow['name'] ?? "").toString().trim();
    final bike = (userRow['bike'] ?? "").toString().trim();
    final userId = (userRow['id'] ?? "").toString().trim();

    return _ExistingUser(
      name: name.isNotEmpty ? name : "Rider",
      bike: bike.isNotEmpty ? bike : "No bike added",
      userId: userId,
    );
  }

  Future<void> _saveLocalSession({
    required String name,
    required String bike,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("isLoggedIn", true);

    await prefs.setString("userName", name);

    await prefs.setString("userBike", bike);

    await prefs.setString("userPhone", verifiedPhone);
    await prefs.setString("phoneEmailAccessToken", accessToken);
    await prefs.setString("phoneEmailJwtToken", jwtToken);

    if (_looksLikeUuid(userId)) {
      await prefs.setString("userId", userId);
    } else {
      await prefs.remove("userId");
    }
  }

  bool _looksLikeUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }

  String? _normalizeIndianPhone({
    required String countryCode,
    required String phoneNumber,
  }) {
    final ccDigits = countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneDigits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (ccDigits != '91') return null;
    if (phoneDigits.length == 10) {
      return "+91$phoneDigits";
    }
    if (phoneDigits.length == 12 && phoneDigits.startsWith('91')) {
      return "+$phoneDigits";
    }
    return null;
  }
}

class _ExistingUser {
  const _ExistingUser({
    required this.name,
    required this.bike,
    required this.userId,
  });

  final String name;
  final String bike;
  final String userId;
}
