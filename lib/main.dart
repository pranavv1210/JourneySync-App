import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'services/app_navigation.dart';
import 'services/app_config.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'coordinators/active_ride_coordinator.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");

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
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      options.tracesSampleRate = 1.0;
      options.environment = 'production';
    },
    appRunner:
        () =>
            runApp(JourneySyncApp(initializationFuture: initializationFuture)),
  );
}

Future<void> _initializeServices() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? AppConfig.supabaseUrl;
  final supabaseAnonKey =
      dotenv.env['SUPABASE_ANON_KEY'] ?? AppConfig.supabaseAnonKey;

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
      title: 'JourneySync',
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
