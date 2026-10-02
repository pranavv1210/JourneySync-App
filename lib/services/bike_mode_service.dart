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
      "I'm currently riding and can't take your call. I'll get back to you when I stop. Sent by JourneySync Ride Mode.";
  static const String _enabledKey = 'bikeModeEnabled';
  static const String _messagesKey = 'bikeModeMessages';
  static const String _selectedMessageKey = 'bikeModeSelectedMessage';
  static const String _sendSmsKey = 'rideModeSendSms';
  static const String _allowEmergencyKey = 'rideModeAllowEmergency';
  static const String _allowFavoritesKey = 'rideModeAllowFavorites';
  static const String _allowRepeatKey = 'rideModeAllowRepeatCallers';
  static const String _allowRideMembersKey = 'rideModeAllowRideMembers';
  static const String _remindWhenStoppedKey = 'rideModeRemindWhenStopped';
  static const String _autoTurnOffKey = 'rideModeAutoTurnOff';
  static const String _stationaryMinutesKey = 'rideModeStationaryMinutes';
  static const String _activatedAtKey = 'rideModeActivatedAt';
  static const String _restoreCallerIdKey = 'rideModeRestoreCallerId';

  bool _initialized = false;
  bool _enabled = false;
  bool _busy = false;
  String _profileId = '';
  List<String> _messages = const <String>[defaultMessage];
  String _selectedMessage = defaultMessage;
  BikeModeCapability _capability = const BikeModeCapability.unavailable();
  bool _sendSms = true;
  bool _allowEmergencyContacts = true;
  bool _allowFavorites = true;
  bool _allowRepeatCallers = true;
  bool _allowRideMembers = true;
  bool _remindWhenStopped = true;
  bool _autoTurnOff = false;
  int _stationaryMinutes = 10;
  bool _restoreCallerIdAfterRide = true;
  DateTime? _activatedAt;
  List<String> _emergencyNumbers = const [];
  List<String> _rideMemberNumbers = const [];

  bool get enabled => _enabled;
  bool get busy => _busy;
  List<String> get messages => List<String>.unmodifiable(_messages);
  String get selectedMessage => _selectedMessage;
  BikeModeCapability get capability => _capability;
  bool get sendSms => _sendSms;
  bool get allowEmergencyContacts => _allowEmergencyContacts;
  bool get allowFavorites => _allowFavorites;
  bool get allowRepeatCallers => _allowRepeatCallers;
  bool get allowRideMembers => _allowRideMembers;
  bool get remindWhenStopped => _remindWhenStopped;
  bool get autoTurnOff => _autoTurnOff;
  int get stationaryMinutes => _stationaryMinutes;
  bool get restoreCallerIdAfterRide => _restoreCallerIdAfterRide;
  DateTime? get activatedAt => _activatedAt;

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
      _sendSms = prefs.getBool(_sendSmsKey) ?? true;
      _allowEmergencyContacts = prefs.getBool(_allowEmergencyKey) ?? true;
      _allowFavorites = prefs.getBool(_allowFavoritesKey) ?? true;
      _allowRepeatCallers = prefs.getBool(_allowRepeatKey) ?? true;
      _allowRideMembers = prefs.getBool(_allowRideMembersKey) ?? true;
      _remindWhenStopped = prefs.getBool(_remindWhenStoppedKey) ?? true;
      _autoTurnOff = prefs.getBool(_autoTurnOffKey) ?? false;
      _stationaryMinutes = (prefs.getInt(_stationaryMinutesKey) ?? 10).clamp(
        5,
        30,
      );
      _restoreCallerIdAfterRide = prefs.getBool(_restoreCallerIdKey) ?? true;
      _activatedAt = DateTime.tryParse(prefs.getString(_activatedAtKey) ?? '');
      _emergencyNumbers = _phoneNumbersFromRows(
        prefs.getStringList('emergencyContacts') ?? const [],
      );
      _rideMemberNumbers =
          prefs.getStringList('activeRideMemberPhones') ?? const [];
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
        // The switch represents working call handling, not merely the user's
        // preference. Never leave it on when Android declined or cannot offer
        // the call-screening role.
        if (!_capability.callScreeningAvailable ||
            !_capability.callScreeningGranted) {
          _enabled = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enabledKey, false);
          await _pushNativeState();
          await _syncCloud();
          return _capability;
        }
      }

      _enabled = value;
      _activatedAt = value ? DateTime.now() : null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      if (_activatedAt == null) {
        await prefs.remove(_activatedAtKey);
      } else {
        await prefs.setString(_activatedAtKey, _activatedAt!.toIso8601String());
      }
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

  Future<void> refreshCapability() async {
    await _refreshNativeState();
    notifyListeners();
  }

  Future<BikeModeCapability> prepareAccess() async {
    if (defaultTargetPlatform != TargetPlatform.android) return _capability;
    _busy = true;
    notifyListeners();
    try {
      _capability = await _prepareAndroidCapability();
      await _pushNativeState();
      return _capability;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    bool? sendSms,
    bool? allowEmergencyContacts,
    bool? allowFavorites,
    bool? allowRepeatCallers,
    bool? allowRideMembers,
    bool? remindWhenStopped,
    bool? autoTurnOff,
    int? stationaryMinutes,
    bool? restoreCallerIdAfterRide,
  }) async {
    _sendSms = sendSms ?? _sendSms;
    _allowEmergencyContacts = allowEmergencyContacts ?? _allowEmergencyContacts;
    _allowFavorites = allowFavorites ?? _allowFavorites;
    _allowRepeatCallers = allowRepeatCallers ?? _allowRepeatCallers;
    _allowRideMembers = allowRideMembers ?? _allowRideMembers;
    _remindWhenStopped = remindWhenStopped ?? _remindWhenStopped;
    _autoTurnOff = autoTurnOff ?? _autoTurnOff;
    _stationaryMinutes = (stationaryMinutes ?? _stationaryMinutes).clamp(5, 30);
    _restoreCallerIdAfterRide =
        restoreCallerIdAfterRide ?? _restoreCallerIdAfterRide;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_sendSmsKey, _sendSms),
      prefs.setBool(_allowEmergencyKey, _allowEmergencyContacts),
      prefs.setBool(_allowFavoritesKey, _allowFavorites),
      prefs.setBool(_allowRepeatKey, _allowRepeatCallers),
      prefs.setBool(_allowRideMembersKey, _allowRideMembers),
      prefs.setBool(_remindWhenStoppedKey, _remindWhenStopped),
      prefs.setBool(_autoTurnOffKey, _autoTurnOff),
      prefs.setInt(_stationaryMinutesKey, _stationaryMinutes),
      prefs.setBool(_restoreCallerIdKey, _restoreCallerIdAfterRide),
    ]);
    _emergencyNumbers = _phoneNumbersFromRows(
      prefs.getStringList('emergencyContacts') ?? const [],
    );
    _rideMemberNumbers =
        prefs.getStringList('activeRideMemberPhones') ?? const [];
    await _pushNativeState();
    notifyListeners();
  }

  Future<bool> openCallerIdSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('openCallerIdSettings') ?? false;
    } on PlatformException catch (error) {
      debugPrint(
        '[BikeMode] Could not open caller ID settings: ${error.message}',
      );
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> updateRideMemberNumbers(Iterable<String> numbers) async {
    _rideMemberNumbers = numbers
        .map((number) => number.replaceAll(RegExp(r'\D'), ''))
        .where((number) => number.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('activeRideMemberPhones', _rideMemberNumbers);
    await _pushNativeState();
  }

  List<String> _phoneNumbersFromRows(List<String> rows) => rows
      .map((row) => row.split('|'))
      .where((parts) => parts.length > 1)
      .map((parts) => parts[1].replaceAll(RegExp(r'\D'), ''))
      .where((number) => number.isNotEmpty)
      .toSet()
      .toList(growable: false);

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
        if (_enabled && !_capability.callScreeningGranted) {
          _enabled = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enabledKey, false);
          await prefs.remove(_activatedAtKey);
          _activatedAt = null;
        }
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
        'sendSms': _sendSms,
        'allowEmergencyContacts': _allowEmergencyContacts,
        'allowFavorites': _allowFavorites,
        'allowRepeatCallers': _allowRepeatCallers,
        'allowRideMembers': _allowRideMembers,
        'remindWhenStopped': _remindWhenStopped,
        'autoTurnOff': _autoTurnOff,
        'stationaryMinutes': _stationaryMinutes,
        'activatedAt': _activatedAt?.millisecondsSinceEpoch ?? 0,
        'emergencyNumbers': _emergencyNumbers,
        'rideMemberNumbers': _rideMemberNumbers,
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
      // Activation is deliberately device-local. Restoring a cloud `true`
      // here could re-enable call rejection after the native stationary
      // monitor turned it off, after a reinstall, or on a second phone.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
      await _persistMessages();
      await _pushNativeState();
      notifyListeners();
    } catch (error) {
      // The migration may not be installed yet. Local Ride Mode remains usable.
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
