import 'package:flutter_test/flutter_test.dart';
import 'package:journeysync/models/rider_location.dart';
import 'package:journeysync/services/group_ride_intelligence.dart';

RiderLocation location({
  required String id,
  required double latitude,
  double accuracy = 10,
  bool leader = false,
}) {
  return RiderLocation(
    userId: id,
    rideId: 'ride',
    latitude: latitude,
    longitude: 77.5946,
    updatedAt: DateTime.now(),
    userName: id,
    bikeName: 'Bike',
    isLeader: leader,
    speed: 5,
    heading: 0,
    accuracy: accuracy,
  );
}

void main() {
  group('GroupRideIntelligence GPS reliability', () {
    test('does not report separation from a low-accuracy fix', () {
      final engine = GroupRideIntelligence();
      final snapshot = engine.update(
        locations: [
          location(id: 'leader', latitude: 12.9716, leader: true),
          location(id: 'rider', latitude: 12.9916, accuracy: 180),
        ],
        leaderId: 'leader',
        currentUserId: 'leader',
      );

      expect(snapshot.riderFor('rider')!.gpsQuality, 'Weak');
      expect(
        engine
            .detectAlerts(snapshot)
            .where((alert) => alert.type == GroupAlertType.separated),
        isEmpty,
      );
    });

    test('reports a fresh accurate rider beyond the separation threshold', () {
      final engine = GroupRideIntelligence();
      final snapshot = engine.update(
        locations: [
          location(id: 'leader', latitude: 12.9716, leader: true),
          location(id: 'rider', latitude: 12.9916),
        ],
        leaderId: 'leader',
        currentUserId: 'leader',
      );

      expect(
        engine
            .detectAlerts(snapshot)
            .where((alert) => alert.type == GroupAlertType.separated),
        hasLength(1),
      );
    });

    test('does not invent GPS confidence when accuracy is unavailable', () {
      final engine = GroupRideIntelligence();
      final snapshot = engine.update(
        locations: [
          location(id: 'leader', latitude: 12.9716, leader: true),
          RiderLocation(
            userId: 'legacy-rider',
            rideId: 'ride',
            latitude: 12.9916,
            longitude: 77.5946,
            updatedAt: DateTime.now(),
            userName: 'Legacy rider',
            bikeName: 'Bike',
            isLeader: false,
            speed: 5,
          ),
        ],
        leaderId: 'leader',
        currentUserId: 'leader',
      );

      expect(snapshot.riderFor('legacy-rider')!.gpsQuality, 'Unknown');
      expect(
        engine
            .detectAlerts(snapshot)
            .where((alert) => alert.type == GroupAlertType.separated),
        isEmpty,
      );
    });
  });
}
