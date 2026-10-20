import 'package:flutter/material.dart';

import '../../controllers/empty_slot_marker_controller.dart';
import '../../domain/day_course_display_logic.dart';
import '../../l10n/app_localizations.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/home/home_chrome_spec.dart';
import 'package:flutter/foundation.dart';

import '../course_weather_display.dart';
import 'timetable_back_to_current_week_button.dart';
import 'timetable_back_to_today_button.dart';
import 'timetable_week_grid.dart';
import 'timetable_home_pull_surface.dart';
import 'timetable_home_stack.dart';
import 'timetable_week_grid_builder.dart';
import 'timetable_week_page.dart';

/// 首页栈的参数宿主（2026-10-20 从 `TimetableScreen._buildHomeStackView` 搬出）。
///
/// 全部字段都是数据/回调，builder 不 import 屏幕或 part。
class TimetableHomeStackHost {
  final TimetableProvider provider;
  final TimetableSettings settings;
  final AppLocalizations l10n;
  final HomeChromeSpec chrome;
  final Color chromeForeground;
  final Color chromeMutedForeground;
  final bool hasBackdrop;
  final bool glassDockForm;
  final PageController weekPageController;
  final Widget title;
  final List<Widget> suffixes;
  final GlobalKey timetableSurfaceKey;
  final bool isPullRunning;
  final double pullDragDistance;
  final double pullTriggerDistance;
  final bool isDayView;
  final double glassDockContentScrollInset;
  final bool Function(ScrollNotification notification) onScrollNotification;
  final ValueChanged<double> onPullUpdate;
  final VoidCallback onPullEnd;
  final VoidCallback onPullCancel;
  final VoidCallback resetFreeze;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final PageController? dayViewPageController;
  final int? visibleDayViewWeek;
  final bool shouldShowDayViewOverlay;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayLuminance;
  final double? wallpaperBodyLuminance;
  final double timeColumnWidth;
  final List<int> visibleDays;
  final double cardInset;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final bool Function(DateTime date) hasExamOnDate;
  final VoidCallback onShowWeekSelector;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(int week, int dayOfWeek) onDayTap;
  final VoidCallback onFinalizeWeekPageSettled;
  final ValueChanged<int> onHandleWeekPageChanged;
  final EmptySlotMarkerController emptySlot;
  final TimetableCoursesForDay coursesForDay;
  final TimetableBuildDisplayItems buildDisplayItems;
  final TimetableWrapSurfaceHost wrapSurfaceHost;
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
    int week,
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
  final Widget Function(
    TimetableSettings settings,
    int week,
    Widget grid,
  )
  buildBody;
  final Widget Function(int week) buildAnchoredOverlay;
  final void Function(TimetableSettings settings, DragStartDetails details)
  onWeekdayBarDragStart;
  final ValueChanged<DragUpdateDetails> onWeekdayBarDragUpdate;
  final ValueChanged<DragEndDetails> onWeekdayBarDragEnd;
  final VoidCallback onWeekdayBarDragCancel;
  final ValueListenable<int> visibleWeekListenable;
  final bool Function(TimetableProvider provider, TimetableSettings settings, int visibleWeek)
  shouldShowBackToCurrentWeek;
  final VoidCallback onJumpToCurrentWeek;
  final double glassDockPillOccupancy;
  final ValueListenable<(int, int)?> dayHeaderPreview;
  final bool Function(TimetableProvider provider) shouldShowBackToToday;
  final double Function(TimetableSettings settings) backToTodayBottomInset;
  final VoidCallback onNavigateToday;

  const TimetableHomeStackHost({
    required this.provider,
    required this.settings,
    required this.l10n,
    required this.chrome,
    required this.chromeForeground,
    required this.chromeMutedForeground,
    required this.hasBackdrop,
    required this.glassDockForm,
    required this.weekPageController,
    required this.title,
    required this.suffixes,
    required this.timetableSurfaceKey,
    required this.isPullRunning,
    required this.pullDragDistance,
    required this.pullTriggerDistance,
    required this.isDayView,
    required this.glassDockContentScrollInset,
    required this.onScrollNotification,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
    required this.resetFreeze,
    required this.onPointerMove,
    required this.dayViewPageController,
    required this.visibleDayViewWeek,
    required this.shouldShowDayViewOverlay,
    required this.wallpaperTopLuminance,
    required this.wallpaperWeekdayLuminance,
    required this.wallpaperBodyLuminance,
    required this.timeColumnWidth,
    required this.visibleDays,
    required this.cardInset,
    required this.isSelectedDay,
    required this.hasExamOnDate,
    required this.onShowWeekSelector,
    required this.onDayTapDown,
    required this.onDayTap,
    required this.onFinalizeWeekPageSettled,
    required this.onHandleWeekPageChanged,
    required this.emptySlot,
    required this.coursesForDay,
    required this.buildDisplayItems,
    required this.wrapSurfaceHost,
    required this.dateForWeekDay,
    required this.startingAt,
    required this.resolveColor,
    required this.overline,
    required this.badge,
    required this.weather,
    required this.showActions,
    required this.onOpenAddCourse,
    required this.buildBody,
    required this.buildAnchoredOverlay,
    required this.onWeekdayBarDragStart,
    required this.onWeekdayBarDragUpdate,
    required this.onWeekdayBarDragEnd,
    required this.onWeekdayBarDragCancel,
    required this.visibleWeekListenable,
    required this.shouldShowBackToCurrentWeek,
    required this.onJumpToCurrentWeek,
    required this.glassDockPillOccupancy,
    required this.dayHeaderPreview,
    required this.shouldShowBackToToday,
    required this.backToTodayBottomInset,
    required this.onNavigateToday,
  });
}

