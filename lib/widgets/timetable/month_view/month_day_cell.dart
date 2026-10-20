import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
import '../../course_surface.dart';

/// 月视图单格（日期数字 + 事项圆点 + 假期/调休标）。
///
/// 视觉口径**与周视图/日视图一致**（2026-10-20 用户口径：「应该要跟周视图、
/// 日视图保持一致风格，现在差太远了，就像是一个设置里面的二级页面一样」）：
/// - 底色是**首页壁纸**，不是设置页的纯色页；
/// - 卡片材质走 [CourseSurface]，与课程卡/日视图议程卡同一条路径、同一档
///   （[dayViewContentCardSurfaceStyle]），用户调什么材质这里就是什么；
/// - 圆角、判墨（壁纸亮时用深墨）都跟首页同源。
///
/// 纯展示：所有判定结果由 [MonthDayEntry] 带进来，本部件不做取数、不读
/// provider。密度取舍见 `.agents/notes/implemented/feature/2026-10-20-month-view.md`：
/// 格子宽约屏宽/7，只表达「有没有」，不写课程名。
class MonthDayCell extends StatelessWidget {
  const MonthDayCell({
    super.key,
    required this.entry,
    required this.settings,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.courseDotBudget = 3,
    this.radius = 16,
    this.inkOverride,
  });

  final MonthDayEntry entry;
  final TimetableSettings settings;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final int courseDotBudget;
  final double radius;

  /// 壁纸上的判定墨色（由页面按壁纸亮度算好传入，见 [monthCellInkColor]）。
  final Color? inkOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backdropBlurOn = HyperosBlurredHeader.backdropBlurEnabled(context);

    // 判墨与首页同一套：卡片真的把壁纸透出来时按壁纸亮度自动黑白，
    // 否则跟主题走（理由见 `contentCardInkOverWallpaper`）。
    final ink = inkOverride ?? colorScheme.onSurface;
    final mutedInk = ink.withValues(alpha: 0.55);
    // 月外日期淡显（前后月补位格）。
    final dayInk = entry.isOutsideMonth
        ? mutedInk.withValues(alpha: 0.45)
        : (entry.isHoliday ? monthHolidayInk(colorScheme) : ink);

    // 假期/调休优先于圆点：一格只有一个位置，语义标比数量点更重要。
    final badge = entry.isAdjustedWorkday
        ? (l10n.monthViewAdjustedWorkdayBadge, monthWorkdayBadgeInk(colorScheme))
        : entry.isHoliday
        ? (l10n.monthViewHolidayBadge, monthHolidayInk(colorScheme))
        : null;

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

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${entry.date.day}',
            style: TextStyle(
              fontSize: isToday ? 15 : 14,
              height: 1.1,
              fontWeight: isToday || isSelected
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: dayInk,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge != null)
                  MonthBadge(text: badge.$1, color: badge.$2)
                else
                  ...dots,
              ],
            ),
          ),
        ],
      ),
    );

    // 今天 / 选中用**边框与色块**表达，不换材质：与首页课程卡选中态同一种语言。
    final surfaceColor = isSelected
        ? colorScheme.primary
        : (isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest);
    final border = isToday
        ? Border.all(color: colorScheme.primary, width: 1.4)
        : null;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticsLabel(l10n),
      child: CourseSurface(
        style: dayViewContentCardSurfaceStyle(
          settings,
          backdropBlurOn: backdropBlurOn,
        ),
        color: surfaceColor,
        borderRadius: radius,
        opacityScale: entry.isOutsideMonth ? 0.55 : 1,
        border: border,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('month-day-cell-${_dateKey(entry.date)}'),
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: content,
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

/// 格子里的文字墨色：按**壁纸亮度**判定，与首页同一条判据。
///
/// 卡面真的透出壁纸时（玻璃/磨砂档且有壁纸），暗壁纸配浅墨、亮壁纸配深墨；
/// 否则跟主题走——只看壁纸亮度会在没有壁纸的纯色页上判反。
Color monthCellInkColor(
  BuildContext context,
  TimetableSettings settings, {
  required double? wallpaperBodyLuminance,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final hasBackdrop = hasHomePageBackdrop(settings);
  final blurOn = HyperosBlurredHeader.backdropBlurEnabled(context);
  final translucent = blurOn && hasBackdrop;
  if (!translucent || wallpaperBodyLuminance == null) {
    return colorScheme.onSurface;
  }
  // 壁纸深 → 浅墨（白）；壁纸浅 → 深墨。阈值与首页 chrome 一致（0.45）。
  return wallpaperBodyLuminance < 0.45
      ? Colors.white.withValues(alpha: 0.92)
      : Colors.black.withValues(alpha: 0.82);
}

/// 假期日数字/标：与周视图「假期灰显」同语义的暖红。
Color monthHolidayInk(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFFFF7A72)
      : const Color(0xFFD93025);
}

/// 调休上班日「班」标色。
Color monthWorkdayBadgeInk(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFF7FB4FF)
      : const Color(0xFF1A66D6);
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
/// ⚠️ 这里**刻意不用 `colorScheme.primary`**：真机截图里用户主题是青绿色，
/// 「课程点（青绿）+ 日程点（primary，同青绿）」并排时看着像同一个意思
/// 说了两遍，语义彻底失效。语义色必须与主题色解耦。
Color monthScheduleDotColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFF6AA8FF)
      : const Color(0xFF3B82F6);
}

/// 事项圆点：5dp 圆。
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
      style: TextStyle(
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
