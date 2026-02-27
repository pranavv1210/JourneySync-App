import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RideRecord {
  const RideRecord({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.createdAt,
    this.participantCount = 0,
  });

  final String id;
  final String creatorId;
  final String title;
  final String startLocation;
  final String endLocation;
  final DateTime? createdAt;
  final int participantCount;
}

class NearbyRide {
  const NearbyRide({
    required this.ride,
    required this.hostName,
    required this.hostBike,
    required this.joined,
  });

  final RideRecord ride;
  final String hostName;
  final String hostBike;
  final bool joined;

  NearbyRide copyWith({
    RideRecord? ride,
    String? hostName,
    String? hostBike,
    bool? joined,
  }) {
    return NearbyRide(
      ride: ride ?? this.ride,
      hostName: hostName ?? this.hostName,
      hostBike: hostBike ?? this.hostBike,
      joined: joined ?? this.joined,
    );
  }
}

class RideService {
  RideService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  Future<List<RideRecord>> fetchRecentRides(String creatorId) async {
    final rows = await _supabaseService.fetchRecentRidesByCreator(
      creatorId: creatorId,
      limit: 5,
    );
    final rides = rows.map(_toRideRecord).toList();
    return _attachParticipantCounts(rides);
  }

  Future<List<RideRecord>> fetchNearbyRides(String currentUserId) async {
    final rows = await _supabaseService.fetchNearbyRides(
      excludeCreatorId: currentUserId,
      limit: 5,
    );
    return rows.map(_toRideRecord).toList();
  }

  Future<RideRecord> createRide({
    required String creatorId,
    required String title,
    required String startLocation,
    required String endLocation,
  }) async {
    final row = await _supabaseService.createRide(
      creatorId: creatorId,
      title: title,
      startLocation: startLocation,
      endLocation: endLocation,
    );
    final ride = _toRideRecord(row);
    await joinRide(rideId: ride.id, userId: creatorId, suppressDuplicate: true);
    return ride;
  }

  Future<List<NearbyRide>> searchNearbyRides(String currentUserId) async {
    final rides = await fetchNearbyRides(currentUserId);
    if (rides.isEmpty) {
      return <NearbyRide>[];
    }

    final recentCutoff = DateTime.now().subtract(const Duration(hours: 24));
    final filtered =
        rides.where((ride) {
          final createdAt = ride.createdAt;
          if (createdAt == null) return true;
          return createdAt.isAfter(recentCutoff);
        }).toList();

    if (filtered.isEmpty) {
      return <NearbyRide>[];
    }

    final rideIds = filtered.map((r) => r.id).toList();
    final participants = await _supabaseService.fetchParticipantsByRideIds(
      rideIds,
    );
    final participantCounts = _countByRideId(participants);

    final joinedRows = await _supabaseService.fetchParticipantsByUser(
      currentUserId,
    );
    final joinedRideIds =
        joinedRows
            .map((row) => (row['ride_id'] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toSet();

    final creatorIds = filtered.map((r) => r.creatorId).toSet().toList();
    final creatorProfiles = await _fetchCreatorProfiles(creatorIds);

    return filtered.map((ride) {
      final profile =
          creatorProfiles[ride.creatorId] ?? const <String, String>{};
      final hostName = (profile['name'] ?? 'Rider').trim();
      final hostBike = (profile['bike'] ?? 'No bike added').trim();
      final participantCount = participantCounts[ride.id] ?? 0;

      return NearbyRide(
        ride: RideRecord(
          id: ride.id,
          creatorId: ride.creatorId,
          title: ride.title,
          startLocation: ride.startLocation,
          endLocation: ride.endLocation,
          createdAt: ride.createdAt,
          participantCount: participantCount,
        ),
        hostName: hostName.isNotEmpty ? hostName : 'Rider',
        hostBike: hostBike.isNotEmpty ? hostBike : 'No bike added',
        joined:
            joinedRideIds.contains(ride.id) || ride.creatorId == currentUserId,
      );
    }).toList();
  }

  Future<void> joinRide({
    required String rideId,
    required String userId,
    bool suppressDuplicate = false,
  }) async {
    try {
      await _supabaseService.addParticipant(rideId: rideId, userId: userId);
    } catch (error) {
      if (suppressDuplicate &&
          error is PostgrestException &&
          (error.code ?? '') == '23505') {
        return;
      }
      rethrow;
    }
  }

  Stream<List<RideRecord>> watchRides() {
    return _supabaseService.watchRides().map((rows) {
      return rows.map(_toRideRecord).toList();
    });
  }

  RideRecord _toRideRecord(Map<String, dynamic> row) {
    final creator =
        (row['creator_id'] ?? row['user_id'] ?? '').toString().trim();
    return RideRecord(
      id: (row['id'] ?? '').toString(),
      creatorId: creator,
      title: (row['title'] ?? 'Ride').toString(),
      startLocation: (row['start_location'] ?? '').toString(),
      endLocation: (row['end_location'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
    );
  }

  Future<List<RideRecord>> _attachParticipantCounts(
    List<RideRecord> rides,
  ) async {
    if (rides.isEmpty) return rides;
    final rideIds = rides.map((ride) => ride.id).toList();
    final participants = await _supabaseService.fetchParticipantsByRideIds(
      rideIds,
    );
    final counts = _countByRideId(participants);

    return rides
        .map(
          (ride) => RideRecord(
            id: ride.id,
            creatorId: ride.creatorId,
            title: ride.title,
            startLocation: ride.startLocation,
            endLocation: ride.endLocation,
            createdAt: ride.createdAt,
            participantCount: counts[ride.id] ?? 0,
          ),
        )
        .toList();
  }

  Map<String, int> _countByRideId(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final rideId = (row['ride_id'] ?? '').toString().trim();
      if (rideId.isEmpty) continue;
      counts[rideId] = (counts[rideId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, Map<String, String>>> _fetchCreatorProfiles(
    List<String> creatorIds,
  ) async {
    final uniqueIds =
        creatorIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return <String, Map<String, String>>{};
    }

    final entries = await Future.wait(
      uniqueIds.map((id) async {
        final row = await _supabaseService.fetchUserById(id);
        final name = (row?['name'] ?? '').toString();
        final bike = (row?['bike'] ?? '').toString();
        return MapEntry(id, <String, String>{'name': name, 'bike': bike});
      }),
    );

    return Map<String, Map<String, String>>.fromEntries(entries);
  }
}
