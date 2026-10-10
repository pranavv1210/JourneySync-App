import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/services/ride_session_recovery.dart';

void main() {
  group('RideSessionRecovery', () {
    test('restores the newest active joined ride', () {
      final result = RideSessionRecovery.selectActiveRideId([
        {
          'id': 'older-live',
          'status': 'live',
          'started_at': '2026-10-10T06:00:00Z',
        },
        {'id': 'scheduled', 'status': 'scheduled'},
        {
          'id': 'newer-active',
          'status': 'active',
          'started_at': '2026-10-10T07:00:00Z',
        },
      ]);

      expect(result, 'newer-active');
    });

    test('does not restore finished, cancelled, or archived rides', () {
      final result = RideSessionRecovery.selectActiveRideId([
        {'id': 'done', 'status': 'completed'},
        {'id': 'cancelled', 'status': 'cancelled'},
        {'id': 'archived', 'status': 'active', 'archived_at': '2026-10-10'},
      ]);

      expect(result, isEmpty);
    });

    test('ignores malformed active rows without an id', () {
      expect(
        RideSessionRecovery.selectActiveRideId([
          {'status': 'active'},
        ]),
        isEmpty,
      );
    });
  });
}
