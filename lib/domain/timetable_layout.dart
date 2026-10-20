import '../models/timetable_settings.dart';

/// 课表页的纯布局计算（2026-10-20 从 `TimetableScreen` State 搬出）。
///
/// 只读 settings，不碰 UI/状态；主文件与 part 都可以直接调用。
List<int> visibleDayNumbers(TimetableSettings settings) {
  return settings.timetableHideWeekends
      ? const [1, 2, 3, 4, 5]
      : const [1, 2, 3, 4, 5, 6, 7];
}

double timeColumnWidth(TimetableSettings settings) {
  return switch (settings.timetableTimeColumnWidthMode) {
    TimetableTimeColumnWidthMode.narrow => 34,
    TimetableTimeColumnWidthMode.wide => 40,
  };
}

double courseCardInset(TimetableSettings settings) {
  return settings.timetableCourseCardGap.clamp(0.0, 3.0);
}

int clampWeek(int week, int maxWeek) {
  if (week < 1) return 1;
  if (week > maxWeek) return maxWeek;
  return week;
}
