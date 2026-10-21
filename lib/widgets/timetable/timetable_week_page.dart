import 'package:flutter/material.dart';

import '../../domain/timetable_layout.dart';
import '../../models/timetable_settings.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/home_page_region_blur.dart';
import 'timetable_weekday_header.dart';

/// 周 pager 里的一页（2026-10-19 从课表页 State 搬出）。
///
/// 负责星期栏底色/玻璃、网格 body 的背景层与周页 key；网格和 body 滚动壳由
/// `buildGrid` / `buildBody` 回调注入（它们仍持有课表 State 的网格/滚动状态）。
class TimetableWeekPage extends StatelessWidget {
  final TimetableSettings settings;
  final int week;
  final double availableHeight;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayLuminance;
  final PageController? dayViewPageController;
  final bool isDayView;
  final int? visibleDayViewWeek;
  final bool shouldShowDayViewOverlay;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final bool Function(DateTime date) hasExamOnDate;
  final bool Function(DateTime date) hasScheduleOnDate;
  final VoidCallback onShowWeekSelector;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(int week, int dayOfWeek) onDayTap;
  final double timeColumnWidth;
  final Widget Function(double sectionHeight) buildGrid;
  final Widget Function(Widget grid) buildBody;

  const TimetableWeekPage({
    super.key,
    required this.settings,
    required this.week,
    required this.availableHeight,
    required this.wallpaperTopLuminance,
    required this.wallpaperWeekdayLuminance,
    required this.dayViewPageController,
    required this.isDayView,
    required this.visibleDayViewWeek,
    required this.shouldShowDayViewOverlay,
    required this.isSelectedDay,
    required this.hasExamOnDate,
    required this.hasScheduleOnDate,
    required this.onShowWeekSelector,
    required this.onDayTapDown,
    required this.onDayTap,
    required this.timeColumnWidth,
    required this.buildGrid,
    required this.buildBody,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    // Day view keeps the same weekday chrome as the week view: the panel below
    // now shows the wallpaper, so an opaque non-blurred bar would read as a
    // seam across the top of the glass.
    final weekdayChromeBlurEnabled =
        hasBackdrop && settings.homePageWeekdayBarBlurEnabled;
    final chromeGridClearance = weekdayChromeBlurEnabled
        ? homePageFrostedRegionSeamOverlap
        : 0.0;
    // 自适应节高按完整可用高度计算：玻璃坞满屏悬浮下网格延伸到药丸
    // 底下（层次感）；被遮住的最后几节由 body 的滚动余量救回——上滑把整段
    // 课表完全滑出到药丸上方，下滑再让药丸盖回。
    // 节高的唯一事实来源（`domain/timetable_layout.dart`）：转场算「卡片从哪个
    // 格子起飞」用的是同一份，两边不会漂。
    final sectionHeight = gridSectionHeight(
      settings: settings,
      availableHeight: availableHeight,
      weekdayHeaderHeight: TimetableWeekdayHeader.height,
      chromeSeam: chromeGridClearance,
    );
    final grid = buildGrid(sectionHeight);
    final weekdayShowsBackdrop = homePageRegionShowsBackdrop(
      settings,
      HomePageBackgroundScope.weekdayBar,
    );
    final pageChromeFallback = Theme.of(context).colorScheme.surface;
    // Keep the week slot at a fixed height while the day overlay owns the
    // visible header, avoiding duplicate weekday bars during the transition.
    final weekdayHeader = SizedBox(
      height: TimetableWeekdayHeader.height,
      child: shouldShowDayViewOverlay
          ? const SizedBox.shrink()
          : homePageBackgroundLayer(
              visual: homePageRegionChromeVisual(
                settings: settings,
                isDark: isDark,
                darkFallback: pageChromeFallback,
                region: HomePageBackgroundScope.weekdayBar,
                chromeBlurEnabled: weekdayChromeBlurEnabled,
              ),
              child: TimetableWeekdayHeader(
                settings: settings,
                week: week,
                timeColumnWidth: timeColumnWidth,
                hideBottomBorder:
                    weekdayShowsBackdrop || weekdayChromeBlurEnabled,
                wallpaperTopLuminance: wallpaperTopLuminance,
                wallpaperWeekdayLuminance: wallpaperWeekdayLuminance,
                pageController: dayViewPageController,
                isDayView: isDayView,
                visibleDayViewWeek: visibleDayViewWeek,
                shouldShowOverlay: shouldShowDayViewOverlay,
                isSelectedDay: isSelectedDay,
                hasExamOnDate: hasExamOnDate,
                hasScheduleOnDate: hasScheduleOnDate,
                onShowWeekSelector: onShowWeekSelector,
                onDayTapDown: onDayTapDown,
                onDayTap: onDayTap,
              ),
            ),
    );

    return KeyedSubtree(
      key: ValueKey('week-page-$week'),
      child: Column(
        children: [
          weekdayHeader,
          // Original chrome↔grid clearance (same token as frosted seam overlap).
          // Keeps gaussian cards from sitting flush on the first course row.
          if (weekdayChromeBlurEnabled)
            const SizedBox(height: homePageFrostedRegionSeamOverlap),
          Expanded(
            child: homePageBackgroundLayer(
              visual: resolveHomePageRegionBackground(
                settings: settings,
                isDark: isDark,
                darkFallback: Theme.of(context).colorScheme.surface,
                region: HomePageBackgroundScope.timetable,
              ),
              child: buildBody(grid),
            ),
          ),
        ],
      ),
    );
  }
}
