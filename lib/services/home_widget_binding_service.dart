import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import 'app_log_service.dart';
import 'home_widget_snapshot_service.dart';

/// 今日课程类卡片的类型标识（与原生 resolveWidgetProvider/todayWidgetProviders 对齐）。
enum HomeWidgetType {
  compact('compact'),
  miniList('mini_list'),
  medium('medium'),
  large('large'),
  todayStrip('today_strip'),
  todayWide('today_wide');

  const HomeWidgetType(this.value);

  final String value;

  static HomeWidgetType? fromValue(String? value) {
    for (final type in HomeWidgetType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

/// 桌面上一个真实存在的今日课程卡片实例。
class HomeWidgetInstance {
  final int appWidgetId;
  final HomeWidgetType? widgetType;

  /// 绑定的课表 id；null = 未登记（跟随当前课表）。
  final String? boundProfileId;

  const HomeWidgetInstance({
    required this.appWidgetId,
    required this.widgetType,
    required this.boundProfileId,
  });

  factory HomeWidgetInstance.fromChannel(Object? raw) {
    final map = raw as Map<Object?, Object?>?;
    return HomeWidgetInstance(
      appWidgetId: (map?['appWidgetId'] as num?)?.toInt() ?? -1,
      widgetType: HomeWidgetType.fromValue(map?['widgetType'] as String?),
      boundProfileId: map?['boundProfileId'] as String?,
    );
  }
}

/// 卡片绑定档案的 Flutter 侧入口。
///
/// 绑定表本体存放在原生 `home_widget_prefs`，由 Kotlin 的 WidgetBindingStore
/// 独家管理；Flutter 只通过 home_widget 通道读写，不持有第二份副本，
/// 保证绑定更新、卡片删除清理在两端看到的是同一份事实。
class HomeWidgetBindingService {
  const HomeWidgetBindingService();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/home_widget',
  );

  Future<List<HomeWidgetInstance>> listTodayWidgetInstances() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'listTodayWidgetInstances',
      );
      return (raw ?? const [])
          .map(HomeWidgetInstance.fromChannel)
          .where((instance) => instance.appWidgetId >= 0)
          .toList(growable: false);
    } on MissingPluginException {
      if (kDebugMode) {
        return const [];
      }
      rethrow;
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_list_instances_failed',
          AppLogMessages.homeWidgetSyncFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('HomeWidget', '列出桌面卡片失败：$e');
      return const [];
    }
  }

  Future<String?> getWidgetBinding(int appWidgetId) async {
    try {
      return await _channel.invokeMethod<String>('getWidgetBinding', {
        'appWidgetId': appWidgetId,
      });
    } on MissingPluginException {
      return null;
    } catch (e) {
      appDebugLog('HomeWidget', '读取卡片绑定失败：$e');
      return null;
    }
  }

  /// profileId 传 null = 解除绑定（回落「跟随当前课表」）。
  Future<bool> setWidgetBinding(int appWidgetId, String? profileId) async {
    try {
      await _channel.invokeMethod('setWidgetBinding', {
        'appWidgetId': appWidgetId,
        'profileId': profileId,
      });
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'home_widget_set_binding_failed',
          AppLogMessages.homeWidgetSyncFailed,
          extras: {'error': '$e', 'appWidgetId': appWidgetId},
        ),
      );
      appDebugLog('HomeWidget', '保存卡片绑定失败：$e');
    }
    return false;
  }

  Future<bool> syncWidgetSnapshot(int appWidgetId, HomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod('syncWidgetSnapshot', {
        'appWidgetId': appWidgetId,
        'snapshot': snapshot.toJson(),
      });
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (e) {
      appDebugLog('HomeWidget', '同步卡片专属快照失败：$e');
    }
    return false;
  }

  Future<void> clearWidgetSnapshot(int appWidgetId) async {
    try {
      await _channel.invokeMethod('clearWidgetSnapshot', {
        'appWidgetId': appWidgetId,
      });
    } on MissingPluginException {
      // ignore
    } catch (e) {
      appDebugLog('HomeWidget', '清理卡片专属快照失败：$e');
    }
  }

  /// 消费一次卡片点击（原生 pending）。null = 本次启动没有卡片点击。
  Future<int?> consumePendingWidgetLaunch() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getPendingWidgetLaunch');
      return (raw as num?)?.toInt();
    } on MissingPluginException {
      return null;
    } catch (e) {
      appDebugLog('HomeWidget', '读取卡片点击失败：$e');
      return null;
    }
  }
}
