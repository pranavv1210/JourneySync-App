/// Represents a rider's real-time presence status.
///
/// This model powers the presence system, showing:
/// - Current status (online, offline, tracking, idle, disconnected, background, sos)
/// - Last seen timestamp
/// - Ride context (if applicable)
/// - Custom status message
class PresenceInfo {
  const PresenceInfo({
    required this.profileId,
    this.status = RiderPresenceStatus.online,
    this.lastSeenAt,
    this.currentRideId,
    this.customStatus,
    this.isInRide = false,
  });

  final String profileId;
  final RiderPresenceStatus status;
  final DateTime? lastSeenAt;
  final String? currentRideId;
  final String? customStatus;
  final bool isInRide;

  PresenceInfo copyWith({
    String? profileId,
    RiderPresenceStatus? status,
    DateTime? lastSeenAt,
    String? currentRideId,
    String? customStatus,
    bool? isInRide,
    bool clearLastSeen = false,
    bool clearCurrentRide = false,
    bool clearCustomStatus = false,
  }) {
    return PresenceInfo(
      profileId: profileId ?? this.profileId,
      status: status ?? this.status,
      lastSeenAt: clearLastSeen ? null : (lastSeenAt ?? this.lastSeenAt),
      currentRideId:
          clearCurrentRide ? null : (currentRideId ?? this.currentRideId),
      customStatus:
          clearCustomStatus ? null : (customStatus ?? this.customStatus),
      isInRide: isInRide ?? this.isInRide,
    );
  }

  factory PresenceInfo.fromMap(Map<String, dynamic> row) {
    final rawStatus =
        (row['status'] ?? row['presence_status'] ?? 'online').toString().trim();
    return PresenceInfo(
      profileId: (row['profile_id'] ?? row['user_id'] ?? '').toString().trim(),
      status: riderPresenceStatusFromString(rawStatus),
      lastSeenAt: DateTime.tryParse((row['last_seen_at'] ?? '').toString()),
      currentRideId:
          (row['current_ride_id'] ?? '').toString().trim().isEmpty
              ? null
              : row['current_ride_id'].toString(),
      customStatus:
          (row['custom_status'] ?? '').toString().trim().isEmpty
              ? null
              : row['custom_status'].toString(),
      isInRide: (row['is_in_ride'] ?? row['in_ride'] ?? false) == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profile_id': profileId,
      'status': riderPresenceStatusToString(status),
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
      if (currentRideId != null) 'current_ride_id': currentRideId,
      if (customStatus != null) 'custom_status': customStatus,
      'is_in_ride': isInRide,
    };
  }

  /// Human-readable "last seen" string.
  String get lastSeenText {
    if (lastSeenAt == null) return 'Unknown';
    final diff = DateTime.now().difference(lastSeenAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

/// Enum for rider presence status with visual indicators.
enum RiderPresenceStatus {
  online,
  offline,
  tracking,
  idle,
  disconnected,
  background,
  sos,
}

RiderPresenceStatus riderPresenceStatusFromString(String value) {
  return switch (value.trim().toLowerCase()) {
    'online' => RiderPresenceStatus.online,
    'tracking' || 'live' => RiderPresenceStatus.tracking,
    'idle' => RiderPresenceStatus.idle,
    'disconnected' => RiderPresenceStatus.disconnected,
    'background' => RiderPresenceStatus.background,
    'sos' || 'emergency' => RiderPresenceStatus.sos,
    _ => RiderPresenceStatus.offline,
  };
}

String riderPresenceStatusToString(RiderPresenceStatus status) {
  return switch (status) {
    RiderPresenceStatus.online => 'online',
    RiderPresenceStatus.offline => 'offline',
    RiderPresenceStatus.tracking => 'tracking',
    RiderPresenceStatus.idle => 'idle',
    RiderPresenceStatus.disconnected => 'disconnected',
    RiderPresenceStatus.background => 'background',
    RiderPresenceStatus.sos => 'sos',
  };
}
