import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'models/ride_member.dart';
import 'models/ride_route.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _avatarBucket = String.fromEnvironment(
    'SUPABASE_AVATAR_BUCKET',
    defaultValue: AppConfig.supabaseAvatarBucket,
  );

  static const String _userColumnsWithAvatar =
      'id,phone,name,bike,avatar_url,created_at';
  static const String _userColumnsWithoutAvatar =
      'id,phone,name,bike,created_at';
  static const String _rideColumnsWithCreator =
      'id,creator_id,title,start_location,end_location,created_at';
  static const String _rideColumnsWithHost =
      'id,host_id,title,start_location,end_location,created_at';
  static const String _rideColumnsWithUser =
      'id,user_id,title,start_location,end_location,created_at';
  static const String _rideColumnsLegacy =
      'id,leader_id,name,destination,status,created_at';

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
    try {
      final row =
          await _client
              .from('users')
              .update({'avatar_url': avatarUrl.trim()})
              .eq('id', userId.trim())
              .select(_userColumnsWithAvatar)
              .single();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingAvatarColumn(error)) {
        throw Exception(
          'Missing users.avatar_url column. Add this column in Supabase, then refresh the API schema cache.',
        );
      }
      rethrow;
    }
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
    final normalized = creatorId.trim();
    if (normalized.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final byId = <String, Map<String, dynamic>>{};

    Future<void> collectByOwner(String column) async {
      try {
        final rows = await _client
            .from('rides')
            .select()
            .eq(column, normalized)
            .order('created_at', ascending: false)
            .limit(limit * 3);
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          byId[id] = row;
        }
      } on PostgrestException catch (error) {
        final missingOwnerColumn =
            _isMissingRideCreatorColumn(error) ||
            _isMissingRideUserColumn(error) ||
            (error.code ?? '').trim() == '42703' ||
            (error.code ?? '').trim() == 'PGRST204';
        if (!missingOwnerColumn) rethrow;
      }
    }

    await collectByOwner('creator_id');
    await collectByOwner('user_id');
    await collectByOwner('leader_id');

    // Include rides user joined even if they did not create.
    try {
      final participantRows = await _client
          .from('participants')
          .select('ride_id')
          .eq('user_id', normalized);
      final rideIds =
          participantRows
              .map((row) => (row['ride_id'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      if (rideIds.isNotEmpty) {
        final rows = await _client
            .from('rides')
            .select()
            .inFilter('id', rideIds);
        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final id = (row['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          byId[id] = row;
        }
      }
    } on PostgrestException catch (_) {
      // Keep recent rides usable even if participants schema is unavailable.
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      final at = DateTime.tryParse((a['created_at'] ?? '').toString());
      final bt = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return merged.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchNearbyRides({
    required String excludeCreatorId,
    int limit = 5,
  }) async {
    try {
      final rows =
          excludeCreatorId.trim().isEmpty
              ? await _client
                  .from('rides')
                  .select(_rideColumnsWithHost)
                  .order('created_at', ascending: false)
                  .limit(limit)
              : await _client
                  .from('rides')
                  .select(_rideColumnsWithHost)
                  .not('host_id', 'eq', excludeCreatorId.trim())
                  .order('created_at', ascending: false)
                  .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRideHostColumn(error)) rethrow;
    }

    try {
      final rows =
          excludeCreatorId.trim().isEmpty
              ? await _client
                  .from('rides')
                  .select(_rideColumnsWithCreator)
                  .order('created_at', ascending: false)
                  .limit(limit)
              : await _client
                  .from('rides')
                  .select(_rideColumnsWithCreator)
                  .not('creator_id', 'eq', excludeCreatorId.trim())
                  .order('created_at', ascending: false)
                  .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (_isMissingRideCreatorColumn(error)) {
        try {
          final rows =
              excludeCreatorId.trim().isEmpty
                  ? await _client
                      .from('rides')
                      .select(_rideColumnsWithUser)
                      .order('created_at', ascending: false)
                      .limit(limit)
                  : await _client
                      .from('rides')
                      .select(_rideColumnsWithUser)
                      .not('user_id', 'eq', excludeCreatorId.trim())
                      .order('created_at', ascending: false)
                      .limit(limit);
          return List<Map<String, dynamic>>.from(rows);
        } on PostgrestException catch (nestedError) {
          if (_isMissingRideUserColumn(nestedError)) {
            final rows =
                excludeCreatorId.trim().isEmpty
                    ? await _client
                        .from('rides')
                        .select(_rideColumnsLegacy)
                        .order('created_at', ascending: false)
                        .limit(limit)
                    : await _client
                        .from('rides')
                        .select(_rideColumnsLegacy)
                        .not('leader_id', 'eq', excludeCreatorId.trim())
                        .order('created_at', ascending: false)
                        .limit(limit);
            return List<Map<String, dynamic>>.from(rows);
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRide({
    required String creatorId,
    required String title,
    required String startLocation,
    required String endLocation,
    DateTime? scheduledStartTime,
    int? maxRiders,
  }) async {
    final optionalPayload = <String, dynamic>{
      if (scheduledStartTime != null)
        'start_time': scheduledStartTime.toIso8601String(),
      if (maxRiders != null) 'max_riders': maxRiders,
    };
    final basePayload = <String, dynamic>{
      'title': title.trim(),
      'start_location': startLocation.trim(),
      'end_location': endLocation.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
    final payload = <String, dynamic>{...basePayload, ...optionalPayload};
    try {
      final row =
          await _client
              .from('rides')
              .insert({...payload, 'host_id': creatorId.trim()})
              .select(_rideColumnsWithHost)
              .single();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingRideOptionalColumns(error) && optionalPayload.isNotEmpty) {
        final row =
            await _client
                .from('rides')
                .insert({...basePayload, 'host_id': creatorId.trim()})
                .select(_rideColumnsWithHost)
                .single();
        return row;
      }
      if (!_isMissingRideHostColumn(error)) rethrow;
    }

    try {
      final row =
          await _client
              .from('rides')
              .insert({...payload, 'creator_id': creatorId.trim()})
              .select(_rideColumnsWithCreator)
              .single();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingRideOptionalColumns(error) && optionalPayload.isNotEmpty) {
        final row =
            await _client
                .from('rides')
                .insert({...basePayload, 'creator_id': creatorId.trim()})
                .select(_rideColumnsWithCreator)
                .single();
        return row;
      }
      if (_isMissingRideCreatorColumn(error)) {
        try {
          final row =
              await _client
                  .from('rides')
                  .insert({...payload, 'user_id': creatorId.trim()})
                  .select(_rideColumnsWithUser)
                  .single();
          return row;
        } on PostgrestException catch (nestedError) {
          if (_isMissingRideOptionalColumns(nestedError) &&
              optionalPayload.isNotEmpty) {
            final row =
                await _client
                    .from('rides')
                    .insert({...basePayload, 'user_id': creatorId.trim()})
                    .select(_rideColumnsWithUser)
                    .single();
            return row;
          }
          if (_isMissingRideUserColumn(nestedError) ||
              _isMissingRideLocationColumns(nestedError)) {
            final row =
                await _client
                    .from('rides')
                    .insert({
                      'leader_id': creatorId.trim(),
                      'name': title.trim(),
                      'destination': endLocation.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    })
                    .select(_rideColumnsLegacy)
                    .single();
            return row;
          }
          rethrow;
        }
      }
      if (_isMissingRideLocationColumns(error)) {
        final row =
            await _client
                .from('rides')
                .insert({
                  'leader_id': creatorId.trim(),
                  'name': title.trim(),
                  'destination': endLocation.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select(_rideColumnsLegacy)
                .single();
        return row;
      }
      rethrow;
    }
  }

  Future<void> addParticipant({
    required String rideId,
    required String userId,
  }) async {
    try {
      await _client.from('ride_members').insert({
        'ride_id': rideId.trim(),
        'user_id': userId.trim(),
      });
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }

    await _client.from('participants').insert({
      'ride_id': rideId.trim(),
      'user_id': userId.trim(),
    });
  }

  Future<void> removeParticipant({
    required String rideId,
    required String userId,
  }) async {
    try {
      await _client
          .from('ride_members')
          .delete()
          .eq('ride_id', rideId.trim())
          .eq('user_id', userId.trim());
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }

    await _client
        .from('participants')
        .delete()
        .eq('ride_id', rideId.trim())
        .eq('user_id', userId.trim());
  }

  Future<void> createJoinRequest({
    required String rideId,
    required String userId,
  }) async {
    await _client.from('join_requests').insert({
      'ride_id': rideId.trim(),
      'user_id': userId.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchRecentRidesForCodeLookup({
    int limit = 250,
  }) async {
    final rows = await _client
        .from('rides')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> deleteRideAsCreator({
    required String rideId,
    required String creatorId,
  }) async {
    final normalizedRideId = rideId.trim();
    final normalizedCreatorId = creatorId.trim();
    if (normalizedRideId.isEmpty || normalizedCreatorId.isEmpty) {
      throw Exception('Ride delete failed: invalid ride/user id.');
    }

    // Best-effort cleanup of dependent rows.
    try {
      await _client
          .from('participants')
          .delete()
          .eq('ride_id', normalizedRideId);
    } catch (_) {}
    try {
      await _client
          .from('join_requests')
          .delete()
          .eq('ride_id', normalizedRideId);
    } catch (_) {}

    Future<Map<String, dynamic>?> findRideByOwnerColumn(
      String ownerColumn,
    ) async {
      final row =
          await _client
              .from('rides')
              .select('id,$ownerColumn')
              .eq('id', normalizedRideId)
              .eq(ownerColumn, normalizedCreatorId)
              .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    }

    Future<bool> deleteWithOwnerColumn(String ownerColumn) async {
      final matchingRide = await findRideByOwnerColumn(ownerColumn);
      if (matchingRide == null) {
        return false;
      }

      await _client
          .from('rides')
          .delete()
          .eq('id', normalizedRideId)
          .eq(ownerColumn, normalizedCreatorId);

      final remainingRide = await findRideByOwnerColumn(ownerColumn);
      return remainingRide == null;
    }

    try {
      final deleted = await deleteWithOwnerColumn('creator_id');
      if (deleted) return;
    } on PostgrestException catch (error) {
      if (!_isMissingRideCreatorColumn(error)) rethrow;
    }

    try {
      final deleted = await deleteWithOwnerColumn('user_id');
      if (deleted) return;
    } on PostgrestException catch (error) {
      if (!_isMissingRideUserColumn(error)) rethrow;
    }

    final deleted = await deleteWithOwnerColumn('leader_id');
    if (!deleted) {
      final stillExists =
          await _client
              .from('rides')
              .select('id')
              .eq('id', normalizedRideId)
              .maybeSingle() !=
          null;
      if (!stillExists) {
        // Treat "already removed" as a successful delete.
        return;
      }
      throw Exception(
        'Ride was not deleted. Delete permission is missing for this user.',
      );
    }
  }

  Future<void> archiveCompletedRideAsCreator({
    required String rideId,
    required String creatorId,
  }) async {
    final normalizedRideId = rideId.trim();
    final normalizedCreatorId = creatorId.trim();
    if (normalizedRideId.isEmpty || normalizedCreatorId.isEmpty) {
      throw Exception('Ride archive failed: invalid ride/user id.');
    }

    Future<void> updateWithCreatorFilter(
      String ownerColumn,
      Map<String, dynamic> payload,
    ) async {
      await _client
          .from('rides')
          .update(payload)
          .eq('id', normalizedRideId)
          .eq(ownerColumn, normalizedCreatorId);
    }

    Future<void> updatePayloadWithFallbackOwner(
      Map<String, dynamic> payload,
    ) async {
      try {
        await updateWithCreatorFilter('creator_id', payload);
        return;
      } on PostgrestException catch (error) {
        if (!_isMissingRideCreatorColumn(error)) rethrow;
      }

      try {
        await updateWithCreatorFilter('user_id', payload);
        return;
      } on PostgrestException catch (error) {
        if (!_isMissingRideUserColumn(error)) rethrow;
      }

      await updateWithCreatorFilter('leader_id', payload);
    }

    final payloads = <Map<String, dynamic>>[
      {'archived_at': DateTime.now().toIso8601String()},
      {'is_archived': true},
      {'archived': true},
      {'status': 'archived'},
    ];

    PostgrestException? lastSchemaError;
    for (final payload in payloads) {
      try {
        await updatePayloadWithFallbackOwner(payload);
        return;
      } on PostgrestException catch (error) {
        final code = (error.code ?? '').trim();
        final message = error.message.toLowerCase();
        final likelyMissingColumn =
            code == '42703' ||
            code == 'PGRST204' ||
            message.contains('archived_at') ||
            message.contains('is_archived') ||
            message.contains('archived');
        if (likelyMissingColumn) {
          lastSchemaError = error;
          continue;
        }
        rethrow;
      }
    }

    if (lastSchemaError != null) {
      throw Exception(
        'Ride archive is not configured in DB. Add one of: archived_at, is_archived, archived, or status column.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchParticipantsByRideIds(
    List<String> rideIds,
  ) async {
    final ids =
        rideIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final rows = await _client
          .from('ride_members')
          .select('ride_id,user_id')
          .inFilter('ride_id', ids);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }

    final rows = await _client
        .from('participants')
        .select('ride_id,user_id')
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

    try {
      final rows = await _client
          .from('ride_members')
          .select('ride_id,user_id')
          .eq('user_id', normalized);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }

    final rows = await _client
        .from('participants')
        .select('ride_id,user_id')
        .eq('user_id', normalized);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> fetchRideById(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return null;

    Future<Map<String, dynamic>?> getRide(String columns) {
      return _client.from('rides').select(columns).eq('id', normalized).maybeSingle();
    }

    try {
      return await getRide('*');
    } catch (_) {
      return null;
    }
  }

  Future<List<RideMember>> fetchRideMembers(String rideId) async {
    final normalizedRideId = rideId.trim();
    if (normalizedRideId.isEmpty) return <RideMember>[];

    final ride = await fetchRideById(normalizedRideId);
    final hostId =
        (ride?['host_id'] ??
                ride?['creator_id'] ??
                ride?['user_id'] ??
                ride?['leader_id'] ??
                '')
            .toString()
            .trim();
    final memberRows = await fetchParticipantsByRideIds(<String>[normalizedRideId]);
    final userIds = <String>{
      ...memberRows
          .map((row) => (row['user_id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty),
      if (hostId.isNotEmpty) hostId,
    }.toList();

    final users = await fetchUsersByIds(userIds);
    return userIds.map((userId) {
      final row = users[userId];
      return RideMember(
        userId: userId,
        name: ((row?['name'] ?? 'Rider').toString().trim().isEmpty)
            ? 'Rider'
            : (row?['name'] ?? 'Rider').toString().trim(),
        bike: ((row?['bike'] ?? 'No bike added').toString().trim().isEmpty)
            ? 'No bike added'
            : (row?['bike'] ?? 'No bike added').toString().trim(),
        avatarUrl: (row?['avatar_url'] ?? '').toString().trim(),
        isHost: userId == hostId,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> fetchUsersByIds(
    List<String> userIds,
  ) async {
    final ids =
        userIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return <String, Map<String, dynamic>>{};

    try {
      final rows = await _client
          .from('users')
          .select(_userColumnsWithAvatar)
          .inFilter('id', ids);
      return {
        for (final row in rows)
          (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(row),
      };
    } on PostgrestException catch (error) {
      if (!_isMissingAvatarColumn(error)) rethrow;
      final rows = await _client
          .from('users')
          .select(_userColumnsWithoutAvatar)
          .inFilter('id', ids);
      return {
        for (final row in rows)
          (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(row),
      };
    }
  }

  Future<void> saveRideRoute({
    required String rideId,
    required String hostId,
    required String startLabel,
    required String endLabel,
    required List<RouteStop> stops,
  }) async {
    final payload = <String, dynamic>{
      'ride_id': rideId.trim(),
      'host_id': hostId.trim(),
      'start_label': startLabel.trim(),
      'end_label': endLabel.trim(),
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('ride_routes').upsert(payload, onConflict: 'ride_id');
  }

  Future<RideRoute?> fetchRideRoute(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return null;
    try {
      final row = await _client
          .from('ride_routes')
          .select()
          .eq('ride_id', normalized)
          .maybeSingle();
      if (row == null) return null;
      final rawStops = (row['stops'] as List?) ?? const [];
      return RideRoute(
        rideId: normalized,
        startLabel: (row['start_label'] ?? '').toString().trim(),
        endLabel: (row['end_label'] ?? '').toString().trim(),
        stops: rawStops
            .whereType<Map>()
            .map((stop) => RouteStop.fromJson(Map<String, dynamic>.from(stop)))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
      );
    } on PostgrestException catch (error) {
      if (_isMissingRideRoutesSchema(error)) return null;
      rethrow;
    }
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
        (error.code ?? '').trim() == 'PGRST204' ||
        error.message.toLowerCase().contains('avatar_url');
  }

  bool _isMissingRideCreatorColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' &&
            (message.contains('creator_id') || message.contains('user_id')) ||
        message.contains('creator_id');
  }

  bool _isMissingRideHostColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' && message.contains('host_id') ||
        message.contains('host_id');
  }

  bool _isMissingRideUserColumn(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' && message.contains('user_id') ||
        message.contains('user_id');
  }

  bool _isMissingRideLocationColumns(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    return code == '42703' ||
        code == 'PGRST204' &&
            (message.contains('end_location') ||
                message.contains('start_location') ||
                message.contains('title')) ||
        message.contains('end_location') ||
        message.contains('start_location') ||
        message.contains('title');
  }

  bool _isMissingRideOptionalColumns(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    if (code != '42703' && code != 'PGRST204') {
      return false;
    }
    return message.contains('start_time') || message.contains('max_riders');
  }

  bool _isMissingRideMembersSchema(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42P01' ||
        code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('ride_members');
  }

  bool _isMissingRideRoutesSchema(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42P01' ||
        code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('ride_routes');
  }
}
