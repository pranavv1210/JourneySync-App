import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast_premium.dart';
import 'create_account_screen.dart';
import 'sign_in_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const WelcomeScreen();
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: AppCurves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _WelcomeBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: Column(
                    children: [
                      _brandHeader(),
                      const Spacer(),
                      _heroPanel(context),
                      const Spacer(),
                      _actions(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return Row(
      children: [
        Hero(
          tag: 'journeysync-logo',
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: AppShadows.primary,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JourneySync',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Ride together. Stay together.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroPanel(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      elevated: true,
      borderRadius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppBadge(label: 'LIVE GROUP RIDES', icon: Icons.route_rounded),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Your crew, synced in real time.',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Plan rides, track your pack, and send safety alerts without turning a group ride into a group chat.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              _metric('Live', 'tracking'),
              const SizedBox(width: AppSpacing.md),
              _metric('SOS', 'alerts'),
              const SizedBox(width: AppSpacing.md),
              _metric('Route', 'sync'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Continue with Google',
          customIcon: SvgPicture.asset(
            'assets/google_logo.svg',
            width: 24,
            height: 24,
          ),
          onPressed: () => pushAppRoute(context, const SignInScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Continue with Phone',
          icon: Icons.phone_iphone_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.medium,
          onPressed: () => _showPhoneLater(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: _accountAction(
                  label: 'Sign In',
                  caption: 'Existing account',
                  icon: Icons.login_rounded,
                  onTap: () => pushAppRoute(context, const SignInScreen()),
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.divider),
              Expanded(
                child: _accountAction(
                  label: 'Create Account',
                  caption: 'New rider',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap:
                      () => pushAppRoute(context, const CreateAccountScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountAction({
    required String label,
    required String caption,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneLater(BuildContext context) {
    showPremiumToast(
      context,
      'Phone verification is optional. You can add it later in settings.',
      type: PremiumToastType.info,
    );
  }
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.background)),
      ],
    );
  }
}
