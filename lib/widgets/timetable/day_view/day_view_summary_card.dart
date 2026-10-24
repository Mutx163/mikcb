import 'package:flutter/material.dart';

import '../../../domain/day_course_display_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/course.dart';
import '../../../models/exam.dart';
import '../../../models/schedule_item.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/card_surface_ink.dart';
import '../../../utils/hex_color.dart';
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

  /// 当天**还没做完**的作业条数（逾期 + 今天到期，已完成不算）。
  ///
  /// 只用来救主计数胶囊：日视图现在有「有作业没课」的日子，那时
  /// courseItems 与 scheduleItems 都为空，主胶囊会显示「0 门课」——
  /// 与「这一天什么都没有」长得一模一样。**比多一个信号更隐蔽的是少一个信号**：
  /// 用户在摘要卡上看不出今天有三个作业要交，滚下去才发现。
  ///
  /// 默认 0：既有调用点（测试与预览）不必跟着改，行为与改动前逐像素一致。
  final int taskCount;

  final DayViewInkEnvironment inkEnvironment;

  /// 这张卡在屏幕上的实际矩形（首帧为 null）。
  ///
  /// 判字色按它背后那一小块壁纸的亮度；为 null 时回落到星期栏那条带。
  final Rect? cardRect;

  /// 卡片圆角；正源是 `_TimetableScreenState._dayViewCardRadius`。
  final double radius;

  /// 关闭日视图（回到周视图）。
  final VoidCallback onClose;

  /// 情侣空闲摘要（需读 State 的展开态，故用回调构造）。
  final Widget Function(Color ink)? sharedFreeSummaryBuilder;

  /// 日期标题**以下**那整块（计数行 / 状态与考试行 / 情侣空闲块）构建完成时回调。
  ///
  /// 转场中的「飞行摘要卡」要用**同一份**：它自己复刻一套的话，落定那一帧会
  /// 「多出几个胶囊」（真卡有「X 节日程」、进行中、冲突、考试、情侣空闲，
  /// 而飞行卡只画了计数）。复刻一套还迟早会跟真卡分叉。
  ///
  /// 只在**正在打开的那一页**传（翻页器同时挂三页，都回调会互相覆盖）。
  final ValueChanged<Widget>? onLowerSectionBuilt;

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
    this.taskCount = 0,
    required this.inkEnvironment,
    required this.radius,
    required this.onClose,
    this.cardRect,
    this.sharedFreeSummaryBuilder,
    this.onLowerSectionBuilt,
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
    //
    // ── 墨色（2026-10-21 重写） ──
    //
    // 旧实现走 `contentCardInkOverWallpaper`：卡面亮度 = 主题背景色 × 染色比例
    // + 壁纸带 × 其余，分界点 0.20。问题在于**浅色主题下主题背景色接近纯白**，
    // 白 × 20% 就已经等于 0.20 的分界点，再叠上壁纸分量恒定 ≥ 0.2 ——
    // 于是「壁纸再怎么黑，这张卡也永远给黑字」。真机上表现为黑字压在近黑夜景上
    // （截图 2：日期卡 ≈ 1.7:1）。
    //
    // 现在与议程卡统一走 `cardSurfaceInk`：卡面亮度按真实染色比例合成，然后
    // 直接比黑/白各自的**对比度**（等价于在 0.20 处翻转，但不再被"白底加成"
    // 顶死）。用户手挑的字色仍然优先保留，只要求它在这张卡的实际卡面上达标。
    final summaryFill = foruiTheme.colors.background;
    // 墨色抽成 [resolveSummaryCardInk]：转场里的「飞行摘要卡」必须与这张卡**同
    // 一个判据**，否则它会中途换色（课程卡上一轮就是这么修的）。
    // 课程计数胶囊与「X 节日程」胶囊同款中性墨：跟摘要卡其余文字一样走
    // 壁纸自动黑白，有课与否不再切换主题蓝强调色。
    final resolvedInk = resolveSummaryCardInk(
      context: context,
      settings: settings,
      inkEnvironment: inkEnvironment,
      cardRect: cardRect,
      fill: summaryFill,
      surfaceStyle: courseCardStyle,
    );
    final summaryInk = resolvedInk.ink;
    final summaryMutedInk = resolvedInk.mutedInk;
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
            SummaryCardLowerSection(
              countLabel: courseCount > 0
                  ? l10n.courseCountSummary(courseCount)
                  : scheduleCount > 0
                  ? l10n.scheduleCountSummary(scheduleCount)
                  : taskCount > 0
                  ? l10n.dayTaskBandCountSummary(taskCount)
                  : l10n.courseCountSummary(0),
              scheduleLabel: (scheduleCount > 0 && courseCount > 0)
                  ? l10n.scheduleCountSummary(scheduleCount)
                  : null,
              agendaRangeLabel: firstAgenda == null
                  ? null
                  : '${l10n.classStartsAtLabel(firstAgenda.startTime)} · '
                        '${l10n.classEndsAtLabel(lastAgenda!.endTime)}',
              statusChips: <SummaryChipSpec>[
                if (currentCourse != null)
                  SummaryChipSpec(
                    icon: Icons.bolt_rounded,
                    text: '${l10n.ongoingCourseBadge} · ${currentCourse!.name}',
                    accentColor: colorScheme.primary,
                  ),
                if (conflictCount > 0)
                  SummaryChipSpec(
                    icon: Icons.warning_amber_rounded,
                    text: l10n.conflictCountLabel(conflictCount),
                    accentColor: colorScheme.error,
                  ),
                if (nonCurrentWeekCourseCount > 0)
                  SummaryChipSpec(
                    icon: Icons.visibility_rounded,
                    text:
                        '${l10n.nonCurrentWeekLabel} ${l10n.courseCountSummary(nonCurrentWeekCourseCount)}',
                  ),
                ...dayExams.map(
                  (exam) => SummaryChipSpec(
                    icon: Icons.school_outlined,
                    text:
                        '${exam.name} · ${exam.daysUntil == 0 ? l10n.examCountdownToday : l10n.examCountdownDays(exam.daysUntil)}',
                    accentColor: colorScheme.error,
                  ),
                ),
              ],
              bottomBlock: sharedFreeSummary,
              ink: summaryInk,
              mutedInk: summaryMutedInk,
              // 转场中的飞行卡复用**同一份**（见 [onLowerSectionBuilt]）。
              onBuilt: onLowerSectionBuilt,
            ),
          ],
        ),
      ),
    );
  }
}

