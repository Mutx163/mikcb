/// 周次计算领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 解耦阶段 1 从 `TimetableProvider` 与各 service 中收口的重复实现：
/// 此前 `startOfWeek` 在 provider、ics_import_service、
/// import_week_alignment_service、unified_transfer_service 各有一份。
class WeekCalculator {
  WeekCalculator._();

  /// 将 [date] 归到其所在周的周一 00:00（周一为每周起始日）。
  static DateTime startOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }

  /// 计算 [date] 在学期中的周次（从 1 开始），周一为每周起始日。
  /// 返回 null 表示 [date] 早于学期开始日期。
  static int? getWeekIndex(DateTime date, DateTime semesterStart) {
    final alignedStart = startOfWeek(semesterStart);
    final alignedTarget = startOfWeek(date);
    final diffDays =
        DateTime.utc(alignedTarget.year, alignedTarget.month, alignedTarget.day)
            .difference(
              DateTime.utc(
                alignedStart.year,
                alignedStart.month,
                alignedStart.day,
              ),
            )
            .inDays;
    if (diffDays < 0) return null;
    return (diffDays ~/ 7) + 1;
  }

  /// 教学周次（UI 展示口径，钳制到 [semesterWeekCount]）。
  ///
  /// 学期开始日期未配置时返回 [fallback]；开学前一律第 1 周（与
  /// [fallback] 无关，保持原 `_calculateWeekForDate` 语义）；超出
  /// 学期周数钳制到最后一周。
  static int weekForDate(
    DateTime date, {
    required DateTime? semesterStart,
    required int semesterWeekCount,
    required int fallback,
  }) {
    if (semesterStart == null) return fallback;
    final week = getWeekIndex(date, semesterStart);
    if (week == null) return 1;
    if (week > semesterWeekCount) return semesterWeekCount;
    return week;
  }

  /// 真实日历周次，不按 [semesterWeekCount] 钳制。
  ///
  /// UI 周次在学期结束后钳制到最后一周，让用户停留在已配置的末周；
  /// 超级岛 / 小部件必须用真实日历周，避免已结束课程反复出现（各校
  /// [semesterWeekCount] 不同）。开学前返回 0，避免课程提前显示。
  static int calendarWeekForDate(
    DateTime date, {
    required DateTime? semesterStart,
    required int fallback,
  }) {
    if (semesterStart == null) return fallback;
    final week = getWeekIndex(date, semesterStart);
    if (week == null) return 0;
    return week;
  }
}
