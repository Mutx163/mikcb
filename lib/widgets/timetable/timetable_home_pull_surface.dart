import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import 'timetable_home_scroll.dart';
import 'timetable_week_pager.dart';

/// 首页周课表的滚动/下拉快捷导入承载面（2026-10-19 从课表页 State 搬出）。
///
/// 负责 ScrollConfiguration、顶部下拉手势层（自适应网格用原始指针、可滚动网格
/// 用 Overscroll 通知）与内部 `TimetableWeekPager` 的装配；下拉进度、冻结标志、
/// 触发/取消与日视图翻页仍全部由 State 回调注入。
class TimetableHomePullSurface extends StatelessWidget {
  final TimetableSettings settings;
  final bool hasBackdrop;
  final GlobalKey timetableSurfaceKey;
  final bool isRunning;
  final bool isDayView;
  final double glassDockContentScrollInset;
  final bool Function(ScrollNotification notification) onScrollNotification;
  final ValueChanged<double> onPullUpdate;
  final VoidCallback onPullEnd;
  final VoidCallback onPullCancel;
  final VoidCallback resetFreeze;
  final ValueChanged<PointerMoveEvent> onPointerMove;

  final PageController weekPageController;
  final PageController? dayViewPageController;
  final int? visibleDayViewWeek;
  final bool shouldShowDayViewOverlay;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayLuminance;
  final double timeColumnWidth;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final bool Function(DateTime date) hasExamOnDate;
  final bool Function(DateTime date) hasScheduleOnDate;
  final VoidCallback onShowWeekSelector;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(int week, int dayOfWeek) onDayTap;
  final VoidCallback onFinalizeWeekPageSettled;
  final ValueChanged<int> onHandleWeekPageChanged;
  final Widget Function(int week, double width, double height) buildWeekPage;
  final Widget Function(int week) buildAnchoredDayViewOverlay;
  final void Function(TimetableSettings settings, DragStartDetails details)
  onWeekdayBarDragStart;
  final ValueChanged<DragUpdateDetails> onWeekdayBarDragUpdate;
  final ValueChanged<DragEndDetails> onWeekdayBarDragEnd;
  final VoidCallback onWeekdayBarDragCancel;

  const TimetableHomePullSurface({
    super.key,
    required this.settings,
    required this.hasBackdrop,
    required this.timetableSurfaceKey,
    required this.isRunning,
    required this.isDayView,
    required this.glassDockContentScrollInset,
    required this.onScrollNotification,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
    required this.resetFreeze,
    required this.onPointerMove,
    required this.weekPageController,
    required this.dayViewPageController,
    required this.visibleDayViewWeek,
    required this.shouldShowDayViewOverlay,
    required this.wallpaperTopLuminance,
    required this.wallpaperWeekdayLuminance,
    required this.timeColumnWidth,
    required this.isSelectedDay,
    required this.hasExamOnDate,
    required this.hasScheduleOnDate,
    required this.onShowWeekSelector,
    required this.onDayTapDown,
    required this.onDayTap,
    required this.onFinalizeWeekPageSettled,
    required this.onHandleWeekPageChanged,
    required this.buildWeekPage,
    required this.buildAnchoredDayViewOverlay,
    required this.onWeekdayBarDragStart,
    required this.onWeekdayBarDragUpdate,
    required this.onWeekdayBarDragEnd,
    required this.onWeekdayBarDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Home timetable only: no HyperOS rubber-band. Other pages keep
    // [HyperosScrollBehavior] from [HyperosRootPage].
    Widget surface = ScrollConfiguration(
      behavior: const TimetableHomeScrollBehavior(),
      child: Padding(
        key: timetableSurfaceKey,
        padding: EdgeInsets.only(bottom: hasBackdrop ? 0 : 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return TimetableWeekPager(
              settings: settings,
              weekPageController: weekPageController,
              dayViewPageController: dayViewPageController,
              visibleDayViewWeek: visibleDayViewWeek,
              isDayView: isDayView,
              shouldShowDayViewOverlay: shouldShowDayViewOverlay,
              wallpaperTopLuminance: wallpaperTopLuminance,
              wallpaperWeekdayLuminance: wallpaperWeekdayLuminance,
              timeColumnWidth: timeColumnWidth,
              isSelectedDay: isSelectedDay,
              hasExamOnDate: hasExamOnDate,
              hasScheduleOnDate: hasScheduleOnDate,
              onShowWeekSelector: onShowWeekSelector,
              onDayTapDown: onDayTapDown,
              onDayTap: onDayTap,
              onFinalizeWeekPageSettled: onFinalizeWeekPageSettled,
              onHandleWeekPageChanged: onHandleWeekPageChanged,
              buildWeekPage: (week) => buildWeekPage(
                week,
                constraints.maxWidth,
                constraints.maxHeight,
              ),
              buildAnchoredDayViewOverlay: buildAnchoredDayViewOverlay,
              onWeekdayBarDragStart: onWeekdayBarDragStart,
              onWeekdayBarDragUpdate: onWeekdayBarDragUpdate,
              onWeekdayBarDragEnd: onWeekdayBarDragEnd,
              onWeekdayBarDragCancel: onWeekdayBarDragCancel,
            );
          },
        ),
      ),
    );

    if (!settings.homePullQuickImportEnabled) {
      return surface;
    }

    // Prefer scroll overscroll (clamping) so left/right week paging stays free.
    surface = NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification,
      child: surface,
    );

    // Auto-fit week grid has no vertical Scrollable; use a vertical-only drag
    // that does not claim the arena until the gesture is clearly vertical.
    //
    // 玻璃坞形态会给周课表注入底部滚动余量（inset > 0），网格变成可滚动的
    // SingleChildScrollView——此时若仍挂原始拖拽探测器，任何竖向下拉都会不计
    // 滚动位置地累计下拉进度，「还没滑动到顶部」就打开下拉 → 提前触发快捷导入。
    // 有余量的场景统一交给上方的 NotificationListener / OverscrollNotification
    // （自带 atTop 位置判定 + 手势起点是否在顶部的判定）。
    // 两种驱动二选一，避免同一段手指位移被计两次：
    // - 无纵向滚动体（自适应周课表 + 经典形态）：探测器自己看原始指针；
    // - 有纵向滚动体：打开仍由 Overscroll 通知驱动，一旦打开，纵向滚动被
    //   [TimetableHomePullFreezeScrollPhysics] 冻住，改由原始指针收放。
    if (settings.timetableAutoFitSectionHeight &&
        !isDayView &&
        glassDockContentScrollInset <= 0) {
      surface = TimetableHomePullVerticalDragDetector(
        enabled: !isRunning,
        onPullUpdate: onPullUpdate,
        onPullEnd: onPullEnd,
        onPullCancel: onPullCancel,
        child: surface,
      );
    } else {
      surface = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => resetFreeze(),
        onPointerUp: (_) => resetFreeze(),
        onPointerCancel: (_) => resetFreeze(),
        onPointerMove: onPointerMove,
        child: surface,
      );
    }

    return surface;
  }
}
