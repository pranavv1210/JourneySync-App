import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast_premium.dart';
import 'create_account_screen.dart';
import 'home_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.autoStart = false});

  final bool autoStart;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      eyebrow: 'SIGN IN',
      title: 'Welcome back.',
      subtitle:
          'Continue with your Google account to restore rides, profile, and live sessions.',
      action: AppButton(
        label: _loading ? 'Signing in...' : 'Continue with Google',
        icon: _loading ? null : null,
        customIcon:
            _loading
                ? null
                : SvgPicture.asset(
                  'assets/google_logo.svg',
                  width: 24,
                  height: 24,
                ),
        loading: _loading,
        onPressed: _loading ? null : _signIn,
      ),
      footer: TextButton(
        onPressed:
            () => replaceWithAppRoute<void, void>(
              context,
              const CreateAccountScreen(),
            ),
        child: Text(
          'New user? Create Account',
          style: AppTypography.buttonMedium.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await _authService.authenticateWithGoogle();
      final user = await _authService.resolveUser(
        identity: result.identity,
        isNewAccount: false,
        enteredName: '',
        enteredBike: '',
      );
      await _authService.saveSession(
        user: user,
        accessToken: result.accessToken,
        jwtToken: result.idToken,
      );
      if (!mounted) return;
      replaceWithAppRoute(context, const HomeScreen());
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      final noAccount = message.contains('No account found');
      if (noAccount) {
        showPremiumToast(
          context,
          'No JourneySync profile found. Create your account first.',
          type: PremiumToastType.info,
        );
        replaceWithAppRoute<void, void>(context, const CreateAccountScreen());
        return;
      }
      final rlsBlocked =
          error is PostgrestException && (error.code ?? '') == '42501';
      showPremiumToast(
        context,
        rlsBlocked
            ? 'Supabase policies blocked sign in.'
            : 'Google sign-in failed: $error',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _AuthShell extends StatelessWidget {
  const _AuthShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget action;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              Hero(
                tag: 'journeysync-logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      subtitle,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    action,
                  ],
                ),
              ),
              const Spacer(),
              Center(child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
