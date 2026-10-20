import '../models/course.dart';
import '../models/exam.dart';
import '../models/holiday_entry.dart';
import '../models/schedule_item.dart';
import '../models/timetable_settings.dart';
import 'clock_order.dart';
import 'holiday_resolver.dart';
import 'schedule_item_expander.dart';
import 'week_calculator.dart';

/// 月历里一天的展示判定结果（纯数据，无 Flutter / IO 依赖）。
class MonthDayEntry {
  /// 当天 00:00 的本地日期（一律 [DateTime] 归一，勿带时分秒使用）。
  final DateTime date;

  /// 真实日历周次（[WeekCalculator.getWeekIndex] 口径，不按
  /// [TimetableSettings.semesterWeekCount] 钳制）。学期未配置或开学前为 null。
  final int? weekIndex;

  /// [weekIndex] 落在配置学期内（1 ≤ 周次 ≤ semesterWeekCount）。
  /// 行标「第 N 周」与课程点都以它为准，学期外不画。
  final bool weekInSemester;

  /// 当天实际有课的课程数：只数 `dayOfWeek` 匹配且 `isInWeek` 命中的课程。
  ///
  /// **刻意不用 `getCoursesForDay`**：那関数带「非本周淡化」扩展
  /// （未落在本周、但本周之后还有课的课程也会返回），那是给周网格用的；
  /// 月视图一格是具体日期，只承认当天真实发生的课程，否则一个课程会在
  /// 它不上课的日期也占一颗点（重复计数）。
  final int courseCount;

  /// 当天课程的去重颜色（hex 串，最多 3 个，保持出现顺序）。
  /// 渲染层解析失败回落主题色，域层不做颜色解析。
  final List<String> courseColorHexes;

  /// 未过期考试数（过期口径见 [MonthViewLogic.examsOnDate]）。
  final int examCount;

  /// 日程实例数（与日视图同口径：`ScheduleItemExpander.instancesForDate`，
  /// 含已暂停项——日视图也不过滤 enabled，两侧必须一致）。
  final int scheduleCount;

  /// 假期（[HolidayResolver.isHoliday] 全语义：调休上班日优先、
  /// 假期覆盖开关、假期标记开关都已折算）。
  final bool isHoliday;

  /// 调休上班日（显示「班」标）。
  final bool isAdjustedWorkday;

  /// 是否前后月补位格（固定 42 格里落在本月之外的日期）。
  final bool isOutsideMonth;

  const MonthDayEntry({
    required this.date,
    required this.weekIndex,
    required this.weekInSemester,
    required this.courseCount,
    required this.courseColorHexes,
    required this.examCount,
    required this.scheduleCount,
    required this.isHoliday,
    required this.isAdjustedWorkday,
    required this.isOutsideMonth,
  });
}

/// 一个月的月历（6 行 × 7 列 = 42 格，周一为列首）。
class MonthGridData {
  final int year;
  final int month;

  /// 固定 42 格，与 [MonthViewLogic.monthGridDates] 同序。
  final List<MonthDayEntry> days;

  /// 聚合时刻的「今天」（dateOnly）。固定 42 格可能不含今天。
  final DateTime today;

  const MonthGridData({
    required this.year,
    required this.month,
    required this.days,
    required this.today,
  });

  MonthDayEntry? entryFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    for (final day in days) {
      if (day.date == key) {
        return day;
      }
    }
    return null;
  }
}

/// 月视图当日议程的一行。
enum MonthAgendaRowKind { course, exam, schedule }

class MonthAgendaRow {
  final MonthAgendaRowKind kind;

  /// 展示钟点（已按 [compareClockText] 口径可比较）。课程节次映射不到
  /// 作息时间时为 null（排序垫底，展示层画占位）。
  final String? clockText;

  final String title;
  final String? subtitle;

  /// 课程/日程颜色 hex；考试为 null（渲染层固定 error 色）。
  final String? colorHex;

  final Course? course;
  final Exam? exam;
  final ScheduleItemInstance? schedule;

  const MonthAgendaRow({
    required this.kind,
    required this.clockText,
    required this.title,
    required this.subtitle,
    required this.colorHex,
    this.course,
    this.exam,
    this.schedule,
  });
}

