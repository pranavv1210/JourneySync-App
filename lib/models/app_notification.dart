enum AppNotificationCategory {
  sos,
  rideStarted,
  rideEnded,
  routeChanged,
  memberJoined,
  memberLeft,
  invitation,
  nearbyRide,
  weather,
  system,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.profileId,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.rideId,
    this.read = false,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final String profileId;
  final String title;
  final String body;
  final AppNotificationCategory category;
  final DateTime createdAt;
  final String? rideId;
  final bool read;
  final Map<String, dynamic> data;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      profileId: profileId,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      rideId: rideId,
      read: read ?? this.read,
      data: data,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> row) {
    final type = (row['category'] ?? row['type'] ?? 'system').toString().trim();
    final payload = row['payload'] ?? row['data'];
    return AppNotification(
      id: (row['id'] ?? '').toString(),
      profileId: (row['profile_id'] ?? row['user_id'] ?? '').toString(),
      title: (row['title'] ?? 'JourneySync').toString(),
      body: (row['body'] ?? row['message'] ?? '').toString(),
      category: notificationCategoryFromString(type),
      rideId:
          (row['ride_id'] ?? '').toString().trim().isEmpty
              ? null
              : row['ride_id'].toString(),
      read: (row['read'] ?? row['is_read'] ?? false) == true,
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
      data:
          payload is Map
              ? Map<String, dynamic>.from(payload)
              : const <String, dynamic>{},
    );
  }
}

AppNotificationCategory notificationCategoryFromString(String value) {
  return switch (value.trim().toLowerCase()) {
    'sos' || 'emergency' => AppNotificationCategory.sos,
    'ride_started' || 'ridestarted' => AppNotificationCategory.rideStarted,
    'ride_ended' || 'rideended' => AppNotificationCategory.rideEnded,
    'route_changed' || 'routechanged' => AppNotificationCategory.routeChanged,
    'member_joined' || 'memberjoined' => AppNotificationCategory.memberJoined,
    'member_left' || 'memberleft' => AppNotificationCategory.memberLeft,
    'invitation' || 'invite' => AppNotificationCategory.invitation,
    'nearby_ride' || 'nearbyride' => AppNotificationCategory.nearbyRide,
    'weather' || 'weather_alert' => AppNotificationCategory.weather,
    _ => AppNotificationCategory.system,
  };
}

String notificationCategoryToString(AppNotificationCategory category) {
  return switch (category) {
    AppNotificationCategory.sos => 'sos',
    AppNotificationCategory.rideStarted => 'ride_started',
    AppNotificationCategory.rideEnded => 'ride_ended',
    AppNotificationCategory.routeChanged => 'route_changed',
    AppNotificationCategory.memberJoined => 'member_joined',
    AppNotificationCategory.memberLeft => 'member_left',
    AppNotificationCategory.invitation => 'invitation',
    AppNotificationCategory.nearbyRide => 'nearby_ride',
    AppNotificationCategory.weather => 'weather',
    AppNotificationCategory.system => 'system',
  };
}
