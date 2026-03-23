import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_navigation.dart';
import 'app_config.dart';
import 'splash_screen.dart';

const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: AppConfig.supabaseUrl,
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: AppConfig.supabaseAnonKey,
);
const String _auth0Domain = String.fromEnvironment(
  'AUTH0_DOMAIN',
  defaultValue: AppConfig.auth0Domain,
);
const String _auth0ClientId = String.fromEnvironment(
  'AUTH0_CLIENT_ID',
  defaultValue: AppConfig.auth0ClientId,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final initializationFuture = _initializeServices();
  runApp(JourneySyncApp(initializationFuture: initializationFuture));
}

Future<void> _initializeServices() async {
  final supabaseUrl = _requiredDefine('SUPABASE_URL', _supabaseUrl);
  final supabaseAnonKey = _requiredDefine(
    'SUPABASE_ANON_KEY',
    _supabaseAnonKey,
  );
  _requiredDefine('AUTH0_DOMAIN', _auth0Domain);
  _requiredDefine('AUTH0_CLIENT_ID', _auth0ClientId);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  ).timeout(const Duration(seconds: 20));
}

String _requiredDefine(String key, String value) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) return trimmed;
  throw StateError('Missing app configuration value: $key.');
}

class JourneySyncApp extends StatelessWidget {
  const JourneySyncApp({super.key, required this.initializationFuture});
  final Future<void> initializationFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      home: SplashScreen(initializationFuture: initializationFuture),
    );
  }
}
