/// 周次计算领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 解耦阶段 1 从 `TimetableProvider` 与各 service 中收口的重复实现：
/// 此前 `startOfWeek` 在 provider、ics_import_service、
/// import_week_alignment_service、unified_transfer_service 各有一份。
class WeekCalculator {
  WeekCalculator._();

  /// 按**日历日**做加减，而不是按 24 小时的绝对时长。
  ///
  /// `base.add(Duration(days: n))` 在实行夏令时的时区里会出错：那一周有一天是
  /// 23 或 25 小时，从午夜起的本地日期加 7×24h 会落到**前一天 23:00 或后一天
  /// 01:00**，于是「第 N 周周几」这种日期整体挪一天 —— 周预览表头、导出的 ICS
  /// 日期、学期结束日、提醒日都会差一天，而且只有在特定周才复现。
  /// `DateTime(y, m, d + n)` 由 Dart 自己按日历归一，与-hour 无关。
  static DateTime addDays(DateTime date, int days) => DateTime(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );

  /// [from] 到 [to] 的日历日差（同一天为 0，[to] 更早为负）。
  ///
  /// 与 [addDays] 同一个理由：本地 `DateTime.difference().inDays` 数的是**经过
  /// 的时间**，跨拨快夜 23 小时会被 `inDays` 截成 0 天、跨拨慢夜 25 小时多算。
  /// 上游已经为这件事修过一次（ff0ae83d 把周次推导从 `difference().inDays ~/ 7`
  /// 换成本文件的 [getWeekIndex]），这里把同一口径开放给其余调用点。
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(
        DateTime.utc(from.year, from.month, from.day),
      ).inDays;

  /// 将 [date] 归到其所在周的周一 00:00（周一为每周起始日）。
  static DateTime startOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return addDays(normalizedDate, -(normalizedDate.weekday - 1));
  }

  /// 计算 [date] 在学期中的周次（从 1 开始），周一为每周起始日。
  /// 返回 null 表示 [date] 早于学期开始日期。
  static int? getWeekIndex(DateTime date, DateTime semesterStart) {
    final diffDays = daysBetween(
      startOfWeek(semesterStart),
      startOfWeek(date),
    );
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
