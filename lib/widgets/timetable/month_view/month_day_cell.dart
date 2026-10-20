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
            // 课程点用课程自身色：同色相邻时靠描边分开，避免糊成一坨。
            outlined: true,
          ),
      if (entry.examCount > 0) MonthDot(color: monthExamDotColor(colorScheme)),
      if (entry.scheduleCount > 0)
        MonthDot(color: monthScheduleDotColor(colorScheme)),
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

/// 考试圆点色：固定红系，**不跟主题走**。
///
/// 用 `colorScheme.error` 会遇到「用户主题本身就是红/橙」时与课程点撞色；
/// 这里取一个在明暗主题下都读作"考试"的固定红。
Color monthExamDotColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFFFF6B6B)
      : const Color(0xFFE5484D);
}

/// 日程圆点色：固定蓝系，与考试红、课程自身色三者互相可辨。
///
/// ⚠️ 这里**刻意不用 `colorScheme.primary`**：截图里用户主题是青绿色，
/// 「课程点（青绿）+ 日程点（primary，同青绿）」并排时看着像同一个意思
/// 说了两遍，语义彻底失效。语义色必须与主题色解耦。
Color monthScheduleDotColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFF6AA8FF)
      : const Color(0xFF3B82F6);
}

/// 事项圆点：4dp 圆（尺寸与周视图星期栏的考试/日程点一致）。
///
/// [outlined] 为真时给圆点加一圈背景色描边：课程点用的是课程自身的颜色，
/// 与旁边语义点贴在一起时容易糊成一坨（尤其同一门课两节）。
class MonthDot extends StatelessWidget {
  const MonthDot({super.key, required this.color, this.outlined = false});

  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: outlined
            ? Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 0.5,
              )
            : null,
      ),
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
