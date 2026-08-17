import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/app_navigation.dart';
import '../services/app_version.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'setup_error_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.initializationFuture});

  final Future<void>? initializationFuture;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _introController.forward();
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    Object? initError;
    try {
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 1400)),
        widget.initializationFuture ?? Future.value(),
      ]);
    } catch (error) {
      initError = error;
    }

    if (!mounted) return;
    if (initError != null) {
      unawaited(
        replaceWithAppRoute(
          context,
          SetupErrorScreen(errorMessage: initError.toString()),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    final hasAuthSession = Supabase.instance.client.auth.currentSession != null;

    if (loggedIn && hasAuthSession) {
      unawaited(replaceWithAppRoute(context, const HomeScreen()));
      return;
    }
    if (loggedIn && !hasAuthSession) {
      await AuthService().clearSession();
      if (!mounted) return;
    }
    unawaited(replaceWithAppRoute(context, const LoginScreen()));
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background,
                          AppColors.surfaceAlt.withValues(alpha: 0.86),
                        ],
                      ),
                    ),
                  ),
                ),

                JourneyIntroAnimation(animation: _introController),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 54,
                  child: Text(
                    'v${AppVersion.version}',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JourneyIntroAnimation extends StatelessWidget {
  const JourneyIntroAnimation({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final backgroundFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
    );
    final pinOpacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.14, 0.32, curve: Curves.easeOutCubic),
    );
    final pinScale = Tween<double>(begin: 0.82, end: 1.0).animate(pinOpacity);
    final routeProgress = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.32, 0.57, curve: Curves.easeInOutCubic),
    );
    final routesFade = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 57),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 21),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 22),
    ]).animate(animation);
    final logoOpacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.57, 0.79, curve: Curves.easeOutCubic),
    );
    final logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(logoOpacity);
    final brandOpacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.79, 1.0, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: backgroundFade,
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: 430,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Opacity(
                    opacity: routesFade.value,
                    child: CustomPaint(
                      size: const Size(360, 260),
                      painter: AnimatedRoutePainter(
                        progress: routeProgress.value,
                        primary: AppColors.primary,
                        forest: AppColors.forest,
                      ),
                    ),
                  );
                },
              ),
              FadeTransition(
                opacity: pinOpacity,
                child: ScaleTransition(
                  scale: pinScale,
                  child: const _CenterPin(),
                ),
              ),
              LogoRevealWidget(
                opacity: logoOpacity,
                scale: logoScale,
                sweepProgress: animation,
              ),
              Positioned(
                top: 270,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: brandOpacity,
                  child: Column(
                    children: [
                      Text(
                        'JourneySync',
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 54,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.forest],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ride Together. Stay Together.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface.withValues(alpha: 0.88),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: AppColors.primary,
        size: 30,
      ),
    );
  }
}

class LogoRevealWidget extends StatelessWidget {
  const LogoRevealWidget({
    super.key,
    required this.opacity,
    required this.scale,
    required this.sweepProgress,
  });

  final Animation<double> opacity;
  final Animation<double> scale;
  final Animation<double> sweepProgress;

  @override
  Widget build(BuildContext context) {
    final sweep = CurvedAnimation(
      parent: sweepProgress,
      curve: const Interval(0.62, 0.86, curve: Curves.easeInOutCubic),
    );

    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: AnimatedBuilder(
          animation: sweep,
          builder: (context, child) {
            final dx = -1.4 + sweep.value * 2.8;
            return Stack(
              alignment: Alignment.center,
              children: [
                child!,
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Transform.translate(
                    offset: Offset(dx * 96, 0),
                    child: Container(
                      width: 34,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.34),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: AppShadows.primary,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedRoutePainter extends CustomPainter {
  const AnimatedRoutePainter({
    required this.progress,
    required this.primary,
    required this.forest,
  });

  final double progress;
  final Color primary;
  final Color forest;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final leftPath =
        Path()
          ..moveTo(-12, size.height * 0.72)
          ..cubicTo(
            size.width * 0.18,
            size.height * 0.62,
            size.width * 0.28,
            size.height * 0.28,
            center.dx,
            center.dy,
          );
    final rightPath =
        Path()
          ..moveTo(size.width + 12, size.height * 0.24)
          ..cubicTo(
            size.width * 0.78,
            size.height * 0.34,
            size.width * 0.73,
            size.height * 0.72,
            center.dx,
            center.dy,
          );

    _drawProgressPath(
      canvas,
      leftPath,
      Paint()
        ..color = primary.withValues(alpha: 0.72)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    _drawProgressPath(
      canvas,
      rightPath,
      Paint()
        ..color = forest.withValues(alpha: 0.62)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawProgressPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedRoutePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.forest != forest;
  }
}
