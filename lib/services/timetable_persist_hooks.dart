import 'dart:async';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import 'user_data_sync_hooks.dart';
import 'weekly_report_service.dart';

/// 落盘成功后副作用需要的最小宿主面。
///
/// `TimetableProvider` 的三个公开 getter 已满足，直接 `implements` 即可；
/// 服务不 import provider，可用假端口单测。
abstract interface class TimetablePersistPort {
  TimetableSettings get settings;
  List<Course> get courses;
  int get currentWeek;
}

/// 周报正文重推的实现面；测试可注入假实现，生产用
/// `refreshWeeklyReportForSettings`（`weekly_report_service.dart`）。
typedef WeeklyReportRefresher =
    Future<bool> Function({
      required String localeTag,
      required List<Course> allCourses,
      required int currentWeek,
      required int semesterWeekCount,
    });

/// 一次课表/设置落盘成功之后必须跟着跑的副作用 —— **只有这一份定义**。
///
/// 2026-10-20 从 `providers/timetable/live_activity_controller.dart` 的
/// `_afterProfilePersisted` / `_syncWeeklyReportContent` 拆出（K1）：原先核心
/// 持久化路径反向依赖直播分片，直播无法先拆。行为逐字保持：
///
/// - `notifySync == false`（补偿写 / 回滚路径）直接返回，不通知、不重推；
/// - 先通知同步层，再按设置决定是否重推周报正文；
/// - 周报的正文去重与 locale 解析仍在 `weekly_report_service.dart`，
///   内容没变就不碰原生通道，所以这里可以每次保存都调。
class TimetablePersistHooks {
  const TimetablePersistHooks._();

  static void afterProfilePersisted(
    TimetablePersistPort host, {
    required bool notifySync,
    void Function()? notifySyncHook,
    WeeklyReportRefresher? refreshWeeklyReport,
  }) {
    if (!notifySync) {
      return;
    }
    (notifySyncHook ?? notifyUserDataChangedForSync)();
    _syncWeeklyReportContent(
      host,
      refreshWeeklyReport ?? refreshWeeklyReportForSettings,
    );
  }

  static void _syncWeeklyReportContent(
    TimetablePersistPort host,
    WeeklyReportRefresher refresh,
  ) {
    final settings = host.settings;
    if (!settings.weeklyReportEnabled) {
      return;
    }
    unawaited(
      refresh(
        localeTag: settings.appLocaleTag,
        allCourses: host.courses,
        currentWeek: host.currentWeek,
        semesterWeekCount: settings.semesterWeekCount,
      ),
    );
  }
}
