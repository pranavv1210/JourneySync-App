import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('INFO: $prefix${_redact(message)}');
    }
  }

  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('WARNING: $prefix${_redact(message)}');
    }
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('ERROR: $prefix${_redact(message)}');
      if (error != null) debugPrint(_redact(error.toString()));
      if (stackTrace != null) debugPrint(_redact(stackTrace.toString()));
    }

    _recordToCrashlytics(
      error ?? Exception(message),
      stackTrace,
      reason: message,
    );
    Sentry.captureException(
      error ?? Exception(message),
      stackTrace: stackTrace,
    );
  }

  static void critical(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('CRITICAL: $prefix${_redact(message)}');
      if (error != null) debugPrint(_redact(error.toString()));
      if (stackTrace != null) debugPrint(_redact(stackTrace.toString()));
    }

    _recordToCrashlytics(
      error ?? Exception(message),
      stackTrace,
      reason: message,
      fatal: true,
    );
    Sentry.captureException(
      error ?? Exception(message),
      stackTrace: stackTrace,
    );
  }

  static void _recordToCrashlytics(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      // Ignore if Firebase isn't initialized yet
    }
  }

  static String _redact(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
          ),
          '[uuid]',
        )
        .replaceAll(RegExp(r'\b\d{10,15}\b'), '[number]')
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'),
          '[token]',
        );
  }
}
