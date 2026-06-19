import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:journeysync/services/app_config.dart';
import 'package:journeysync/screens/login_screen.dart';
import 'package:journeysync/screens/home_screen.dart';
import 'package:journeysync/widgets/premium/premium_button.dart';

void main() {
  setUpAll(() async {
    // Initialize standard widget binding mock
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock shared preferences values
    SharedPreferences.setMockInitialValues({});

    // Initialize dummy Supabase client to support widget instantiation
    // that references Supabase.instance.client.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
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
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsAtLeastNWidgets(1));

      // Verify primary action button exists (PremiumButton, not ElevatedButton)
      expect(find.byType(PremiumButton), findsOneWidget);
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
