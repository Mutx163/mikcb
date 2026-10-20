import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../timetable_page_chrome_shell.dart';

/// 月视图工具行的高度（逻辑 px）。玻璃带的几何按它算，写歪了带底与工具行
/// 错开几像素，读成一条横贯屏幕的缝（见 [MonthViewToolbar]）。
///
/// **必须与周/日视图的星期栏（`TimetableWeekdayHeader.height` = 40）同高**：
/// 顶栏总高 = 标题行 44 + 这一行。曾经取 48（IconButton 的默认点击尺寸），
/// 结果月视图顶栏比周/日视图高出 8px —— 用户 2026-10-20 实测提出
/// 「为什么和日视图周视图的顶栏不一样高」。`visualDensity: compact` 的
/// IconButton 实测恰好 40（探针证实），40 下按钮不裁内容、点击区仍达标。
/// 再动这个数之前先想清楚：它决定的是「顶栏总高与首页三视图是否一致」。
///
/// 常量住在 widgets 层而不是页面里：页面（screens 层）与工具行（widgets 层）
/// 必须取同一个值，而 widgets **不许 import screens**（依赖守卫会拦）。
const double kMonthViewToolbarHeight = 40;

/// 月视图工具行：‹ 上月 · 年月 · 下月 ›（+ 非本月时的「回到本月」）。
///
/// ## 为什么是一个独立 widget 而不是页面里的一个方法
///
/// 它的墨色来自 [HomePageChromeInk] 作用域 —— 那是外壳按**壁纸亮度**判好的
/// 极性。如果页面在自己的 `build` 里调方法就去读那个作用域，读到的会是页面
/// 自己的 context（在作用域**外面**），只能拿到 null 并回落主题色；深色壁纸上
/// 就成了看不见的字。做成 widget，build 就跑在外壳内部，能正确读到作用域。
///
/// 高度由 [kMonthViewToolbarHeight] 钉死，调用方必须用同一个常量 —— 玻璃带的
/// 几何按它算，写歪了带底与工具行错开几像素，读成一条横贯屏幕的缝。
class MonthViewToolbar extends StatelessWidget {
  const MonthViewToolbar({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onBackToCurrentMonth,
    super.key,
  });

  final int year;
  final int month;

  /// 当前聚焦的是不是「本月」：是就不再给「回到本月」按钮（按了也不动）。
  final bool isCurrentMonth;

  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onBackToCurrentMonth;

  /// 工具行高度。与调用方给外壳的 `toolbarHeight` 必须同值。
  static const double height = kMonthViewToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 作用域里没有时回落主题墨色：无壁纸的纯色页上这就是正确值。
    final ink =
        HomePageChromeInk.foregroundOf(context) ??
        Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        const SizedBox(width: 4),
        IconButton(
          onPressed: onPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
          color: ink,
          tooltip: l10n.monthViewPreviousMonth,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            l10n.monthViewHeaderTitle(year, month),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        IconButton(
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
          color: ink,
          tooltip: l10n.monthViewNextMonth,
          visualDensity: VisualDensity.compact,
        ),
        // 两条分支都给同样宽的尾部，标题才不会左右跳（本月 40 / 非本月 40+4）。
        if (isCurrentMonth)
          const SizedBox(width: 44)
        else
          IconButton(
            onPressed: onBackToCurrentMonth,
            icon: const Icon(Icons.today_rounded),
            color: ink,
            tooltip: l10n.monthViewBackToCurrentMonth,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
