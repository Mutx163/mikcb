import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import '../../widgets/preblurred_wallpaper_glass.dart';
import 'timetable_weekday_header.dart';

/// 首页周 pager 与其上的日视图覆盖层（2026-10-19 从课表页 State 搬出）。
///
/// 页面内容、锚点展开面板、周次切换与手势收尾全部由回调注入；组件只负责
/// PageView/RepaintBoundary/星期栏/scrubber 的位次。`buildWeekPage` 与
/// `buildAnchoredDayViewOverlay` 仍由 State 构造（它们持有网格/动画状态）。
class TimetableWeekPager extends StatelessWidget {
  final TimetableSettings settings;
  final PageController weekPageController;
  final PageController? dayViewPageController;
  final int? visibleDayViewWeek;
  final bool isDayView;
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
  final Widget Function(int week) buildWeekPage;
  final Widget Function(int week) buildAnchoredDayViewOverlay;
  final void Function(TimetableSettings settings, DragStartDetails details)
  onWeekdayBarDragStart;
  final ValueChanged<DragUpdateDetails> onWeekdayBarDragUpdate;
  final ValueChanged<DragEndDetails> onWeekdayBarDragEnd;
  final VoidCallback onWeekdayBarDragCancel;

  const TimetableWeekPager({
    super.key,
    required this.settings,
    required this.weekPageController,
    required this.dayViewPageController,
    required this.visibleDayViewWeek,
    required this.isDayView,
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
    final visibleWeek = visibleDayViewWeek;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.horizontal) {
              if (notification is ScrollEndNotification) {
                onFinalizeWeekPageSettled();
              }
            }
            return false;
          },
          child: PageView.builder(
            controller: weekPageController,
            itemCount: settings.semesterWeekCount,
            allowImplicitScrolling: true,
            physics: isDayView
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(parent: ClampingScrollPhysics()),
            onPageChanged: onHandleWeekPageChanged,
            itemBuilder: (context, index) {
              final week = index + 1;
              return RepaintBoundary(
                // Lets card glass fills align to the wallpaper instance that
                // slides with this page (see PreblurredWallpaperAlignedFill).
                child: PreblurredWallpaperPage(
                  pageIndex: index,
                  child: buildWeekPage(week),
                ),
              );
            },
          ),
        ),
        if (shouldShowDayViewOverlay && visibleWeek != null)
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 日视图自己的星期信息栏（scrubber 视觉由外部手势层覆盖）。
                TimetableWeekdayHeader(
                  settings: settings,
                  week: visibleWeek,
                  timeColumnWidth: timeColumnWidth,
                  hideBottomBorder: true,
                  wallpaperTopLuminance: wallpaperTopLuminance,
                  wallpaperWeekdayLuminance: wallpaperWeekdayLuminance,
                  pageController: dayViewPageController,
                  isDayView: isDayView,
                  visibleDayViewWeek: visibleWeek,
                  shouldShowOverlay: shouldShowDayViewOverlay,
                  isSelectedDay: isSelectedDay,
                  hasExamOnDate: hasExamOnDate,
                  hasScheduleOnDate: hasScheduleOnDate,
                  onShowWeekSelector: onShowWeekSelector,
                  onDayTapDown: onDayTapDown,
                  onDayTap: onDayTap,
                ),
                Expanded(
                  child: buildAnchoredDayViewOverlay(visibleWeek),
                ),
              ],
            ),
          ),
        // Swipeable weekday bar: when day view is open, the bar is a
        // follow-finger scrubber over the day pager — drags are amplified by
        // the visible-day count and injected into the pager position, so one
        // bar-width sweep flies the content across the whole week.
        if (shouldShowDayViewOverlay && visibleWeek != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: TimetableWeekdayHeader.height,
            child: GestureDetector(
              key: const ValueKey('day-view-weekday-bar-swipe-area'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) =>
                  onWeekdayBarDragStart(settings, details),
              onHorizontalDragUpdate: onWeekdayBarDragUpdate,
              onHorizontalDragEnd: onWeekdayBarDragEnd,
              onHorizontalDragCancel: onWeekdayBarDragCancel,
            ),
          ),
      ],
    );
  }
}