/// 摘要卡（以及转场中那张飞行卡）的墨色。
///
/// 抽成公共函数而不是各算一份：飞行卡与真卡必须**同一个判据**。曾经的课程卡就是
/// 因为「两边各配一个颜色」在中途换色（用户口径「颜色差得非常远」）。
class SummaryCardInk {
  const SummaryCardInk({required this.ink, required this.mutedInk});

  final Color ink;
  final Color mutedInk;
}

SummaryCardInk resolveSummaryCardInk({
  required BuildContext context,
  required TimetableSettings settings,
  required DayViewInkEnvironment inkEnvironment,
  required Color fill,
  required CourseCardSurfaceStyle surfaceStyle,
  Rect? cardRect,
}) {
  final theme = Theme.of(context);
  final foruiTheme = context.theme;
  final isDark = theme.brightness == Brightness.dark;
  final glassOverWallpaper =
      inkEnvironment.backdropBlurOn && surfaceStyle.isGlass;
  final ink = cardSurfaceInk(
    fill: fill,
    washAlpha: glassOverWallpaper
        ? CourseSurface.washAlpha(context, surfaceStyle)
        : 1.0,
    // 判据亮度取**这张卡实际压着的那一小块**壁纸（`cardRect`），拿不到时回落到
    // 星期栏那条带 —— 这张卡的墨色本来就是信息栏那套（`weekdayBarFontColor*`），
    // 旧实现错在「只看带、不看卡在哪」。
    wallpaperLuminance: glassOverWallpaper
        ? (inkEnvironment.luminanceBehind(cardRect) ??
              inkEnvironment.wallpaperWeekdayInkLuminance)
        : null,
    preferred: isDark
        ? parseHexColorOrFallback(
            settings.weekdayBarFontColorDark,
            fallback: foruiTheme.colors.foreground,
          )
        : parseHexColorOrFallback(
            settings.weekdayBarFontColorLight,
            fallback: foruiTheme.colors.foreground,
          ),
    fallback: foruiTheme.colors.foreground,
  );
  return SummaryCardInk(
    ink: ink,
    mutedInk: homePageOverWallpaperMutedInk(ink),
  );
}

