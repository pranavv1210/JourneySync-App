import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import '../models/ride_member.dart';
import '../models/ride_route.dart';
import '../utils/app_logger.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _avatarBucket = String.fromEnvironment(
    'SUPABASE_AVATAR_BUCKET',
    defaultValue: AppConfig.supabaseAvatarBucket,
  );

  static const String _rideColumnsWithHost =
      'id,host_id,title,start_location,end_location,created_at,status,ride_visibility,ride_mode';
  static const List<String> _rideCreatorColumns = <String>[
    'host_id',
    'profile_id',
    'creator_id',
    'user_id',
  ];

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

    if (_looksLikeUuid(normalized)) {
      final byAuthUserId = await _fetchUserSingle(
        eqColumn: 'auth_user_id',
        eqValue: normalized,
      );
      if (byAuthUserId != null) return byAuthUserId;
    }

    return _fetchUserSingle(eqColumn: 'id', eqValue: normalized);
  }

  Future<Map<String, dynamic>?> fetchOrCreateCurrentUserProfile({
    required String cachedUserId,
    required String cachedPhone,
    required String cachedName,
    required String cachedBike,
  }) async {
    final authUser = _client.auth.currentUser;
    AppLogger.info(
      'Auth profile lookup started. signedIn=${authUser != null}',
      'SupabaseService',
    );

    final authUserId = (authUser?.id ?? '').trim();
    final authPhone = (authUser?.phone ?? '').trim();
    final authMetadata = authUser?.userMetadata ?? const <String, dynamic>{};
    final metadataPhone =
        (authMetadata['phone'] ??
                authMetadata['phone_number'] ??
                authMetadata['mobile'] ??
                '')
            .toString()
            .trim();
    final metadataName =
        (authMetadata['name'] ??
                authMetadata['full_name'] ??
                authMetadata['first_name'] ??
                '')
            .toString()
            .trim();

    final preferredId =
        authUserId.isNotEmpty ? authUserId : cachedUserId.trim();
    final preferredPhone =
        authPhone.isNotEmpty
            ? authPhone
            : metadataPhone.isNotEmpty
            ? metadataPhone
            : cachedPhone.trim();

    Map<String, dynamic>? row;
    if (preferredId.isNotEmpty) {
      row = await fetchUserById(preferredId);
    }
    if (row == null && preferredPhone.isNotEmpty) {
      row = await fetchUserByPhone(preferredPhone);
    }
    if (row != null) {
      return row;
    }

    if (authUserId.isEmpty) {
      return null;
    }

    return upsertAuthenticatedUserProfile(
      userId: authUserId,
      phone: preferredPhone,
      name:
          cachedName.trim().isNotEmpty
              ? cachedName.trim()
              : metadataName.isNotEmpty
              ? metadataName
              : 'Rider',
      bike: cachedBike.trim().isNotEmpty ? cachedBike.trim() : 'No bike added',
    );
  }

  Future<Map<String, dynamic>> upsertAuthenticatedUserProfile({
    required String userId,
    required String phone,
    required String name,
    required String bike,
  }) async {
    final desired = <String, dynamic>{
      'id': userId.trim(),
      'auth_user_id': userId.trim(),
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      'name': name.trim().isEmpty ? 'Rider' : name.trim(),
      'bike': bike.trim().isEmpty ? 'No bike added' : bike.trim(),
    };
    return _upsertProfileWithFallbacks(desired);
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
    };

    return _insertProfileWithFallbacks(payload);
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required String name,
    required String bike,
    String? phone,
  }) async {
    final desired = <String, dynamic>{
      'id': userId.trim(),
      'auth_user_id': userId.trim(),
      'name': name.trim().isEmpty ? 'Rider' : name.trim(),
      'bike': bike.trim().isEmpty ? 'No bike added' : bike.trim(),
      if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
    };
    return _updateProfileWithFallbacks(userId.trim(), desired);
  }

  Future<({List<Map<String, String>> bikes, String activeBikeId})?>
  fetchGarage({required String userId}) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return null;

    Future<Map<String, dynamic>?> fetchBy(String column) {
      return _client
          .from('profiles')
          .select('garage_bikes,active_bike_id')
          .eq(column, normalized)
          .maybeSingle();
    }

    try {
      Map<String, dynamic>? row;
      if (await _profileColumnExists('auth_user_id')) {
        row = await fetchBy('auth_user_id');
      }
      row ??= await fetchBy('id');
      if (row == null) return null;
      return (
        bikes: _decodeGarageBikes(row['garage_bikes']),
        activeBikeId: (row['active_bike_id'] ?? '').toString().trim(),
      );
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) return null;
      rethrow;
    }
  }

  Future<void> saveGarage({
    required String userId,
    required List<Map<String, String>> bikes,
    required String activeBikeId,
  }) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return;
    final payload = <String, dynamic>{
      'garage_bikes':
          bikes.map((bike) => Map<String, String>.from(bike)).toList(),
      'active_bike_id':
          activeBikeId.trim().isEmpty ? null : activeBikeId.trim(),
    };

    Future<void> updateBy(String column) {
      return _client.from('profiles').update(payload).eq(column, normalized);
    }

    try {
      if (await _profileColumnExists('auth_user_id')) {
        await updateBy('auth_user_id');
        return;
      }
      await updateBy('id');
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) return;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserAvatar({
    required String userId,
    required String avatarUrl,
  }) async {
    try {
      return await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl.trim()})
          .eq('id', userId.trim())
          .select('id,phone,name,bike,avatar_url')
          .single();
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) {
        try {
          return await _client
              .from('profiles')
              .update({'avatar_url': avatarUrl.trim()})
              .eq('id', userId.trim())
              .select('id,phone,name,avatar_url')
              .single();
        } catch (_) {
          return await _client
              .from('profiles')
              .update({'avatar_url': avatarUrl.trim()})
              .eq('id', userId.trim())
              .select('id,avatar_url')
              .single();
        }
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

    final hostRows = await _selectRidesByCreator(
      creatorId: normalized,
      limit: limit * 3,
    );
    for (final row in List<Map<String, dynamic>>.from(hostRows)) {
      final id = (row['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      byId[id] = row;
    }

    try {
      final participantRows = await _client
          .from('ride_members')
          .select('ride_id')
          .eq('member_id', normalized)
          .eq('status', 'approved');
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
    } on PostgrestException catch (_) {}

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
    final rows =
        excludeCreatorId.trim().isEmpty
            ? await _client
                .from('rides')
                .select()
                .order('created_at', ascending: false)
                .limit(limit)
            : await _selectNearbyRidesExcludingCreator(
              creatorId: excludeCreatorId.trim(),
              limit: limit,
            );
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRide({
    required String creatorId,
    required String title,
    required String startLocation,
    required String endLocation,
    DateTime? scheduledStartTime,
    int? maxRiders,
    String rideVisibility = 'public',
    String rideMode = 'group',
    String status = 'scheduled',
  }) async {
    final optionalPayload = <String, dynamic>{
      if (scheduledStartTime != null)
        'start_time': scheduledStartTime.toIso8601String(),
      if (maxRiders != null) 'max_riders': maxRiders,
      'ride_visibility':
          rideVisibility.trim().toLowerCase() == 'private'
              ? 'private'
              : 'public',
      'ride_mode': rideMode.trim().isEmpty ? 'group' : rideMode.trim(),
      'status': status.trim().isEmpty ? 'scheduled' : status.trim(),
    };
    final basePayload = <String, dynamic>{
      'title': title.trim(),
      'start_location': startLocation.trim(),
      'end_location': endLocation.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
    final payload = <String, dynamic>{...basePayload, ...optionalPayload};
    try {
      return await _insertRideWithCreator(
        payload: payload,
        creatorId: creatorId,
        preferredSelect: _rideColumnsWithHost,
      );
    } on PostgrestException catch (error) {
      if (_isMissingRideColumn(error, 'end_location')) {
        return _createRideWithLegacyDestinationFallback(
          creatorId: creatorId,
          basePayload: basePayload,
          optionalPayload: optionalPayload,
          endLocation: endLocation,
        );
      }
      if (_isMissingRideOptionalColumns(error) && optionalPayload.isNotEmpty) {
        return _insertRideWithCreator(
          payload: {
            ...basePayload,
            'status': status.trim().isEmpty ? 'scheduled' : status.trim(),
          },
          creatorId: creatorId,
          preferredSelect:
              'id,host_id,title,start_location,end_location,created_at,status',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _createRideWithLegacyDestinationFallback({
    required String creatorId,
    required Map<String, dynamic> basePayload,
    required Map<String, dynamic> optionalPayload,
    required String endLocation,
  }) async {
    final legacyBase =
        Map<String, dynamic>.from(basePayload)
          ..remove('end_location')
          ..['destination'] = endLocation.trim();
    final attempts = <Map<String, dynamic>>[
      {...legacyBase, ...optionalPayload},
      {
        ...legacyBase,
        'status':
            (optionalPayload['status'] ?? 'scheduled').toString().trim().isEmpty
                ? 'scheduled'
                : optionalPayload['status'],
      },
    ];

    Object? lastError;
    for (final attempt in attempts) {
      try {
        return await _insertRideWithCreator(
          payload: attempt,
          creatorId: creatorId,
        );
      } on PostgrestException catch (error) {
        lastError = error;
        if (!_isMissingColumnError(error)) rethrow;
      }
    }

    final minimalPayload = Map<String, dynamic>.from(basePayload)
      ..remove('end_location');
    try {
      final row = await _insertRideWithCreator(
        payload: minimalPayload,
        creatorId: creatorId,
      );
      return {...Map<String, dynamic>.from(row), 'end_location': endLocation};
    } on PostgrestException {
      throw lastError ?? Exception('Could not create ride.');
    }
  }

  Future<Map<String, dynamic>> _insertRideWithCreator({
    required Map<String, dynamic> payload,
    required String creatorId,
    String preferredSelect = '*',
  }) async {
    final normalizedCreatorId = creatorId.trim();
    Object? lastCreatorColumnError;

    for (final creatorColumn in _rideCreatorColumns) {
      final attempt = <String, dynamic>{
        ...payload,
        if (normalizedCreatorId.isNotEmpty) creatorColumn: normalizedCreatorId,
      };
      try {
        final selectColumns =
            creatorColumn == 'host_id' ? preferredSelect : '*';
        return await _client
            .from('rides')
            .insert(attempt)
            .select(selectColumns)
            .single();
      } on PostgrestException catch (error) {
        final missingAttemptColumn = _isMissingRideColumn(error, creatorColumn);
        final missingPreferredSelectHost =
            creatorColumn == 'host_id' &&
            preferredSelect.contains('host_id') &&
            _isMissingRideColumn(error, 'host_id');
        if (missingAttemptColumn || missingPreferredSelectHost) {
          lastCreatorColumnError = error;
          continue;
        }
        rethrow;
      }
    }

    try {
      return await _client.from('rides').insert(payload).select().single();
    } on PostgrestException catch (error) {
      throw lastCreatorColumnError ?? error;
    }
  }

  Future<List<Map<String, dynamic>>> _selectRidesByCreator({
    required String creatorId,
    required int limit,
  }) async {
    Object? lastError;
    for (final creatorColumn in _rideCreatorColumns) {
      try {
        final rows = await _client
            .from('rides')
            .select()
            .eq(creatorColumn, creatorId)
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(rows);
      } on PostgrestException catch (error) {
        if (_isMissingRideColumn(error, creatorColumn)) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }
    if (lastError != null) return <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _selectNearbyRidesExcludingCreator({
    required String creatorId,
    required int limit,
  }) async {
    for (final creatorColumn in _rideCreatorColumns) {
      try {
        final rows = await _client
            .from('rides')
            .select()
            .not(creatorColumn, 'eq', creatorId)
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(rows);
      } on PostgrestException catch (error) {
        if (_isMissingRideColumn(error, creatorColumn)) continue;
        rethrow;
      }
    }

    final rows = await _client
        .from('rides')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _deleteRideWithCreatorFilter({
    required String rideId,
    required String creatorId,
  }) async {
    Object? lastError;
    for (final creatorColumn in _rideCreatorColumns) {
      try {
        await _client
            .from('rides')
            .delete()
            .eq('id', rideId)
            .eq(creatorColumn, creatorId);
        return;
      } on PostgrestException catch (error) {
        if (_isMissingRideColumn(error, creatorColumn)) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }
    if (lastError is PostgrestException) throw lastError;
  }

  Future<void> _updateRideWithCreatorFilter({
    required String rideId,
    required String creatorId,
    required Map<String, dynamic> payload,
  }) async {
    Object? lastError;
    for (final creatorColumn in _rideCreatorColumns) {
      try {
        await _client
            .from('rides')
            .update(payload)
            .eq('id', rideId)
            .eq(creatorColumn, creatorId);
        return;
      } on PostgrestException catch (error) {
        if (_isMissingRideColumn(error, creatorColumn)) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }
    if (lastError is PostgrestException) throw lastError;
  }

  Future<void> addParticipant({
    required String rideId,
    required String userId,
  }) async {
    await _client.from('ride_members').upsert({
      'ride_id': rideId.trim(),
      'member_id': userId.trim(),
      'status': 'approved',
      'role': 'member',
    }, onConflict: 'ride_id,member_id');
  }

  Future<void> removeParticipant({
    required String rideId,
    required String userId,
  }) async {
    await _client
        .from('ride_members')
        .delete()
        .eq('ride_id', rideId.trim())
        .eq('member_id', userId.trim());
  }

  Future<void> createJoinRequest({
    required String rideId,
    required String userId,
  }) async {
    await _client.from('ride_members').upsert({
      'ride_id': rideId.trim(),
      'member_id': userId.trim(),
      'status': 'pending',
      'role': 'member',
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'ride_id,member_id');
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

    await _client.from('ride_members').delete().eq('ride_id', normalizedRideId);
    await _deleteRideWithCreatorFilter(
      rideId: normalizedRideId,
      creatorId: normalizedCreatorId,
    );
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

    Future<void> updateWithHostFilter(Map<String, dynamic> payload) =>
        _updateRideWithCreatorFilter(
          rideId: normalizedRideId,
          creatorId: normalizedCreatorId,
          payload: payload,
        );

    final payloads = <Map<String, dynamic>>[
      {'archived_at': DateTime.now().toIso8601String()},
      {'is_archived': true},
      {'archived': true},
      {'status': 'archived'},
    ];

    for (final payload in payloads) {
      try {
        await updateWithHostFilter(payload);
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
          continue;
        }
        rethrow;
      }
    }
    throw Exception(
      'Ride archive is not configured in DB. Add one of: archived_at, is_archived, archived, or status column.',
    );
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
          .select('ride_id,user_id:member_id,status')
          .inFilter('ride_id', ids);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }
    return <Map<String, dynamic>>[];
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
          .select('ride_id,user_id:member_id,status')
          .eq('member_id', normalized);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      if (!_isMissingRideMembersSchema(error)) rethrow;
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> fetchRideById(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return null;

    Future<Map<String, dynamic>?> getRide(String columns) {
      return _client
          .from('rides')
          .select(columns)
          .eq('id', normalized)
          .maybeSingle();
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
                ride?['profile_id'] ??
                ride?['creator_id'] ??
                ride?['user_id'] ??
                '')
            .toString()
            .trim();
    final memberRows = await fetchParticipantsByRideIds(<String>[
      normalizedRideId,
    ]);
    final userIds =
        <String>{
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
        name:
            ((row?['name'] ?? 'Rider').toString().trim().isEmpty)
                ? 'Rider'
                : (row?['name'] ?? 'Rider').toString().trim(),
        bike:
            ((row?['bike'] ?? 'No bike added').toString().trim().isEmpty)
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
        userIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    if (ids.isEmpty) return <String, Map<String, dynamic>>{};

    try {
      final rows = await _client
          .from('profiles')
          .select('id,phone,name,bike,avatar_url')
          .inFilter('id', ids);
      return {
        for (final row in rows)
          (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(row),
      };
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) {
        try {
          final rows = await _client
              .from('profiles')
              .select('id,phone,name')
              .inFilter('id', ids);
          return {
            for (final row in rows)
              (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(
                row,
              ),
          };
        } catch (_) {
          final rows = await _client
              .from('profiles')
              .select('id,phone')
              .inFilter('id', ids);
          return {
            for (final row in rows)
              (row['id'] ?? '').toString().trim(): Map<String, dynamic>.from(
                row,
              ),
          };
        }
      }
      rethrow;
    }
  }

  Future<void> updateRideStatus({
    required String rideId,
    required String status,
    String? timestampColumn,
  }) async {
    final payload = <String, dynamic>{'status': status.trim()};
    if (timestampColumn != null) {
      payload[timestampColumn] = DateTime.now().toIso8601String();
    }

    try {
      await _client.from('rides').update(payload).eq('id', rideId.trim());
    } on PostgrestException catch (error) {
      if (timestampColumn != null &&
          (error.code == '42703' ||
              error.message.toLowerCase().contains(timestampColumn))) {
        // Retry without the timestamp column if it doesn't exist
        await _client
            .from('rides')
            .update({'status': status.trim()})
            .eq('id', rideId.trim());
        return;
      }
      rethrow;
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
    try {
      await _client.from('ride_routes').upsert(payload, onConflict: 'ride_id');
    } on PostgrestException catch (error) {
      if (!_isMissingRideColumn(error, 'host_id')) rethrow;
      final fallbackPayload =
          Map<String, dynamic>.from(payload)
            ..remove('host_id')
            ..['profile_id'] = hostId.trim();
      try {
        await _client
            .from('ride_routes')
            .upsert(fallbackPayload, onConflict: 'ride_id');
      } on PostgrestException catch (fallbackError) {
        if (_isMissingRideColumn(fallbackError, 'profile_id')) {
          fallbackPayload.remove('profile_id');
          await _client
              .from('ride_routes')
              .upsert(fallbackPayload, onConflict: 'ride_id');
          return;
        }
        rethrow;
      }
    }
  }

  Future<RideRoute?> fetchRideRoute(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return null;
    try {
      final row =
          await _client
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
        stops:
            rawStops
                .whereType<Map>()
                .map(
                  (stop) => RouteStop.fromJson(Map<String, dynamic>.from(stop)),
                )
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

  Future<void> submitFeedback({
    required String userId,
    required int rating,
    required String improvementFeedback,
    required String appVersion,
    required String platform,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('Sign in again to send feedback.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5.');
    }

    var profileId = normalizedUserId;
    final profile = await fetchUserById(normalizedUserId);
    final resolvedProfileId = (profile?['id'] ?? '').toString().trim();
    if (resolvedProfileId.isNotEmpty) {
      profileId = resolvedProfileId;
    }

    final trimmedFeedback = improvementFeedback.trim();
    final authUserId = (_client.auth.currentUser?.id ?? '').trim();
    final payload = <String, dynamic>{
      'user_id': profileId,
      if (authUserId.isNotEmpty) 'auth_user_id': authUserId,
      'rating': rating,
      'improvement_feedback': trimmedFeedback.isEmpty ? null : trimmedFeedback,
      'app_version': appVersion.trim(),
      'platform': platform.trim(),
    };

    try {
      await _client.from('app_feedback').insert(payload);
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error) && payload.containsKey('auth_user_id')) {
        payload.remove('auth_user_id');
        await _client.from('app_feedback').insert(payload);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserSingle({
    required String eqColumn,
    required String eqValue,
  }) async {
    if (eqColumn == 'phone') {
      final hasPhone = await _profileColumnExists('phone');
      if (!hasPhone) return null;
    }
    if (eqColumn == 'auth_user_id') {
      final hasAuthUserId = await _profileColumnExists('auth_user_id');
      if (!hasAuthUserId) return null;
    }
    if (eqColumn == 'id' && _looksLikeUuid(eqValue)) {
      final idIsUuid = await _profileIdLooksUuid();
      if (!idIsUuid) return null;
    }
    try {
      return await _client
          .from('profiles')
          .select('id,auth_user_id,phone,name,bike,avatar_url')
          .eq(eqColumn, eqValue)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) {
        try {
          return await _client
              .from('profiles')
              .select('id,auth_user_id,phone,name')
              .eq(eqColumn, eqValue)
              .maybeSingle();
        } catch (_) {
          return await _client
              .from('profiles')
              .select('id,phone')
              .eq(eqColumn, eqValue)
              .maybeSingle();
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _insertProfileWithFallbacks(
    Map<String, dynamic> desired,
  ) async {
    final attempts = <({Map<String, dynamic> payload, String select})>[
      (
        payload: _pickExistingValues(desired, const [
          'auth_user_id',
          'phone',
          'name',
          'bike',
        ]),
        select: 'id,auth_user_id,phone,name,bike,avatar_url',
      ),
      (
        payload: _pickExistingValues(desired, const ['phone', 'name', 'bike']),
        select: 'id,phone,name,bike,avatar_url',
      ),
      (
        payload: _pickExistingValues(desired, const ['phone', 'name', 'bike']),
        select: 'id,phone,name,bike',
      ),
      (
        payload: _pickExistingValues(desired, const ['name', 'bike']),
        select: 'id,name,bike,avatar_url',
      ),
      (
        payload: _pickExistingValues(desired, const ['name', 'bike']),
        select: 'id,name,bike',
      ),
      (
        payload: _pickExistingValues(desired, const ['name']),
        select: 'id,name',
      ),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      if (attempt.payload.isEmpty) continue;
      try {
        final row =
            await _client
                .from('profiles')
                .insert(attempt.payload)
                .select(attempt.select)
                .single();
        return _mergeProfileFallbacks(Map<String, dynamic>.from(row), desired);
      } on PostgrestException catch (error) {
        lastError = error;
        if (!_isRecoverableProfileSchemaError(error)) rethrow;
      }
    }
    throw lastError ?? Exception('Could not create profile.');
  }

  Future<Map<String, dynamic>> _upsertProfileWithFallbacks(
    Map<String, dynamic> desired,
  ) async {
    final idIsUuid = await _profileIdLooksUuid();
    if (!idIsUuid) {
      final authUserId = (desired['auth_user_id'] ?? '').toString().trim();
      if (authUserId.isEmpty) {
        throw Exception('Could not save profile: missing auth user id.');
      }
      final existing = await _fetchUserSingle(
        eqColumn: 'auth_user_id',
        eqValue: authUserId,
      );
      if (existing != null) {
        return _updateProfileWithFallbacks(authUserId, desired);
      }
      return _insertProfileWithFallbacks(desired);
    }

    final attempts =
        <({Map<String, dynamic> payload, String select, String conflict})>[
          (
            payload: _pickExistingValues(desired, const [
              'id',
              'auth_user_id',
              'phone',
              'name',
              'bike',
            ]),
            select: 'id,auth_user_id,phone,name,bike,avatar_url',
            conflict: 'id',
          ),
          (
            payload: _pickExistingValues(desired, const [
              'id',
              'phone',
              'name',
              'bike',
            ]),
            select: 'id,phone,name,bike',
            conflict: 'id',
          ),
          (
            payload: _pickExistingValues(desired, const ['id', 'name']),
            select: 'id,name',
            conflict: 'id',
          ),
        ];

    Object? lastError;
    for (final attempt in attempts) {
      if (!attempt.payload.containsKey(attempt.conflict)) continue;
      try {
        final row =
            await _client
                .from('profiles')
                .upsert(attempt.payload, onConflict: attempt.conflict)
                .select(attempt.select)
                .single();
        return _mergeProfileFallbacks(Map<String, dynamic>.from(row), desired);
      } on PostgrestException catch (error) {
        lastError = error;
        if (!_isRecoverableProfileSchemaError(error)) rethrow;
      }
    }
    throw lastError ?? Exception('Could not save profile.');
  }

  Future<Map<String, dynamic>> _updateProfileWithFallbacks(
    String userId,
    Map<String, dynamic> desired,
  ) async {
    final attempts = <({Map<String, dynamic> payload, String select})>[
      (
        payload: _pickExistingValues(desired, const ['phone', 'name', 'bike']),
        select: 'id,auth_user_id,phone,name,bike,avatar_url',
      ),
      (
        payload: _pickExistingValues(desired, const ['phone', 'name', 'bike']),
        select: 'id,phone,name,bike',
      ),
      (
        payload: _pickExistingValues(desired, const ['name']),
        select: 'id,name,avatar_url',
      ),
      (
        payload: _pickExistingValues(desired, const ['name']),
        select: 'id,name',
      ),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      if (attempt.payload.isEmpty) continue;
      try {
        final filterColumns = <String>[
          if (await _profileColumnExists('auth_user_id')) 'auth_user_id',
          'id',
        ];
        for (final column in filterColumns) {
          try {
            final row =
                await _client
                    .from('profiles')
                    .update(attempt.payload)
                    .eq(column, userId)
                    .select(attempt.select)
                    .single();
            return _mergeProfileFallbacks(
              Map<String, dynamic>.from(row),
              desired,
            );
          } on PostgrestException catch (error) {
            lastError = error;
            if (!_isRecoverableProfileSchemaError(error)) rethrow;
          }
        }
      } on PostgrestException catch (error) {
        lastError = error;
        if (!_isRecoverableProfileSchemaError(error)) rethrow;
      }
    }

    final existing = await fetchUserById(userId);
    if (existing != null) return _mergeProfileFallbacks(existing, desired);
    throw lastError ?? Exception('Could not update profile.');
  }

  Map<String, dynamic> _pickExistingValues(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    final result = <String, dynamic>{};
    for (final key in keys) {
      if (source.containsKey(key)) {
        result[key] = source[key];
      }
    }
    return result;
  }

  Map<String, dynamic> _mergeProfileFallbacks(
    Map<String, dynamic> row,
    Map<String, dynamic> desired,
  ) {
    final authUserId =
        (row['auth_user_id'] ?? desired['auth_user_id'] ?? desired['id'] ?? '')
            .toString();
    return <String, dynamic>{
      ...desired,
      ...row,
      'id': authUserId.isNotEmpty ? authUserId : (row['id'] ?? '').toString(),
      'profile_row_id': (row['id'] ?? '').toString(),
      'auth_user_id': authUserId,
      'phone': (row['phone'] ?? desired['phone'] ?? '').toString(),
      'name': (row['name'] ?? desired['name'] ?? 'Rider').toString(),
      'bike': (row['bike'] ?? desired['bike'] ?? 'No bike added').toString(),
      'avatar_url': (row['avatar_url'] ?? '').toString(),
    };
  }

  List<Map<String, String>> _decodeGarageBikes(Object? raw) {
    final source = raw is List ? raw : const [];
    return source
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return <String, String>{
            'id': (map['id'] ?? '').toString(),
            'brand': (map['brand'] ?? '').toString(),
            'model': (map['model'] ?? '').toString(),
            'cc': (map['cc'] ?? '').toString(),
            'nickname': (map['nickname'] ?? 'Motorcycle').toString(),
            'fuelType': (map['fuelType'] ?? 'Petrol').toString(),
            'imagePath': (map['imagePath'] ?? '').toString(),
          };
        })
        .toList(growable: false);
  }

  Future<bool> _profileColumnExists(String column) async {
    try {
      await _client.from('profiles').select(column).limit(1);
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(error)) return false;
      rethrow;
    }
  }

  Future<bool> _profileIdLooksUuid() async {
    try {
      await _client
          .from('profiles')
          .select('id')
          .eq('id', '00000000-0000-0000-0000-000000000000')
          .limit(1);
      return true;
    } on PostgrestException catch (error) {
      final text = '${error.message} $error'.toLowerCase();
      if (text.contains('uuid') || text.contains('bigint')) return false;
      if ((error.code ?? '').trim() == '22P02') return false;
      return true;
    }
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  bool _isMissingColumnError(dynamic error) {
    if (error is! PostgrestException) return false;
    final code = (error.code ?? '').trim();
    if (code == '42703' || code == 'PGRST204') return true;
    final message = error.message.toLowerCase();
    final text = error.toString().toLowerCase();
    return message.contains('"code":"42703"') ||
        message.contains('"code":"pgrst204"') ||
        text.contains('"code":"42703"') ||
        text.contains('"code":"pgrst204"') ||
        text.contains('column') && text.contains('does not exist');
  }

  bool _isRecoverableProfileSchemaError(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final text = '${error.message} $error'.toLowerCase();
    return _isMissingColumnError(error) ||
        code == '22P02' ||
        code == '42804' ||
        code == '42883' ||
        code == 'PGRST116' ||
        text.contains('schema cache') ||
        text.contains('uuid = bigint') ||
        text.contains('invalid input syntax') ||
        text.contains('profiles');
  }

  bool _isMissingRideOptionalColumns(PostgrestException error) {
    final code = (error.code ?? '').trim();
    final message = error.message.toLowerCase();
    if (code != '42703' && code != 'PGRST204') {
      return false;
    }
    return message.contains('start_time') ||
        message.contains('max_riders') ||
        message.contains('ride_visibility') ||
        message.contains('ride_mode');
  }

  bool _isMissingRideColumn(PostgrestException error, String column) {
    if (!_isMissingColumnError(error)) return false;
    final target = column.toLowerCase();
    final text = '${error.message} $error'.toLowerCase();
    return text.contains(target);
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

  // ==================== ROUTE SYNC METHODS ====================

  /// Upserts a ride route with destination coordinates and optional route points
  /// Used for saving routes from Google Maps links
  Future<void> upsertRideRoute({
    required String rideId,
    double? destinationLat,
    double? destinationLng,
    List<Map<String, dynamic>>? routePoints,
  }) async {
    final payload = <String, dynamic>{
      'ride_id': rideId.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (destinationLat != null) {
      payload['destination_lat'] = destinationLat;
    }
    if (destinationLng != null) {
      payload['destination_lng'] = destinationLng;
    }
    if (routePoints != null && routePoints.isNotEmpty) {
      payload['route_points'] = routePoints;
    }

    await _client.from('ride_routes').upsert(payload, onConflict: 'ride_id');
  }

  /// Fetches ride route data by ride ID
  /// Returns null if route not found or table doesn't exist
  Future<Map<String, dynamic>?> fetchRideRouteMap(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return null;

    try {
      final row =
          await _client
              .from('ride_routes')
              .select()
              .eq('ride_id', normalized)
              .maybeSingle();
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingRideRoutesSchema(error)) return null;
      rethrow;
    }
  }
}
