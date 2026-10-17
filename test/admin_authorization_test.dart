import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/screens/admin_dashboard_screen.dart';

void main() {
  test('owner dashboard requires exact email and server admin role', () {
    expect(
      isJourneySyncAdminIdentity(
        email: 'journeysync.app@gmail.com',
        appMetadata: const {'role': 'admin'},
      ),
      isTrue,
    );
    expect(
      isJourneySyncAdminIdentity(
        email: 'attacker@example.com',
        appMetadata: const {'role': 'admin'},
      ),
      isFalse,
    );
    expect(
      isJourneySyncAdminIdentity(
        email: 'journeysync.app@gmail.com',
        appMetadata: const {'role': 'member'},
      ),
      isFalse,
    );
  });
}
