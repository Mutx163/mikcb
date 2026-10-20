import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../models/settings/timetable_settings_live.dart';
import '../utils/clock_time.dart';
import 'clock_order.dart';

/// 周网格「考试/日程卡」的落格条目：一种非课程事项 + 它覆盖的节次区间。
///
/// 周网格按（星期几 × 节次）定位课程卡；考试与日程只有钟点串（考试
/// `Exam.dateTime + startTime/endTime`，日程是日期区间 + 钟点），落进网格
/// 要先做「钟点 → 重叠节次」映射（[WeekGridAgendaPlacement
/// .sectionSpanForClockRange]）。条目本身不持有颜色与文案——卡片层从
/// exam / scheduleInstance 现取，与日视图议程卡同源。
class WeekGridAgendaEntry {
  final Exam? exam;
  final ScheduleItemInstance? scheduleInstance;
  final int startSection;
  final int endSection;

  /// 卡片显示用的钟点串：跨天日程已按日视图议程同款口径换成
  /// `00:00` / `23:59`（见 [continuesFromPreviousDay] / [continuesToNextDay]）。
  final String startTime;
  final String endTime;
  final bool continuesFromPreviousDay;
  final bool continuesToNextDay;

  const WeekGridAgendaEntry._({
    this.exam,
    this.scheduleInstance,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.endTime,
    this.continuesFromPreviousDay = false,
    this.continuesToNextDay = false,
  });

  factory WeekGridAgendaEntry.exam(
    Exam exam, {
    required int startSection,
    required int endSection,
  }) {
    return WeekGridAgendaEntry._(
      exam: exam,
      startSection: startSection,
      endSection: endSection,
      startTime: exam.startTime,
      endTime: exam.endTime,
    );
  }

  factory WeekGridAgendaEntry.schedule(
    ScheduleItemInstance instance, {
    required int startSection,
    required int endSection,
    required String startTime,
    required String endTime,
    bool continuesFromPreviousDay = false,
    bool continuesToNextDay = false,
  }) {
    return WeekGridAgendaEntry._(
      scheduleInstance: instance,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      continuesFromPreviousDay: continuesFromPreviousDay,
      continuesToNextDay: continuesToNextDay,
    );
  }

  bool get isExam => exam != null;
  String get title => exam?.name ?? scheduleInstance?.title ?? '';
  String get id => exam?.id ?? scheduleInstance?.id ?? '';
}

/// 周网格「考试/日程卡」落格领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 提案见 `.agents/notes/proposed/feature/2026-10-20-week-view-exam-agenda-display.md`：
/// WakeUp 式「考试当一节特殊卡落进对应时段」；映射规则是「任一重叠即算」，
/// 不做精确分钟裁切。
class WeekGridAgendaPlacement {
  WeekGridAgendaPlacement._();

  /// 组装某一天（[date]）的网格落格条目：考试 + 日程实例，已按节次映射并排序。
  ///
  /// - 考试过滤与日视图议程同一条口径：`!exam.isExpired && 当天`
  ///   （`timetable_day_view_part.dart` 的 `_buildDayAgendaItems`）；
  /// - 日程实例由调用方按日期展开（`provider.getScheduleItemInstancesForDate`），
  ///   这里不再过滤 `enabled`——日视图议程也不过滤，两处必须一致；
  /// - 跨天日程口径与日视图议程一致：前日续来按 `00:00`、续到次日按 `23:59`
  ///   参与映射（整日区间 → 覆盖全部节次 → 整列卡）；
  /// - 排序与日视图议程同款：开始钟点 → 结束钟点 → 类型（日程先、考试后，
  ///   同跨度时考试卡叠在最上层）→ id。钟点一律走 `compareClockText`
  ///   —— 架构棘 `test/architecture/clock_field_compare_guard_test.dart`
  ///   禁止对钟点字段做字典序比较。
  static List<WeekGridAgendaEntry> resolve({
    required List<Exam> exams,
    required List<ScheduleItemInstance> scheduleInstances,
    required DateTime date,
    required List<SectionTime> sections,
  }) {
    final target = DateTime(date.year, date.month, date.day);
    final entries = <WeekGridAgendaEntry>[];

    for (final exam in exams) {
      final examDate = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
      );
      if (exam.isExpired || examDate != target) {
        continue;
      }
      final span = sectionSpanForClockRange(
        startTime: exam.startTime,
        endTime: exam.endTime,
        sections: sections,
      );
      if (span == null) {
        continue;
      }
      entries.add(
        WeekGridAgendaEntry.exam(
          exam,
          startSection: span.$1,
          endSection: span.$2,
        ),
      );
    }

