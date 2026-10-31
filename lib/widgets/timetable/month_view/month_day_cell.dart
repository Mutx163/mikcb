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

/// 月视图单格（日期数字 + 底边分段色带 + 假期/调休角标）。
///
/// ## 2026-10-23：格子不再是一张卡，而是「白卡里的一格」
///
/// 用户拿小米日历截图提的口径：「框框区域像这样」。上一版是 42 个格子各一张
/// 玻璃卡（`CourseSurface`），直接铺在壁纸上 —— 一屏 42 个边框，没有"一张表"
/// 的阅读单位，而且卡片材质会跟着用户的课程卡材质设置变，与"日历"这个语义无关。
///
/// 现在格子只负责**画内容**：底色由外面的 [MonthCalendarCard] 那张白卡提供。
/// 于是：
///
/// * 不再 import 课程卡材质（`CourseSurface` / `dayViewContentCardSurfaceStyle`）；
/// * 判墨不看壁纸（卡是实底白），一律按主题 —— 2026-10-21 那套「逐行壁纸亮度
///   判墨」是为"字压在壁纸上"设计的，格子进了白卡之后它不再成立（详见
///   `utils/month_cell_ink.dart` 顶部的说明）。
///
/// ## 选中 / 今天 / 假期怎么表达（不用卡片材质）
///
/// | 状态 | 表达 | 理由 |
/// |---|---|---|
/// | 选中 | primary **实心圆/圆角块** + 反白数字 | 小米日历同款，一眼看出选的是哪天 |
/// | 今天 | 数字用 primary 色、加粗 | 与「选中」区分：今天可能没被选中 |
/// | 假期 | 数字用暖红 + 右上角「休」 | 颜色即语义，不必再加底色 |
/// | 调休 | 右上角「班」（蓝） | 同上 |
/// | 月外 | 整体降低对比度（按对比度算，不乘 alpha） | 见 [dimInkToContrast] |
///
/// ## 色带仍然保留
///
/// 底边色带是「这天有没有课 / 考试 / 日程」的背景信号，一条连续色带**永不溢出**
/// （圆点在 43.86dp 格宽里 5 个要 55dp，实测溢出 14.57dp）。
class MonthDayCell extends StatelessWidget {
  const MonthDayCell({
    super.key,
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.courseStripBudget = 4,
    this.radius = MonthMetrics.cellRadius,
    this.surfaceLuminance,
  });

  final MonthDayEntry entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  /// 底边色带里最多画几段课程色（考试 / 日程会在此基础上再加一段）。
  ///
  /// 4 不是「装得下多少」而是「分不分得清」：一格 ~43dp 宽，4 段每段约 10dp，
  /// 仍是能分辨的色块；再多就成了一条渐变色带，颜色失去指向性。
  final int courseStripBudget;

  final double radius;

  /// 卡片底色（白卡）的亮度；null 时按主题明暗自己取。
  ///
  /// 只用于**月外日期**的对比度弱化：弱化要按"墨与卡面的对比度"算，不能乘
  /// alpha（乘 alpha 会把墨与卡面的亮度差一起吃掉，那是 2026-10-22 修过的坑）。
  final double? surfaceLuminance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 卡面墨色：白卡上就是主题墨。**不跟壁纸走** —— 卡是实底的。
    final ink = colorScheme.onSurface;
    // 卡面亮度只用于「月外日期按对比度弱化」这一件事。
    //
    // ⚠️ 旧写法在这里按 brightness 分了个叉，两个分支**算的是同一个值**
    // （都是 `colorScheme.surface.computeLuminance()`）—— 分叉是漏改一半的
    // 经典成因，这里直接消掉。
    final cardLuminance =
        surfaceLuminance ?? colorScheme.surface.computeLuminance();

    // 假期 / 调休在卡面上是彩色角标，判据仍是"与自己那档色对比够不够"。
    final badge = entry.isAdjustedWorkday
        ? (
            l10n.monthViewAdjustedWorkdayBadge,
            monthWorkdayBadgeInk(colorScheme),
          )
        : entry.isHoliday
        ? (l10n.monthViewHolidayBadge, monthHolidayInk(colorScheme))
        : null;

