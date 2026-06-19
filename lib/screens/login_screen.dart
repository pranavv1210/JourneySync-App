import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/glass_card.dart';
import '../widgets/premium/premium_input.dart';
import '../widgets/premium/premium_toast.dart';
import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

enum AuthMode { newAccount, existingAccount }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService authService = AuthService();

  String accessToken = '';
  String jwtToken = '';
  String verifiedPhone = '';
  PhoneIdentity? verifiedIdentity;
  bool isSubmitting = false;

  final nameController = TextEditingController();
  final bikeController = TextEditingController();

  AuthMode authMode = AuthMode.existingAccount;
  bool quickLoginLoading = false;
  SessionUser? cachedUser;

  late final AnimationController _pageController;
  late final Animation<double> _pageAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    )..forward();
    _pageAnimation = CurvedAnimation(
      parent: _pageController,
      curve: AppCurves.easeOutCubic,
    );
    _loadQuickLoginCandidate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    bikeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient gradient orbs
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forest.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top brand bar
                _buildTopBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _pageAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(_pageAnimation),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xxl,
                          8,
                          AppSpacing.xxl,
                          40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            // Hero section
                            _buildHero(),
                            const SizedBox(height: 32),
                            // Mode toggle
                            _buildModeToggle(),
                            const SizedBox(height: 20),
                            // Dynamic content
                            AnimatedSwitcher(
                              duration: AppDurations.normal,
                              switchInCurve: AppCurves.easeOutCubic,
                              switchOutCurve: AppCurves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: AppCurves.easeOutCubic,
                                      ),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  authMode == AuthMode.existingAccount
                                      ? _buildPhoneVerification(
                                        key: ValueKey(
                                          'auth_${verifiedPhone.isNotEmpty}',
                                        ),
                                      )
                                      : _buildRegistrationForm(
                                        key: const ValueKey('reg'),
                                      ),
                            ),
                            const SizedBox(height: 24),
                            // Primary action
                            _buildPrimaryAction(),
                            const SizedBox(height: 20),
                            // Legal text
                            _buildLegalText(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 14, AppSpacing.xl, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'JourneySync',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _showAuthHelp,
            icon: Icon(
              Icons.help_outline_rounded,
              color: AppColors.textTertiary,
            ),
            tooltip: 'Help',
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          authMode == AuthMode.newAccount ? 'Create Account' : 'Welcome Back',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          authMode == AuthMode.newAccount
              ? 'Set up your profile to start riding with your crew.'
              : 'Sign in to continue where you left off.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleOption(
              label: 'Sign In',
              selected: authMode == AuthMode.existingAccount,
              onTap: () => _switchMode(AuthMode.existingAccount),
            ),
          ),
          Expanded(
            child: _toggleOption(
              label: 'Create Account',
              selected: authMode == AuthMode.newAccount,
              onTap: () => _switchMode(AuthMode.newAccount),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.buttonMedium.copyWith(
            color: selected ? AppColors.textOnDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _switchMode(AuthMode mode) {
    if (authMode == mode) return;
    setState(() {
      authMode = mode;
      verifiedPhone = '';
      verifiedIdentity = null;
      accessToken = '';
      jwtToken = '';
    });
  }

  Widget _buildPhoneVerification({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUTHENTICATION',
          style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in with your account to access your rides.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        if (authMode == AuthMode.existingAccount &&
            cachedUser != null &&
            verifiedPhone.isEmpty) ...[
          // Quick login with cached account
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: quickLoginLoading ? null : _continueWithCachedAccount,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.forest,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quickLoginLoading
                            ? 'Loading account...'
                            : 'Continue as ${cachedUser!.name}',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Tap to sign in instantly',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quickLoginLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textTertiary,
                    size: 14,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        ],
        if (verifiedPhone.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Authenticated as $verifiedPhone',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRegistrationForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumInput(
          controller: nameController,
          label: 'Full Name',
          hint: 'Enter your name',
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 20),
        PremiumInput(
          controller: bikeController,
          label: 'Bike Name',
          hint: 'e.g. Ducati Desert Sled',
          icon: Icons.two_wheeler_outlined,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Register once, then sign in instantly on return.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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

  Widget _buildPrimaryAction() {
    final requiresDetails = authMode == AuthMode.newAccount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumButton(
          label:
              isSubmitting
                  ? 'Please wait...'
                  : (requiresDetails
                      ? 'Create Account & Continue'
                      : 'Continue'),
          icon: isSubmitting ? null : Icons.arrow_forward_rounded,
          trailing:
              isSubmitting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : null,
          loading: isSubmitting,
          onPressed:
              isSubmitting
                  ? null
                  : () =>
                      _handlePrimaryContinue(requiresDetails: requiresDetails),
        ),
      ],
    );
  }

  Widget _buildLegalText() {
    return Text(
      'By continuing, you agree to JourneySync\'s Terms of Service and Privacy Policy.',
      textAlign: TextAlign.center,
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        height: 1.5,
      ),
    );
  }

  Future<void> _showAuthHelp() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Login Help', style: AppTypography.headlineSmall),
            content: Text(
              '1. Existing Account: Sign in with Auth0 and continue.\n\n'
              '2. New Account: Fill Name and Bike, then Continue.\n\n'
              'If login fails, verify Auth0 callback/logout URLs are configured.',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTypography.buttonMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _completeSignIn() async {
    final identity = verifiedIdentity;
    if (identity == null) {
      if (!mounted) return;
      showPremiumToast(context, 'Sign in first.', type: PremiumToastType.error);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final enteredName = nameController.text.trim();
      final enteredBike = bikeController.text.trim();

      if (authMode == AuthMode.newAccount &&
          (enteredName.isEmpty || enteredBike.isEmpty)) {
        throw Exception('Please fill name and bike.');
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
      replaceWithAppRoute(context, const HomeScreen());
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString();
      final noAccountFound = errorText.contains(
        'No account found for this account',
      );

      if (noAccountFound && authMode == AuthMode.existingAccount) {
        setState(() {
          authMode = AuthMode.newAccount;
          if (nameController.text.trim().isEmpty) {
            nameController.text = identity.fullName;
          }
        });
        showPremiumToast(
          context,
          'No account found. Please add your name and bike.',
          type: PremiumToastType.info,
        );
        return;
      }

      final rlsBlocked =
          (error is PostgrestException && (error.code ?? '') == '42501') ||
          errorText.toLowerCase().contains('row-level security');
      if (rlsBlocked) {
        showPremiumToast(
          context,
          'Supabase RLS blocked this request. Enable policies.',
          type: PremiumToastType.error,
        );
        return;
      }

      showPremiumToast(
        context,
        'Could not continue: $error',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _loadQuickLoginCandidate() async {
    try {
      final user = await authService.tryResolveCachedUser();
      if (!mounted) return;
      setState(() => cachedUser = user);
    } catch (_) {
      // Explicit sign-in remains available
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _continueWithCachedAccount() async {
    if (quickLoginLoading || cachedUser == null) return;
    setState(() => quickLoginLoading = true);
    try {
      await authService.saveSession(
        user: cachedUser!,
        accessToken: '',
        jwtToken: '',
      );
      if (!mounted) return;
      replaceWithAppRoute(context, const HomeScreen());
    } catch (error) {
      if (!mounted) return;
      showPremiumToast(
        context,
        'Could not continue with cached account.',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => quickLoginLoading = false);
    }
  }

  Future<void> _authenticateWithAuth0() async {
    try {
      final result = await authService.authenticateWithAuth0();
      if (!mounted) return;
      setState(() {
        verifiedIdentity = result.identity;
        verifiedPhone = result.identity.phone;
        accessToken = result.accessToken;
        jwtToken = result.idToken;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      if (message.toLowerCase().contains('callback') &&
          message.toLowerCase().contains('mismatch')) {
        showPremiumToast(
          context,
          'Auth0 callback mismatch. Check console for details.',
          type: PremiumToastType.error,
        );
        return;
      }
      showPremiumToast(
        context,
        'Auth0 login failed: $error',
        type: PremiumToastType.error,
      );
    }
  }

  Future<void> _handlePrimaryContinue({required bool requiresDetails}) async {
    if (isSubmitting) return;
    if (requiresDetails &&
        (nameController.text.trim().isEmpty ||
            bikeController.text.trim().isEmpty)) {
      showPremiumToast(
        context,
        'Please fill name and bike.',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      if (verifiedIdentity == null || verifiedPhone.isEmpty) {
        await _authenticateWithAuth0();
      }
      if (verifiedIdentity == null || verifiedPhone.isEmpty) {
        throw Exception('Authentication was not completed.');
      }
      await _completeSignIn();
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