    for (final instance in scheduleInstances) {
      final item = instance.effectiveItem;
      final continuesFromPreviousDay = item.startDate.isBefore(target);
      final continuesToNextDay = item.endDate.isAfter(target);
      final startTime = continuesFromPreviousDay ? '00:00' : item.startTime;
      final endTime = continuesToNextDay ? '23:59' : item.endTime;
      final span = sectionSpanForClockRange(
        startTime: startTime,
        endTime: endTime,
        sections: sections,
      );
      if (span == null) {
        continue;
      }
      entries.add(
        WeekGridAgendaEntry.schedule(
          instance,
          startSection: span.$1,
          endSection: span.$2,
          startTime: startTime,
          endTime: endTime,
          continuesFromPreviousDay: continuesFromPreviousDay,
          continuesToNextDay: continuesToNextDay,
        ),
      );
    }

    entries.sort((left, right) {
      final startCompare = compareClockText(left.startTime, right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = compareClockText(left.endTime, right.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      final leftType = left.isExam ? 2 : 1;
      final rightType = right.isExam ? 2 : 1;
      if (leftType != rightType) {
        return leftType.compareTo(rightType);
      }
      return left.id.compareTo(right.id);
    });
    return List.unmodifiable(entries);
  }

  /// 把当天钟点区间映射到重叠的节次区间（节次从 1 起算，含首尾）。
  ///
  /// 规则是**任一重叠即算**：考试 8:30–10:30 对 8:00–9:50 + 10:05–11:45
  /// 命中第 1–2 节，高度取并集。不做精确分钟裁切——精确裁切会与课程卡的
  /// 「整行节次」模型打架（课程卡从不裁切）。
  ///
  /// 完全不重叠（晚间考试落在末节之后、早读落在第 1 节之前）钳到**距离最近**
  /// 的节：画出来比不画有价值（WakeUp 对晚间时段同样落最后一行）。距离按
  /// 「区间与节区间的间隔分钟数」算（重叠为 0），并列取更早的节，全序稳定。
  ///
  /// 返回 null 的三种情形：节次表为空；钟点串不可解析（`ClockTime.tryParse`
  /// 拒收 `"08.30"` / `"8"` 这类脏值——`SectionTime.fromJson` 只要求非空串，
  /// 脏节次本来就能进库）；节次表存在但全部条目不可解析。
  static (int, int)? sectionSpanForClockRange({
    required String startTime,
    required String endTime,
    required List<SectionTime> sections,
  }) {
    if (sections.isEmpty) {
      return null;
    }
    final start = ClockTime.tryParse(
      startTime,
      allowEndOfDay: true,
    )?.totalMinutes;
    final end = ClockTime.tryParse(endTime, allowEndOfDay: true)?.totalMinutes;
    if (start == null || end == null) {
      return null;
    }
    // 容错：结束早于开始按单点算（外来数据可能反填），不抛异常。
    final effectiveEnd = end < start ? start : end;

    int? overlapStart;
    int? overlapEnd;
    int? nearestIndex;
    int? nearestDistance;
    for (var index = 0; index < sections.length; index++) {
      final sectionStart = ClockTime.tryParse(
        sections[index].startTime,
      )?.totalMinutes;
      final sectionEnd = ClockTime.tryParse(
        sections[index].endTime,
      )?.totalMinutes;
      if (sectionStart == null || sectionEnd == null || sectionEnd <= sectionStart) {
        // 坏节次跳过：SectionTime.fromJson 只要求非空串，"08.30" 这类值
        // 本来就能进库（见 clock_time.dart 的类注释）。
        continue;
      }
      if (start <= sectionEnd && sectionStart <= effectiveEnd) {
        overlapStart ??= index + 1;
        overlapEnd = index + 1;
      }
      final distance = effectiveEnd < sectionStart
          ? sectionStart - effectiveEnd
          : start > sectionEnd
          ? start - sectionEnd
          : 0;
      if (nearestDistance == null || distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    if (overlapStart != null) {
      return (overlapStart, overlapEnd!);
    }
    if (nearestIndex == null) {
      return null;
    }
    return (nearestIndex + 1, nearestIndex + 1);
  }
}