class TimetableHomeStackBuilder extends StatelessWidget {
  final TimetableHomeStackHost host;

  const TimetableHomeStackBuilder({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    return TimetableHomeStack(
      settings: host.settings,
      l10n: host.l10n,
      chrome: host.chrome,
      weekPageController: host.weekPageController,
      title: host.title,
      suffixes: host.suffixes,
      weekSurface: TimetableHomePullSurface(
        settings: host.settings,
        hasBackdrop: host.hasBackdrop,
        timetableSurfaceKey: host.timetableSurfaceKey,
        isRunning: host.isPullRunning,
        isDayView: host.isDayView,
        glassDockContentScrollInset: host.glassDockContentScrollInset,
        onScrollNotification: host.onScrollNotification,
        onPullUpdate: host.onPullUpdate,
        onPullEnd: host.onPullEnd,
        onPullCancel: host.onPullCancel,
        resetFreeze: host.resetFreeze,
        onPointerMove: host.onPointerMove,
        weekPageController: host.weekPageController,
        dayViewPageController: host.dayViewPageController,
        visibleDayViewWeek: host.visibleDayViewWeek,
        shouldShowDayViewOverlay: host.shouldShowDayViewOverlay,
        wallpaperTopLuminance: host.wallpaperTopLuminance,
        wallpaperWeekdayLuminance: host.wallpaperWeekdayLuminance,
        timeColumnWidth: host.timeColumnWidth,
        isSelectedDay: host.isSelectedDay,
        hasExamOnDate: host.hasExamOnDate,
        onShowWeekSelector: host.onShowWeekSelector,
        onDayTapDown: host.onDayTapDown,
        onDayTap: host.onDayTap,
        onFinalizeWeekPageSettled: host.onFinalizeWeekPageSettled,
        onHandleWeekPageChanged: host.onHandleWeekPageChanged,
        buildWeekPage: (week, width, height) => TimetableWeekPage(
          settings: host.settings,
          week: week,
          availableHeight: height,
          wallpaperTopLuminance: host.wallpaperTopLuminance,
          wallpaperWeekdayLuminance: host.wallpaperWeekdayLuminance,
          dayViewPageController: host.dayViewPageController,
          isDayView: host.isDayView,
          visibleDayViewWeek: host.visibleDayViewWeek,
          shouldShowDayViewOverlay: host.shouldShowDayViewOverlay,
          isSelectedDay: host.isSelectedDay,
          hasExamOnDate: host.hasExamOnDate,
          onShowWeekSelector: host.onShowWeekSelector,
          onDayTapDown: host.onDayTapDown,
          onDayTap: host.onDayTap,
          timeColumnWidth: host.timeColumnWidth,
          buildGrid: (sectionHeight) => TimetableWeekGridBuilder(
            provider: host.provider,
            settings: host.settings,
            week: week,
            availableWidth: width,
            sectionHeight: sectionHeight,
            visibleDays: host.visibleDays,
            timeColumnWidth: host.timeColumnWidth,
            cardInset: host.cardInset,
            emptySlot: host.emptySlot,
            wallpaperTopLuminance: host.wallpaperTopLuminance,
            wallpaperBodyLuminance: host.wallpaperBodyLuminance,
            coursesForDay: host.coursesForDay,
            buildDisplayItems: host.buildDisplayItems,
            wrapSurfaceHost: host.wrapSurfaceHost,
            overlayVisible: host.shouldShowDayViewOverlay,
            dateForWeekDay: host.dateForWeekDay,
            startingAt: host.startingAt,
            resolveColor: host.resolveColor,
            overline: host.overline,
            badge: host.badge,
            weather: (item, date) => host.weather(item, date, week),
            showActions: host.showActions,
            onOpenAddCourse: host.onOpenAddCourse,
          ),
          buildBody: (grid) => host.buildBody(host.settings, week, grid),
        ),
        buildAnchoredDayViewOverlay: host.buildAnchoredOverlay,
        onWeekdayBarDragStart: host.onWeekdayBarDragStart,
        onWeekdayBarDragUpdate: host.onWeekdayBarDragUpdate,
        onWeekdayBarDragEnd: host.onWeekdayBarDragEnd,
        onWeekdayBarDragCancel: host.onWeekdayBarDragCancel,
      ),
      isPullRunning: host.isPullRunning,
      pullDragDistance: host.pullDragDistance,
      pullTriggerDistance: host.pullTriggerDistance,
      onPullCancel: host.onPullCancel,
      backToCurrentWeek: ValueListenableBuilder<int>(
        valueListenable: host.visibleWeekListenable,
        builder: (context, visibleWeek, child) {
          if (!host.shouldShowBackToCurrentWeek(
            host.provider,
            host.settings,
            visibleWeek,
          )) {
            return const SizedBox.shrink();
          }
          return TimetableBackToCurrentWeekButton(
            settings: host.settings,
            glassDockPillOccupancy: host.glassDockPillOccupancy,
            onJumpToCurrentWeek: host.onJumpToCurrentWeek,
          );
        },
      ),
      backToToday: ValueListenableBuilder<(int, int)?>(
        valueListenable: host.dayHeaderPreview,
        builder: (context, _, _) {
          if (!host.shouldShowBackToToday(host.provider)) {
            return const SizedBox.shrink();
          }
          return TimetableBackToTodayButton(
            bottomInset: host.backToTodayBottomInset(host.settings),
            onTap: host.onNavigateToday,
          );
        },
      ),
      isDayView: host.isDayView,
      glassDockForm: host.glassDockForm,
      isLoading: host.provider.isLoading,
    );
  }
}
