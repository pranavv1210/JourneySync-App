import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'services/app_navigation.dart';
import 'services/app_config.dart';
import 'services/app_version.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'coordinators/active_ride_coordinator.dart';
import 'utils/app_logger.dart';

/// Whether the .env file was loaded successfully.
bool _envLoaded = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load .env file (fail silently so app works without it)
  try {
    await dotenv.load(fileName: ".env");
    _envLoaded = true;
  } catch (_) {
    // .env file not found - fallback to AppConfig defaults
  }

  // Initialize Firebase and Crashlytics
  try {
    await Firebase.initializeApp();
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    AppLogger.error('Failed to initialize Firebase', e);
  }

  final initializationFuture = _initializeServices();

  await SentryFlutter.init(
    (options) {
      options.dsn = _envLoaded ? (dotenv.env['SENTRY_DSN'] ?? '') : '';
      options.tracesSampleRate = 0.1;
      options.environment = 'production';
    },
    appRunner:
        () =>
            runApp(JourneySyncApp(initializationFuture: initializationFuture)),
  );
}

Future<void> _initializeServices() async {
  // Use dotenv values if available, otherwise fall back to compile-time defaults
  final supabaseUrl =
      _envLoaded
          ? (dotenv.env['SUPABASE_URL'] ?? AppConfig.supabaseUrl)
          : AppConfig.supabaseUrl;
  final supabaseAnonKey =
      _envLoaded
          ? (dotenv.env['SUPABASE_ANON_KEY'] ?? AppConfig.supabaseAnonKey)
          : AppConfig.supabaseAnonKey;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  ).timeout(const Duration(seconds: 20));
  await ActiveRideCoordinator.instance.restore();
}

class JourneySyncApp extends StatelessWidget {
  const JourneySyncApp({super.key, required this.initializationFuture});
  final Future<void> initializationFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppVersion.name,
      theme: AppTheme.light,
      navigatorObservers: [
        appRouteObserver,
        if (Firebase.apps.isNotEmpty)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: SplashScreen(initializationFuture: initializationFuture),
    );
  }
}