/// 摘要卡里一个胶囊的内容（图标 / 文案 / 强调色）。
class SummaryChipSpec {
  const SummaryChipSpec({
    required this.icon,
    required this.text,
    this.accentColor,
  });

  final IconData icon;
  final String text;
  final Color? accentColor;
}

/// 摘要卡**日期标题以下**的整块内容（计数行 / 状态与考试行 / 情侣空闲块）。
///
/// ## 为什么必须两端共用一份
///
/// 转场中的「飞行摘要卡」曾经自己只画了计数胶囊，而真卡还有「X 节日程」、
/// 进行中、冲突、非本周、考试、情侣空闲 —— 落定那一帧这些块**凭空冒出来**。
///
/// 各自复刻一套还迟早会分叉（真卡加一个胶囊，飞行卡就漏一个）。所以这里收成
/// 一个组件：真卡直接用它，飞行卡通过 [TimetableDayViewSummaryCard
/// .onLowerSectionBuilt] 拿到**同一个 widget 实例**画进自己的卡片里。
///
/// ## 布局口径
///
/// 这一段完全靠 `Wrap` 自己排，没有写死的坐标 —— 所以飞行卡只要给它**终点宽度**
/// 和正确的顶边，内部排布就与真卡逐像素一致（不会出现「中途换个行」）。
class SummaryCardLowerSection extends StatelessWidget {
  const SummaryCardLowerSection({
    super.key,
    required this.countLabel,
    required this.ink,
    required this.mutedInk,
    this.scheduleLabel,
    this.agendaRangeLabel,
    this.statusChips = const <SummaryChipSpec>[],
    this.bottomBlock,
    this.onBuilt,
  });

  /// 计数胶囊的文案（「3 门课」/「2 节日程」/「1 个作业」）。
  final String countLabel;

  /// 「X 节日程」，null = 不显示（只有「有课且有日程」才显示）。
  final String? scheduleLabel;

  /// 「08:00 开始 · 09:40 结束」，null = 当天没有议程条目。
  final String? agendaRangeLabel;

  /// 第二排的状态胶囊（进行中 / 冲突 / 非本周 / 考试）。
  final List<SummaryChipSpec> statusChips;

  /// 情侣空闲块（浮层未启用时为 null）。
  final Widget? bottomBlock;

  final Color ink;
  final Color mutedInk;

  /// 构建完成时把**这一段自己**交出去（飞行卡复用它）。
  final ValueChanged<Widget>? onBuilt;

  @override
  Widget build(BuildContext context) {
    final foruiTheme = context.theme;
    final chipTextStyle = foruiTheme.typography.body.xs2.copyWith(
      color: mutedInk,
      fontWeight: FontWeight.w600,
    );

    Widget neutralChip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label, style: chipTextStyle),
    );

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            neutralChip(countLabel),
            if (scheduleLabel != null) neutralChip(scheduleLabel!),
            if (agendaRangeLabel != null)
              Text(
                agendaRangeLabel!,
                style: foruiTheme.typography.body.xs2.copyWith(
                  color: mutedInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (statusChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in statusChips)
                _SummaryChip(
                  icon: chip.icon,
                  text: chip.text,
                  accentColor: chip.accentColor,
                ),
            ],
          ),
        ],
        if (bottomBlock != null) ...[
          const SizedBox(height: 12),
          bottomBlock!,
        ],
      ],
    );
    onBuilt?.call(section);
    return section;
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
