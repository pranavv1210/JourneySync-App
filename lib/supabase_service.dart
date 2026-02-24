import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final row =
        await _client
            .from('users')
            .select('id,phone,name,bike,created_at')
            .eq('phone', normalized)
            .maybeSingle();
    return row;
  }

  Future<Map<String, dynamic>?> fetchUserById(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final row =
        await _client
            .from('users')
            .select('id,phone,name,bike,created_at')
            .eq('id', normalized)
            .maybeSingle();
    return row;
  }

  Future<Map<String, dynamic>> createUser({
    required String phone,
    required String name,
    required String bike,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone.trim(),
      'name': name.trim(),
      'bike': bike.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final row =
        await _client
            .from('users')
            .insert(payload)
            .select('id,phone,name,bike,created_at')
            .single();
    return row;
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required String name,
    required String bike,
  }) async {
    final row =
        await _client
            .from('users')
            .update({
              'name': name.trim(),
              'bike': bike.trim(),
            })
            .eq('id', userId.trim())
            .select('id,phone,name,bike,created_at')
            .single();
    return row;
  }

  Future<List<Map<String, dynamic>>> fetchRecentRidesByCreator({
    required String creatorId,
    int limit = 5,
  }) async {
    if (creatorId.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final rows = await _client
        .from('rides')
        .select('id,creator_id,title,start_location,end_location,created_at')
        .eq('creator_id', creatorId.trim())
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchNearbyRides({
    required String excludeCreatorId,
    int limit = 5,
  }) async {
    final rows =
        excludeCreatorId.trim().isEmpty
            ? await _client
                .from('rides')
                .select(
                  'id,creator_id,title,start_location,end_location,created_at',
                )
                .order('created_at', ascending: false)
                .limit(limit)
            : await _client
                .from('rides')
                .select(
                  'id,creator_id,title,start_location,end_location,created_at',
                )
                .not('creator_id', 'eq', excludeCreatorId.trim())
                .order('created_at', ascending: false)
                .limit(limit);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRide({
    required String creatorId,
    required String title,
    required String startLocation,
    required String endLocation,
  }) async {
    final payload = <String, dynamic>{
      'creator_id': creatorId.trim(),
      'title': title.trim(),
      'start_location': startLocation.trim(),
      'end_location': endLocation.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final row =
        await _client
            .from('rides')
            .insert(payload)
            .select(
              'id,creator_id,title,start_location,end_location,created_at',
            )
            .single();
    return row;
  }

  Future<void> addParticipant({
    required String rideId,
    required String userId,
  }) async {
    await _client.from('participants').insert({
      'ride_id': rideId.trim(),
      'user_id': userId.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchParticipantsByRideIds(
    List<String> rideIds,
  ) async {
    final ids =
        rideIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final rows = await _client
        .from('participants')
        .select('id,ride_id,user_id')
        .inFilter('ride_id', ids);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchParticipantsByUser(
    String userId,
  ) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final rows = await _client
        .from('participants')
        .select('id,ride_id,user_id')
        .eq('user_id', normalized);
    return List<Map<String, dynamic>>.from(rows);
  }

  Stream<List<Map<String, dynamic>>> watchRides() {
    return _client
        .from('rides')
        .stream(primaryKey: const ['id'])
        .order('created_at', ascending: false);
  }
}
