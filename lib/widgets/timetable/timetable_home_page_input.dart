import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/day_view_transition_controller.dart';
import '../../controllers/empty_slot_marker_controller.dart';
import '../../controllers/home_menu_controller.dart';
import '../../controllers/home_pull_controller.dart';
import '../../controllers/wallpaper_luminance_controller.dart';
import '../../controllers/week_pager_controller.dart';
import '../../domain/day_course_display_logic.dart';
import '../../l10n/app_localizations.dart';
import '../../models/course.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurfaceState;
import 'timetable_week_grid.dart';
import 'weekday_ink_contrast_guard.dart';


/// 课表首页每帧构建所需的宿主端口（2026-10-20 从 `timetable_screen.dart` 的
/// `build()` / `_buildHomeStackView` / `_buildDockShell` 三处搬出）。
///
/// 这里只收「数据 + 控制器 + 回调」：不 import `screens/`、也不读
/// [TimetableProvider]（provider 是参数），把组装逻辑与 State 解耦成可单测的
/// 组合根。真正持有状态的仍是页面 State，本类只在一帧内有效。
class TimetableHomePageInput {
  final BuildContext context;
  final TimetableProvider provider;
  final TimetableSettings settings;
  final AppLocalizations l10n;
  final bool Function() isMounted;

  final WeekPagerController weekPager;
  final DayViewTransitionController dayViewTransition;
  final HomePullController homePull;
  final EmptySlotMarkerController emptySlot;
  final WallpaperLuminanceController luminance;
  final WeekdayInkContrastGuard weekdayInkGuard;
  final HomeMenuController homeMenu;
  final AnimationController dayViewExpandAnimation;

  final ScrollPhysics homePullVerticalPhysics;
  final ScrollController? Function(String key) previewControllerFor;
  final Widget Function(String key, Widget child) reportHomeScroll;

  final GlobalKey timetableSurfaceKey;
  final GlobalKey topMenuButtonKey;
  final LayerLink moreBallLink;
  final LayerLink heartBallLink;
  final GlobalKey<LiquidGlassSurfaceState> glassDockKey;
  final GlobalKey<LiquidGlassSurfaceState> glassDockRoundKey;
  final Listenable glassDockCardRepaint;

  final String? dockInlinePageId;
  final bool isDayView;
  final bool hasSelectedDay;
  final bool coupleOverlayActive;
  final ValueListenable<(int, int)?> dayHeaderPreview;
  final double glassDockPillOccupancy;
  final double Function(TimetableSettings settings) glassDockContentScrollInset;

  final VoidCallback onToggleCoupleOverlay;
  final void Function(BuildContext hostContext, Rect sourceRect)
  openProfileManagePage;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(
    int week,
    int dayOfWeek,
    int startSection,
    int endSection,
  )
  onOpenAddCourse;
  final Widget Function(int week) buildAnchoredDayViewOverlay;
  final void Function(
    Course course,
    int week, {
    DayCourseDisplayItem? displayItem,
  })
  showCourseActions;

  final TimetableCoursesForDay coursesForDay;
  final TimetableBuildDisplayItems buildDisplayItems;
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

  final void Function(String id, TimetableSettings settings) onDockTap;
  final Widget Function({required Color dotBorderColor}) buildMoreActionIcon;

  final bool Function(
    TimetableProvider provider,
    TimetableSettings settings,
    int visibleWeek,
  )
  shouldShowBackToCurrentWeek;
  final VoidCallback onJumpToCurrentWeek;
  final bool Function(TimetableProvider provider) shouldShowBackToToday;
  final double Function(TimetableSettings settings) backToTodayBottomInset;
  final VoidCallback onNavigateToday;

  const TimetableHomePageInput({
    required this.context,
    required this.provider,
    required this.settings,
    required this.l10n,
    required this.isMounted,
    required this.weekPager,
    required this.dayViewTransition,
    required this.homePull,
    required this.emptySlot,
    required this.luminance,
    required this.weekdayInkGuard,
    required this.homeMenu,
    required this.dayViewExpandAnimation,
    required this.homePullVerticalPhysics,
    required this.previewControllerFor,
    required this.reportHomeScroll,
    required this.timetableSurfaceKey,
    required this.topMenuButtonKey,
    required this.moreBallLink,
    required this.heartBallLink,
    required this.glassDockKey,
    required this.glassDockRoundKey,
    required this.glassDockCardRepaint,
    required this.dockInlinePageId,
    required this.isDayView,
    required this.hasSelectedDay,
    required this.coupleOverlayActive,
    required this.dayHeaderPreview,
    required this.glassDockPillOccupancy,
    required this.glassDockContentScrollInset,
    required this.onToggleCoupleOverlay,
    required this.openProfileManagePage,
    required this.isSelectedDay,
    required this.onDayTapDown,
    required this.onOpenAddCourse,
    required this.buildAnchoredDayViewOverlay,
    required this.showCourseActions,
    required this.coursesForDay,
    required this.buildDisplayItems,
    required this.dateForWeekDay,
    required this.startingAt,
    required this.resolveColor,
    required this.onDockTap,
    required this.buildMoreActionIcon,
    required this.shouldShowBackToCurrentWeek,
    required this.onJumpToCurrentWeek,
    required this.shouldShowBackToToday,
    required this.backToTodayBottomInset,
    required this.onNavigateToday,
  });
}
