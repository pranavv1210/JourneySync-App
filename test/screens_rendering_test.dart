import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:journeysync/services/app_config.dart';
import 'package:journeysync/screens/login_screen.dart';
import 'package:journeysync/screens/home_screen.dart';
import 'package:journeysync/screens/ride_mode_settings_screen.dart';
import 'package:journeysync/widgets/premium/premium_button.dart';
import 'package:journeysync/widgets/ride_loading_indicator.dart';

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

      // Welcome now exposes primary Google and secondary Phone CTAs.
      expect(find.byType(PremiumButton), findsAtLeastNWidgets(2));
    });

    testWidgets('HomeScreen renders with skeleton loading or main HUD elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // HomeScreen has an initial loading block if Supabase fetch is triggered,
      // which shows the branded ride loader.
      // Let's verify either loader or main widgets render safely.
      await tester.pump();

      final loaderFinder = find.byType(RideLoadingIndicator);
      final scaffoldFinder = find.byType(Scaffold);

      expect(scaffoldFinder, findsOneWidget);
      expect(
        loaderFinder.evaluate().isNotEmpty ||
            find.text("Let's ride, Rider").evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Ride Mode settings renders diagnostics and safety controls', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: RideModeSettingsScreen()),
      );
      await tester.pump();

      expect(find.text('Ride Mode'), findsOneWidget);
      expect(find.text('PERMISSION STATUS'), findsOneWidget);
      expect(find.text('Call rejection'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Repeat callers'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Repeat callers'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Automatic shutoff'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Automatic shutoff'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
