import 'supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_member.dart';
import '../models/ride_route.dart';
import '../utils/app_logger.dart';

import '../models/ride_record.dart';

class RideService {
  RideService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  Future<List<RideRecord>> fetchRecentRides(
    String creatorId, {
    int limit = 5,
  }) async {
    final rows = await _supabaseService.fetchRecentRidesByCreator(
      creatorId: creatorId,
      limit: limit,
    );
    final rides =
        rows.map(_toRideRecord).where((ride) => !ride.archived).toList();
    return _attachParticipantCounts(rides);
  }

  Future<List<RideRecord>> fetchNearbyRides(
    String currentUserId, {
    int limit = 50,
  }) async {
    final rows = await _supabaseService.fetchNearbyRides(
      // Deliberately empty: the host's own rides are wanted on the radar so a
      // freshly created ride confirms itself immediately. searchNearbyRides
      // tags them instead of dropping them.
      excludeCreatorId: '',
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
    String rideVisibility = 'public',
    String rideMode = 'group',
    String status = 'scheduled',
  }) async {
    final row = await _supabaseService.createRide(
      creatorId: creatorId,
      title: title,
      startLocation: startLocation,
      endLocation: endLocation,
      scheduledStartTime: scheduledStartTime,
      maxRiders: maxRiders,
      rideVisibility: rideVisibility,
      rideMode: rideMode,
      status: status,
    );
    final ride = _toRideRecord(row);
    try {
      await joinRide(
        rideId: ride.id,
        userId: creatorId,
        suppressDuplicate: true,
      );
    } catch (error) {
      // The ride row already exists, so a failed host-membership insert must not
      // fail creation - the lobby and the repair migration both backfill hosts.
      AppLogger.warning('Could not add host to new ride: $error');
    }
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

    final rides = await fetchNearbyRides(currentUserId, limit: 50);
    if (rides.isEmpty) {
      return <NearbyRide>[];
    }

    final filtered =
        rides.where((ride) {
          final isOwn =
              currentUserId.isNotEmpty && ride.creatorId == currentUserId;
          // Visible from creation onward - a host does not have to start the
          // ride before it shows up on someone else's radar.
          if (!ride.isDiscoverable) return false;
          // Own rides skip the distance test. The host is standing at their own
          // start point, but a stale or missing GPS fix would otherwise hide the
          // one ride they most expect to see.
          if (isOwn) return true;
          if (origin == null) return true;

          final startPoint = _parseLatLng(ride.startLocation);
          if (startPoint == null) {
            return true; // Show rides missing coords instead of hiding completely
          }
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

    final results =
        filtered.map((ride) {
          final profile =
              creatorProfiles[ride.creatorId] ?? const <String, String>{};
          final hostName = (profile['name'] ?? 'Rider').trim();
          final hostBike = (profile['bike'] ?? 'No bike added').trim();
          final hostAvatarUrl = (profile['avatar_url'] ?? '').trim();
          final participantCount = participantCounts[ride.id] ?? 0;
          final isOwn =
              currentUserId.isNotEmpty && ride.creatorId == currentUserId;

          return NearbyRide(
            ride: RideRecord(
              id: ride.id,
              creatorId: ride.creatorId,
              title: ride.title,
              startLocation: ride.startLocation,
              endLocation: ride.endLocation,
              createdAt: ride.createdAt,
              status: ride.status,
              endedAt: ride.endedAt,
              archived: ride.archived,
              visibility: ride.visibility,
              rideMode: ride.rideMode,
              participantCount: participantCount,
            ),
            hostName: hostName.isNotEmpty ? hostName : 'Rider',
            hostBike: hostBike.isNotEmpty ? hostBike : 'No bike added',
            hostAvatarUrl: hostAvatarUrl,
            joined: joinedRideIds.contains(ride.id) || isOwn,
            isOwnRide: isOwn,
          );
        }).toList();

    // The host's own ride leads, then the most recently created. A host opening
    // the radar right after creating a ride should find theirs without hunting.
    results.sort((a, b) {
      if (a.isOwnRide != b.isOwnRide) return a.isOwnRide ? -1 : 1;
      final aCreated = a.ride.createdAt;
      final bCreated = b.ride.createdAt;
      if (aCreated == null || bCreated == null) return 0;
      return bCreated.compareTo(aCreated);
    });
    return results;
  }

  Future<JoinByCodeStatus> requestJoinRide({
    required String rideId,
    required String userId,
  }) async {
    final normalizedRideId = rideId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedRideId.isEmpty) {
      throw Exception('This ride is no longer available.');
    }
    if (normalizedUserId.isEmpty) {
      throw Exception('Missing user session. Please login again.');
    }

    // Resolve current membership first so a second tap reports the real state
    // instead of bubbling up a duplicate-key error.
    final existing = await _supabaseService.fetchRideMembershipStatus(
      rideId: normalizedRideId,
      userId: normalizedUserId,
    );
    if (existing != null) {
      return existing == 'pending'
          ? JoinByCodeStatus.alreadyRequested
          : JoinByCodeStatus.alreadyJoined;
    }

    try {
      await _supabaseService.createJoinRequest(
        rideId: normalizedRideId,
        userId: normalizedUserId,
      );
      return JoinByCodeStatus.requested;
    } on PostgrestException catch (error) {
      if (_isDuplicateRow(error)) {
        return JoinByCodeStatus.alreadyRequested;
      }
      if (!_isMissingJoinRequestSchema(error)) rethrow;
    }

    // Deployment has no request/approval columns - join outright.
    await joinRide(
      rideId: normalizedRideId,
      userId: normalizedUserId,
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
    } on PostgrestException catch (error) {
      // A duplicate row means the rider is already a member, which is the
      // outcome the caller wanted. Everything else - RLS denials, constraint
      // violations, a missing table - must surface, otherwise the UI reports a
      // successful join for a row that was never written.
      if (suppressDuplicate && _isDuplicateRow(error)) return;
      rethrow;
    }
  }

  Future<void> leaveRide({
    required String rideId,
    required String userId,
  }) async {
    await _supabaseService.removeParticipant(rideId: rideId, userId: userId);
  }

  Future<List<RideMember>> fetchRideMembers(String rideId) {
    return _supabaseService.fetchRideMembers(rideId);
  }

  /// Name / bike / avatar for a single profile, used when the cached session in
  /// SharedPreferences is missing the avatar URL. Returns null when the profile
  /// cannot be resolved so callers can fall back to initials.
  Future<({String name, String bike, String avatarUrl})?> fetchProfileSummary(
    String userId,
  ) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return null;
    try {
      final profiles = await _fetchCreatorProfiles(<String>[normalized]);
      final profile = profiles[normalized];
      if (profile == null) return null;
      return (
        name: (profile['name'] ?? '').trim(),
        bike: (profile['bike'] ?? '').trim(),
        avatarUrl: (profile['avatar_url'] ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRideRoute({
    required String rideId,
    required String hostId,
    required String startLabel,
    required String endLabel,
    required List<RouteStop> stops,
  }) {
    return _supabaseService.saveRideRoute(
      rideId: rideId,
      hostId: hostId,
      startLabel: startLabel,
      endLabel: endLabel,
      stops: stops,
    );
  }

  Future<RideRoute?> fetchRideRoute(String rideId) {
    return _supabaseService.fetchRideRoute(rideId);
  }

  Future<void> startRide(String rideId) async {
    try {
      await _supabaseService.updateRideStatus(
        rideId: rideId,
        status: 'active',
        timestampColumn: 'started_at',
      );
    } catch (_) {
      // Fallback if status update fails
      await _supabaseService.updateRideStatus(rideId: rideId, status: 'active');
    }
  }

  Future<void> finishRide(String rideId) async {
    await _supabaseService.updateRideStatus(
      rideId: rideId,
      status: 'completed',
      timestampColumn: 'ended_at',
    );
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
        (row['host_id'] ??
                row['profile_id'] ??
                row['creator_id'] ??
                row['user_id'] ??
                '')
            .toString()
            .trim();
    final status = (row['status'] ?? '').toString().trim();
    final endedAt = DateTime.tryParse((row['ended_at'] ?? '').toString());
    final archived =
        row['archived_at'] != null ||
        row['is_archived'] == true ||
        row['archived'] == true ||
        status.toLowerCase() == 'archived';
    final visibility =
        (row['ride_visibility'] ?? row['visibility'] ?? 'public')
            .toString()
            .trim();
    final rideMode = (row['ride_mode'] ?? 'group').toString().trim();
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
      visibility: visibility.isEmpty ? 'public' : visibility,
      rideMode: rideMode.isEmpty ? 'group' : rideMode,
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
            visibility: ride.visibility,
            rideMode: ride.rideMode,
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
        creatorIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) {
      return <String, Map<String, String>>{};
    }

    final profiles = await _supabaseService.fetchUsersByIds(uniqueIds);
    return profiles.map((id, row) {
      return MapEntry(id, {
        'name': (row['name'] ?? 'Rider').toString(),
        'bike': (row['bike'] ?? 'No bike added').toString(),
        'avatar_url': (row['avatar_url'] ?? '').toString(),
      });
    });
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
    return (row['host_id'] ??
            row['profile_id'] ??
            row['creator_id'] ??
            row['user_id'] ??
            '')
        .toString()
        .trim();
  }

  bool _isMissingJoinRequestSchema(PostgrestException error) {
    final code = (error.code ?? '').trim();
    // Only a genuinely absent table/column means "this deployment has no
    // request-and-approve flow". Matching on message text such as 'status' also
    // caught check-constraint and RLS failures, which then fell through to a
    // direct join and reported success for a write that never happened.
    return code == '42P01' ||
        code == '42703' ||
        code == 'PGRST204' ||
        error.message.toLowerCase().contains('join_requests');
  }

  bool _isDuplicateRow(PostgrestException error) {
    return (error.code ?? '').trim() == '23505';
  }

  // ==================== ROUTE SYNC METHODS ====================

  /// Saves a route from a Google Maps link to the ride_routes table
  /// Returns true if successful, false otherwise
  Future<bool> saveRouteFromGoogleMapsLink({
    required String rideId,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      await _supabaseService.upsertRideRoute(
        rideId: rideId,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetches the raw route data map for a specific ride.
  /// Returns the raw [Map] or null if not found.
  Future<Map<String, dynamic>?> fetchRideRouteMap(String rideId) async {
    try {
      // Use the supabase service's raw map variant (line 1016 in supabase_service)
      return await Supabase.instance.client
          .from('ride_routes')
          .select()
          .eq('ride_id', rideId.trim())
          .maybeSingle()
          .then((row) => row != null ? Map<String, dynamic>.from(row) : null);
    } catch (e) {
      return null;
    }
  }

  /// Saves a ride route with full route points (premium feature)
  Future<bool> saveRideRouteFull({
    required String rideId,
    required String hostId,
    required String startLabel,
    required String endLabel,
    required List<({double lat, double lng, String? name})> stops,
  }) async {
    try {
      final routePoints =
          stops
              .map(
                (stop) => {'lat': stop.lat, 'lng': stop.lng, 'name': stop.name},
              )
              .toList();

      await _supabaseService.upsertRideRoute(
        rideId: rideId,
        routePoints: routePoints,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
