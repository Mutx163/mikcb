import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
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
    var daysUntilSunday = (DateTime.sunday - current.weekday + 7) % 7;
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
