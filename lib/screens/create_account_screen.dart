import 'package:flutter/material.dart';
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
            title: 'Create your rider profile',
            subtitle:
                'Google creates the account. These details shape your JourneySync identity.',
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
                  'Google is the preferred onboarding method. Phone verification can be added later in settings.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Your rider name',
                    labelText: 'FULL NAME',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _bikeController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Himalayan 450',
                    labelText: 'BIKE',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                  label:
                      _loading
                          ? 'Creating account...'
                          : 'Create Account with Google',
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
                  onPressed: _loading ? null : _createAccount,
                ),
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

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final bike = _bikeController.text.trim();
    if (name.isEmpty || bike.isEmpty) {
      showPremiumToast(
        context,
        'Add your name and bike to create an account.',
        type: PremiumToastType.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _authService.authenticateWithGoogle();
      final user = await _authService.resolveUser(
        identity: result.identity,
        isNewAccount: true,
        enteredName: name,
        enteredBike: bike,
      );
      await _authService.saveSession(
        user: user,
        accessToken: result.accessToken,
        jwtToken: result.idToken,
      );
      if (!mounted) return;
      replaceAllWithAppRoute(context, const HomeScreen());
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
}
