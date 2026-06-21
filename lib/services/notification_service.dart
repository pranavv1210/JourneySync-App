import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../coordinators/notification_coordinator.dart';

/// Comprehensive notification service handling:
/// - Firebase Cloud Messaging (FCM) push notifications
/// - Local notifications fallback
/// - Foreground / background / terminated state handling
/// - All 10 notification categories
/// - Device token registration
class NotificationService {
  NotificationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final NotificationService instance = NotificationService();

  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _pushAvailable = false;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Whether push notifications are available (Firebase initialized).
  bool get pushAvailable => _pushAvailable;

  /// Initialize the notification service.
  ///
  /// Call once during app startup. If [profileId] is provided, the device
  /// will also be registered for push notifications.
  Future<void> initialize({String? profileId}) async {
    if (_initialized) {
      if (profileId != null) await registerDevice(profileId);
      return;
    }
    _initialized = true;

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Initialize Firebase Cloud Messaging
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      // Request permissions
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        journeysyncFirebaseBackgroundHandler,
      );

      // Handle foreground messages
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );

      // Handle notification taps (app opened from terminated/background)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationData(initialMessage.data);
      }

      // Handle when app is in background and user taps notification
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleNotificationData(message.data),
      );

      _pushAvailable = true;
      debugPrint('[Notifications] Firebase initialized successfully');

      if (profileId != null) await registerDevice(profileId);
    } catch (error) {
      _pushAvailable = false;
      debugPrint('[Notifications] Firebase unavailable: $error');
    }
  }

  /// Register the device's FCM token for push notifications.
  Future<void> registerDevice(String profileId) async {
    if (!_pushAvailable || profileId.trim().isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;

      await _client
          .from('profiles')
          .update({
            'fcm_token': token,
            'push_platform': defaultTargetPlatform.name,
            'push_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId.trim());

      debugPrint('[Notifications] Device registered for profile $profileId');
    } catch (error) {
      debugPrint('[Notifications] Device registration failed: $error');
    }
  }

  /// Shows a local notification with the given title and body.
  Future<void> showLocal({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int? id,
    String? channelId,
    String? channelName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'journeysync_realtime',
      'JourneySync realtime',
      channelDescription: 'Ride alerts, route changes, and member updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data?.toString(),
    );
  }

  /// Send a notification for any of the 10 supported categories.
  Future<void> showCategoryNotification({
    required AppNotificationCategory category,
    required String title,
    required String body,
    String? rideId,
    String? profileId,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    // Persist to notification history
    if (profileId != null && profileId.trim().isNotEmpty) {
      await NotificationCoordinator.instance.persist(
        profileId: profileId,
        title: title,
        body: body,
        category: category,
        rideId: rideId,
        data: data,
      );
    }

    // Show local notification
    await showLocal(title: title, body: body, data: data);
  }

  /// Handle foreground push messages.
  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'JourneySync';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (body.toString().trim().isEmpty) return;

    // Parse category from data
    final rawCategory =
        (message.data['category'] ?? message.data['type'] ?? 'system')
            .toString()
            .trim();
    final category = notificationCategoryFromString(rawCategory);

    // Persist notification
    final profileId = (message.data['profile_id'] ?? '').toString().trim();
    if (profileId.isNotEmpty) {
      await NotificationCoordinator.instance.persist(
        profileId: profileId,
        title: title.toString(),
        body: body.toString(),
        category: category,
        rideId:
            (message.data['ride_id'] ?? '').toString().trim().isEmpty
                ? null
                : message.data['ride_id'].toString(),
        data: message.data,
      );
    }

    await showLocal(
      title: title.toString(),
      body: body.toString(),
      data: message.data,
    );
  }

  /// Handle notification tap / open events.
  void _handleNotificationData(Map<String, dynamic> data) {
    // Navigation logic for notification taps
    final rideId = (data['ride_id'] ?? '').toString().trim();
    final category = (data['category'] ?? data['type'] ?? '').toString().trim();

    debugPrint('[Notifications] Tapped: category=$category rideId=$rideId');
    // Navigation is handled by AppNavigation based on stored route context
  }

  /// Handle local notification tap.
  void _handleNotificationTap(NotificationResponse response) {
    debugPrint(
      '[Notifications] Local notification tapped: ${response.payload}',
    );
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _foregroundMessageSub?.cancel();
    _foregroundMessageSub = null;
  }
}

/// Firebase Cloud Messaging background message handler.
///
/// This is a top-level function required for FCM background processing.
/// It must be annotated with `@pragma('vm:entry-point')` and must not
/// use any Flutter-specific APIs (no context, no widgets).
@pragma('vm:entry-point')
Future<void> journeysyncFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'JourneySync';
    final body = notification?.body ?? message.data['body'] ?? '';

    if (body.toString().trim().isEmpty) return;

    // Show local notification from background
    const androidDetails = AndroidNotificationDetails(
      'journeysync_realtime',
      'JourneySync realtime',
      channelDescription: 'Ride alerts, route changes, and member updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.toString(),
    );
  } catch (error) {
    debugPrint('[Notifications] Background handler error: $error');
  }
}
