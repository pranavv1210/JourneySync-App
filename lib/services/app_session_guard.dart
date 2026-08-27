import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import 'app_navigation.dart';
import 'auth_service.dart';

class AppSessionGuard with WidgetsBindingObserver {
  AppSessionGuard._();

  static final AppSessionGuard instance = AppSessionGuard._();

  static const _deviceIdKey = 'journeysyncDeviceId';
  static const _sessionTokenKey = 'journeysyncSessionToken';

  final SupabaseClient _client = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  RealtimeChannel? _channel;
  String _profileId = '';
  String _sessionToken = '';
  bool _started = false;
  bool _loggingOut = false;

  Future<void> restore() async {
    if (_started) return;
    WidgetsBinding.instance.addObserver(this);
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    final profileId = (prefs.getString('userId') ?? '').trim();
    if (profileId.isEmpty || _client.auth.currentSession == null) return;
    await start(profileId);
  }

  Future<void> start(String profileId) async {
    final normalized = profileId.trim();
    if (normalized.isEmpty || _client.auth.currentSession == null) return;
    if (_profileId == normalized && _sessionToken.isNotEmpty) {
      _subscribe();
      unawaited(validate());
      return;
    }

    _profileId = normalized;
    final deviceId = await _deviceId();
    _sessionToken = _newSessionToken();
    await _storage.write(key: _sessionTokenKey, value: _sessionToken);

    try {
      await _client.rpc(
        'register_device_session',
        params: {
          'p_profile_id': _profileId,
          'p_device_id': deviceId,
          'p_session_token': _sessionToken,
        },
      );
    } catch (error) {
      debugPrint('Device session registration failed: $error');
      return;
    }

    _subscribe();
  }

  Future<void> stop() async {
    _channel?.unsubscribe().ignore();
    _channel = null;
    _profileId = '';
    _sessionToken = '';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(validate());
    }
  }

  Future<void> validate() async {
    if (_profileId.isEmpty || _sessionToken.isEmpty || _loggingOut) return;
    try {
      final row =
          await _client
              .from('user_device_sessions')
              .select('session_token,revoked_at,deleted_at')
              .eq('profile_id', _profileId)
              .maybeSingle();
      if (row == null) return;
      _handleSessionRow(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('Device session validation failed: $error');
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = _client.channel('device-session:$_profileId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_device_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: _profileId,
          ),
          callback: (payload) {
            final row =
                payload.eventType == PostgresChangeEvent.delete
                    ? payload.oldRecord
                    : payload.newRecord;
            _handleSessionRow(Map<String, dynamic>.from(row));
          },
        )
        .subscribe();
  }

  void _handleSessionRow(Map<String, dynamic> row) {
    if (_profileId.isEmpty || _sessionToken.isEmpty || _loggingOut) return;
    final remoteToken = (row['session_token'] ?? '').toString();
    final revoked = (row['revoked_at'] ?? '').toString().trim().isNotEmpty;
    final deleted = (row['deleted_at'] ?? '').toString().trim().isNotEmpty;
    if (deleted) {
      unawaited(_forceLogout('Your JourneySync account was deleted.'));
      return;
    }
    if (revoked || (remoteToken.isNotEmpty && remoteToken != _sessionToken)) {
      unawaited(_confirmRemoteLogout());
    }
  }

  Future<void> _confirmRemoteLogout() async {
    if (_profileId.isEmpty || _sessionToken.isEmpty || _loggingOut) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_profileId.isEmpty || _sessionToken.isEmpty || _loggingOut) return;
    try {
      final row =
          await _client
              .from('user_device_sessions')
              .select('session_token,revoked_at,deleted_at')
              .eq('profile_id', _profileId)
              .maybeSingle();
      if (row == null) return;
      final remote = Map<String, dynamic>.from(row);
      final remoteToken = (remote['session_token'] ?? '').toString();
      final revoked = (remote['revoked_at'] ?? '').toString().trim().isNotEmpty;
      final deleted = (remote['deleted_at'] ?? '').toString().trim().isNotEmpty;
      if (deleted) {
        await _forceLogout('Your JourneySync account was deleted.');
        return;
      }
      if (revoked || (remoteToken.isNotEmpty && remoteToken != _sessionToken)) {
        await _forceLogout('JourneySync was opened on another phone.');
      }
    } catch (error) {
      debugPrint('Device session logout confirmation failed: $error');
    }
  }

  Future<void> _forceLogout(String reason) async {
    if (_loggingOut) return;
    _loggingOut = true;
    await stop();
    await AuthService().clearSession();
    final context = appNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(reason)));
      unawaited(replaceAllWithAppRoute(context, const LoginScreen()));
    }
    _loggingOut = false;
  }

  Future<String> _deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();
    final generated = _newSessionToken();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  String _newSessionToken() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
