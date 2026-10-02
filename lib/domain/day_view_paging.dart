/// 日视图分页与"可见星期"的唯一口径。
///
/// 首页日视图是一根**全局连续**的 PageView：页号 = `(week - 1) * 可见星期数 +
/// 该星期在可见列表里的下标`。原来这套算式散在 `timetable_screen.dart` 的
/// `_dayViewPageIndexForDay` / `_dayViewTargetForPage` / `_resolveStoredDayOfWeek`
/// 三处，其中页号那处写的是
///
/// ```dart
/// final dayIndex = math.max(0, visibleDays.indexOf(dayOfWeek));
/// ```
///
/// 越界星期（例如开着「隐藏周末」时选中日还是 6/7）`indexOf` 返回 -1，被
/// `math.max` 静默折成 0，也就是**周一那一页**。页面本身没崩，但它只修了页号，
/// 没修"选中日"这份状态，于是同一帧里三处读到的值互相矛盾：
/// - 内容已经是周一，`_isSelectedDay` 却拿 6/7 去比可见的 5 格 → 表头一格都不亮；
/// - `_weekday-header-*` 的高亮下划线停在周一，与"没有任何一天被选中"的表头并存；
/// - `_addCourseInitialDayOfWeek` 继续把周六预填进「添加课程」，存下来的课在
///   5 列周视图里根本不显示（用户视角是"我加的课不见了"）。
///
/// 所以这里把两件事收成一个显式口径：**先归一星期，再算页号**，并且让"页号 →
/// 星期"与"星期 → 页号"严格互逆（下面 `dayViewTargetForGlobalPage` 与
/// `dayViewGlobalPage` 的往返不变量）。归一的回落值（第一个可见日）与
/// `_resolveStoredDayOfWeek` 恢复"上次浏览日"时用的口径保持一致，避免出现第三种答案。
library;

/// 把一个可能越界的星期归一到 [visibleDays] 内。
///
/// 已在列表里就原样返回；不在就回落到第一个可见日（与"恢复上次浏览日"的既有
/// 口径相同）。[visibleDays] 为空（不该发生）时原样返回，交调用方自己判。
int normalizeDayOfWeekForVisibleDays(
  List<int> visibleDays,
  int dayOfWeek,
) {
  if (visibleDays.isEmpty || visibleDays.contains(dayOfWeek)) {
    return dayOfWeek;
  }
  return visibleDays.first;
}

/// 星期 → 全局页号。越界星期先归一再算，因此结果永远落在
/// `[0, week 数 * visibleDays.length)` 内，且**与 [dayViewTargetForGlobalPage] 互逆**。
int dayViewGlobalPage({
  required List<int> visibleDays,
  required int week,
  required int dayOfWeek,
}) {
  final normalized = normalizeDayOfWeekForVisibleDays(visibleDays, dayOfWeek);
  return (week - 1) * visibleDays.length + visibleDays.indexOf(normalized);
}

/// 全局页号 → （周次, 星期），[dayViewGlobalPage] 的逆。
///
/// 返回 `null` 表示可见星期表为空、页号无意义。
(int week, int dayOfWeek)? dayViewTargetForGlobalPage(
  List<int> visibleDays,
  int page,
) {
  if (visibleDays.isEmpty) {
    return null;
  }
  final count = visibleDays.length;
  return (page ~/ count + 1, visibleDays[page % count]);
}
