import 'supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum JoinByCodeStatus {
  requested,
  joinedDirectly,
  alreadyRequested,
  alreadyJoined,
}

class JoinByCodeResult {
  const JoinByCodeResult({
    required this.status,
    required this.rideId,
    required this.rideTitle,
  });

  final JoinByCodeStatus status;
  final String rideId;
  final String rideTitle;
}

class RideRecord {
  const RideRecord({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.createdAt,
    this.status = '',
    this.endedAt,
    this.archived = false,
    this.participantCount = 0,
  });

  final String id;
  final String creatorId;
  final String title;
  final String startLocation;
  final String endLocation;
  final DateTime? createdAt;
  final String status;
  final DateTime? endedAt;
  final bool archived;
  final int participantCount;

  bool get isCompleted =>
      endedAt != null ||
      status.toLowerCase() == 'ended' ||
      status.toLowerCase() == 'completed';

  bool get isScheduled =>
      !isCompleted &&
      status.toLowerCase() != 'active' &&
      status.toLowerCase() != 'live';
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

  Future<List<RideRecord>> fetchRecentRides(String creatorId, {int limit = 5}) async {
    final rows = await _supabaseService.fetchRecentRidesByCreator(
      creatorId: creatorId,
      limit: limit,
    );
    final rides =
        rows.map(_toRideRecord).where((ride) => !ride.archived).toList();
    return _attachParticipantCounts(rides);
  }

  Future<List<RideRecord>> fetchNearbyRides(String currentUserId, {int limit = 50}) async {
    final rows = await _supabaseService.fetchNearbyRides(
      excludeCreatorId: currentUserId,
      limit: limit,
    );
    return rows.map(_toRideRecord).toList();
  }

  Future<RideRecord> createRide({
    required String creatorId,
    required String title,
    required String startLocation,
    required String endLocation,
    DateTime? scheduledStartTime,
    int? maxRiders,
  }) async {
    final row = await _supabaseService.createRide(
      creatorId: creatorId,
      title: title,
      startLocation: startLocation,
      endLocation: endLocation,
      scheduledStartTime: scheduledStartTime,
      maxRiders: maxRiders,
    );
    final ride = _toRideRecord(row);
    await joinRide(rideId: ride.id, userId: creatorId, suppressDuplicate: true);
    return ride;
  }