    // ── 日号墨色 ──
    //
    // 四种情况按优先级排：选中（压在 primary 块上）→ 今天 → 假期 → 普通。
    // 月外日期最后统一按对比度弱化。
    final Color dayInk;
    if (isSelected) {
      // 选中块是 primary 实心：数字必须反白/反暗，按 primary 自身亮度取。
      dayInk =
          colorScheme.onPrimary.computeLuminance() >
              colorScheme.primary.computeLuminance()
          ? colorScheme.onPrimary
          : colorScheme.onSurface;
    } else if (isToday) {
      dayInk = colorScheme.primary;
    } else if (entry.isHoliday) {
      dayInk = monthHolidayInk(colorScheme);
    } else {
      dayInk = ink;
    }

    // 月外日期：按**对比度**弱化到「刚好读得出」，而不是再乘一个 alpha。
    final resolvedDayInk =
        entry.isOutsideMonth && !isSelected && !isToday && !entry.isHoliday
        ? dimInkToContrast(dayInk, cardLuminance)
        : dayInk;

    // ── 底边分段色带 ──
    //
    // 顺序与含义不变：课程色（最多 4 段）→ 考试红 → 日程蓝。
    final strips = <Color>[
      for (var i = 0; i < entry.courseColorHexes.length; i++)
        if (i < courseStripBudget)
          parseHexColorOrFallback(
            entry.courseColorHexes[i],
            fallback: colorScheme.primary,
          ),
      if (entry.examCount > 0) monthExamDotColor(colorScheme),
      if (entry.scheduleCount > 0) monthScheduleDotColor(colorScheme),
    ];
    // 月外格不画色带：它们是邻月的日子，不该在本月里"浮出来"（哪怕那天有课）——
    // 否则同一批格子翻月后会有两种长相。
    final showStrips = strips.isNotEmpty && !entry.isOutsideMonth;

