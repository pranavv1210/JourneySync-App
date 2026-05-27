import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized manager for all Supabase Realtime channels used during a ride.
///
/// Prevents duplicate subscriptions and provides automatic cleanup.
/// Manages:
///  - SOS alert channel  → onAlert callback
///  - Route sync channel → onRoute callback
///
/// The live location channel is managed separately by [LiveTrackingService]
/// because it has its own stream/cache lifecycle.
class RealtimeService {
  RealtimeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel? _alertChannel;
  RealtimeChannel? _routeChannel;

  String? _activeRideId;

  /// Start listening for SOS alerts and route changes for [rideId].
  ///
  /// [onAlert]  — called with the full alert record when a new SOS is fired.
  /// [onRoute]  — called with the route record when a route update arrives.
  void startListening({
    required String rideId,
    required void Function(Map<String, dynamic> alert) onAlert,
    required void Function(Map<String, dynamic> route) onRoute,
  }) {
    if (_activeRideId == rideId) return; // already subscribed

    stopListening(); // clean up any previous ride
    _activeRideId = rideId;

    _subscribeAlerts(rideId, onAlert);
    _subscribeRoutes(rideId, onRoute);
  }

  void _subscribeAlerts(
    String rideId,
    void Function(Map<String, dynamic>) onAlert,
  ) {
    _alertChannel?.unsubscribe();
    _alertChannel = _client.channel('alerts:$rideId');

    _alertChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty) return;
            onAlert(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[RealtimeService] Alert channel error: $error');
          }
        });
  }

  void _subscribeRoutes(
    String rideId,
    void Function(Map<String, dynamic>) onRoute,
  ) {
    _routeChannel?.unsubscribe();
    _routeChannel = _client.channel('routes:$rideId');

    _routeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_routes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            final record =
                payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord;
            if (record.isEmpty) return;
            onRoute(Map<String, dynamic>.from(record));
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[RealtimeService] Route channel error: $error');
          }
        });
  }

  /// Sends a SOS alert to all riders in the ride.
  Future<void> triggerSOS({
    required String rideId,
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
  }) async {
    await _client.from('ride_alerts').insert({
      'ride_id': rideId,
      'user_id': userId,
      'user_name': userName,
      'type': 'SOS',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Stop all active realtime subscriptions.
  void stopListening() {
    _alertChannel?.unsubscribe();
    _alertChannel = null;
    _routeChannel?.unsubscribe();
    _routeChannel = null;
    _activeRideId = null;
  }
}