  Future<List<NearbyRide>> searchNearbyRides(
    String currentUserId, {
    double? currentLat,
    double? currentLng,
    double maxDistanceKm = 5.0,
    bool requestPermissionIfNeeded = false,
  }) async {
    final origin =
        (currentLat != null && currentLng != null)
            ? (lat: currentLat, lng: currentLng)
            : await _resolveCurrentPosition(
              requestPermissionIfNeeded: requestPermissionIfNeeded,
            );
    if (origin == null) {
      return <NearbyRide>[];
    }

    final rides = await fetchNearbyRides(currentUserId, limit: 50);
    if (rides.isEmpty) {
      return <NearbyRide>[];
    }

    final recentCutoff = DateTime.now().subtract(const Duration(hours: 24));
    final filtered =
        rides.where((ride) {
          final createdAt = ride.createdAt;
          if (createdAt == null) return true;
          if (!createdAt.isAfter(recentCutoff)) return false;
          if (ride.archived || ride.isCompleted) return false;
          if (ride.status.trim().toLowerCase() == 'cancelled') return false;

          final startPoint = _parseLatLng(ride.startLocation);
          if (startPoint == null) return true; // Show rides missing coords instead of hiding completely
          final meters = Geolocator.distanceBetween(
            origin.lat,
            origin.lng,
            startPoint.lat,
            startPoint.lng,
          );
          return meters <= maxDistanceKm * 1000;
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

  Future<JoinByCodeStatus> requestJoinRide({
    required String rideId,
    required String userId,
  }) async {
    try {
      await _supabaseService.createJoinRequest(
        rideId: rideId,
        userId: userId,
      );
      return JoinByCodeStatus.requested;
    } on PostgrestException catch (error) {
      if ((error.code ?? '').trim() == '23505') {
        return JoinByCodeStatus.alreadyRequested;
      }
      if (!_isMissingJoinRequestSchema(error)) rethrow;
    }

    // fallback if schema missing
    await joinRide(
      rideId: rideId,
      userId: userId,
      suppressDuplicate: true,
    );
    return JoinByCodeStatus.joinedDirectly;
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

  Future<JoinByCodeResult> joinRideByAccessCode({
    required String accessCode,
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('Missing user session. Please login again.');
    }

    final normalizedCode = _normalizeAccessCode(accessCode);
    if (!_looksLikeAccessCode(normalizedCode)) {
      throw Exception('Enter a valid code like JS-0370.');
    }

    final rides = await _supabaseService.fetchRecentRidesForCodeLookup(
      limit: 250,
    );
    Map<String, dynamic>? matchedRide;
    for (final row in rides) {
      final rideId = (row['id'] ?? '').toString().trim();
      if (rideId.isEmpty) continue;
      if (_rideCodeFromId(rideId) != normalizedCode) continue;
      final status = (row['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'cancelled' || status == 'completed' || status == 'ended') {
        continue;
      }
      if (row['archived_at'] != null ||
          row['is_archived'] == true ||
          row['archived'] == true) {
        continue;
      }
      matchedRide = row;
      break;
    }

    if (matchedRide == null) {
      throw Exception('No active ride found for this access code.');
    }

    final rideId = (matchedRide['id'] ?? '').toString().trim();
    final title =
        (matchedRide['title'] ?? matchedRide['name'] ?? 'Ride')
            .toString()
            .trim();
    final hostId = _rideHostId(matchedRide);

    if (hostId.isNotEmpty && hostId == normalizedUserId) {
      throw Exception('This is your own ride.');
    }

    final participantRows = await _supabaseService.fetchParticipantsByUser(
      normalizedUserId,
    );
    final alreadyJoined = participantRows.any(
      (row) => (row['ride_id'] ?? '').toString().trim() == rideId,
    );
    if (alreadyJoined) {
      return JoinByCodeResult(
        status: JoinByCodeStatus.alreadyJoined,
        rideId: rideId,
        rideTitle: title.isNotEmpty ? title : 'Ride',
      );
    }

    try {
      await _supabaseService.createJoinRequest(
        rideId: rideId,
        userId: normalizedUserId,
      );
      return JoinByCodeResult(
        status: JoinByCodeStatus.requested,
        rideId: rideId,
        rideTitle: title.isNotEmpty ? title : 'Ride',
      );
    } on PostgrestException catch (error) {
      if (_isDuplicateRow(error)) {
        return JoinByCodeResult(
          status: JoinByCodeStatus.alreadyRequested,
          rideId: rideId,
          rideTitle: title.isNotEmpty ? title : 'Ride',
        );
      }
      if (!_isMissingJoinRequestSchema(error)) rethrow;
    }

    await joinRide(
      rideId: rideId,
      userId: normalizedUserId,
      suppressDuplicate: true,
    );
    return JoinByCodeResult(
      status: JoinByCodeStatus.joinedDirectly,
      rideId: rideId,
      rideTitle: title.isNotEmpty ? title : 'Ride',
    );
  }

  Future<void> deleteRideAsCreator({
    required String rideId,
    required String creatorId,
  }) async {
    await _supabaseService.deleteRideAsCreator(
      rideId: rideId,
      creatorId: creatorId,
    );
  }

  Future<void> archiveCompletedRideAsCreator({
    required String rideId,
    required String creatorId,
  }) async {
    await _supabaseService.archiveCompletedRideAsCreator(
      rideId: rideId,
      creatorId: creatorId,
    );
  }

  Stream<List<RideRecord>> watchRides() {
    return _supabaseService.watchRides().map((rows) {
      return rows.map(_toRideRecord).toList();
    });
  }

  RideRecord _toRideRecord(Map<String, dynamic> row) {
    final creator =
        (row['creator_id'] ?? row['user_id'] ?? row['leader_id'] ?? '')
            .toString()
            .trim();
    final status = (row['status'] ?? '').toString().trim();
    final endedAt = DateTime.tryParse((row['ended_at'] ?? '').toString());
    final archived =
        row['archived_at'] != null ||
        row['is_archived'] == true ||
        row['archived'] == true ||
        status.toLowerCase() == 'archived';
    return RideRecord(
      id: (row['id'] ?? '').toString(),
      creatorId: creator,
      title: (row['title'] ?? row['name'] ?? 'Ride').toString(),
      startLocation: (row['start_location'] ?? row['start'] ?? '').toString(),
      endLocation: (row['end_location'] ?? row['destination'] ?? '').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
      status: status,
      endedAt: endedAt,
      archived: archived,
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
            status: ride.status,
            endedAt: ride.endedAt,
            archived: ride.archived,
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

  Future<({double lat, double lng})?> _resolveCurrentPosition({
    required bool requestPermissionIfNeeded,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermissionIfNeeded) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  }

  ({double lat, double lng})? _parseLatLng(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return (lat: lat, lng: lng);
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

  String _normalizeAccessCode(String value) {
    final text = value.trim().toUpperCase().replaceAll(' ', '');
    if (text.contains('-')) return text;
    if (text.startsWith('JS') && text.length >= 6) {
      return 'JS-${text.substring(2)}';
    }
    return text;
  }

  bool _looksLikeAccessCode(String code) {
    return RegExp(r'^JS-[A-Z0-9]{4}$').hasMatch(code);
  }

  String _rideCodeFromId(String id) {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return "JS-0000";
    final tail =
        cleaned.length >= 4 ? cleaned.substring(cleaned.length - 4) : cleaned;
    return "JS-$tail";
  }

  String _rideHostId(Map<String, dynamic> row) {
    return (row['creator_id'] ?? row['leader_id'] ?? row['user_id'] ?? '')
        .toString()
        .trim();
  }

  bool _isMissingJoinRequestSchema(PostgrestException error) {
    final code = (error.code ?? '').trim();
    return code == '42P01' ||
        code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('join_requests');
  }

  bool _isDuplicateRow(PostgrestException error) {
    return (error.code ?? '').trim() == '23505';
  }
}