    final content = Column(
      // ⚠️ 日号与色带槽位必须**紧挨着作为一个整体居中**（2026-10-23 真机截图）：
      // 旧写法把日号放进 `Expanded` 居中、色带钉在格子底部，于是在 48dp 高的
      // 行里两者被拉开 ~20dp —— 色带读起来像"悬在行中间的一根横线"，
      // 跟上面哪个日期都对不上。现在是一组：数字 + 5dp + 色带槽位。
      //
      // ⚠️ **槽位高度恒定**（2026-10-25）：这一组的总高必须与"有没有色带"无关，
      // 否则有课的那天日号会被顶上去 4px、没课的那天沉下来 —— 同一行七个数字
      // 高低错落（真机逐像素量过：顶边 271/275，离散 4px）。详见
      // `MonthMetrics.cellStripSlotHeight`。
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${entry.date.day}',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            fontSize: MonthType.dayNumber,
            height: 1.1,
            fontWeight: isToday || isSelected
                ? FontWeight.w800
                : FontWeight.w600,
            color: resolvedDayInk,
          ),
        ),
        // 色带槽位：**恒在**。有内容时画色带，没有时留空 —— 但高度不变，
        // 所以日号在每一格里的位置都一样。
        SizedBox(
          height: MonthMetrics.cellStripSlotHeight,
          child: showStrips
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    // 色带贴到格子左右内沿（圆角由外层裁掉），看起来像从日期
                    // 下面长出来的一条，而不是浮在格子里的药丸。
                    //
                    // 左右各留 `cellInnerPadding`，让色带不与日期数字等宽 ——
                    // 等宽时读起来像"下划线"，留一点内缩才读作"标记条"。
                    padding: const EdgeInsets.symmetric(
                      horizontal: MonthMetrics.cellInnerPadding,
                    ),
                    child: SizedBox(
                      height: MonthMetrics.cellStripHeight,
                      child: Row(
                        // ⚠️ 必须 stretch：`ColoredBox` 无子节点时高度是 0，
                        // 默认的 center 会让整条色带塌成看不见（本地实测过一次）。
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final color in strips)
                            Expanded(child: ColoredBox(color: color)),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticsLabel(l10n),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('month-day-cell-${_dateKey(entry.date)}'),
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Stack(
            children: [
              // 选中态：整格一块 primary 圆角块（小米日历那种"药丸/圆块"）。
              if (isSelected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              // 今天但没选中：**淡底 + 主题色粗体数字**。
              //
              // ⚠️ 2026-10-25 从"描一圈 primary 细边"改成淡底：旧那圈边用了
              // `primary @ 0.55`，在真机截图里读起来是"一个灰圆环"，与选中态
              // 那块实心 primary 圆角块**像同一件事的两种画法** —— 用户分不清
              // "我选中了"和"今天是这天"。
              //
              // 现在两者的差别是**重量级**而不是样式级：今天 = 淡底（primary
              // 最浅一档），选中 = 实心 primary 块 + 反白数字。同屏出现时一眼
              // 能看出哪个是"被选中的那天"。
              if (isToday && !isSelected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: MonthInk.hairline,
                      ),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              Positioned.fill(child: content),
              if (badge != null)
                Positioned(
                  top: 1,
                  right: MonthMetrics.cellInnerPadding + 1,
                  child: MonthBadge(text: badge.$1, color: badge.$2),
                ),
            ],
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

/// 月视图里**压在壁纸上**的文字该用哪种墨（分区标题、日期标题）。
///
/// ⚠️ 只用于**卡外**文字。卡片里的字一律走 `monthInfoCardInk`（按卡面判）——
/// 2026-10-23 起格子与信息卡都是白卡，卡内不受壁纸影响；而分区标题
/// （「本月概览」「10月22日」）直接压在壁纸上，必须按壁纸亮度判。
///
/// 判据与日视图卡片同源（`cardSurfaceInk`）：按「卡面压在壁纸上的混合亮度」
/// 选黑白，等价于在 0.20 处翻转，不是裸壁纸亮度 —— 只取壁纸会把浅色主题下
/// 被冲白的卡面判成深字。
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
    fill: isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest,
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

/// 考试强调色：固定红系，**不跟主题走**。
///
/// 用 `colorScheme.error` 会遇到「用户主题本身就是红/橙」时与课程色撞色；
/// 这里取一个在明暗主题下都读作"考试"的固定红。
Color monthExamDotColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFFFF6B6B)
      : const Color(0xFFE5484D);
}

/// 日程强调色：固定蓝系，与考试红、课程自身色三者互相可辨。
///
/// ⚠️ 这里**刻意不用 `colorScheme.primary`**：真机截图里用户主题是青绿色，
/// 「课程色（青绿）+ 日程色（primary，同青绿）」并排时看着像同一个意思
/// 说了两遍，语义彻底失效。语义色必须与主题色解耦。
Color monthScheduleDotColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFF6AA8FF)
      : const Color(0xFF3B82F6);
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

/// 事项圆点：8dp 圆。
///
/// ## 2026-10-22：圆点已被**底边色带**取代，本类只剩兼容
///
/// 换成色带的原因是硬约束 —— 一格实测 **43.86dp** 宽、内容区 40.43dp：
///
/// | 标记数 | 需要的宽度 | 结果 |
/// |---|---|---|
/// | 3 | 33dp | 装得下 |
/// | 4 | 44dp | 溢出 3.57dp |
/// | 5 | 55dp | 溢出 14.57dp |
///
/// 一天 5 个标记很常见（三门课 + 一场考试 + 一条日程）。而色带按格宽**均分**，
/// 段数再多也只是变窄，永远不会溢出。
///
/// 圆点本身没有删干净是为了两件事：① [diameter] / [extent] 仍是「标记必须
/// 看得见」这条口径的**记录值**（`test/utils/month_cell_ink_test.dart` 钉着），
/// ② `readableMonthDotColor` 的对比度保底逻辑现在被色带复用。
///
/// ⚠️ 别再把它接回 [MonthDayCell]：宽度问题不是调参数能解决的，见上表。
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

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
