import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../day_view/day_view_agenda_surface.dart';
import 'month_day_agenda.dart';
import 'month_day_cell.dart';

/// 月视图下半屏在**没选中日期**时的内容：本月概览 + 本月有安排的日子。
///
/// ## 为什么需要它
///
/// 用户口径（2026-10-21）：「下面信息区域，看看怎么丰富一下，目前没有课程的
/// 时候，下面就是纯空白」，同时要求删掉原来那句「点任意一天查看安排」。
///
/// 旧实现只有一句话：既没告诉用户这个月有多少事，也没提供任何去处，整屏下半
/// 就是一块白。现在换成两块**有数据**的内容：
///
/// 1. **本月概览**：课程节次 / 考试 / 日程三个数字 + 「有安排 N 天」——
///    回答"这个月忙不忙"；
/// 2. **本月有安排的日子**：从今天往后数几天的预览卡（整月的都走完了就从月首
///    开始），点一张就选中那一天、下面立刻换成当日议程 —— 等于把
///    「点日期格」这条交互又给了一条更好按的入口（格子只有 1/7 屏宽）。
///
/// ## 为什么统计数字来自 [MonthGridData.overview]
///
/// 面板是**渲染层**，它拿不到 provider 的原始集合（那是页面的事），而网格数据
/// 已经跟着 build 一起传进来了。把月度累加放在域层（[MonthViewLogic]）而不是
/// 在这里 `for` 一遍 42 格：①补位格的排除规则只有一处（前后月那几天不算本月）；
/// ②缓存命中时不必再扫一遍；③纯 Dart 可单测。
///
/// ## 材质
///
/// 与 [MonthDayAgenda] 同一套：面板是不透明白底，卡片一律 `forceSolid` ——
/// 玻璃卡采的是**屏级 backdrop**（壁纸），父容器不透明也拦不住，会从白底上透出
/// 壁纸纹理（见 `month_day_agenda.dart` 的类注释）。
class MonthPanelOverview extends StatelessWidget {
  const MonthPanelOverview({
    super.key,
    required this.grid,
    required this.upcoming,
    required this.settings,
    required this.onDayTap,
    this.inkColor,
    this.radius = 20,
    this.maxUpcoming = 5,
  });

  /// 当前聚焦月的网格数据（统计取自它的 `overview`）。
  final MonthGridData grid;

  /// 「本月有安排的日子」预览（顺序由调用方按"从今天往后"排好，
  /// 见 [MonthViewLogic.scheduledDaysOfMonth]）。
  final List<MonthDayEntry> upcoming;

  final TimetableSettings settings;

  /// 点一张预览卡 = 选中那一天。
  final ValueChanged<DateTime> onDayTap;

  /// 面板内的墨色（跟主题走，不跟壁纸）。null = `colorScheme.onSurface`。
  final Color? inkColor;

  final double radius;

  /// 预览卡最多几张（超出的部分用户自己滑网格去点，不做"展开全部"）。
  final int maxUpcoming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final ink = inkColor ?? colorScheme.onSurface;
    final overview = grid.overview;

    // 整月没有任何安排：只留一块空态，不摆三个 0 —— "0 节课 / 0 场考试 /
    // 0 个日程"读起来像加载失败，而不是"这个月确实没事"。
    if (overview.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(text: l10n.monthOverviewTitle, ink: ink),
          _EmptyMonthCard(
            settings: settings,
            radius: radius,
            ink: ink,
            title: l10n.monthViewEmptyMonthTitle,
            hint: l10n.monthViewEmptyMonthHint,
          ),
        ],
      );
    }

    final days = upcoming.take(maxUpcoming).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(text: l10n.monthOverviewTitle, ink: ink),
        _StatsCard(
          settings: settings,
          radius: radius,
          ink: ink,
          overview: overview,
          scheduledDaysLabel: l10n.monthOverviewScheduledDays(
            overview.scheduledDayCount,
          ),
        ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(text: l10n.monthOverviewDaysTitle, ink: ink),
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UpcomingDayTile(
                entry: day,
                settings: settings,
                radius: radius,
                ink: ink,
                onTap: () => onDayTap(day.date),
              ),
            ),
        ],
      ],
    );
  }
}

/// 小节标题（「本月概览」/「本月有安排的日子」）：与当日议程的日期标题同款。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: ink.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

