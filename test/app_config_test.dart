import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/services/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('Default Supabase URL is not empty', () {
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseUrl.startsWith('https://'), isTrue);
    });

    test('Default auth redirect URL is structured correctly', () {
      expect(AppConfig.authRedirectUrl, equals('journeysync://login-callback'));
    });
  });
}
