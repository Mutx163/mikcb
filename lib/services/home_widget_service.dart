import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'home_widget_snapshot_service.dart';

enum HomeWidgetPinTarget {
  compact22('compact', '主卡 2×2'),
  miniList22('mini_list', '迷你列表 2×2'),
  medium24('medium', '概览 2×4'),
  large44('large', '列表 4×4');

  const HomeWidgetPinTarget(this.value, this.label);

  final String value;
  final String label;
}

enum HomeWidgetPinRequestResult {
  requested,
  unsupported,
  invalidWidgetType,
  failed,
}

class HomeWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.mutx163.qingyu/home_widget');

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<bool> canRequestPinWidget() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final supported = await _channel.invokeMethod<bool>('canRequestPinWidget');
      return supported ?? false;
    } on MissingPluginException {
      if (kDebugMode) {
        return false;
      }
    } catch (e) {
      debugPrint('Failed to check pin widget support: $e');
    }
    return false;
  }

  Future<HomeWidgetPinRequestResult> requestPinWidget(
    HomeWidgetPinTarget target,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return HomeWidgetPinRequestResult.unsupported;
    }
    try {
      final status = await _channel.invokeMethod<String>(
        'requestPinWidget',
        {'widgetType': target.value},
      );
      return switch (status) {
        'requested' => HomeWidgetPinRequestResult.requested,
        'unsupported' => HomeWidgetPinRequestResult.unsupported,
        'invalid_widget_type' => HomeWidgetPinRequestResult.invalidWidgetType,
        _ => HomeWidgetPinRequestResult.failed,
      };
    } on MissingPluginException {
      if (kDebugMode) {
        return HomeWidgetPinRequestResult.unsupported;
      }
    } catch (e) {
      debugPrint('Failed to request pin widget: $e');
    }
    return HomeWidgetPinRequestResult.failed;
  }

  Future<bool> syncSnapshot(HomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod(
        'syncSnapshot',
        snapshot.toJson(),
      );
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      debugPrint('Failed to sync home widget snapshot: $e');
    }
    return false;
  }

  Future<bool> clearSnapshot() async {
    try {
      await _channel.invokeMethod('clearSnapshot');
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      debugPrint('Failed to clear home widget snapshot: $e');
    }
    return false;
  }

  Future<void> scheduleRefresh(List<int> triggerAtMillis) async {
    try {
      await _channel.invokeMethod(
        'scheduleRefresh',
        {'triggerAtMillis': triggerAtMillis},
      );
    } on MissingPluginException {
      if (kDebugMode) {
        return;
      }
    } catch (e) {
      debugPrint('Failed to schedule home widget refresh: $e');
    }
  }
}
