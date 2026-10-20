import 'package:flutter/material.dart';

import '../../domain/week_calculator.dart';
import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/home_page_region_blur.dart';
import 'timetable_weekday_selection_indicator.dart';

/// 课表星期信息栏（2026-10-19 从 timetable_screen 的 State 方法搬出）。
///
/// 周视图每页一行；日视图叠三周并随 pager 平移，整条栏像周视图表头一样跟手。
/// 选中态、考试红点、周次选择与点按行为全部由调用方显式注入；widget 自己不读
/// provider / State。
class TimetableWeekdayHeader extends StatelessWidget {
  const TimetableWeekdayHeader({
    super.key,
    required this.settings,
    required this.week,
    required this.timeColumnWidth,
    required this.hideBottomBorder,
    required this.wallpaperTopLuminance,
    required this.wallpaperWeekdayLuminance,
    required this.pageController,
    required this.isDayView,
    required this.visibleDayViewWeek,
    required this.shouldShowOverlay,
    required this.isSelectedDay,
    required this.hasExamOnDate,
    required this.hasScheduleOnDate,
    required this.onShowWeekSelector,
    required this.onDayTapDown,
    required this.onDayTap,
  });

  final TimetableSettings settings;
  final int week;
  final double timeColumnWidth;
  final bool hideBottomBorder;
  final double? wallpaperTopLuminance;
  final double? wallpaperWeekdayLuminance;
  final PageController? pageController;
  final bool isDayView;
  final int? visibleDayViewWeek;
  final bool shouldShowOverlay;
  final bool Function(int week, int dayOfWeek) isSelectedDay;
  final bool Function(DateTime date) hasExamOnDate;
  final bool Function(DateTime date) hasScheduleOnDate;
  final VoidCallback onShowWeekSelector;
  final ValueChanged<Offset> onDayTapDown;
  final void Function(int week, int dayOfWeek) onDayTap;

  static const double height = 40;