/// 本月概览卡：三个数字（课程 / 考试 / 日程）+ 一行「有安排 N 天」。
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.settings,
    required this.radius,
    required this.ink,
    required this.overview,
    required this.scheduledDaysLabel,
  });

  final TimetableSettings settings;
  final double radius;
  final Color ink;
  final MonthOverviewStats overview;
  final String scheduledDaysLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mutedInk = ink.withValues(alpha: 0.55);
    final divider = ink.withValues(alpha: 0.08);
    return DayViewAgendaSurface(
      settings: settings,
      color: Theme.of(context).colorScheme.surface,
      radius: radius,
      // 面板内一律实体：玻璃会透出屏级 backdrop（壁纸），而它躺在白色面板上。
      forceSolid: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatCell(
                  value: overview.courseCount,
                  label: l10n.courseCountLabel,
                  ink: ink,
                  mutedInk: mutedInk,
                  // 课程用课程卡同族的强调色，让"这是课"与下面两张卡可分。
                  dotColor: Theme.of(context).colorScheme.primary,
                ),
                VerticalDivider(width: 1, thickness: 1, color: divider),
                _StatCell(
                  value: overview.examCount,
                  label: l10n.examBadgeLabel,
                  ink: ink,
                  mutedInk: mutedInk,
                  dotColor: monthExamAccent(Theme.of(context).colorScheme),
                ),
                VerticalDivider(width: 1, thickness: 1, color: divider),
                _StatCell(
                  value: overview.scheduleCount,
                  label: l10n.scheduleBadgeLabel,
                  ink: ink,
                  mutedInk: mutedInk,
                  dotColor: monthScheduleDotColor(
                    Theme.of(context).colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: mutedInk,
                ),
                const SizedBox(width: 6),
                Text(
                  scheduledDaysLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: mutedInk,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 概览卡里的一格：大数字 + 小标签 + 一颗语义色小点。
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.ink,
    required this.mutedInk,
    required this.dotColor,
  });

  final int value;
  final String label;
  final Color ink;
  final Color mutedInk;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            maxLines: 1,
            style: TextStyle(
              fontSize: 21,
              height: 1.1,
              fontWeight: FontWeight.w700,
              // 0 弱化：一栏里对比出来"这个月没考试"比三行等重的数字好读。
              color: value == 0 ? mutedInk.withValues(alpha: 0.6) : ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: value == 0
                      ? dotColor.withValues(alpha: 0.28)
                      : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: mutedInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「本月有安排的日子」里的一行：日期块 + 事项摘要 + 箭头。
///
/// 点它等于选中那一天（下面立刻换成当日议程），所以右侧的箭头与当日议程行的
/// 箭头同一个语义。
class _UpcomingDayTile extends StatelessWidget {
  const _UpcomingDayTile({
    required this.entry,
    required this.settings,
    required this.radius,
    required this.ink,
    required this.onTap,
  });

  final MonthDayEntry entry;
  final TimetableSettings settings;
  final double radius;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedInk = ink.withValues(alpha: 0.58);
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surface
        : colorScheme.surfaceContainerHighest;

    final parts = <String>[
      if (entry.courseCount > 0)
        l10n.monthViewCourseCountSemantics(entry.courseCount),
      if (entry.examCount > 0)
        l10n.monthViewExamCountSemantics(entry.examCount),
      if (entry.scheduleCount > 0)
        l10n.monthViewScheduleCountSemantics(entry.scheduleCount),
    ];

    return DayViewAgendaSurface(
      settings: settings,
      color: cardColor,
      radius: radius,
      forceSolid: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            // 日期块：日号大、周几小 —— 与网格里的日期格同一个读取顺序。
            Container(
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: entry.isHoliday ? monthHolidayInk(colorScheme) : ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _weekdayLabel(l10n, entry.date.weekday),
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.monthViewAgendaTitle(
                      entry.date.month,
                      entry.date.day,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ink.withValues(alpha: 0.32),
            ),
          ],
        ),
      ),
    );
  }
}

/// 整月无安排时的空态卡（图标 + 标题 + 一句去处）。
///
/// 「这个月还没有安排」这个键此前就存在、但没有任何地方用 —— 现在它有了确切
/// 的场景：面板在没有选中日期、而整月确实空的时候，要说的正是这句。
class _EmptyMonthCard extends StatelessWidget {
  const _EmptyMonthCard({
    required this.settings,
    required this.radius,
    required this.ink,
    required this.title,
    required this.hint,
  });

  final TimetableSettings settings;
  final double radius;
  final Color ink;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final mutedInk = ink.withValues(alpha: 0.5);
    return DayViewAgendaSurface(
      settings: settings,
      color: Theme.of(context).colorScheme.surface,
      radius: radius,
      forceSolid: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 26),
        child: Column(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 30,
              color: ink.withValues(alpha: 0.24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// 星期几（1 = 周一）。与网格表头同一批 l10n 文案，不另写一套。
String _weekdayLabel(AppLocalizations l10n, int weekday) {
  return switch (weekday) {
    DateTime.monday => l10n.weekdayMon,
    DateTime.tuesday => l10n.weekdayTue,
    DateTime.wednesday => l10n.weekdayWed,
    DateTime.thursday => l10n.weekdayThu,
    DateTime.friday => l10n.weekdayFri,
    DateTime.saturday => l10n.weekdaySat,
    _ => l10n.weekdaySun,
  };
}

