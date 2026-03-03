import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'home_screen.dart';

enum AuthMode { newAccount, existingAccount }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService authService = AuthService();

  String accessToken = "";

  String jwtToken = "";

  String verifiedPhone = "";
  PhoneIdentity? verifiedIdentity;
  bool isSubmitting = false;

  final nameController = TextEditingController();

  final bikeController = TextEditingController();

  AuthMode authMode = AuthMode.existingAccount;
  bool showPhoneVerification = false;
  bool quickLoginLoading = false;
  SessionUser? cachedUser;

  final primary = const Color(0xFFDB7706);
  final forest = const Color(0xFF1E2D24);
  final sandText = const Color(0xFF4A3F35);
  final backgroundLight = const Color(0xFFF8F7F5);

  @override
  void initState() {
    super.initState();
    _loadQuickLoginCandidate();
  }

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
                                        "auth0_${authMode.name}_${verifiedPhone.isNotEmpty}",
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
            ? "Create your profile once, then authenticate to get started."
            : "Already have an account? Sign in and continue instantly.";

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
      verifiedIdentity = null;
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
                  "Register once, then returning logins only need one-tap sign in.",
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
            ? "Authenticate to fetch your profile from JourneySync."
            : "Tap the button below to authenticate and continue.";

    return Column(
      key: ValueKey(keyValue),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SIGN IN",
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
        if (authMode == AuthMode.existingAccount &&
            cachedUser != null &&
            verifiedPhone.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: quickLoginLoading ? null : _continueWithCachedAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: forest,
              side: BorderSide(color: forest.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon:
                quickLoginLoading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.person_outline),
            label: Text(
              quickLoginLoading
                  ? "Loading account..."
                  : "Continue as ${cachedUser!.name}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Or sign in again with Auth0.",
            style: TextStyle(
              fontSize: 12,
              color: sandText.withOpacity(0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: fieldGap),
        ],
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
                    "Authenticated: $verifiedPhone",
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
          ElevatedButton.icon(
            onPressed: isSubmitting ? null : _authenticateWithAuth0,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: primary.withOpacity(0.2),
            ),
            icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
            label: const Text(
              "Continue with Auth0",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
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

  Future<void> _completeSignIn() async {
    if (isSubmitting) return;
    final identity = verifiedIdentity;
    if (identity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sign in first.")));
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final enteredName = nameController.text.trim();
      final enteredBike = bikeController.text.trim();

      if (authMode == AuthMode.newAccount &&
          (enteredName.isEmpty || enteredBike.isEmpty)) {
        throw Exception("Please fill name and bike.");
      }

      final user = await authService.resolveUser(
        identity: identity,
        isNewAccount: authMode == AuthMode.newAccount,
        enteredName: enteredName,
        enteredBike: enteredBike,
      );

      await authService.saveSession(
        user: user,
        accessToken: accessToken,
        jwtToken: jwtToken,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString();
      final noAccountFound = errorText.contains(
        "No account found for this account",
      );

      if (noAccountFound && authMode == AuthMode.existingAccount) {
        setState(() {
          authMode = AuthMode.newAccount;
          showPhoneVerification = false;
          if (nameController.text.trim().isEmpty) {
            nameController.text = identity.fullName;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No account found. Please add your name and bike to create one.",
            ),
          ),
        );
        return;
      }

      final rlsBlocked =
          (error is PostgrestException && (error.code ?? '') == '42501') ||
          errorText.toLowerCase().contains('row-level security');
      if (rlsBlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Supabase RLS blocked this request. Enable users SELECT/INSERT policy for anon.",
              /*  */
            ),
          ),
        );
        return;
      }

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

  Future<void> _loadQuickLoginCandidate() async {
    try {
      final user = await authService.tryResolveCachedUser();
      if (!mounted) return;
      setState(() {
        cachedUser = user;
      });
    } catch (_) {
      // If quick lookup fails, explicit sign-in remains available.
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _continueWithCachedAccount() async {
    if (quickLoginLoading || cachedUser == null) return;
    setState(() {
      quickLoginLoading = true;
    });
    try {
      await authService.saveSession(
        user: cachedUser!,
        accessToken: "",
        jwtToken: "",
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not continue with cached account: $error"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          quickLoginLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateWithAuth0() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });
    try {
      final result = await authService.authenticateWithAuth0();
      if (!mounted) return;
      setState(() {
        verifiedIdentity = result.identity;
        verifiedPhone = result.identity.phone;
        accessToken = result.accessToken;
        jwtToken = result.idToken;
      });
      await _completeSignIn();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Auth0 login failed: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}
