import 'package:flutter/material.dart';

import '../../domain/day_course_display_logic.dart';
import '../../models/exam.dart';
import '../../models/schedule_item.dart';

/// 日视图翻页目标（2026-10-19 从 timetable_screen 的库级私有类搬出）。
class TimetableDayViewPageTarget {
  final int week;
  final int dayOfWeek;

  const TimetableDayViewPageTarget({
    required this.week,
    required this.dayOfWeek,
  });
}

/// 日视图议程条目（课程 / 日程 / 考试三选一 + 起止钟点）。
class TimetableDayAgendaItem {
  final DayCourseDisplayItem? courseItem;
  final ScheduleItem? scheduleItem;
  final ScheduleItemInstance? scheduleInstance;
  final Exam? exam;
  final String startTime;
  final String endTime;
  final bool continuesFromPreviousDay;
  final bool continuesToNextDay;

  const TimetableDayAgendaItem._({
    this.courseItem,
    this.scheduleItem,
    this.scheduleInstance,
    this.exam,
    required this.startTime,
    required this.endTime,
    this.continuesFromPreviousDay = false,
    this.continuesToNextDay = false,
  });

  factory TimetableDayAgendaItem.course(DayCourseDisplayItem item) {
    return TimetableDayAgendaItem._(
      courseItem: item,
      startTime: item.course.startTime,
      endTime: item.course.endTime,
    );
  }

  factory TimetableDayAgendaItem.schedule(
    ScheduleItem item, {
    ScheduleItemInstance? instance,
    required String startTime,
    required String endTime,
    bool continuesFromPreviousDay = false,
    bool continuesToNextDay = false,
  }) {
    return TimetableDayAgendaItem._(
      scheduleItem: item,
      scheduleInstance: instance,
      startTime: startTime,
      endTime: endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  factory TimetableDayAgendaItem.exam(Exam exam) {
    return TimetableDayAgendaItem._(
      exam: exam,
      startTime: exam.startTime,
      endTime: exam.endTime,
    );
  }

  /// 某一天的那一次日程实例 → 议程条目（原
  /// `_TimetableScreenState._buildScheduleAgendaItemForDate`，2026-10-20 下沉）。
  ///
  /// 跨天口径是日视图议程的定义：前日续来按 `00:00`、续到次日按 `23:59`，
  /// 这样排序与「X 开始 · Y 结束」摘要都按当天可视区间算。周网格的
  /// `WeekGridAgendaPlacement` 抄的就是这条口径，改这里要同步那边。
  factory TimetableDayAgendaItem.scheduleForDate({
    required ScheduleItemInstance instance,
    required DateTime targetDate,
  }) {
    final item = instance.effectiveItem;
    final normalizedTargetDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final continuesFromPreviousDay = item.startDate.isBefore(
      normalizedTargetDate,
    );
    final continuesToNextDay = item.endDate.isAfter(normalizedTargetDate);
    return TimetableDayAgendaItem.schedule(
      item,
      instance: instance,
      startTime: continuesFromPreviousDay ? '00:00' : item.startTime,
      endTime: continuesToNextDay ? '23:59' : item.endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  bool get isScheduleItem => scheduleItem != null;
  bool get isExam => exam != null;
  String get id =>
      exam?.id ??
      (isScheduleItem
          ? scheduleInstance?.occurrenceId ?? scheduleItem!.id
          : courseItem!.course.id);
}

/// 日视图议程卡的进度/状态配色（2026-10-19 从 timetable_screen 搬出）。
class TimetableDayAgendaProgressInfo {
  final double progress;
  final int remainingMinutes;
  final String statusText;
  final Color statusBackgroundColor;
  final Color statusTextColor;
  final Color baseColor;
  final Color fillColor;

  const TimetableDayAgendaProgressInfo({
    required this.progress,
    required this.remainingMinutes,
    required this.statusText,
    required this.statusBackgroundColor,
    required this.statusTextColor,
    required this.baseColor,
    required this.fillColor,
  });
}

/// 日视图议程卡的底色/填充/前景色三元组（2026-10-19 从 timetable_screen 搬出）。
class TimetableDayAgendaPalette {
  final Color baseColor;
  final Color fillColor;
  final Color foregroundColor;

  const TimetableDayAgendaPalette({
    required this.baseColor,
    required this.fillColor,
    required this.foregroundColor,
  });
}
