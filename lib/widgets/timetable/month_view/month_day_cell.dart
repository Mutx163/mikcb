import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/card_surface_ink.dart';
import '../../../utils/hex_color.dart';
import '../../../utils/home_page_background.dart';
import '../../../utils/month_cell_ink.dart';
import '../../course_surface.dart';
import 'month_metrics.dart';

/// 月视图单格（日期数字 + 事项圆点 + 假期/调休标）。
///
/// 视觉口径**与周视图/日视图一致**（2026-10-20 用户口径：「应该要跟周视图、
/// 日视图保持一致风格，现在差太远了，就像是一个设置里面的二级页面一样」）：
/// - 底色是**首页壁纸**，不是设置页的纯色页；
/// - 卡片材质走 [CourseSurface]，与课程卡/日视图议程卡同一条路径、同一档
///   （[dayViewContentCardSurfaceStyle]），用户调什么材质这里就是什么；
/// - 圆角、判墨（壁纸亮时用深墨）都跟首页同源。
///
/// ## 判墨是**逐格**的（2026-10-21 专业评审 P0-1）
///
/// 旧实现由页面按「主体带平均亮度」算出**一个**墨色，42 个格子共用。真机上同一
/// 屏壁纸自上而下亮度 0.56 → 0.23，卡面填充跟着走同一条坡，于是同一个黑字在
/// 42 格上的实测对比度从 12:1 掉到 5:1，月外日期（再叠两层弱化）掉到 **1.97:1**。
///
/// 现在每格自己算：页面把「这一行背后那段壁纸的亮度」按行传进来（[rowLuminance]），
/// 本组件据此算出**这张卡的真实卡面亮度**，再按 WCAG 对比度选墨。判据全部在
/// `utils/month_cell_ink.dart`（纯 Dart，`test/utils/` 覆盖）。
///
/// ## 弱化不是"变淡"
///
/// 月外日期（前后月补位）仍然要弱，但**弱化的手段**换了：旧实现乘两次 alpha
/// （墨 0.45 × 整卡 0.55），把墨与卡面的亮度差吃掉了；现在按对比度弱化 ——
/// 推到「刚好还读得出」（3.2:1）为止（[dimInkToContrast]）。浅卡面上它照样明显
/// 更淡，深卡面上几乎不淡 —— 因为那里已经没有可淡的空间。
class MonthDayCell extends StatelessWidget {
  const MonthDayCell({
    super.key,
    required this.entry,
    required this.settings,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.courseDotBudget = 3,
    this.radius = MonthMetrics.cardRadius,
    this.rowLuminance,
    this.inkOverride,
  });

  final MonthDayEntry entry;
  final TimetableSettings settings;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final int courseDotBudget;
  final double radius;

  /// **这一行**背后那段壁纸的亮度（由页面按行算好，见 `monthRowLuminances`）。
  ///
  /// null = 剖面还没采到 / 没有壁纸：回落到 [inkOverride]（整屏带判出的墨色），
  /// 再回落到主题墨色 —— 与改动前逐字相同的兜底链，不会比原来更差。
  final double? rowLuminance;

  /// 整屏带判出的墨色（旧口径）。仅在 [rowLuminance] 为 null 时使用。
  final Color? inkOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backdropBlurOn = HyperosBlurredHeader.backdropBlurEnabled(context);

