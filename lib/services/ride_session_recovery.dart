class RideSessionRecovery {
  const RideSessionRecovery._();

  /// Returns the newest live ride that the current profile hosts or has joined.
  /// Finished, cancelled, archived, and merely scheduled rides are never
  /// restored into Ride Mode.
  static String selectActiveRideId(List<Map<String, dynamic>> rides) {
    final candidates = rides.where(_isActive).toList(growable: false)
      ..sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));
    if (candidates.isEmpty) return '';
    return (candidates.first['id'] ?? '').toString().trim();
  }

  static bool _isActive(Map<String, dynamic> ride) {
    final id = (ride['id'] ?? '').toString().trim();
    final status = (ride['status'] ?? '').toString().trim().toLowerCase();
    final archived =
        ride['archived_at'] != null ||
        ride['is_archived'] == true ||
        ride['archived'] == true;
    return id.isNotEmpty &&
        !archived &&
        (status == 'active' || status == 'live');
  }

  static DateTime _timestamp(Map<String, dynamic> ride) {
    return DateTime.tryParse(
          (ride['started_at'] ?? ride['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