  DateTime? _dateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }
    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));
    return WeekCalculator.addDays(
      normalizedStart,
      (week - 1) * 7 + dayOfWeek - 1,
    );
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _weekdayLabel(BuildContext context, int dayOfWeek) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    if (dayOfWeek < 1 || dayOfWeek > labels.length) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
  }

  double _dayViewPagerPage() {
    final controller = pageController;
    if (controller == null) {
      return 0;
    }
    if (!controller.hasClients) {
      return controller.initialPage.toDouble();
    }
    return controllerPageOrNull(controller) ??
        controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    // Opaque/no-wallpaper chrome still needs a separator, but a full 1dp
    // ThemeData outline lands as a dark multi-physical-pixel band on dense
    // Android screens. Keep the wallpaper path's existing border untouched
    // and use the lighter HyperOS divider token only for the fallback.
    final subtleBorder = hasBackdrop
        ? context.theme.colors.border
        : HyperosColors.dividerLine(context);
    final dividerWidth = hasBackdrop ? 1.0 : 0.5;
    // Only flip by wallpaper luminance when this band actually shows the
    // wallpaper / frosted glass; with the scope toggled off it paints the
    // opaque page background and must use the theme / configured ink. 实体档
    // 那条不透明实心条同样不属于「压在壁纸上」（真机 2026-09-30 修）；液态 /
    // 磨砂带在模糊管线不在时降级的实心条亦然。
    final weekdayChromeOverWallpaper = homePageWeekdayBarOverWallpaper(
      settings: settings,
      hasBackdrop: hasBackdrop,
      blurPipelineOn:
          hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context),
    );
    // Judge ink from the band actually behind the weekday bar, not the
    // status/title strip above it — the two can differ on the same photo.
    // With the weekday glass band on, follow the band's scrim polarity (the
    // scrim derives from the top sample) so ink and wash never fight.
    final weekdayLuminance = settings.homePageWeekdayBarBlurEnabled
        ? wallpaperTopLuminance
        : wallpaperWeekdayLuminance ?? wallpaperTopLuminance;
    // Week label sits in the weekday chrome band: auto-invert default black/white
    // over a dark wallpaper; a custom ink keeps its hue, only the lightness moves.
    final weekLabelColor = homePageOverWallpaperInk(
      configuredHex: isDark
          ? settings.weekdayBarFontColorDark
          : settings.weekdayBarFontColorLight,
      defaultHex: isDark
          ? TimetableSettings.defaultWeekdayBarFontColorDark
          : TimetableSettings.defaultWeekdayBarFontColorLight,
      themeFallback: colorScheme.onSurface,
      hasBackdrop: weekdayChromeOverWallpaper,
      wallpaperLuminance: weekdayLuminance,
    );
    final visibleDays = settings.timetableHideWeekends
        ? const [1, 2, 3, 4, 5]
        : const [1, 2, 3, 4, 5, 6, 7];

    // Shared full-row builder: week label + back-to-current-week + the seven
    // day slots + the selection indicator — one complete weekday bar row.
    // Week view renders one row per page (it scrolls with that page); day
    // view stacks three consecutive weeks and translates them with the pager
    // so the WHOLE bar slides like the week view's header.
    Widget fullWeekRowFor(int rowWeek, {required bool showExtras}) {
      return Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: onShowWeekSelector,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    // 时间列偏窄，略向右让周次与节次数字视觉中心对齐。
                    padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
                    child: Text(
                      l10n.currentWeekCompact(rowWeek),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: weekLabelColor,
                      ),
                    ),
                  ),
                ),
                // （内嵌「回本周」小字已移除）
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Row(
                  children: visibleDays
                      .map((dayOfWeek) {
                        final date = _dateForWeekDay(
                          settings,
                          rowWeek,
                          dayOfWeek,
                        );
                        final isToday =
                            date != null && _isSameDate(date, DateTime.now());
                        final isSelected = isSelectedDay(rowWeek, dayOfWeek);
                        final configuredWeekdayHex = isDark
                            ? settings.weekdayBarFontColorDark
                            : settings.weekdayBarFontColorLight;
                        final configuredAccentHex = isDark
                            ? settings.weekdayBarAccentColorDark
                            : settings.weekdayBarAccentColorLight;
                        // Default weekday ink flips with the band behind this
                        // bar; a custom hex keeps its colour, only the
                        // lightness moves when it would be unreadable. Accent
                        // (today/selected) obeys the same rule so the "today"
                        // column neither vanishes into the photo nor loses the
                        // colour the user picked.
                        final weekdayColor = homePageOverWallpaperInk(
                          configuredHex: configuredWeekdayHex,
                          defaultHex: isDark
                              ? TimetableSettings.defaultWeekdayBarFontColorDark
                              : TimetableSettings
                                    .defaultWeekdayBarFontColorLight,
                          themeFallback: colorScheme.onSurface,
                          hasBackdrop: weekdayChromeOverWallpaper,
                          wallpaperLuminance: weekdayLuminance,
                        );
                        final accentColor = homePageOverWallpaperAccent(
                          configuredHex: configuredAccentHex,
                          themeFallback: colorScheme.primary,
                          hasBackdrop: weekdayChromeOverWallpaper,
                          wallpaperLuminance: weekdayLuminance,
                        );
                        final labelColor = (isSelected || isToday)
                            ? accentColor
                            : weekdayColor;
                        final subLabelColor = (isSelected || isToday)
                            ? accentColor.withValues(
                                alpha: isSelected ? 0.9 : 0.78,
                              )
                            : homePageOverWallpaperMutedInk(weekdayColor);
                        final showsTodayMarker = isToday && !isSelected;
                        final hasExamOnDay =
                            date != null && hasExamOnDate(date);
                        final hasScheduleOnDay =
                            date != null && hasScheduleOnDate(date);

                        return Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'weekday-header-$rowWeek-$dayOfWeek',
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onTapDown: (details) =>
                                  onDayTapDown(details.globalPosition),
                              onTap: () => onDayTap(rowWeek, dayOfWeek),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: showsTodayMarker
                                          ? accentColor.withValues(alpha: 0.35)
                                          : Colors.transparent,
                                      width: showsTodayMarker ? 2 : 0,
                                    ),
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 固定 40dp 的星期栏扣掉 3+3 内边距和 0.5
                                    // 分隔线后格子只剩 33.5dp，平铺考试/日程
                                    // 圆点会把内容顶到 34dp 溢出；改悬浮层后
                                    // 基础内容恒为 28dp，任何外观模式都有余量
                                    // （圆点并排成一行，高度不变）。
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _weekdayLabel(context, dayOfWeek),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected || isToday
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: labelColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          date == null
                                              ? ''
                                              : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: subLabelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasExamOnDay || hasScheduleOnDay)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Row(
                                          key: const ValueKey(
                                            'weekday-indicator-dots',
                                          ),
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (hasExamOnDay)
                                              Container(
                                                key: const ValueKey(
                                                  'weekday-exam-dot',
                                                ),
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: colorScheme.error,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            if (hasExamOnDay &&
                                                hasScheduleOnDay)
                                              const SizedBox(width: 2),
                                            if (hasScheduleOnDay)
                                              Container(
                                                key: const ValueKey(
                                                  'weekday-schedule-dot',
                                                ),
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  // 日程点用主题强调色（与
                                                  // today/选中标签同一来源，
                                                  // 壁纸下自动适配明暗），与
                                                  // 考试红点区分两种事项；
                                                  // 形状（居中圆点）与 today
                                                  // 的全宽底边线不同。
                                                  color: accentColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                if (showExtras)
                  TimetableWeekdaySelectionIndicator(
                    settings: settings,
                    week: rowWeek,
                    visibleDays: visibleDays,
                    wallpaperOverChrome: weekdayChromeOverWallpaper,
                    wallpaperLuminance: weekdayLuminance,
                    pageController: pageController,
                    isDayView: isDayView,
                    visibleDayViewWeek: visibleDayViewWeek,
                    shouldShowOverlay: shouldShowOverlay,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      height: height,
      padding: EdgeInsets.zero,
      decoration: hideBottomBorder
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: subtleBorder, width: dividerWidth),
              ),
            ),
      child: isDayView && pageController != null
          ? AnimatedBuilder(
              animation: pageController!,
              builder: (context, _) {
                // The whole bar (week label + day row + indicator) is one row
                // per week. Within a week it stays put (the indicator follows
                // the pager); only during the cross-week transition does the
                // outgoing week slide out and the next week slide in — glued
                // to the pager's position, like the week view's per-page
                // header moving under the finger.
                final rawPage = _dayViewPagerPage();
                final count = visibleDays.length;
                final totalWeeks = settings.semesterWeekCount;
                final weekIndex = (rawPage / count).floor().clamp(
                  0,
                  totalWeeks - 1,
                );
                final inWeekPos = rawPage - weekIndex * count;
                final isCrossing = inWeekPos >= count - 1;
                final progress = isCrossing
                    ? (inWeekPos - (count - 1)).clamp(0.0, 1.0)
                    : 0.0;
                final weekRow = weekIndex + 1;
                final nextWeek = weekRow + 1;
                final extrasOnOutgoing = !isCrossing || progress < 0.5;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isCrossing)
                            Transform.translate(
                              offset: Offset(-progress * barWidth, 0),
                              child: SizedBox(
                                width: barWidth,
                                child: fullWeekRowFor(
                                  weekRow,
                                  showExtras: extrasOnOutgoing,
                                ),
                              ),
                            ),
                          if (isCrossing)
                            Transform.translate(
                              offset: Offset((1 - progress) * barWidth, 0),
                              child: SizedBox(
                                width: barWidth,
                                child: fullWeekRowFor(
                                  nextWeek,
                                  showExtras: !extrasOnOutgoing,
                                ),
                              ),
                            ),
                          if (!isCrossing)
                            fullWeekRowFor(weekRow, showExtras: true),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          : fullWeekRowFor(week, showExtras: true),
    );
  }
}
