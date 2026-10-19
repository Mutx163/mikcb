import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import '../../utils/home_page_background.dart';

/// 星期栏的选中指示条（2026-10-19 从 timetable_screen 的 State 方法搬出）。
///
/// 日视图里跟随翻页器逐帧移动；周视图里每页一份，只在落定页显示。
/// 所有状态都由调用方显式传入，widget 自己不读 provider / State。
class TimetableWeekdaySelectionIndicator extends StatelessWidget {
  const TimetableWeekdaySelectionIndicator({
    super.key,
    required this.settings,
    required this.week,
    required this.visibleDays,
    required this.wallpaperOverChrome,
    required this.wallpaperLuminance,
    required this.pageController,
    required this.isDayView,
    required this.visibleDayViewWeek,
    required this.shouldShowOverlay,
  });

  final TimetableSettings settings;
  final int week;
  final List<int> visibleDays;
  final bool wallpaperOverChrome;
  final double? wallpaperLuminance;
  final PageController? pageController;
  final bool isDayView;
  final int? visibleDayViewWeek;
  final bool shouldShowOverlay;

  @override
  Widget build(BuildContext context) {
    final controller = pageController;
    if (!shouldShowOverlay || controller == null || visibleDays.isEmpty) {
      return const SizedBox.shrink();
    }
    // In day view the indicator follows the pager live even mid cross-week
    // (its week argument is the pager's floor week, which briefly differs
    // from the settled selection); in week view it is per-page and only
    // shows on the settled page.
    if (!isDayView && visibleDayViewWeek != week) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectionAccent = homePageOverWallpaperAccent(
      configuredHex: isDark
          ? settings.weekdayBarAccentColorDark
          : settings.weekdayBarAccentColorLight,
      themeFallback: colorScheme.primary,
      hasBackdrop: wallpaperOverChrome,
      wallpaperLuminance: wallpaperLuminance,
    );

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          if (totalWidth <= 0) {
            return const SizedBox.shrink();
          }
          final slotWidth = totalWidth / visibleDays.length;

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final rawPage =
                  controllerPageOrNull(controller) ??
                  controller.initialPage.toDouble();
              // Weekday position within the bar's week: the pager is
              // globally continuous, so subtract the week's page offset.
              final rawDayPosition = rawPage - (week - 1) * visibleDays.length;
              final maxDayIndex = (visibleDays.length - 1).toDouble();
              final clampedDayPosition = rawDayPosition
                  .clamp(0.0, maxDayIndex)
                  .toDouble();
              final overflow = rawDayPosition < 0
                  ? -rawDayPosition
                  : rawDayPosition > maxDayIndex
                  ? rawDayPosition - maxDayIndex
                  : 0.0;
              final fractionalProgress =
                  clampedDayPosition - clampedDayPosition.floorToDouble();
              final betweenDaysProgress =
                  (1 - (2 * (fractionalProgress - 0.5).abs()))
                      .clamp(0.0, 1.0)
                      .toDouble();
              final betweenDaysCurve = Curves.easeInOutCubicEmphasized
                  .transform(betweenDaysProgress);
              final edgeCurve = Curves.easeOutCubic.transform(
                overflow.clamp(0.0, 1.0),
              );
              final morphProgress = math.max(
                betweenDaysCurve * 0.55,
                edgeCurve,
              );
              final baseWidth = math.min(22, slotWidth * 0.34);
              final indicatorWidth =
                  baseWidth + (slotWidth * 0.24 * morphProgress);
              final edgeDirection = rawDayPosition < 0
                  ? -1.0
                  : rawDayPosition > maxDayIndex
                  ? 1.0
                  : 0.0;
              final edgePull = slotWidth * 0.10 * edgeCurve * edgeDirection;
              final centeredLeft =
                  slotWidth * clampedDayPosition +
                  ((slotWidth - indicatorWidth) / 2);
              final maxLeft = math.max(0, totalWidth - indicatorWidth);
              final indicatorLeft = (centeredLeft + edgePull)
                  .clamp(0.0, maxLeft)
                  .toDouble();
              final indicatorHeight = 3.0 + (1.4 * morphProgress);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: indicatorLeft,
                    bottom: 0,
                    child: DecoratedBox(
                      key: ValueKey('weekday-selection-indicator-$week'),
                      decoration: BoxDecoration(
                        // Match weekday accent (custom blue etc.), not raw primary.
                        color: selectionAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: selectionAccent.withValues(alpha: 0.18),
                            blurRadius: 8 + (8 * morphProgress),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: indicatorWidth,
                        height: indicatorHeight,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