    // 卡面底色：与渲染层同一个取法（深色取 surface、浅色取
    // surfaceContainerHighest）。判墨必须拿它去混壁纸，不能只看壁纸。
    final fill = isSelected
        ? colorScheme.primary
        : (isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest);
    final style = dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: backdropBlurOn,
    );
    // 月外日期整卡减淡：**这是渲染层的透明度**（0.55），判墨时必须把它算进
    // 卡面亮度里 —— 否则会按"满不透明"的卡面判墨，而实际卡面比那亮/暗得多。
    final opacityScale = entry.isOutsideMonth ? 0.55 : 1.0;
    final washAlpha = CourseSurface.washAlpha(
      context,
      style,
      opacityScale: opacityScale,
    );

    final rowLuminance = this.rowLuminance;
    // 卡面实际亮度：自有底色 × 染色比例 + 背后壁纸 × 其余。
    final surface = rowLuminance == null
        ? null
        : monthCellSurfaceLuminance(
            fill: fill,
            washAlpha: washAlpha,
            wallpaperLuminance: rowLuminance,
          );

    final Color ink;
    if (surface != null) {
      ink = monthCellInkFor(
        wallpaperLuminance: rowLuminance!,
        fill: fill,
        washAlpha: washAlpha,
      );
    } else {
      ink = inkOverride ?? colorScheme.onSurface;
    }

    // 月外日期：按对比度弱化到「刚好读得出」，而不是再乘一个 alpha。
    final baseInk = surface == null
        ? (entry.isOutsideMonth ? ink.withValues(alpha: 0.55) : ink)
        : ink;
    final dayInk = entry.isHoliday && !entry.isOutsideMonth
        ? monthHolidayInk(colorScheme)
        : (entry.isOutsideMonth && surface != null
              ? dimInkToContrast(baseInk, surface)
              : baseInk);

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
            // 课程点用课程自身颜色，与卡面撞色是常态（浅粉课压浅色卡面实测
            // 1.01:1）。所以：① 对比不达标时压明度保色相；② 一律加一圈卡面墨色
            // 描边 —— 描边色取**墨色**而不是主题背景色（后者在外壳里是
            // transparent，等于没画，这正是旧实现 outlined 从未生效的原因）。
            surfaceLuminance: surface,
            outlineColor: monthDotOutlineColor(ink),
          ),
      if (entry.examCount > 0)
        MonthDot(
          color: monthExamDotColor(colorScheme),
          surfaceLuminance: surface,
          outlineColor: monthDotOutlineColor(ink),
        ),
      if (entry.scheduleCount > 0)
        MonthDot(
          color: monthScheduleDotColor(colorScheme),
          surfaceLuminance: surface,
          outlineColor: monthDotOutlineColor(ink),
        ),
    ];

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${entry.date.day}',
            maxLines: 1,
            style: TextStyle(
              fontSize: MonthType.dayNumber,
              height: 1.1,
              fontWeight: isToday || isSelected
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: dayInk,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            // 圆点从 5dp 长到 8dp 后这一行要跟着长高，否则会被上下裁掉边。
            height: MonthDot.extent,
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
    //
    // ⚠️ 边框色要能压在选中态（primary 色块）上：选中格用 primary 底时，
    // primary 边框在同色块上是隐形的，所以今天环改用卡面墨色。
    final border = isToday
        ? Border.all(
            color: isSelected ? ink : colorScheme.primary,
            width: 1.4,
          )
        : null;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticsLabel(l10n),
      child: CourseSurface(
        style: style,
        color: fill,
        borderRadius: radius,
        opacityScale: opacityScale,
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

/// 月视图整页的**墨色兜底口径**（表头 / 行标 / 议程行共用这一处）。
///
/// 这是**整屏带**版本，只在逐行剖面拿不到时使用（见 [MonthDayCell.rowLuminance]）。
/// 有剖面时日期格一律走 `monthCellInkFor` 的逐格判据 —— 一个数管 42 格必然错掉
/// 一头，那是评审里最要紧的一条。
///
/// 与日视图的卡统一走 [cardSurfaceInk]：按「卡面压在壁纸上的混合亮度」判黑白，
/// 判据是**黑/白各自的对比度**（等价于在 0.20 处翻转），不是裸壁纸亮度。
///
/// [wallpaperBodyLuminance] 是整屏 body 带：表头与周次轨贴着网格上沿，没有
/// 逐行数据可用，整带口径对它们仍然成立。
Color monthPageInkOverWallpaper({
  required BuildContext context,
  required TimetableSettings settings,
  required double? wallpaperBodyLuminance,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final blurOn = HyperosBlurredHeader.backdropBlurEnabled(context);
  final glassOverWallpaper = blurOn && hasHomePageBackdrop(settings);
  return cardSurfaceInk(
    // 与 [MonthDayCell] 里真正的卡底色同一份取法（深色取 surface、浅色取
    // surfaceContainerHighest）。两处必须同源，否则「按卡面判墨」判的是另一张卡。
    fill: isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest,
    // 卡面把壁纸透出来的比例 —— 与渲染层同一个函数，不另写一份（实体档它
    // 返回 1，此时壁纸亮度不参与计算，正好等价于「实体卡按主题判墨」）。
    washAlpha: CourseSurface.washAlpha(
      context,
      dayViewContentCardSurfaceStyle(settings, backdropBlurOn: blurOn),
    ),
    // 不透壁纸时传 null：卡面亮度算不出来，按主题墨色走。
    wallpaperLuminance: glassOverWallpaper ? wallpaperBodyLuminance : null,
    fallback: colorScheme.onSurface,
  );
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

/// 事项圆点：8dp 圆。
///
/// ## 为什么是 8 而不是 5
///
/// 旧实现 5dp。8dp 是「一眼能分辨形状」的下限（随手截图量过：5dp 在 393dp 宽
/// 的屏上只有 1.5% 宽，压在纹理复杂的照片上直接消失，实测课程点对比度
/// **1.01:1** —— 不是偏淡，是等于没有）。
///
/// [outlineColor] 给一圈描边：课程点用的是课程自身颜色，与卡面撞色是常态，
/// 描边是唯一能保证"边界看得见"的手段。旧实现的 `outlined: true` 取
/// `scaffoldBackgroundColor` —— 独立页外壳里那是 **transparent**，从来没画出来。
class MonthDot extends StatelessWidget {
  const MonthDot({
    super.key,
    required this.color,
    this.surfaceLuminance,
    this.outlineColor,
  });

  final Color color;

  /// 卡面亮度：给了就保证圆点与卡面 ≥3:1（不达标时压明度、保色相）。
  final double? surfaceLuminance;

  /// 描边色（卡面墨色）。null = 不描边。
  final Color? outlineColor;

  /// 圆点直径。
  static const double diameter = 8;

  /// 圆点行占的高度（含描边外扩，避免被裁）。
  static const double extent = 10;

  @override
  Widget build(BuildContext context) {
    final luminance = surfaceLuminance;
    final dot = luminance == null
        ? color
        : readableMonthDotColor(color, luminance);
    // 先落到局部变量再判空：`outlineColor` 是 public field，Dart 不对它做
    // 类型提升（non-promo public field），直接 `outlineColor` 传进去会因为
    // 类型是 `Color?` 报 argument_type_not_assignable。
    final outline = outlineColor;
    return Container(
      width: diameter,
      height: diameter,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: dot,
        shape: BoxShape.circle,
        border: outline == null ? null : Border.all(color: outline),
      ),
    );
  }
}

/// 「休 / 班」小字标（假期与调休上班日）。
///
/// 字号从 9 提到 [MonthType.caption]（11）：9px 在真机上实测 cap height 只有
/// ~6px，中文字符在这个尺寸上已经辨认不出笔画（截图里"休"和"班"糊成小块）。
class MonthBadge extends StatelessWidget {
  const MonthBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: MonthType.caption,
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
