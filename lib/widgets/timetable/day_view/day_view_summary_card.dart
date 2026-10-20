import 'package:flutter/material.dart';

import '../../../domain/day_course_display_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/course.dart';
import '../../../models/exam.dart';
import '../../../models/schedule_item.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/home_page_background.dart';
import '../../course_surface.dart';
import '../timetable_day_agenda_models.dart';
import 'day_view_agenda_surface.dart';
import 'day_view_ink_style.dart';

/// 日视图顶部摘要卡（日期 + 「今天 · 第几周」+ 计数/徽标 + 关闭叉）。
///
/// 2026-10-20 自 `timetable_day_view_part.dart` 的
/// `_TimetableScreenState._buildDayViewSummary`（约 320 行）搬出：只做展示，
/// 全部输入由调用方算好传进来 —— 日期文案（`dateLabel`，含 locale 格式化与
/// 星期名）、当日考试列表（`dayExams`，排序留在调用方，钟点比较的口径由
/// `clock_field_compare_guard_test` 钉在 day part）、以及判墨所需的
/// [DayViewInkEnvironment] 壁纸亮度快照。
///
/// 唯一的「往回拿状态」入口是 [sharedFreeSummaryBuilder]：情侣空闲摘要要用本卡
/// 算出的墨色，又要读 State 里的展开态，所以由调用方给一个「给墨色、还我
/// widget」的回调，本卡只负责摆位置。为 null 时不渲染那一块（= 情侣浮层未启用）。
class TimetableDayViewSummaryCard extends StatelessWidget {
  /// 表层（[CourseSurface]）的 key，不是本 widget 的 key —— 见
  /// [DayViewAgendaSurface.surfaceKey]。
  final Key? surfaceKey;

  final TimetableSettings settings;
  final int week;

  /// 已经本地化好的日期标题（含星期名）。
  final String dateLabel;

  final bool isToday;
  final Course? currentCourse;
  final List<DayCourseDisplayItem> courseItems;
  final List<ScheduleItem> scheduleItems;
  final List<TimetableDayAgendaItem> agendaItems;

  /// 当天的考试，已按开考钟点升序排好。
  final List<Exam> dayExams;

  final DayViewInkEnvironment inkEnvironment;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  /// 关闭日视图（回到周视图）。
  final VoidCallback onClose;

  /// 情侣空闲摘要（需读 State 的展开态，故用回调构造）。
  final Widget Function(Color ink)? sharedFreeSummaryBuilder;