/// 月视图领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 与 [WeekCalculator]、[ScheduleItemExpander]、[HolidayResolver] 同一套
/// 收口思路：数据组装全部落在这里，渲染层只画。日期一律「日历日」口径
/// （`DateTime(y, m, d)` 归一），禁止按 24 小时时长加减（DST 纪律同
/// [WeekCalculator.addDays]）。
abstract final class MonthViewLogic {
  /// 固定 42 格（6 行 × 7 列，周一为列首）的日期序列，含前后月补位。
  ///
  /// 固定 42 格而不按月裁 4~6 行：月视图整页高度跨月统一，翻页不跳变
  /// （与周网格 `sectionHeight × sectionCount` 的整页高度纪律同源）。
  static List<DateTime> monthGridDates(int year, int month) {
    final first = DateTime(year, month);
    final gridStart = WeekCalculator.startOfWeek(first);
    return [
      for (var i = 0; i < 42; i++) WeekCalculator.addDays(gridStart, i),
    ];
  }

  /// [date]（开学配置下）当天真实发生的课程。
  ///
  /// 周次取 [WeekCalculator.getWeekIndex]（开学前 null → 无课程可映射）；
  /// 学期配置了但该周超出 semesterWeekCount 时仍按真实周次匹配（课程
  /// startWeek/endWeek 不会超出，自然为空）。
  static List<Course> coursesOnDate(
    List<Course> courses,
    DateTime date,
    TimetableSettings settings,
  ) {
    final normalized = DateTime(date.year, date.month, date.day);
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return const [];
    }
    final weekIndex = WeekCalculator.getWeekIndex(normalized, semesterStart);
    if (weekIndex == null) {
      return const [];
    }
    return courses
        .where(
          (course) =>
              course.dayOfWeek == normalized.weekday &&
              course.isInWeek(weekIndex),
        )
        .toList();
  }

  /// [date] 的未过期考试。过期口径与 [Exam.isExpired] 完全一致
  /// （endTime 缺省 23:59），只是把 `DateTime.now()` 收成参数 [now]，
  /// 让域逻辑可测。返回按 [Exam.compareByStart] 排序。
  static List<Exam> examsOnDate(List<Exam> exams, DateTime date, DateTime now) {
    final normalized = DateTime(date.year, date.month, date.day);
    final result = <Exam>[];
    for (final exam in exams) {
      final examDate = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
      );
      if (examDate != normalized) {
        continue;
      }
      final endParts = Exam.parseTimeOfDayParts(
        exam.endTime,
        fallbackHour: 23,
        fallbackMinute: 59,
      );
      final examEnd = DateTime(
        examDate.year,
        examDate.month,
        examDate.day,
        endParts.$1,
        endParts.$2,
      );
      if (now.isAfter(examEnd)) {
        continue;
      }
      result.add(exam);
    }
    return result..sort(Exam.compareByStart);
  }

  /// [date] 的日程实例（与日视图同口径：不过滤 enabled，例外覆盖胜出）。
  static List<ScheduleItemInstance> scheduleInstancesOnDate(
    List<ScheduleItem> scheduleItems,
    DateTime date,
  ) {
    return ScheduleItemExpander.instancesForDate(scheduleItems, date);
  }

  /// 聚合一个月的月历数据（42 格逐日判定）。
  ///
  /// 日程一次性展开整段再按日分桶（42 次逐日调 instancesForDate 会重复
  /// 展开同一批系列）；考试按日分桶一次成型。数据规模（课程/日程/考试
  /// 各几十条 × 42 格）在微秒级，不做缓存。
  static MonthGridData buildMonthGrid({
    required int year,
    required int month,
    required DateTime now,
    required List<Course> courses,
    required List<ScheduleItem> scheduleItems,
    required List<Exam> exams,
    required TimetableSettings settings,
    required HolidayData? holidayData,
  }) {
    final dates = monthGridDates(year, month);
    final rangeStart = DateTime(
      dates.first.year,
      dates.first.month,
      dates.first.day,
    );
    final rangeEnd = DateTime(
      dates.last.year,
      dates.last.month,
      dates.last.day,
    );
    final scheduleByDate = <DateTime, int>{};
    for (final instance in ScheduleItemExpander.instancesForRange(
      scheduleItems,
      rangeStart,
      rangeEnd,
    )) {
      scheduleByDate[instance.date] = (scheduleByDate[instance.date] ?? 0) + 1;
    }
    final examByDate = <DateTime, int>{};
    for (final exam in exams) {
      final key = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
      );
      final endParts = Exam.parseTimeOfDayParts(
        exam.endTime,
        fallbackHour: 23,
        fallbackMinute: 59,
      );
      final examEnd = DateTime(
        key.year,
        key.month,
        key.day,
        endParts.$1,
        endParts.$2,
      );
      if (now.isAfter(examEnd)) {
        continue;
      }
      examByDate[key] = (examByDate[key] ?? 0) + 1;
    }
    final today = DateTime(now.year, now.month, now.day);
    final days = <MonthDayEntry>[];
    for (final raw in dates) {
      final date = DateTime(raw.year, raw.month, raw.day);
      final semesterStart = settings.semesterStartDate;
      final weekIndex = semesterStart == null
          ? null
          : WeekCalculator.getWeekIndex(date, semesterStart);
      final weekInSemester =
          weekIndex != null &&
          weekIndex >= 1 &&
          weekIndex <= settings.semesterWeekCount;
      final dayCourses = coursesOnDate(courses, date, settings);
      final colorHexes = <String>[];
      for (final course in dayCourses) {
        final hex = course.color.trim();
        if (hex.isNotEmpty && !colorHexes.contains(hex)) {
          colorHexes.add(hex);
        }
        if (colorHexes.length >= 3) {
          break;
        }
      }
      days.add(
        MonthDayEntry(
          date: date,
          weekIndex: weekIndex,
          weekInSemester: weekInSemester,
          courseCount: dayCourses.length,
          courseColorHexes: List.unmodifiable(colorHexes),
          examCount: examByDate[date] ?? 0,
          scheduleCount: scheduleByDate[date] ?? 0,
          isHoliday: HolidayResolver.isHoliday(
            date,
            data: holidayData,
            overrideEnabled: settings.holidayOverrideEnabled,
            markingEnabled: settings.enableHolidayMarking,
          ),
          isAdjustedWorkday: HolidayResolver.isAdjustedWorkday(
            date,
            data: holidayData,
          ),
          isOutsideMonth: date.month != month || date.year != year,
        ),
      );
    }
    return MonthGridData(
      year: year,
      month: month,
      days: List.unmodifiable(days),
      today: today,
    );
  }

  /// 选中日的议程行：课程 + 考试 + 日程混排（与日视图同一混排语义）。
  ///
  /// 排序口径：钟点非空的按 [compareClockText]（正源，勿写字符串字典序
  /// 比较——架构守卫会拦）；课程节次映射不到作息时间的行钟点为 null 垫底，
  /// 垫底层保持（kind 优先级, 注入序）稳定序。
  static List<MonthAgendaRow> buildDayAgenda({
    required DateTime date,
    required List<Course> courses,
    required List<ScheduleItem> scheduleItems,
    required List<Exam> exams,
    required TimetableSettings settings,
    required List<SectionTime> sections,
    required DateTime now,
  }) {
    final rows = <MonthAgendaRow>[];
    var order = 0;
    final orderOf = <MonthAgendaRow, int>{};
    void add(MonthAgendaRow row) {
      orderOf[row] = order++;
      rows.add(row);
    }

    for (final course in coursesOnDate(courses, date, settings)) {
      add(
        MonthAgendaRow(
          kind: MonthAgendaRowKind.course,
          clockText: sectionStartClock(sections, course.startSection),
          title: course.name,
          subtitle: course.location.isEmpty ? null : course.location,
          colorHex: course.color.trim().isEmpty ? null : course.color,
          course: course,
        ),
      );
    }
    for (final exam in examsOnDate(exams, date, now)) {
      add(
        MonthAgendaRow(
          kind: MonthAgendaRowKind.exam,
          clockText: exam.startTime,
          title: exam.name,
          subtitle: exam.location,
          colorHex: null,
          exam: exam,
        ),
      );
    }
    for (final instance in scheduleInstancesOnDate(scheduleItems, date)) {
      add(
        MonthAgendaRow(
          kind: MonthAgendaRowKind.schedule,
          clockText: instance.startTime,
          title: instance.title,
          subtitle: instance.location,
          colorHex: instance.color.trim().isEmpty ? null : instance.color,
          schedule: instance,
        ),
      );
    }
    rows.sort((a, b) {
      final aClock = a.clockText;
      final bClock = b.clockText;
      if (aClock == null || bClock == null) {
        if (aClock == bClock) {
          return orderOf[a]!.compareTo(orderOf[b]!);
        }
        return aClock == null ? 1 : -1;
      }
      final clockCompare = compareClockText(aClock, bClock);
      if (clockCompare != 0) {
        return clockCompare;
      }
      return orderOf[a]!.compareTo(orderOf[b]!);
    });
    return List.unmodifiable(rows);
  }

  /// 节次序号（1 起）→ 作息表起始钟点；越界或时间缺失返回 null。
  static String? sectionStartClock(List<SectionTime> sections, int startSection) {
    final index = startSection - 1;
    if (index < 0 || index >= sections.length) {
      return null;
    }
    final clock = sections[index].startTime.trim();
    return clock.isEmpty ? null : clock;
  }
}
