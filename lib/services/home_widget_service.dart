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

  /// Android 12+（S）需要「闹钟和提醒」权限才能用精确闹钟按课程边界
  /// 刷新小组件；低于 S 或无法读取时视为已授权。
  Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return granted ?? true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_check_failed',
          AppLogMessages.homeWidgetExactAlarmCheckFailed,
          extras: {'error': 'MissingPluginException'},
        ),
      );
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_check_failed',
          AppLogMessages.homeWidgetExactAlarmCheckFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '检查精确闹钟权限失败：$e');
    }
    return true;
  }

  /// 跳转系统「闹钟和提醒」授权页（ACTION_REQUEST_SCHEDULE_EXACT_ALARM）。
  ///
  /// 返回是否成功发起跳转；ROM 回退应用详情页或跳转失败时为 false，
  /// 调用方可据此提示用户手动前往系统设置。
  Future<bool> requestScheduleExactAlarm() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestScheduleExactAlarm',
      );
      return ok ?? false;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_request_failed',
          AppLogMessages.homeWidgetExactAlarmRequestFailed,
          extras: {'error': 'MissingPluginException'},
        ),
      );
      return false;
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_exact_alarm_request_failed',
          AppLogMessages.homeWidgetExactAlarmRequestFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '请求精确闹钟权限失败：$e');
      return false;
    }
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
