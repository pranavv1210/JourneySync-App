import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:journeysync/screens/login_screen.dart';
import 'package:journeysync/screens/home_screen.dart';

void main() {
  setUpAll(() async {
    // Initialize standard widget binding mock
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock shared preferences values
    SharedPreferences.setMockInitialValues({});

    // Initialize dummy Supabase client to support widget instantiation
    // that references Supabase.instance.client.
    await Supabase.initialize(
      url: 'https://vvhzofxwiwlffyzyovlw.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2aHpvZnh3aXdsZmZ5enlvdmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMjc4MzAsImV4cCI6MjA4NjgwMzgzMH0.eSlUSJMJtANHnS91VG_ofZW_jO1j-d9zR51w7XqtFKU',
    );
  });

  group('Screen Rendering Tests', () {
    testWidgets('LoginScreen renders header, title, and buttons successfully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Verify that the app name renders
      expect(find.text('JourneySync'), findsOneWidget);

      // Verify that the form mode toggles exist
      expect(find.text('Existing Account'), findsOneWidget);
      expect(find.text('New Account'), findsOneWidget);

      // Verify primary action button exists
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets(
      'HomeScreen renders with skeleton loading or main HUD elements',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

        // HomeScreen has initial loading block if Supabase fetch is triggered,
        // which shows a CircularProgressIndicator.
        // Let's verify either loader or main widgets render safely.
        await tester.pump();

        final loaderFinder = find.byType(CircularProgressIndicator);
        final scaffoldFinder = find.byType(Scaffold);

        expect(scaffoldFinder, findsOneWidget);
        expect(
          loaderFinder.evaluate().isNotEmpty ||
              find.text("Let's ride, Rider").evaluate().isNotEmpty,
          isTrue,
        );
      },
    );
  });
}
