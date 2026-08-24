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
    this.rideLeaderId,
    this.visibility = 'public',
    this.rideMode = 'group',
  });

  final String id;
  final String creatorId;
  final String? rideLeaderId;
  final String title;
  final String startLocation;
  final String endLocation;
  final DateTime? createdAt;
  final String status;
  final DateTime? endedAt;
  final bool archived;
  final int participantCount;
  final String visibility;
  final String rideMode;

  bool get isCompleted =>
      endedAt != null ||
      status.toLowerCase() == 'ended' ||
      status.toLowerCase() == 'completed';

  bool get isScheduled =>
      !isCompleted &&
      status.toLowerCase() != 'active' &&
      status.toLowerCase() != 'live';

  bool get isActive =>
      status.toLowerCase() == 'active' || status.toLowerCase() == 'live';

  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'canceled';

  bool get isPublic => visibility.toLowerCase() != 'private';

  /// Whether this ride belongs on the nearby radar.
  ///
  /// A ride is discoverable from the moment it is created - it does not have to
  /// be started/live - and stays visible until it is finished, cancelled or
  /// archived.
  bool get isDiscoverable =>
      isPublic && !isCompleted && !isCancelled && !archived;

  RideRecord copyWith({
    String? id,
    String? creatorId,
    String? rideLeaderId,
    String? title,
    String? startLocation,
    String? endLocation,
    DateTime? createdAt,
    String? status,
    DateTime? endedAt,
    bool? archived,
    int? participantCount,
    String? visibility,
    String? rideMode,
  }) {
    return RideRecord(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      rideLeaderId: rideLeaderId ?? this.rideLeaderId,
      title: title ?? this.title,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      archived: archived ?? this.archived,
      participantCount: participantCount ?? this.participantCount,
      visibility: visibility ?? this.visibility,
      rideMode: rideMode ?? this.rideMode,
    );
  }
}

class NearbyRide {
  const NearbyRide({
    required this.ride,
    required this.hostName,
    required this.hostBike,
    required this.hostAvatarUrl,
    required this.joined,
    this.isOwnRide = false,
  });

  final RideRecord ride;
  final String hostName;
  final String hostBike;
  final String hostAvatarUrl;
  final bool joined;

  /// True when the signed-in rider created this ride.
  ///
  /// Own rides used to be filtered out of the radar entirely, which made a host
  /// who had just created a ride see "No riders nearby" and no confirmation that
  /// their ride was broadcasting. They now appear, marked as the host's own, and
  /// tapping one opens the lobby rather than offering to join.
  final bool isOwnRide;

  NearbyRide copyWith({
    RideRecord? ride,
    String? hostName,
    String? hostBike,
    String? hostAvatarUrl,
    bool? joined,
    bool? isOwnRide,
  }) {
    return NearbyRide(
      ride: ride ?? this.ride,
      hostName: hostName ?? this.hostName,
      hostBike: hostBike ?? this.hostBike,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      joined: joined ?? this.joined,
      isOwnRide: isOwnRide ?? this.isOwnRide,
    );
  }
}

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
    this.rideStatus = '',
  });

  final JoinByCodeStatus status;
  final String rideId;
  final String rideTitle;
  final String rideStatus;
}
