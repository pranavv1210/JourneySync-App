import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BikeModeCapability {
  const BikeModeCapability({
    required this.callScreeningAvailable,
    required this.callScreeningGranted,
    required this.smsGranted,
    required this.contactsGranted,
    required this.directSmsSupported,
  });

  const BikeModeCapability.unavailable()
    : callScreeningAvailable = false,
      callScreeningGranted = false,
      smsGranted = false,
      contactsGranted = false,
      directSmsSupported = false;

  final bool callScreeningAvailable;
  final bool callScreeningGranted;
  final bool smsGranted;
  final bool contactsGranted;
  final bool directSmsSupported;

  bool get fullyReady =>
      callScreeningGranted &&
      contactsGranted &&
      (!directSmsSupported || smsGranted);
}

class BikeModeService extends ChangeNotifier {
  BikeModeService._();

  static final BikeModeService instance = BikeModeService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.journeysync/bike_mode',
  );
  static const String defaultMessage =
      "I'm currently riding and can't take your call. I'll get back to you when I stop. Sent by JourneySync Bike Mode.";
  static const String _enabledKey = 'bikeModeEnabled';
  static const String _messagesKey = 'bikeModeMessages';
  static const String _selectedMessageKey = 'bikeModeSelectedMessage';

  bool _initialized = false;
  bool _enabled = false;
  bool _busy = false;
  String _profileId = '';
  List<String> _messages = const <String>[defaultMessage];
  String _selectedMessage = defaultMessage;
  BikeModeCapability _capability = const BikeModeCapability.unavailable();

  bool get enabled => _enabled;
  bool get busy => _busy;
  List<String> get messages => List<String>.unmodifiable(_messages);
  String get selectedMessage => _selectedMessage;
  BikeModeCapability get capability => _capability;

  Future<void> initialize({String? profileId}) async {
    final normalizedId = profileId?.trim() ?? '';
    final profileChanged =
        _initialized &&
        normalizedId.isNotEmpty &&
        _profileId.isNotEmpty &&
        normalizedId != _profileId;
    if (normalizedId.isNotEmpty) _profileId = normalizedId;
    if (profileChanged) {
      _enabled = false;
      _messages = const <String>[defaultMessage];
      _selectedMessage = defaultMessage;
      notifyListeners();
    }
    if (!_initialized) {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      final storedMessages =
          prefs
              .getStringList(_messagesKey)
              ?.map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
      _messages =
          storedMessages == null || storedMessages.isEmpty
              ? const <String>[defaultMessage]
              : storedMessages;
      final storedSelection =
          (prefs.getString(_selectedMessageKey) ?? '').trim();
      _selectedMessage =
          storedSelection.isNotEmpty && _messages.contains(storedSelection)
              ? storedSelection
              : _messages.first;
      _initialized = true;
    }
    await _refreshNativeState();
    notifyListeners();
    await _hydrateFromCloud();
  }

  Future<BikeModeCapability> setEnabled(bool value) async {
    if (_busy || value == _enabled) return _capability;
    _busy = true;
    notifyListeners();
    try {
      if (value && defaultTargetPlatform == TargetPlatform.android) {
        _capability = await _prepareAndroidCapability();
        if (_capability.callScreeningAvailable &&
            !_capability.callScreeningGranted) {
          return _capability;
        }
      }
      _enabled = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      await _pushNativeState();
      await _syncCloud();
      return _capability;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> selectMessage(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty || !_messages.contains(normalized)) return;
    _selectedMessage = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedMessageKey, normalized);
    await _pushNativeState();
    await _syncCloud();
    notifyListeners();
  }

  Future<void> addMessage(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    if (!_messages.contains(normalized)) {
      _messages = <String>[..._messages, normalized];
    }
    _selectedMessage = normalized;
    await _persistMessages();
    await _pushNativeState();
    await _syncCloud();
    notifyListeners();
  }

  Future<void> updateMessage(String oldMessage, String newMessage) async {
    final normalized = newMessage.trim();
    if (normalized.isEmpty) return;
    final index = _messages.indexOf(oldMessage);
    if (index < 0) return;
    final next = List<String>.from(_messages);
    next[index] = normalized;
    _messages = next.toSet().toList(growable: false);
    if (_selectedMessage == oldMessage) _selectedMessage = normalized;
    await _persistMessages();
    await _pushNativeState();
    await _syncCloud();
    notifyListeners();
  }

  Future<bool> removeMessage(String message) async {
    if (_messages.length == 1) return false;
    _messages = _messages.where((item) => item != message).toList();
    if (_selectedMessage == message) _selectedMessage = _messages.first;
    await _persistMessages();
    await _pushNativeState();
    await _syncCloud();
    notifyListeners();
    return true;
  }

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_messagesKey, _messages);
    await prefs.setString(_selectedMessageKey, _selectedMessage);
  }

  Future<BikeModeCapability> _prepareAndroidCapability() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'prepareBikeMode',
      );
      return _capabilityFromMap(raw);
    } on PlatformException catch (error) {
      debugPrint('[BikeMode] Android setup failed: ${error.message}');
      return _capability;
    }
  }

  Future<void> _refreshNativeState() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getBikeModeState',
      );
      if (raw != null) {
        _capability = _capabilityFromMap(raw);
        final nativeEnabled = raw['enabled'];
        if (nativeEnabled is bool) _enabled = nativeEnabled;
      }
      await _pushNativeState();
    } on PlatformException catch (error) {
      debugPrint('[BikeMode] Native state unavailable: ${error.message}');
    } on MissingPluginException {
      // Expected on iOS, web, and widget tests.
    }
  }

  BikeModeCapability _capabilityFromMap(Map<String, dynamic>? raw) {
    return BikeModeCapability(
      callScreeningAvailable: raw?['callScreeningAvailable'] == true,
      callScreeningGranted: raw?['callScreeningGranted'] == true,
      smsGranted: raw?['smsGranted'] == true,
      contactsGranted: raw?['contactsGranted'] == true,
      directSmsSupported: raw?['directSmsSupported'] == true,
    );
  }

  Future<void> _pushNativeState() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setBikeModeState', {
        'enabled': _enabled,
        'message': _selectedMessage,
      });
    } on PlatformException catch (error) {
      debugPrint('[BikeMode] Could not update Android state: ${error.message}');
    } on MissingPluginException {
      // Expected in widget tests.
    }
  }

  Future<void> _hydrateFromCloud() async {
    try {
      if (_profileId.isEmpty ||
          Supabase.instance.client.auth.currentSession == null) {
        return;
      }
      final row =
          await Supabase.instance.client
              .from('profiles')
              .select('bike_mode_enabled,bike_mode_message,bike_mode_messages')
              .eq('id', _profileId)
              .maybeSingle();
      if (row == null) return;
      final remoteMessages =
          (row['bike_mode_messages'] as List<dynamic>?)
              ?.map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
      if (remoteMessages != null) {
        _messages =
            remoteMessages.isEmpty
                ? const <String>[defaultMessage]
                : remoteMessages;
      }
      final remoteMessage = (row['bike_mode_message'] ?? '').toString().trim();
      if (remoteMessage.isNotEmpty) {
        if (!_messages.contains(remoteMessage)) {
          _messages = <String>[..._messages, remoteMessage];
        }
        _selectedMessage = remoteMessage;
      } else if (!_messages.contains(_selectedMessage)) {
        _selectedMessage = _messages.first;
      }
      _enabled = row['bike_mode_enabled'] == true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
      await _persistMessages();
      await _pushNativeState();
      notifyListeners();
    } catch (error) {
      // The migration may not be installed yet. Local Bike Mode remains usable.
      debugPrint('[BikeMode] Cloud state unavailable: $error');
    }
  }

  Future<void> _syncCloud() async {
    try {
      if (_profileId.isEmpty ||
          Supabase.instance.client.auth.currentSession == null) {
        return;
      }
      await Supabase.instance.client
          .from('profiles')
          .update({
            'bike_mode_enabled': _enabled,
            'bike_mode_message': _selectedMessage,
            'bike_mode_messages': _messages,
            'bike_mode_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _profileId);
    } catch (error) {
      debugPrint('[BikeMode] Cloud update unavailable: $error');
    }
  }
}
