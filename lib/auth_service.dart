import 'dart:async';

import 'package:phone_email_auth/phone_email_auth.dart';
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
  });

  final String id;
  final String phone;
  final String name;
  final String bike;
}

class AuthService {
  AuthService({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  final SupabaseService _supabaseService;

  Future<PhoneIdentity> getPhoneIdentity(String accessToken) async {
    final trimmedToken = accessToken.trim();
    if (trimmedToken.isEmpty) {
      throw Exception('Missing phone verification token.');
    }

    final completer = Completer<PhoneIdentity>();

    PhoneEmail.getUserInfo(
      accessToken: trimmedToken,
      clientId: PhoneEmail().clientId,
      onSuccess: (userData) {
        final countryCode = (userData.countryCode ?? '').trim();
        final phoneNumber = (userData.phoneNumber ?? '').trim();
        final normalizedPhone = _normalizePhone(
          countryCode: countryCode,
          phoneNumber: phoneNumber,
        );

        if (normalizedPhone == null) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Could not verify phone number. Please try again.'),
            );
          }
          return;
        }

        final identity = PhoneIdentity(
          phone: normalizedPhone,
          countryCode: countryCode,
          firstName: (userData.firstName ?? '').trim(),
          lastName: (userData.lastName ?? '').trim(),
        );

        if (!completer.isCompleted) {
          completer.complete(identity);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout:
          () => throw Exception('Phone verification timed out. Try again.'),
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
        'No account found for this number. Switch to New Account to register.',
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
    await prefs.remove('phoneEmailAccessToken');
    await prefs.remove('phoneEmailJwtToken');
  }

  SessionUser _toSessionUser(
    Map<String, dynamic> row, {
    required String fallbackPhone,
  }) {
    final id = (row['id'] ?? '').toString().trim();
    final phone = (row['phone'] ?? fallbackPhone).toString().trim();
    final name = (row['name'] ?? 'Rider').toString().trim();
    final bike = (row['bike'] ?? 'No bike added').toString().trim();

    if (id.isEmpty) {
      throw Exception('User record is missing id.');
    }

    return SessionUser(
      id: id,
      phone: phone.isNotEmpty ? phone : fallbackPhone,
      name: name.isNotEmpty ? name : 'Rider',
      bike: bike.isNotEmpty ? bike : 'No bike added',
    );
  }

  String? _normalizePhone({
    required String countryCode,
    required String phoneNumber,
  }) {
    final cc = countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    var phoneDigits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cc.isEmpty || phoneDigits.isEmpty) {
      return null;
    }

    if (phoneDigits.startsWith('00')) {
      phoneDigits = phoneDigits.substring(2);
    }

    var local = phoneDigits;
    if (local.startsWith(cc)) {
      local = local.substring(cc.length);
    }

    local = local.replaceFirst(RegExp(r'^0+'), '');
    if (local.isEmpty) {
      return null;
    }

    return '+$cc$local';
  }
}
