import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast_premium.dart';
import '../widgets/journey_screen.dart';
import 'home_screen.dart';
import 'legal_document_screen.dart';
import 'sign_in_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bikeController = TextEditingController();
  ({PhoneIdentity identity, String accessToken, String idToken})?
  _googleAuthResult;
  String _googleEmail = '';
  bool _acceptedPrivacy = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bikeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneyScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JourneyHeader(
            surface: true,
            leading: JourneyBackButton(),
            eyebrow: 'NEW RIDER',
            title: 'Create rider profile',
            subtitle: 'Connect Google first, then finish your rider details.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Hero(
            tag: 'journeysync-logo',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Image.asset(
                'assets/logo.png',
                width: 72,
                height: 72,
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
                  'CREATE ACCOUNT',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Set up your rider profile.',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _googleAuthResult == null
                      ? 'Connect Google to verify your account. Then add your bike name to complete setup.'
                      : 'Google account connected. Confirm details and finish account creation.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_googleAuthResult == null) ...[
                  _buildPrivacyAgreement(),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label:
                        _loading
                            ? 'Connecting Google...'
                            : 'Continue with Google',
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
                    onPressed: _loading ? null : _connectGoogle,
                  ),
                ] else ...[
                  TextField(
                    controller: _nameController,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'FULL NAME (FROM GOOGLE)',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_googleEmail.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'GOOGLE EMAIL',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      child: Text(
                        _googleEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _bikeController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Himalayan 450',
                      labelText: 'BIKE NAME',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.two_wheeler_outlined,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: _loading ? 'Creating account...' : 'Create Account',
                    loading: _loading,
                    onPressed: _loading ? null : _completeAccountCreation,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton(
              onPressed:
                  () => replaceWithAppRoute<void, void>(
                    context,
                    const SignInScreen(),
                  ),
              child: Text(
                'Already have an account? Sign In',
                style: AppTypography.buttonMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectGoogle() async {
    if (_loading) return;
    if (!_acceptedPrivacy) {
      showPremiumToast(
        context,
        'Please accept the Privacy Policy before continuing.',
        type: PremiumToastType.info,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _authService.authenticateWithGoogle();
      final metadataName =
          Supabase.instance.client.auth.currentUser?.userMetadata?['name']
              .toString()
              .trim() ??
          '';
      final resolvedName =
          metadataName.isNotEmpty ? metadataName : result.identity.fullName;
      final authEmail =
          (Supabase.instance.client.auth.currentUser?.email ?? '')
              .trim()
              .toLowerCase();

      if (!mounted) return;
      setState(() {
        _googleAuthResult = result;
        _googleEmail = authEmail;
        _nameController.text = resolvedName.isNotEmpty ? resolvedName : 'Rider';
      });
      showPremiumToast(
        context,
        'Google account connected. Add bike name to finish.',
        type: PremiumToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      final rlsBlocked =
          error is PostgrestException && (error.code ?? '') == '42501';
      showPremiumToast(
        context,
        rlsBlocked
            ? 'Supabase policies blocked account creation.'
            : 'Google sign-in failed: $error',
        type: PremiumToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeAccountCreation() async {
    final auth = _googleAuthResult;
    if (auth == null) {
      showPremiumToast(
        context,
        'Connect Google before creating your account.',
        type: PremiumToastType.info,
      );
      return;
    }

    final name = _nameController.text.trim();
    final bike = _bikeController.text.trim();
    if (bike.isEmpty) {
      showPremiumToast(
        context,
        'Add your bike name to create an account.',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _authService.resolveUser(
        identity: auth.identity,
        isNewAccount: true,
        enteredName: name,
        enteredBike: bike,
      );
      await _authService.saveSession(
        user: user,
        accessToken: auth.accessToken,
        jwtToken: auth.idToken,
      );
      if (!mounted) return;
      unawaited(replaceAllWithAppRoute(context, const HomeScreen()));
    } catch (error) {
      if (!mounted) return;
      final rlsBlocked =
          error is PostgrestException && (error.code ?? '') == '42501';
      showPremiumToast(
        context,
        rlsBlocked
            ? 'Supabase policies blocked account creation.'
            : 'Could not create account: $error',
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
