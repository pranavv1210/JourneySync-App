import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final initializationFuture = _initializeServices();
  runApp(JourneySyncApp(initializationFuture: initializationFuture));
}

Future<void> _initializeServices() async {
  await Supabase.initialize(
    url: 'https://vvhzofxwiwlffyzyovlw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aHpvZnh3aXdsZmZ5enlvdmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMjc4MzAsImV4cCI6MjA4NjgwMzgzMH0.eSlUSJMJtANHnS91VG_ofZW_jO1j-d9zR51w7XqtFKU',
  );

  await PhoneEmail.initializeApp(clientId: "12548171843307398404");
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
