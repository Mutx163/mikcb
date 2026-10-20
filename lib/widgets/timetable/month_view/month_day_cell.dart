import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/hex_color.dart';

/// 月视图单格（日期数字 + 事项圆点 + 假期/调休标）。
///
/// 纯展示：所有判定结果由 [MonthDayEntry] 带进来，本部件不做取数、不读
/// provider、不判「今天」——同一份 Widget 才能被页面与将来的导出图复用。
///
/// 密度口径见 `.agents/notes/proposed/feature/2026-10-20-month-view.md`：
/// 格子宽约屏宽/7（≈50dp），小字课程名会爆版，所以一格只表达「有没有」，
/// 「是什么」靠点格子看当日议程。圆点预算：课程按自己的课程色、最多 3 颗；
/// 考试红点与日程强调点各一颗，与周视图星期栏同一套语义。
class MonthDayCell extends StatelessWidget {
  const MonthDayCell({
    super.key,
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.courseDotBudget = 3,
  });

  final MonthDayEntry entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final int courseDotBudget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseInk = entry.isOutsideMonth
        ? colorScheme.onSurface.withValues(alpha: 0.32)
        : colorScheme.onSurface;
    final holidayInk = colorScheme.error;
    // 假期格数字用 error 色（与周视图假期灰显口径一致），今天/选中仍以
    // 边框与底色表达，不抢数字颜色。
    final dayInk = entry.isHoliday ? holidayInk : baseInk;

    final dots = <Widget>[
      for (var i = 0; i < entry.courseColorHexes.length; i++)
        if (i < courseDotBudget)
          MonthDot(
            color: parseHexColorOrFallback(
              entry.courseColorHexes[i],
              fallback: colorScheme.primary,
            ),
          ),
      if (entry.examCount > 0) MonthDot(color: colorScheme.error),
      if (entry.scheduleCount > 0) MonthDot(color: colorScheme.primary),
    ];

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticsLabel(l10n),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('month-day-cell-${_dateKey(entry.date)}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.14)
                  : null,
              border: isToday
                  ? Border.all(color: colorScheme.primary, width: 1.4)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${entry.date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: dayInk,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (entry.isAdjustedWorkday)
                        MonthBadge(
                          text: l10n.monthViewAdjustedWorkdayBadge,
                          color: colorScheme.primary,
                        )
                      else if (entry.isHoliday)
                        MonthBadge(
                          text: l10n.monthViewHolidayBadge,
                          color: holidayInk,
                        )
                      else
                        ...dots,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel(AppLocalizations l10n) {
    final parts = <String>[
      l10n.monthViewDaySemantics(entry.date.month, entry.date.day),
    ];
    if (entry.isAdjustedWorkday) {
      parts.add(l10n.monthViewAdjustedWorkdayBadge);
    } else if (entry.isHoliday) {
      parts.add(l10n.monthViewHolidayBadge);
    }
    if (entry.examCount > 0) {
      parts.add(l10n.monthViewExamCountSemantics(entry.examCount));
    }
    if (entry.scheduleCount > 0) {
      parts.add(l10n.monthViewScheduleCountSemantics(entry.scheduleCount));
    }
    if (entry.courseCount > 0) {
      parts.add(l10n.monthViewCourseCountSemantics(entry.courseCount));
    }
    return parts.join('，');
  }
}

/// 事项圆点：4dp 圆（尺寸与周视图星期栏的考试/日程点一致）。
class MonthDot extends StatelessWidget {
  const MonthDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 「休 / 班」小字标（假期与调休上班日）。
class MonthBadge extends StatelessWidget {
  const MonthBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 8, height: 1, color: color),
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
