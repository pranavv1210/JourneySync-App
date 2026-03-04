import 'dart:async';
import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class PhoneIdentity {
  const PhoneIdentity({
    required this.phone,
    required this.countryCode,
    required this.firstName,
    required this.lastName,
  });

  final String phone;
  final String countryCode;
  final String firstName;
  final String lastName;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : 'Rider';
  }
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.bike,
    required this.avatarUrl,
  });

  final String id;
  final String phone;
  final String name;
  final String bike;
  final String avatarUrl;
}

class AuthService {
  AuthService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService(),
      _auth0 = Auth0(
        _requiredDefine('AUTH0_DOMAIN', _auth0Domain),
        _requiredDefine('AUTH0_CLIENT_ID', _auth0ClientId),
      );

  final SupabaseService _supabaseService;
  final Auth0 _auth0;
  static const String _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
  static const String _auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
  );
  static const String _auth0Scheme = String.fromEnvironment(
    'AUTH0_SCHEME',
    defaultValue: 'journeysync',
  );

  Future<({PhoneIdentity identity, String accessToken, String idToken})>
  authenticateWithAuth0() async {
    final webAuth =
        _auth0Scheme.trim().toLowerCase() == 'https'
            ? _auth0.webAuthentication()
            : _auth0.webAuthentication(scheme: _auth0Scheme.trim());
    final credentials = await webAuth.login(
      useHTTPS: _auth0Scheme.trim().toLowerCase() == 'https',
      scopes: {'openid', 'profile', 'email'},
    );

    final payload = _decodeJwtPayload(credentials.idToken);
    final subject = (payload['sub'] ?? '').toString().trim();
    final email = (payload['email'] ?? '').toString().trim();
    final phoneNumber = (payload['phone_number'] ?? '').toString().trim();
    final givenName = (payload['given_name'] ?? '').toString().trim();
    final familyName = (payload['family_name'] ?? '').toString().trim();
    final fullName = (payload['name'] ?? '').toString().trim();

    if (subject.isEmpty) {
      throw Exception('Auth0 did not return a valid user subject (sub).');
    }

    final stableKey =
        phoneNumber.isNotEmpty
            ? phoneNumber
            : email.isNotEmpty
            ? email.toLowerCase()
            : 'auth0:$subject';
    final firstName =
        givenName.isNotEmpty
            ? givenName
            : fullName
                .split(' ')
                .firstWhere((part) => part.trim().isNotEmpty, orElse: () => '');
    final lastName =
        familyName.isNotEmpty
            ? familyName
            : fullName
                .split(' ')
                .skip(1)
                .where((part) => part.trim().isNotEmpty)
                .join(' ');

    return (
      identity: PhoneIdentity(
        phone: stableKey,
        countryCode: '',
        firstName: firstName,
        lastName: lastName,
      ),
      accessToken: credentials.accessToken,
      idToken: credentials.idToken,
    );
  }

  Future<void> logoutAuth0() async {
    final webAuth =
        _auth0Scheme.trim().toLowerCase() == 'https'
            ? _auth0.webAuthentication()
            : _auth0.webAuthentication(scheme: _auth0Scheme.trim());
    await webAuth.logout(
      useHTTPS: _auth0Scheme.trim().toLowerCase() == 'https',
    );
  }

  Future<SessionUser> resolveUser({
    required PhoneIdentity identity,
    required bool isNewAccount,
    required String enteredName,
    required String enteredBike,
  }) async {
    final existing = await _findExistingUser(identity);
    if (existing != null) {
      if (isNewAccount &&
          enteredName.trim().isNotEmpty &&
          enteredBike.trim().isNotEmpty) {
        try {
          final existingId = (existing['id'] ?? '').toString().trim();
          if (existingId.isNotEmpty) {
            final updated = await _supabaseService.updateUserProfile(
              userId: existingId,
              name: enteredName,
              bike: enteredBike,
            );
            return _toSessionUser(updated, fallbackPhone: identity.phone);
          }
        } catch (_) {
          // If update fails, continue with existing profile to keep login flowing.
        }
      }
      return _toSessionUser(existing, fallbackPhone: identity.phone);
    }

    if (!isNewAccount) {
      throw Exception(
        'No account found for this account. Switch to New Account to register.',
      );
    }

    final name =
        enteredName.trim().isNotEmpty ? enteredName : identity.fullName;
    final bike = enteredBike.trim().isNotEmpty ? enteredBike : 'No bike added';

    try {
      final inserted = await _supabaseService.createUser(
        phone: identity.phone,
        name: name,
        bike: bike,
      );
      return _toSessionUser(inserted, fallbackPhone: identity.phone);
    } catch (error) {
      if (error is PostgrestException && (error.code ?? '').trim() == '23505') {
        final afterConflict = await _findExistingUser(identity);
        if (afterConflict != null) {
          return _toSessionUser(afterConflict, fallbackPhone: identity.phone);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _findExistingUser(
    PhoneIdentity identity,
  ) async {
    final variants = _phoneVariants(identity);
    for (final candidate in variants) {
      final row = await _supabaseService.fetchUserByPhone(candidate);
      if (row != null) {
        return row;
      }
    }
    return null;
  }

  Set<String> _phoneVariants(PhoneIdentity identity) {
    final variants = <String>{};
    final normalized = identity.phone.trim();
    final cc = identity.countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final fullDigits = normalized.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalized.isNotEmpty) variants.add(normalized);
    if (fullDigits.isNotEmpty) {
      variants.add(fullDigits);
      variants.add('+$fullDigits');
    }

    if (cc.isNotEmpty && fullDigits.startsWith(cc)) {
      final local = fullDigits.substring(cc.length);
      if (local.isNotEmpty) {
        variants.add(local);
        variants.add('+$local');
        variants.add('+$cc$local');
      }
    }

    return variants;
  }

  Future<void> saveSession({
    required SessionUser user,
    required String accessToken,
    required String jwtToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', user.id);
    await prefs.setString('userPhone', user.phone);
    await prefs.setString('userName', user.name);
    await prefs.setString('userBike', user.bike);
    await prefs.setString('userAvatarUrl', user.avatarUrl);
    await prefs.setString('phoneEmailAccessToken', accessToken);
    await prefs.setString('phoneEmailJwtToken', jwtToken);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('userPhone');
    await prefs.remove('userName');
    await prefs.remove('userBike');
    await prefs.remove('userAvatarUrl');
    await prefs.remove('phoneEmailAccessToken');
    await prefs.remove('phoneEmailJwtToken');
  }

  Future<SessionUser?> tryResolveCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUserId = (prefs.getString('userId') ?? '').trim();
    final cachedPhone = (prefs.getString('userPhone') ?? '').trim();

    Map<String, dynamic>? row;
    if (cachedUserId.isNotEmpty) {
      row = await _supabaseService.fetchUserById(cachedUserId);
    }
    if (row == null && cachedPhone.isNotEmpty) {
      row = await _supabaseService.fetchUserByPhone(cachedPhone);
    }
    if (row == null) return null;

    final fallbackPhone =
        cachedPhone.isNotEmpty ? cachedPhone : (row['phone'] ?? '').toString();
    return _toSessionUser(row, fallbackPhone: fallbackPhone);
  }

  SessionUser _toSessionUser(
    Map<String, dynamic> row, {
    required String fallbackPhone,
  }) {
    final id = (row['id'] ?? '').toString().trim();
    final phone = (row['phone'] ?? fallbackPhone).toString().trim();
    final name = (row['name'] ?? 'Rider').toString().trim();
    final bike = (row['bike'] ?? 'No bike added').toString().trim();
    final avatarUrl = (row['avatar_url'] ?? '').toString().trim();

    if (id.isEmpty) {
      throw Exception('User record is missing id.');
    }

    return SessionUser(
      id: id,
      phone: phone.isNotEmpty ? phone : fallbackPhone,
      name: name.isNotEmpty ? name : 'Rider',
      bike: bike.isNotEmpty ? bike : 'No bike added',
      avatarUrl: avatarUrl,
    );
  }

  static String _requiredDefine(String key, String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
    throw StateError(
      'Missing --dart-define=$key. Add it to flutter run/build command.',
    );
  }

  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) {
      throw Exception('Invalid ID token format.');
    }
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final dynamic jsonValue = jsonDecode(decoded);
    if (jsonValue is Map<String, dynamic>) {
      return jsonValue;
    }
    if (jsonValue is Map) {
      return Map<String, dynamic>.from(jsonValue);
    }
    throw Exception('Invalid ID token payload.');
  }
}
