import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'splash_screen.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String _phoneEmailClientId = String.fromEnvironment(
  'PHONE_EMAIL_CLIENT_ID',
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
  final phoneEmailClientId = _requiredDefine(
    'PHONE_EMAIL_CLIENT_ID',
    _phoneEmailClientId,
  );

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  ).timeout(const Duration(seconds: 20));

  await PhoneEmail.initializeApp(
    clientId: phoneEmailClientId,
  ).timeout(const Duration(seconds: 20));
}

String _requiredDefine(String key, String value) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) return trimmed;
  throw StateError(
    'Missing --dart-define=$key. Add it to flutter run/build command.',
  );
}

class JourneySyncApp extends StatelessWidget {
  const JourneySyncApp({super.key, required this.initializationFuture});
  final Future<void> initializationFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(initializationFuture: initializationFuture),
    );
  }
}
