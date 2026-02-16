import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vvhzofxwiwlffyzyovlw.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );

  runApp(const JourneySyncApp());

}

class JourneySyncApp extends StatelessWidget {

  const JourneySyncApp({super.key});

  @override
  Widget build(BuildContext context) {

    return const MaterialApp(

      debugShowCheckedModeBanner: false,

      home: SplashScreen(),

    );

  }

}
