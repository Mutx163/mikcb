import 'package:flutter/material.dart';

import '../../domain/day_course_display_logic.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import 'timetable_day_column.dart';

typedef TimetableBuildSectionTimeCell =
    Widget Function(int index, SectionTime section, TimetableSettings settings);
typedef TimetableWrapSurfaceHost =
    Widget Function({required TimetableSettings settings, required Widget child});
typedef TimetableWrapEmptySlotGesture =
    Widget Function({
      required TimetableSettings settings,
      required int week,
      required double sectionHeight,
      required double dayWidth,
      required List<int> visibleDays,
      required Set<(int, int)> occupiedSections,
      required Widget child,
    });
typedef TimetableCoursesForDay =
    List<Course> Function(
      List<Course> courses,
      int week,
      int dayOfWeek,
      TimetableSettings settings,
    );
typedef TimetableBuildDisplayItems =
    List<DayCourseDisplayItem> Function({
      required TimetableProvider provider,
      required TimetableSettings settings,
      required int week,
      required int dayOfWeek,
      required List<Course> myCourses,
    });

/// 周网格骨架（2026-10-19 从课表页 State 搬出）。
///
/// 时间列、空白手势层、课程覆盖集合与日列位次都在这里；时间格、表面宿主、
/// 空白手势层、课程取数/展示项与日列回调由 State 注入。
class TimetableWeekGrid extends StatelessWidget {
  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final double availableWidth;
  final double sectionHeight;
  final List<int> visibleDays;
  final double timeColumnWidth;
  final double cardInset;
  final TimetableBuildSectionTimeCell buildSectionTimeCell;
  final TimetableWrapSurfaceHost wrapSurfaceHost;
  final TimetableWrapEmptySlotGesture wrapEmptySlotGesture;
  final TimetableCoursesForDay coursesForDay;
  final TimetableBuildDisplayItems buildDisplayItems;
  final TimetableDayColumnCallbacks dayColumnCallbacks;

  const TimetableWeekGrid({
    super.key,
    required this.provider,
    required this.settings,
    required this.week,
    required this.availableWidth,
    required this.sectionHeight,
    required this.visibleDays,
    required this.timeColumnWidth,
    required this.cardInset,
    required this.buildSectionTimeCell,
    required this.wrapSurfaceHost,
    required this.wrapEmptySlotGesture,
    required this.coursesForDay,
    required this.buildDisplayItems,
    required this.dayColumnCallbacks,
  });

  @override
  Widget build(BuildContext context) {
    final dayWidth = (availableWidth - timeColumnWidth) / visibleDays.length;
    // （星期几, 节次）已被课程覆盖的集合，供长按拖动判定空白格。
    final occupiedSections = <(int, int)>{};
    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const ValueKey('timetable-time-column'),
            width: timeColumnWidth,
            // Chrome blur is painted by HomePageContinuousChromeFrostedOverlay.
            child: Column(
              children: List.generate(settings.sectionCount, (index) {
                final section = settings.sections[index];
                return Container(
                  height: sectionHeight,
                  alignment: Alignment.center,
                  child: buildSectionTimeCell(index + 1, section, settings),
                );
              }),
            ),
          ),
          wrapSurfaceHost(
            settings: settings,
            child: wrapEmptySlotGesture(
              settings: settings,
              week: week,
              sectionHeight: sectionHeight,
              dayWidth: dayWidth,
              visibleDays: visibleDays,
              occupiedSections: occupiedSections,
              child: Row(
                children: visibleDays.asMap().entries.map((entry) {
                  final dayIndex = entry.key;
                  final dayOfWeek = entry.value;
                  final dayCourses = coursesForDay(
                    provider.courses,
                    week,
                    dayOfWeek,
                    settings,
                  );
                  final displayItems = buildDisplayItems(
                    provider: provider,
                    settings: settings,
                    week: week,
                    dayOfWeek: dayOfWeek,
                    myCourses: dayCourses,
                  );
                  // 长按拖动换格时判定"某格是否空白"的事实来源：课程覆盖
                  // 的（星期×节次）全集。此处在本 build 内即刻求值。
                  for (final item in displayItems) {
                    for (
                      var s = item.course.startSection;
                      s <= item.course.endSection;
                      s++
                    ) {
                      occupiedSections.add((dayOfWeek, s));
                    }
                  }
                  return SizedBox(
                    width: dayWidth,
                    child: TimetableDayColumn(
                      week: week,
                      dayOfWeek: dayOfWeek,
                      displayItems: displayItems,
                      settings: settings,
                      showConflictBadge:
                          settings.showConflictBadgeOnTimetable,
                      sectionHeight: sectionHeight,
                      cardInset: cardInset,
                      provider: provider,
                      dayIndex: dayIndex,
                      dayCount: visibleDays.length,
                      occupiedSections: occupiedSections,
                      callbacks: dayColumnCallbacks,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
