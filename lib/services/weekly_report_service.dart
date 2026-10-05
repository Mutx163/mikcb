import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../utils/locale_utils.dart';
import 'statistics_service.dart';

/// 每周周报通知：计算下次触发时间与正文，同步给原生 AlarmManager 调度。
class WeeklyReportService {
  WeeklyReportService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/weekly_report',
  );

  /// 每周日 21:00 推送
  static const int _fireHour = 21;

  /// 下次周报触发时间（本地时间，若今天已是推送时刻则顺延一周）
  static DateTime nextFireAt({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final daysUntilSunday = (DateTime.sunday - current.weekday + 7) % 7;
    var fire = today
        .add(Duration(days: daysUntilSunday))
        .add(const Duration(hours: _fireHour));
    if (!fire.isAfter(current)) {
      fire = fire.add(const Duration(days: 7));
    }
    return fire;
  }

  static String buildTitle(AppLocalizations l10n) => l10n.weeklyReportTitle;

  static String buildBody({
    required AppLocalizations l10n,
    required List<Course> allCourses,
    required int currentWeek,
    required int semesterWeekCount,
  }) {
    if (allCourses.isEmpty) {
      return l10n.weeklyReportBodyEmpty;
    }
    final weekStats = StatisticsService.calculate(
      allCourses: allCourses,
      week: currentWeek,
    );
    final comparison = StatisticsService.calculateWeeklyComparison(
      allCourses: allCourses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final busiestDay = weekStats.busiestDay;
    final busiestLabel = busiestDay != null
        ? _weekdayLabel(l10n, busiestDay)
        : '';
    final delta = comparison.deltaVsLastWeek;
    final deltaLabel = currentWeek <= 1
        ? l10n.statisticsComparisonNew
        : (delta > 0 ? '+$delta' : '$delta');
    return l10n.weeklyReportBody(
      currentWeek,
      weekStats.totalSections,
      weekStats.totalCourses,
      deltaLabel,
      busiestLabel,
    );
  }

  /// 同步调度：enabled=false 时取消原生闹钟
  static Future<void> schedule({
    required bool enabled,
    required AppLocalizations l10n,
    required List<Course> allCourses,
    required int currentWeek,
    required int semesterWeekCount,
  }) async {
    if (!enabled) {
      try {
        await _channel.invokeMethod('cancel');
      } catch (_) {
        // 平台未实现（非 Android）时静默
      }
      return;
    }
    final title = buildTitle(l10n);
    final body = buildBody(
      l10n: l10n,
      allCourses: allCourses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    try {
      await _channel.invokeMethod('scheduleNext', {
        'enabled': true,
        'fireAtMillis': nextFireAt().millisecondsSinceEpoch,
        'title': title,
        'body': body,
      });
    } catch (_) {
      // 平台未实现（非 Android）时静默
    }
  }

  static String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayShortMonday,
      2 => l10n.weekdayShortTuesday,
      3 => l10n.weekdayShortWednesday,
      4 => l10n.weekdayShortThursday,
      5 => l10n.weekdayShortFriday,
      6 => l10n.weekdayShortSaturday,
      7 => l10n.weekdayShortSunday,
      _ => dayOfWeek.toString(),
    };
  }
}

/// —— 以下是第二十六轮新增：provider 侧的正文重推入口。
///
/// 存在的理由：原生 `WeeklyReportScheduler` 投递成功后**只推进 `fireAtMillis`**
/// （`WeeklyReportScheduler.kt:164-171`），`KEY_TITLE`/`KEY_BODY` 原样留着，
/// 而它自己的契约注释（`:17-20`）要求 Flutter "whenever the toggle **or the
/// timetable changes**" 都重推 —— 原先全仓只有设置页拨开关那一处推送
/// （`statistics_settings_screen.dart:69-86`），于是正文永久冻结在拨开关那一周：
/// 学期第 16 周还在弹"第 8 周 · 共 12 节"，换课表、导新课表后照旧。
///
/// 本地化走 `lookupAppLocalizations`：与 `main.dart:460` 取启动切换器标签
/// 是同一条 context-free 路径（provider 层没有 BuildContext）。
///
/// [isFinal] 为 false 时**不要**调这里 —— 那会走 `schedule` 的 cancel 分支，
/// 每次保存都去动一次原生闹钟；关闭只由设置页开关那一处负责。
String? _lastPushedWeeklyReportText;

/// 内容真的变了才重推：直接把要下发的标题与正文拼成一份文本比对，
/// 比"课表版本号/条数"这类代理签名精确，也不会因为改了星期/节次而漏推。
Future<bool> refreshWeeklyReportForSettings({
  required String localeTag,
  required List<Course> allCourses,
  required int currentWeek,
  required int semesterWeekCount,
}) async {
  final l10n = lookupAppLocalizations(
    localeFromSettingsTag(localeTag) ?? PlatformDispatcher.instance.locale,
  );
  final text = '${WeeklyReportService.buildTitle(l10n)}\n'
      '${WeeklyReportService.buildBody(
        l10n: l10n,
        allCourses: allCourses,
        currentWeek: currentWeek,
        semesterWeekCount: semesterWeekCount,
      )}';
  if (text == _lastPushedWeeklyReportText) {
    return false;
  }
  await WeeklyReportService.schedule(
    enabled: true,
    l10n: l10n,
    allCourses: allCourses,
    currentWeek: currentWeek,
    semesterWeekCount: semesterWeekCount,
  );
  // 只在通道调用之后记账：schedule 内部已经吞掉非 Android 的 MissingPluginException，
  // 所以这里记的是"这份文本已经交出去了"，不是"用户收到了通知"。
  _lastPushedWeeklyReportText = text;
  return true;
}

/// 测试与"关掉周报"后的复位点：避免上一份文本把下一次真正的内容变更吃掉。
void resetWeeklyReportPushCacheForTesting() =>
    _lastPushedWeeklyReportText = null;
