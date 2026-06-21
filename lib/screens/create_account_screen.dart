import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';
import '../widgets/app_toast_premium.dart';
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
                      style: AppTypography.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Google is the preferred onboarding method. Phone verification can be added later in settings.',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PremiumInput(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Your rider name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumInput(
                      controller: _bikeController,
                      label: 'Bike',
                      hint: 'e.g. Himalayan 450',
                      icon: Icons.two_wheeler_outlined,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      label:
                          _loading
                              ? 'Creating account...'
                              : 'Create Account with Google',
                      icon: _loading ? null : Icons.g_mobiledata_rounded,
                      loading: _loading,
                      onPressed: _loading ? null : _createAccount,
                    ),
                  ],
                ),
              ),
              const Spacer(),
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
        ),
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
      replaceWithAppRoute(context, const HomeScreen());
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
