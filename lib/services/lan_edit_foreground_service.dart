import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef LanEditNotificationTapCallback = void Function();

/// Android foreground service bridge for LAN edit sessions.
class LanEditForegroundBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/lan_edit',
  );

  static LanEditNotificationTapCallback? onNotificationTapped;

  static Future<void> installNotificationTapHandler() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLanEditNotificationTapped') {
        onNotificationTapped?.call();
      }
    });
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('startLanEditForeground');
    } catch (_) {
      // Non-fatal on unsupported platforms or permission issues.
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('stopLanEditForeground');
    } catch (_) {
      // Ignore stop failures.
    }
  }

  static Future<bool> consumePendingOpen() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('getPendingLanEditOpen');
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
