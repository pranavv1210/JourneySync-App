import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
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
    : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  /// Resolves the auth redirect URL from dotenv (runtime) or fallback.
  String get _authRedirectUrl {
    try {
      final env = dotenv.env['AUTH_REDIRECT_URL'];
      return (env ?? AppConfig.authRedirectUrl).trim();
    } catch (_) {
      return AppConfig.authRedirectUrl;
    }
  }

  Future<({PhoneIdentity identity, String accessToken, String idToken})>
  authenticateWithGoogle() async {
    final client = Supabase.instance.client;
    final existingSession = client.auth.currentSession;
    if (existingSession != null) {
      await client.auth.signOut();
    }

    final redirectUrl = _authRedirectUrl;

    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl.isNotEmpty ? redirectUrl : null,
      authScreenLaunchMode: LaunchMode.externalApplication,
      scopes: 'openid email profile',
    );

    final returnedSession = client.auth.currentSession;
    if (returnedSession != null) {
      return _identityFromSession(returnedSession);
    }

    final session = await _waitForGoogleSession(client);
    return _identityFromSession(session);
  }

  ({PhoneIdentity identity, String accessToken, String idToken})
  _identityFromSession(Session session) {
    final user = session.user;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final email = (user.email ?? metadata['email'] ?? '').toString().trim();
    final phoneNumber =
        (user.phone ?? metadata['phone_number'] ?? '').toString().trim();
    final givenName = (metadata['given_name'] ?? '').toString().trim();
    final familyName = (metadata['family_name'] ?? '').toString().trim();
    final fullName =
        (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();

    if (user.id.trim().isEmpty) {
      throw Exception('Google sign-in did not return a valid Supabase user.');
    }

    final stableKey =
        phoneNumber.isNotEmpty
            ? phoneNumber
            : email.isNotEmpty
            ? email.toLowerCase()
            : 'google:${user.id}';
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
      accessToken: session.accessToken,
      idToken: session.providerToken ?? '',
    );
  }

  Future<Session> _waitForGoogleSession(SupabaseClient client) async {
    final currentSession = client.auth.currentSession;
    if (currentSession != null) return currentSession;

    final authState = await client.auth.onAuthStateChange
        .firstWhere((state) {
          return state.event == AuthChangeEvent.signedIn &&
              state.session != null &&
              state.session!.user.appMetadata['provider'] == 'google';
        })
        .timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            throw TimeoutException('Google sign-in was not completed.');
          },
        );

    final session = authState.session;
    if (session == null) {
      throw Exception('Google sign-in did not create a session.');
    }
    return session;
  }

  Future<SessionUser> resolveUser({
    required PhoneIdentity identity,
    required bool isNewAccount,
    required String enteredName,
    required String enteredBike,
  }) async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final authUserId = (authUser?.id ?? '').trim();
    if (authUserId.isEmpty) {
      throw Exception('Google sign-in session is missing.');
    }

    final existingById = await _supabaseService.fetchUserById(authUserId);
    final existing = existingById ?? await _findExistingUser(identity);
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
        } catch (_) {}
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
      final inserted = await _supabaseService.upsertAuthenticatedUserProfile(
        userId: authUserId,
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
      if (row != null) return row;
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
    final authUser = Supabase.instance.client.auth.currentUser;
    final authEmail =
        (authUser?.email ?? authUser?.userMetadata?['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final phoneLooksLikeEmail = user.phone.contains('@');
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', user.id);
    await prefs.setString('userPhone', phoneLooksLikeEmail ? '' : user.phone);
    if (authEmail.isNotEmpty || phoneLooksLikeEmail) {
      await prefs.setString(
        'userEmail',
        authEmail.isNotEmpty ? authEmail : user.phone.toLowerCase(),
      );
    }
    await prefs.setString('userName', user.name);
    await prefs.setString('userBike', user.bike);
    await prefs.setString('userAvatarUrl', user.avatarUrl);

    const storage = FlutterSecureStorage();
    await storage.write(key: 'phoneEmailAccessToken', value: accessToken);
    await storage.write(key: 'phoneEmailJwtToken', value: jwtToken);
  }

  Future<void> clearSession() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('userPhone');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userBike');
    await prefs.remove('userAvatarUrl');

    const storage = FlutterSecureStorage();
    await storage.delete(key: 'phoneEmailAccessToken');
    await storage.delete(key: 'phoneEmailJwtToken');
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
}
