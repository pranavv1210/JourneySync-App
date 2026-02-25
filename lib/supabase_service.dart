import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _avatarBucket = String.fromEnvironment(
    'SUPABASE_AVATAR_BUCKET',
    defaultValue: 'avatars',
  );

  static const String _userColumnsWithAvatar =
      'id,phone,name,bike,avatar_url,created_at';
  static const String _userColumnsWithoutAvatar =
      'id,phone,name,bike,created_at';

  Future<Map<String, dynamic>?> fetchUserByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return _fetchUserSingle(eqColumn: 'phone', eqValue: normalized);
  }

  Future<Map<String, dynamic>?> fetchUserById(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return _fetchUserSingle(eqColumn: 'id', eqValue: normalized);
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

    try {
      final row =
          await _client
              .from('users')
              .insert(payload)
              .select(_userColumnsWithAvatar)
              .single();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingAvatarColumn(error)) {
        final row =
            await _client
                .from('users')
                .insert(payload)
                .select(_userColumnsWithoutAvatar)
                .single();
        return row;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required String name,
    required String bike,
  }) async {
    try {
      final row =
          await _client
              .from('users')
              .update({'name': name.trim(), 'bike': bike.trim()})
              .eq('id', userId.trim())
              .select(_userColumnsWithAvatar)
              .single();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingAvatarColumn(error)) {
        final row =
            await _client
                .from('users')
                .update({'name': name.trim(), 'bike': bike.trim()})
                .eq('id', userId.trim())
                .select(_userColumnsWithoutAvatar)
                .single();
        return row;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    final row =
        await _client
            .from('users')
            .update({'avatar_url': avatarUrl.trim()})
            .eq('id', userId.trim())
            .select(_userColumnsWithAvatar)
            .single();
    return row;
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final bucket = _avatarBucket.trim().isEmpty ? 'avatars' : _avatarBucket;
    final path =
        'user_${userId.trim().isEmpty ? 'unknown' : userId.trim()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return _client.storage.from(bucket).getPublicUrl(path);
    } on StorageException catch (error) {
      if (error.message.toLowerCase().contains('bucket not found')) {
        throw Exception(
          'Storage bucket "$bucket" not found. Create this bucket in Supabase Storage or pass --dart-define=SUPABASE_AVATAR_BUCKET=<bucket-name>.',
        );
      }
      rethrow;
    }
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

  Future<Map<String, dynamic>?> _fetchUserSingle({
    required String eqColumn,
    required String eqValue,
  }) async {
    try {
      final row =
          await _client
              .from('users')
              .select(_userColumnsWithAvatar)
              .eq(eqColumn, eqValue)
              .maybeSingle();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingAvatarColumn(error)) {
        final row =
            await _client
                .from('users')
                .select(_userColumnsWithoutAvatar)
                .eq(eqColumn, eqValue)
                .maybeSingle();
        return row;
      }
      rethrow;
    }
  }

  bool _isMissingAvatarColumn(PostgrestException error) {
    return (error.code ?? '').trim() == '42703' ||
        error.message.toLowerCase().contains('avatar_url');
  }
}