  const TimetableDayViewSummaryCard({
    super.key,
    required this.surfaceKey,
    required this.settings,
    required this.week,
    required this.dateLabel,
    required this.isToday,
    required this.currentCourse,
    required this.courseItems,
    required this.scheduleItems,
    required this.agendaItems,
    required this.dayExams,
    required this.inkEnvironment,
    required this.radius,
    required this.onClose,
    this.sharedFreeSummaryBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final foruiTheme = context.theme;
    final colorScheme = theme.colorScheme;
    final courseCount = courseItems.length;
    final scheduleCount = scheduleItems.length;
    final hasAgenda = agendaItems.isNotEmpty;
    final currentWeekItems = courseItems
        .where((item) => item.isCurrentWeekCourse)
        .toList();
    final nonCurrentWeekCourseCount = courseCount - currentWeekItems.length;
    final conflictCount = courseItems
        .where((item) => item.isConflicting)
        .length;
    final firstAgenda = hasAgenda ? agendaItems.first : null;
    final lastAgenda = hasAgenda ? agendaItems.last : null;

    final isDark = theme.brightness == Brightness.dark;
    final hasBackdrop = hasHomePageBackdrop(settings);
    final backdropBlurOn = inkEnvironment.backdropBlurOn;
    final courseCardStyle = dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: backdropBlurOn,
    );
    // 摘要卡跟**课程卡**同材质（用户口径 2026-09-22：「日视图顶部的日期卡片……
    // 也要跟日视图的课程卡片是一样的材质，选什么就是什么，不要第二种」）：
    // 材质一律由 CourseSurface 按 effectiveCourseCardSurfaceStyle 出 —— 与下方
    // 议程卡走**同一条路径、同一档、同一份预糊位图、同一套调参**。
    //
    // 这里曾经有一条例外分支（`chromeGlass` 亮磨砂替身：跟顶栏铬玻璃带同款）：
    // 课程卡是玻璃档时给摘要卡贴一块固定的亮色 wash，读作"顶栏同款"而不是
    // "课程卡同款"——用户实测两张卡材质不一致。例外已删除，
    // `homePageHasAnyChromeBlur` 也不再参与这张卡的材质判定。
    //
    // 实体档那条老口径自然仍成立：无壁纸 / 全局模糊关掉时
    // [effectiveCourseCardSurfaceStyle] 就回落实体，摘要卡跟着实底，不会出现
    // 「课程卡实心、顶上的日期卡还透」。
    // Ink: 卡面**真的把壁纸透出来**时才自动黑白；否则卡面是主题底色
    // 的实底，墨色必须跟主题走 —— 按壁纸亮度翻白会让白墨落在亮色卡面上
    // 不可读。判据是**卡实际用的材质**，不是顶栏状态。
    //
    // 自动黑白判的是**卡面**亮度（卡自己的底色 + 壁纸那条带按染色强度混合，
    // 见 [contentCardInkOverWallpaper]），不是裸壁纸亮度：2026-09-22 真机反馈
    // "浅色主题下卡面发白、字也是浅色糊在一起"，就是漏了卡面那层 32%~42% 的
    // 自有底色所致。
    //
    // 壁纸那条带取的是 `_weekdayInkLuminance`（信息栏与顶栏带用的就是它）：
    // 这张卡的墨色本来就是信息栏那套
    //（configuredHex 取的就是 weekdayBarFontColor*）。
    // 早先这里用 body 带（整屏下半部，常含壁纸的深色区），于是出现"带是
    // 浅色、卡片也是亮卡，却按深色壁纸翻成白墨"——白字落在亮卡上读不出来
    // （真机反馈：高斯档下日课表那张日期卡）。
    final glassOverWallpaper = backdropBlurOn && courseCardStyle.isGlass;
    final summaryInk = glassOverWallpaper
        ? contentCardInkOverWallpaper(
            // 判据是**卡面**亮度，不是裸壁纸：卡面上还压着
            // `CourseSurface.washAlpha` 比例的自有底色（就是这里的
            // `foruiTheme.colors.background`）。只看壁纸会在浅色主题下把白字
            // 判到被冲白的卡面上（2026-09-22 真机反馈），详见该函数。
            cardFill: foruiTheme.colors.background,
            washAlpha: CourseSurface.washAlpha(context, courseCardStyle),
            configuredHex: isDark
                ? settings.weekdayBarFontColorDark
                : settings.weekdayBarFontColorLight,
            defaultHex: isDark
                ? TimetableSettings.defaultWeekdayBarFontColorDark
                : TimetableSettings.defaultWeekdayBarFontColorLight,
            themeFallback: foruiTheme.colors.foreground,
            hasBackdrop: hasBackdrop,
            wallpaperLuminance: inkEnvironment.wallpaperWeekdayInkLuminance,
          )
        : foruiTheme.colors.foreground;
    final summaryMutedInk = homePageOverWallpaperMutedInk(summaryInk);
    // 课程计数胶囊与「X 节日程」胶囊同款中性墨：跟摘要卡其余文字一样走
    // 壁纸自动黑白，有课与否不再切换主题蓝强调色。
    final countBadgeColor = summaryInk.withValues(alpha: 0.10);
    final countBadgeTextColor = summaryMutedInk;
    final sharedFreeSummary = sharedFreeSummaryBuilder?.call(summaryInk);
    return DayViewAgendaSurface(
      surfaceKey: surfaceKey,
      // 材质全部交给 CourseSurface 按 effectiveCourseCardSurfaceStyle 判
      //（无壁纸 / 全局模糊关掉时它自己回落实体），这里不再覆盖卡片档。
      settings: settings,
      radius: radius,
      // Neutral wash (not a course hue); CourseSurface owns glass vs solid.
      color: foruiTheme.colors.background,
      gradient: LinearGradient(
        colors: [foruiTheme.colors.background, foruiTheme.colors.background],
      ),
      // 摘要卡没有课程色填充可依托：无壁纸（纯色页面）时填充色与页面底色
      // 相同，无边框无阴影会整张隐形（下方课程卡靠 hue + outerShadow 保持
      // 边界）。补一套中性细描边 + 柔和投影，几何参数与 agenda 卡片一致，
      // 让两种卡片在纯白底上读作同一个卡片系统。
      border: Border.all(color: summaryInk.withValues(alpha: 0.12)),
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // 「回到今天」已挪到日视图底部的悬浮按钮（见
                      // [_buildFloatingBackToTodayButton]）：这张摘要卡只留
                      // 「今天 · 第几周」，不再放可点胶囊，避免两个入口。
                      if (isToday) ...[
                        Text(
                          l10n.todayTimetableTitle,
                          style: foruiTheme.typography.body.sm.copyWith(
                            color: summaryMutedInk,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: foruiTheme.typography.body.sm.copyWith(
                              color: summaryMutedInk,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        l10n.weekLabel(week),
                        style: foruiTheme.typography.body.sm.copyWith(
                          color: summaryMutedInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('back-to-week-view-button'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: l10n.backToWeekViewAction,
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: summaryMutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: foruiTheme.typography.display.lg.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                height: 1.15,
                color: summaryInk,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: countBadgeColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    hasAgenda
                        ? (courseCount > 0
                              ? l10n.courseCountSummary(courseCount)
                              : l10n.scheduleCountSummary(scheduleCount))
                        : l10n.courseCountSummary(0),
                    style: foruiTheme.typography.body.xs2.copyWith(
                      color: countBadgeTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (scheduleCount > 0 && courseCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: summaryInk.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.scheduleCountSummary(scheduleCount),
                      style: foruiTheme.typography.body.xs2.copyWith(
                        color: summaryMutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (firstAgenda != null)
                  Text(
                    '${l10n.classStartsAtLabel(firstAgenda.startTime)} · ${l10n.classEndsAtLabel(lastAgenda!.endTime)}',
                    style: foruiTheme.typography.body.xs2.copyWith(
                      color: summaryMutedInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (currentCourse != null ||
                conflictCount > 0 ||
                nonCurrentWeekCourseCount > 0 ||
                dayExams.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (currentCourse != null)
                    _SummaryChip(
                      icon: Icons.bolt_rounded,
                      text:
                          '${l10n.ongoingCourseBadge} · ${currentCourse!.name}',
                      accentColor: colorScheme.primary,
                    ),
                  if (conflictCount > 0)
                    _SummaryChip(
                      icon: Icons.warning_amber_rounded,
                      text: l10n.conflictCountLabel(conflictCount),
                      accentColor: colorScheme.error,
                    ),
                  if (nonCurrentWeekCourseCount > 0)
                    _SummaryChip(
                      icon: Icons.visibility_rounded,
                      text:
                          '${l10n.nonCurrentWeekLabel} ${l10n.courseCountSummary(nonCurrentWeekCourseCount)}',
                    ),
                  ...dayExams.map(
                    (exam) => _SummaryChip(
                      icon: Icons.school_outlined,
                      text:
                          '${exam.name} · ${exam.daysUntil == 0 ? l10n.examCountdownToday : l10n.examCountdownDays(exam.daysUntil)}',
                      accentColor: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
            if (sharedFreeSummary != null) ...[
              const SizedBox(height: 12),
              sharedFreeSummary,
            ],
          ],
        ),
      ),
    );
  }
}

/// 摘要卡下方那排小胶囊（原 `_TimetableScreenState._buildDayViewSummaryChip`）。
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? accentColor;

  const _SummaryChip({required this.icon, required this.text, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final foruiTheme = context.theme;
    final resolvedAccent = accentColor ?? foruiTheme.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: resolvedAccent),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: foruiTheme.typography.body.xs.copyWith(
              color: resolvedAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
