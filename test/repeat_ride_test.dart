import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/models/ride_record.dart';
import 'package:journeysync/screens/create_ride_screen.dart';

void main() {
  test('repeating a completed ride prefills a new editable ride', () {
    final completed = RideRecord(
      id: 'completed-ride',
      creatorId: 'rider-a',
      title: 'Nandi sunrise loop',
      startLocation: 'Bengaluru',
      endLocation: 'Nandi Hills',
      createdAt: DateTime(2026, 10, 16),
      status: 'completed',
      endedAt: DateTime(2026, 10, 16, 9),
    );

    final repeated = CreateRideScreen.repeat(completed);

    expect(repeated.initialRideName, 'Nandi sunrise loop');
    expect(repeated.initialDestination, 'Nandi Hills');
    expect(repeated.initialMaxRiders, isNull);
  });
}
