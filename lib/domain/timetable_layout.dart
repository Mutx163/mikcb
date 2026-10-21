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

/// 网格里每一节的渲染高度（2026-10-21 抽出，供周网格与「卡片飞行」共用）。
///
/// **这是节高的唯一事实来源**：转场要算「某节课在网格里占哪个矩形」，必须与
/// 网格自己算的一致，否则卡片会从错误的位置起飞。两边各写一份公式的话，
/// 只要改一处设置（自适应开关、玻璃坞形态变化带来的缝隙）就会漂。
///
/// - [availableHeight]：课表内容区可用高（不含顶栏）；
/// - [weekdayHeaderHeight]：星期栏高度；
/// - [chromeSeam]：星期栏与网格之间的玻璃缝隙（无玻璃时为 0）。
double gridSectionHeight({
  required TimetableSettings settings,
  required double availableHeight,
  required double weekdayHeaderHeight,
  double chromeSeam = 0,
}) {
  if (!settings.timetableAutoFitSectionHeight || settings.sectionCount <= 0) {
    return settings.sectionHeight;
  }
  final bodyHeight = (availableHeight - weekdayHeaderHeight - chromeSeam)
      .clamp(0.0, double.infinity);
  return bodyHeight / settings.sectionCount;
}
