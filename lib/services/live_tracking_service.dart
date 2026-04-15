import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/live_location.dart';

class LiveTrackingService {
  LiveTrackingService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  final StreamController<List<LiveLocation>> _controller =
      StreamController<List<LiveLocation>>.broadcast();
  final Map<String, LiveLocation> _cache = <String, LiveLocation>{};
  RealtimeChannel? _channel;
  String? _rideId;

  Stream<List<LiveLocation>> watchRideLocations(String rideId) {
    if (_rideId == rideId && !_controller.isClosed) {
      return _controller.stream;
    }

    _rideId = rideId;
    _cache.clear();
    _channel?.unsubscribe();

    _primeLocations(rideId);

    _channel = _client.channel('live_locations:$rideId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_locations',
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
            final next = _fromLiveLocationRow(record);
            if (next == null) return;
            if (payload.eventType == PostgresChangeEvent.delete) {
              _cache.remove(next.userId);
            } else {
              _cache[next.userId] = next;
            }
            _emit();
          },
        )
        .subscribe();

    return _controller.stream;
  }

  Future<void> _primeLocations(String rideId) async {
    try {
      final rows = await _client
          .from('live_locations')
          .select()
          .eq('ride_id', rideId)
          .order('updated_at');
      for (final row in rows) {
        final next = _fromLiveLocationRow(Map<String, dynamic>.from(row));
        if (next != null) {
          _cache[next.userId] = next;
        }
      }
      _emit();
    } on PostgrestException catch (_) {
      _emit();
    }
  }

  void _emit() {
    if (_controller.isClosed) return;
    final values = _cache.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    _controller.add(values);
  }

  Future<void> syncLocation({
    required String rideId,
    required String userId,
    required Position position,
    String? battery,
    String? signal,
  }) async {
    final payload = <String, dynamic>{
      'ride_id': rideId,
      'user_id': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'updated_at': DateTime.now().toIso8601String(),
      'speed_mps': position.speed >= 0 ? position.speed : null,
      'heading': position.heading >= 0 ? position.heading : null,
      'battery': battery,
      'signal': signal,
    };

    try {
      await _client.from('live_locations').upsert(payload);
    } on PostgrestException catch (_) {
      await _client
          .from('users')
          .update({
            'current_lat': position.latitude,
            'current_lng': position.longitude,
            'current_speed_mps': position.speed >= 0 ? position.speed : null,
            'current_heading': position.heading >= 0 ? position.heading : null,
            'location_updated_at': DateTime.now().toIso8601String(),
            'active_ride_id': rideId,
            'battery': battery,
            'signal': signal,
          })
          .eq('id', userId);
    }
  }

  Future<void> clearLiveLocation({
    required String rideId,
    required String userId,
  }) async {
    try {
      await _client
          .from('live_locations')
          .delete()
          .eq('ride_id', rideId)
          .eq('user_id', userId);
    } catch (_) {}
    try {
      await _client
          .from('users')
          .update({'active_ride_id': null})
          .eq('id', userId);
    } catch (_) {}
  }

  LiveLocation? _fromLiveLocationRow(Map<String, dynamic> row) {
    final userId = (row['user_id'] ?? '').toString().trim();
    final rideId = (row['ride_id'] ?? '').toString().trim();
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    final updatedAt = DateTime.tryParse((row['updated_at'] ?? '').toString());
    if (userId.isEmpty ||
        rideId.isEmpty ||
        latitude == null ||
        longitude == null ||
        updatedAt == null) {
      return null;
    }

    return LiveLocation(
      userId: userId,
      rideId: rideId,
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
      speedMps: (row['speed_mps'] as num?)?.toDouble(),
      heading: (row['heading'] as num?)?.toDouble(),
      battery: (row['battery'] ?? '').toString().trim(),
      signal: (row['signal'] ?? '').toString().trim(),
    );
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    await _controller.close();
  }
}
