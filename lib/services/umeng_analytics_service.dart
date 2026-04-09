import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log_service.dart';

typedef DiagnosticLogLevel = String;

abstract final class DiagnosticLogLevels {
  static const DiagnosticLogLevel all = 'all';
  static const DiagnosticLogLevel error = 'error';
  static const DiagnosticLogLevel warn = 'warn';
  static const DiagnosticLogLevel info = 'info';
  static const DiagnosticLogLevel debug = 'debug';
  static const DiagnosticLogLevel verbose = 'verbose';
}

class UmengAnalyticsService {
  UmengAnalyticsService._();

  static const MethodChannel _channel =
      MethodChannel('com.mutx163.qingyu/umeng_analytics');

  static bool _initialized = false;
  static final Map<String, DateTime> _lastReportAt = {};
  static const Duration _reportThrottleWindow = Duration(minutes: 2);

  static Future<void> initializeIfNeeded() async {
    if (_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('initializeIfNeeded');
      _initialized = true;
    } on MissingPluginException {
      // Ignore when the platform implementation is unavailable.
    } catch (_) {
      // Keep startup resilient even if analytics init fails.
    }
  }

  static Future<void> reportUnhandledError(
    Object error,
    StackTrace stackTrace, {
    String category = 'flutter_unhandled_exception',
    DiagnosticLogLevel level = DiagnosticLogLevels.error,
  }) async {
    await AppLogService.instance.error(
      category,
      error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _reportCustomLog(
      category: category,
      message: error.toString(),
      stackTrace: stackTrace.toString(),
      dedupeKey: '$category:${error.runtimeType}',
      level: level,
    );
  }

  static Future<void> reportDiagnostic(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? dedupeKey,
    DiagnosticLogLevel? level,
  }) async {
    final effectiveLevel = level ??
        (error != null || stackTrace != null
            ? DiagnosticLogLevels.error
            : DiagnosticLogLevels.warn);
    await AppLogService.instance.log(
      level: effectiveLevel,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _reportCustomLog(
      category: category,
      message: message,
      stackTrace: stackTrace?.toString(),
      error: error?.toString(),
      dedupeKey: dedupeKey ?? '$category:$message',
      level: effectiveLevel,
    );
  }

  static Future<void> _reportCustomLog({
    required String category,
    required String message,
    String? stackTrace,
    String? error,
    required String dedupeKey,
    DiagnosticLogLevel? level,
  }) async {
    final now = DateTime.now();
    final lastAt = _lastReportAt[dedupeKey];
    if (lastAt != null && now.difference(lastAt) < _reportThrottleWindow) {
      return;
    }
    _lastReportAt[dedupeKey] = now;

    try {
      await _channel.invokeMethod<void>('reportCustomLog', {
        'category': category,
        'message': message,
        'error': error,
        'stackTrace': stackTrace,
        'dedupeKey': dedupeKey,
        'level': level,
      });
    } on MissingPluginException {
      // Ignore when the platform implementation is unavailable.
    } catch (_) {
      // Diagnostics should never affect the app flow.
    }
  }

  static Future<void> setLiveDiagnosticsEnabled(bool value) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setLiveDiagnosticsEnabled', value);
    } on MissingPluginException {
      // Ignore when the platform implementation is unavailable.
    } catch (_) {
      // Diagnostics should never affect the app flow.
    }
  }

  static Future<void> recordDiagnosticEvent(
    String category,
    String message, {
    Map<String, Object?> extras = const {},
    DiagnosticLogLevel level = DiagnosticLogLevels.info,
  }) async {
    await AppLogService.instance.log(
      level: level,
      category: category,
      message: message,
      extras: extras,
    );
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('recordDiagnosticEvent', {
        'category': category,
        'message': message,
        'extras': extras,
        'level': level,
      });
    } on MissingPluginException {
      // Ignore when the platform implementation is unavailable.
    } catch (_) {
      // Diagnostics should never affect the app flow.
    }
  }

  static Future<String?> exportLiveDiagnosticsFile() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final result =
          await _channel.invokeMethod<String>('exportLiveDiagnosticsFile');
      return result;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readLiveDiagnosticsText() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final result =
          await _channel.invokeMethod<String>('readLiveDiagnosticsText');
      return result;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> clearLiveDiagnostics() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('clearLiveDiagnostics');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> triggerTestCrash() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await initializeIfNeeded();
    await _channel.invokeMethod<void>('triggerTestCrash');
  }

  static Future<void> triggerTestAnr() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await initializeIfNeeded();
    await _channel.invokeMethod<void>('triggerTestAnr');
  }
}
