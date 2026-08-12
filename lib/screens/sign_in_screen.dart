import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_navigation.dart';
import '../services/app_version.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast_premium.dart';
import '../widgets/journey_screen.dart';
import 'create_account_screen.dart';
import 'home_screen.dart';
import 'legal_document_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.autoStart = false});

  final bool autoStart;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  bool _acceptedPrivacy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showPremiumToast(
          context,
          'Review and accept the Privacy Policy to continue.',
          type: PremiumToastType.info,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      eyebrow: 'SIGN IN',
      title: 'Welcome back.',
      subtitle:
          'Continue with your Google account to restore rides, profile, and live sessions.',
      action: Column(
        children: [
          _buildPrivacyAgreement(),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _loading ? 'Signing in...' : 'Continue with Google',
            customIcon:
                _loading
                    ? null
                    : SvgPicture.asset(
                      'assets/google_logo.svg',
                      width: 24,
                      height: 24,
                    ),
            loading: _loading,
            disabled: !_acceptedPrivacy,
            onPressed: _loading ? null : _signIn,
          ),
        ],
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
    if (!_acceptedPrivacy) {
      showPremiumToast(
        context,
        'Please accept the Privacy Policy before signing in.',
        type: PremiumToastType.info,
      );
      return;
    }
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

  Widget _buildPrivacyAgreement() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        onTap: () => setState(() => _acceptedPrivacy = !_acceptedPrivacy),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: _acceptedPrivacy ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
            boxShadow:
                _acceptedPrivacy
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : AppShadows.sm,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _acceptedPrivacy ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color:
                        _acceptedPrivacy
                            ? AppColors.primary
                            : AppColors.primaryLight,
                    width: 1.8,
                  ),
                ),
                child:
                    _acceptedPrivacy
                        ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.textOnDark,
                          size: 16,
                        )
                        : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'I agree to the ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showPrivacyPolicy,
                      child: Text(
                        'Privacy Policy',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    Text(
                      '.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyPolicy() async {
    final content = await rootBundle.loadString(
      'assets/legal/privacy_policy.txt',
    );
    if (!mounted) return;
    await showLegalDocumentDialog(
      context: context,
      title: 'Privacy Policy',
      content: content,
      titleStyle: AppTypography.titleLarge.copyWith(
        color: AppColors.textPrimary,
      ),
      contentStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      actionColor: AppColors.primary,
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const JourneyBackButton(),
                  const SizedBox(height: AppSpacing.xxl),
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
                  JourneyHeader(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppVersion.label,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        action,
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(child: footer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
