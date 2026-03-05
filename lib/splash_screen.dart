import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late final AnimationController loadingController;

  @override
  void initState() {
    super.initState();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    Object? initError;
    try {
      await Future.wait([
        Future.delayed(const Duration(seconds: 3)),
        widget.initializationFuture ?? Future.value(),
      ]);
    } catch (error) {
      initError = error;
    }

    if (!mounted) return;
    if (initError != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetupErrorScreen(errorMessage: initError.toString()),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF4EFEA);
    const primary = Color(0xFFF26C0D);
    const brandGray = Color(0xFF2F2F2F);
    const forestGreen = Color(0xFF2D4438);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TopoPatternPainter(
                      color: brandGray.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 160,
                  left: 60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.12),
                          blurRadius: 80,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 170,
                  right: 56,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: forestGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: forestGreen.withValues(alpha: 0.12),
                          blurRadius: 80,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 20),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 126,
                          height: 126,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.22),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 102,
                                height: 102,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.25),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      "assets/logo.png",
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Journey",
                                style: TextStyle(
                                  color: brandGray,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              TextSpan(
                                text: "Sync",
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 52,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [primary, forestGreen],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "Ride Together. Ride Safe.",
                          style: TextStyle(
                            color: brandGray.withValues(alpha: 0.8),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 84,
                          height: 4,
                          color: brandGray.withValues(alpha: 0.12),
                          child: AnimatedBuilder(
                            animation: loadingController,
                            builder: (context, _) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final offsetX =
                                      (loadingController.value * width * 2) -
                                      width;
                                  return Transform.translate(
                                    offset: Offset(offsetX, 0),
                                    child: Container(
                                      width: width,
                                      color: primary,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "v1.0.2 Beta",
                        style: TextStyle(
                          color: brandGray.withValues(alpha: 0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
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

class _TopoPatternPainter extends CustomPainter {
  _TopoPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;

    const spacing = 60.0;
    const arm = 4.0;
    for (double y = 24; y < size.height + spacing; y += spacing) {
      for (double x = 24; x < size.width + spacing; x += spacing) {
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), paint);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
