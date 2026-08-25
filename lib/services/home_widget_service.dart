import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import 'app_log_service.dart';
import 'home_widget_snapshot_service.dart';

enum HomeWidgetPinTarget {
  compact22('compact'),
  miniList22('mini_list'),
  medium24('medium'),
  large44('large'),
  stats22('stats_compact'),
  stats24('stats_medium'),
  todayStrip41('today_strip'),
  statsStrip41('stats_strip'),
  examCard22('exam_card'),
  todayWide42('today_wide');

  const HomeWidgetPinTarget(this.value);

  final String value;
}

enum HomeWidgetPinRequestResult {
  requested,
  unsupported,
  invalidWidgetType,
  failed,
}

class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/home_widget',
  );

  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<bool> canRequestPinWidget() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final supported = await _channel.invokeMethod<bool>(
        'canRequestPinWidget',
      );
      return supported ?? false;
    } on MissingPluginException {
      if (kDebugMode) {
        return false;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_pin_support_failed',
          AppLogMessages.homeWidgetPinSupportFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '检查固定支持失败：$e');
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
      final status = await _channel.invokeMethod<String>('requestPinWidget', {
        'widgetType': target.value,
      });
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
      unawaited(
        AppLogService.instance.warn(
          'home_widget_pin_request_failed',
          AppLogMessages.homeWidgetPinRequestFailed,
          extras: {'error': '$e', 'target': target.value},
        ),
      );
      appDebugLog('HomeWidget', '请求固定小组件失败：$e');
    }
    return HomeWidgetPinRequestResult.failed;
  }

  Future<bool> syncSnapshot(HomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod('syncSnapshot', snapshot.toJson());
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_sync_failed',
          AppLogMessages.homeWidgetSyncFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '同步快照失败：$e');
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
      unawaited(
        AppLogService.instance.warn(
          'home_widget_clear_failed',
          AppLogMessages.homeWidgetClearFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '清空快照失败：$e');
    }
    return false;
  }

  Future<void> scheduleRefresh(List<int> triggerAtMillis) async {
    try {
      await _channel.invokeMethod('scheduleRefresh', {
        'triggerAtMillis': triggerAtMillis,
      });
    } on MissingPluginException {
      if (kDebugMode) {
        return;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_schedule_failed',
          AppLogMessages.homeWidgetScheduleFailed,
          extras: {'error': '$e', 'count': triggerAtMillis.length},
        ),
      );
      appDebugLog('HomeWidget', '调度刷新失败：$e');
    }
  }
}
