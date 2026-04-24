import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/services/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('Default Supabase URL is not empty', () {
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseUrl.startsWith('https://'), isTrue);
    });

    test('Default Auth0 Config is structured correctly', () {
      expect(AppConfig.auth0Domain, isNotEmpty);
      expect(AppConfig.auth0ClientId, isNotEmpty);
      expect(AppConfig.auth0Scheme, equals('journeysync'));
    });
  });
}
