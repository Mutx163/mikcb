import 'package:flutter/material.dart';

import '../../controllers/empty_slot_marker_controller.dart';
import '../../domain/day_course_display_logic.dart';
import '../../models/course.dart';
import '../course_weather_display.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import 'timetable_day_column.dart';
import 'timetable_empty_slot_layer.dart';
import 'timetable_section_time_cell.dart';
import 'timetable_week_grid.dart';

/// 周页里「某一周的网格」装配（2026-10-20 从课表页 `_buildHomeStackView`
/// 的 buildGrid 闭包搬出）。
///
/// 只做网格参数/日列回调的组装；课程取数、展示项、空槽、天气与动作仍由屏幕
/// 注入回调。
class TimetableWeekGridBuilder extends StatelessWidget {
  final TimetableProvider provider;
  final TimetableSettings settings;
  final int week;
  final double availableWidth;
  final double sectionHeight;
  final List<int> visibleDays;
  final double timeColumnWidth;
  final double cardInset;
  final EmptySlotMarkerController emptySlot;
  final double? wallpaperTopLuminance;
  final double? wallpaperBodyLuminance;
  final TimetableCoursesForDay coursesForDay;
  final TimetableBuildDisplayItems buildDisplayItems;
  final TimetableWrapSurfaceHost wrapSurfaceHost;
  final bool overlayVisible;
  final DateTime? Function(TimetableSettings settings, int week, int dayOfWeek)
  dateForWeekDay;
  final List<DayCourseDisplayItem> Function(
    List<DayCourseDisplayItem> items,
    int section,
  )
  startingAt;
  final String? Function(
    DayCourseDisplayItem item, {
    required TimetableSettings settings,
  })
  resolveColor;
  final String? Function(DayCourseDisplayItem item, bool showConflictBadge)
  overline;
  final String? Function(DayCourseDisplayItem item, bool showConflictBadge) badge;
  final CourseWeatherDisplay? Function(
    DayCourseDisplayItem item,
    DateTime? date,
  )
  weather;
  final void Function(
    Course course,
    int week, {
    DayCourseDisplayItem? displayItem,
  })
  showActions;
  final void Function(int week, int dayOfWeek, int startSection, int endSection)
  onOpenAddCourse;

  const TimetableWeekGridBuilder({
    super.key,
    required this.provider,
    required this.settings,
    required this.week,
    required this.availableWidth,
    required this.sectionHeight,
    required this.visibleDays,
    required this.timeColumnWidth,
    required this.cardInset,
    required this.emptySlot,
    required this.wallpaperTopLuminance,
    required this.wallpaperBodyLuminance,
    required this.coursesForDay,
    required this.buildDisplayItems,
    required this.wrapSurfaceHost,
    required this.overlayVisible,
    required this.dateForWeekDay,
    required this.startingAt,
    required this.resolveColor,
    required this.overline,
    required this.badge,
    required this.weather,
    required this.showActions,
    required this.onOpenAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    final dayColumnCallbacks = TimetableDayColumnCallbacks(
      dateForWeekDay: dateForWeekDay,
      markerSpanAt: emptySlot.spanAt,
      markerSection: () => emptySlot.section,
      buildEmptySlotCell:
          (
            week,
            dayOfWeek,
            startSection,
            sectionHeight,
            cardInset,
            settings, {
            required span,
            required occupiedSections,
          }) => TimetableEmptySlotCell(
            controller: emptySlot,
            week: week,
            dayOfWeek: dayOfWeek,
            startSection: startSection,
            sectionHeight: sectionHeight,
            cardInset: cardInset,
            settings: settings,
            span: span,
            occupiedSections: occupiedSections,
            wallpaperLuminance: wallpaperBodyLuminance ?? wallpaperTopLuminance,
            onOpenAddCourse: () =>
                onOpenAddCourse(week, dayOfWeek, startSection, startSection + span - 1),
          ),
      startingAt: startingAt,
      resolveColor: resolveColor,
      overline: overline,
      badge: badge,
      weather: weather,
      clearMarker: emptySlot.clear,
      showActions: showActions,
      border: groupedDayColumnBorderRadius,
      wallpaperBodyLuminance: () => wallpaperBodyLuminance,
      wallpaperTopLuminance: () => wallpaperTopLuminance,
    );
    return TimetableWeekGrid(
      provider: provider,
      settings: settings,
      week: week,
      availableWidth: availableWidth,
      sectionHeight: sectionHeight,
      visibleDays: visibleDays,
      timeColumnWidth: timeColumnWidth,
      cardInset: cardInset,
      buildSectionTimeCell: (index, section, settings) =>
          TimetableSectionTimeCell(
            sectionNumber: index,
            section: section,
            settings: settings,
            wallpaperLuminance: wallpaperBodyLuminance ?? wallpaperTopLuminance,
          ),
      wrapSurfaceHost: wrapSurfaceHost,
      wrapEmptySlotGesture:
          ({
            required settings,
            required week,
            required sectionHeight,
            required dayWidth,
            required visibleDays,
            required occupiedSections,
            required child,
          }) => TimetableEmptySlotGestureArea(
            controller: emptySlot,
            settings: settings,
            week: week,
            sectionHeight: sectionHeight,
            dayWidth: dayWidth,
            visibleDays: visibleDays,
            occupiedSections: occupiedSections,
            overlayVisible: overlayVisible,
            child: child,
          ),
      coursesForDay: coursesForDay,
      buildDisplayItems: buildDisplayItems,
      dayColumnCallbacks: dayColumnCallbacks,
    );
  }
}
