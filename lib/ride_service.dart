import 'supabase_service.dart';

class RideRecord {
  const RideRecord({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String title;
  final String startLocation;
  final String endLocation;
  final DateTime? createdAt;
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
    return rows.map(_toRideRecord).toList();
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
    return _toRideRecord(row);
  }

  Stream<List<RideRecord>> watchRides() {
    return _supabaseService.watchRides().map((rows) {
      return rows.map(_toRideRecord).toList();
    });
  }

  RideRecord _toRideRecord(Map<String, dynamic> row) {
    return RideRecord(
      id: (row['id'] ?? '').toString(),
      creatorId: (row['creator_id'] ?? '').toString(),
      title: (row['title'] ?? 'Ride').toString(),
      startLocation: (row['start_location'] ?? '').toString(),
      endLocation: (row['end_location'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
    );
  }
}
