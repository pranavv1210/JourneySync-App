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
}

class NearbyRide {
  const NearbyRide({
    required this.ride,
    required this.hostName,
    required this.hostBike,
    required this.hostAvatarUrl,
    required this.joined,
  });

  final RideRecord ride;
  final String hostName;
  final String hostBike;
  final String hostAvatarUrl;
  final bool joined;

  NearbyRide copyWith({
    RideRecord? ride,
    String? hostName,
    String? hostBike,
    String? hostAvatarUrl,
    bool? joined,
  }) {
    return NearbyRide(
      ride: ride ?? this.ride,
      hostName: hostName ?? this.hostName,
      hostBike: hostBike ?? this.hostBike,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      joined: joined ?? this.joined,
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
  });

  final JoinByCodeStatus status;
  final String rideId;
  final String rideTitle;
}
