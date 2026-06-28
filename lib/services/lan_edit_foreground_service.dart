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

  /// Returns `true` when the native foreground service started successfully.
  static Future<bool> start() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      await _channel.invokeMethod<void>('startLanEditForeground');
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'START_FOREGROUND_FAILED') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
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
