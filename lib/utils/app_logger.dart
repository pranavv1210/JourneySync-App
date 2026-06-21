import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      print('INFO: $prefix$message');
    }
  }

  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      print('WARNING: $prefix$message');
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
      print('ERROR: $prefix$message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
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
      print('CRITICAL: $prefix$message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
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
}
