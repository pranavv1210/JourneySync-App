import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationCoordinator extends ChangeNotifier {
  NotificationCoordinator._();

  static final NotificationCoordinator instance = NotificationCoordinator._();

  final SupabaseClient _client = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService.instance;

  RealtimeChannel? _channel;
  String _profileId = '';
  bool _loading = false;
  String _error = '';
  List<AppNotification> _notifications = const <AppNotification>[];

  bool get loading => _loading;
  String get error => _error;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.read).length;

  Future<void> start(String profileId) async {
    final normalized = profileId.trim();
    if (normalized.isEmpty) return;
    if (_profileId == normalized && _channel != null) return;

    await stop();
    _profileId = normalized;
    await _notificationService.initialize(profileId: normalized);
    await refresh();
    _subscribe(normalized);
  }

  Future<void> refresh() async {
    if (_profileId.isEmpty) return;
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('profile_id', _profileId)
          .order('created_at', ascending: false)
          .limit(100);
      _notifications =
          List<Map<String, dynamic>>.from(
            rows,
          ).map(AppNotification.fromMap).toList();
    } catch (error) {
      _error = 'Notifications are unavailable right now.';
      debugPrint('[NotificationCoordinator] refresh failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> persist({
    required String profileId,
    required String title,
    required String body,
    required AppNotificationCategory category,
    String? rideId,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final normalized = profileId.trim();
    if (normalized.isEmpty) return;
    try {
      await _client.from('notifications').insert({
        'profile_id': normalized,
        'ride_id': rideId,
        'title': title,
        'body': body,
        'category': notificationCategoryToString(category),
        'payload': data,
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      debugPrint('[NotificationCoordinator] persist failed: $error');
    }
  }

  Future<void> markAllRead() async {
    if (_profileId.isEmpty) return;
    _notifications =
        _notifications.map((item) => item.copyWith(read: true)).toList();
    notifyListeners();
    try {
      await _client
          .from('notifications')
          .update({'read': true})
          .eq('profile_id', _profileId)
          .eq('read', false);
    } catch (error) {
      debugPrint('[NotificationCoordinator] mark read failed: $error');
      unawaited(refresh());
    }
  }

  Future<void> clearAll() async {
    if (_profileId.isEmpty) return;
    _notifications = const <AppNotification>[];
    notifyListeners();
    try {
      await _client.from('notifications').delete().eq('profile_id', _profileId);
    } catch (error) {
      debugPrint('[NotificationCoordinator] clear failed: $error');
      unawaited(refresh());
    }
  }

  Future<void> stop() async {
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
  }

  void _subscribe(String profileId) {
    _channel = _client.channel('notifications:$profileId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: profileId,
          ),
          callback: (_) => unawaited(refresh()),
        )
        .subscribe();
  }
}
