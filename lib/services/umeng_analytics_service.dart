import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UmengAnalyticsService {
  UmengAnalyticsService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.university_timetable/umeng_analytics');

  static bool _initialized = false;

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
