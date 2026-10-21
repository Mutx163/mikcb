import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../timetable_page_chrome_shell.dart';

/// 月视图工具行的高度（逻辑 px）。玻璃带的几何按它算，写歪了带底与工具行
/// 错开几像素，读成一条横贯屏幕的缝（见 [MonthViewToolbar]）。
///
/// **必须与周/日视图的星期栏（`TimetableWeekdayHeader.height` = 40）同高**：
/// 顶栏总高 = 标题行 44 + 这一行。曾经取 48（IconButton 的默认点击尺寸），
/// 结果月视图顶栏比周/日视图高出 8px —— 用户 2026-10-20 实测提出
/// 「为什么和日视图周视图的顶栏不一样高」。本行所有控件都按 40 设计。
///
/// 常量住在 widgets 层而不是页面里：页面（screens 层）与工具行（widgets 层）
/// 必须取同一个值，而 widgets **不许 import screens**（依赖守卫会拦）。
const double kMonthViewToolbarHeight = 40;

/// 月视图的**月份切换行**：`‹  2026年10月  ›`（非本月时尾部再加「今天」）。
///
/// ## 重新设计（2026-10-21）
///
/// 用户口径：「月视图顶部那个月份显示，左右切换到那部分，重新设计一下」。
///
/// 旧版是「两个默认 `IconButton` + 一行 16px 文字」，三个问题：
///
/// 1. **文字与滑动无关**：左右滑时标题瞬间跳变，滚动过程中看不出正在翻向
///    哪个月，读起来像"卡一下才换"；
/// 2. **按钮不像按钮**：两个 chevron 裸贴在玻璃带上，没有可点击的观感；
/// 3. **尾部靠补等宽 `SizedBox` 对齐**：换文案长度时标题会偏。
///
/// 新版：
///
/// * 标题**跟着手指连续滑动**（读 [pageListenable]），滑到一半能看到两个月份
///   各露一半，翻页不再是突变；
/// * 两个箭头是 40×40 的**圆形浅底**按钮（与行高齐平），按下有明确反馈；
/// * 尾部是**固定宽度槽位**：本月空着、非本月放「今天」药丸 —— 标题可用宽度
///   恒定，永远居中。
class MonthViewToolbar extends StatelessWidget {
  const MonthViewToolbar({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onBackToCurrentMonth,
    this.pageListenable,
    this.pageOf,
    this.monthOfPage,
    super.key,
  });

  final int year;
  final int month;

  /// 当前聚焦的是不是「本月」：是就不再给「今天」按钮（按了也不动）。
  final bool isCurrentMonth;

  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onBackToCurrentMonth;

  /// 翻页控制器（传 `PageController` 即可）：让标题**跟着手指连续滑动**。
  ///
  /// 三件套（本参数 + [pageOf] + [monthOfPage]）任一为 null 时退化成
  /// 「只显示当前月、不做过渡」—— 观感差一档，但功能与布局都不丢，
  /// 也便于单独预览这一行。
  final Listenable? pageListenable;

  /// 当前页码（`PageController.page`），需要它才能算出"滑到几成"。
  final double Function()? pageOf;

  /// 页码 → (年, 月)。
  final ({int year, int month}) Function(int page)? monthOfPage;

  /// 工具行高度。与调用方给外壳的 `toolbarHeight` 必须同值。
  static const double height = kMonthViewToolbarHeight;

  /// 左右箭头的命中尺寸（正方形，与行高齐平）。
  static const double arrowSize = kMonthViewToolbarHeight;

  /// 尾部槽位宽度：「今天」药丸与箭头同宽，本月空着时也不会让标题偏移。
  static const double trailingSlotWidth = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 作用域里没有时回落主题墨色：无壁纸的纯色页上这就是正确值。
    final ink =
        HomePageChromeInk.foregroundOf(context) ??
        Theme.of(context).colorScheme.onSurface;
    // mutedOf 自带回落（onSurfaceVariant），不需要再给 ??。
    final muted = HomePageChromeInk.mutedOf(context);

    return Row(
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: l10n.monthViewPreviousMonth,
          ink: ink,
          onTap: onPreviousMonth,
        ),
        Expanded(
          child: _MonthTitle(
            year: year,
            month: month,
            ink: ink,
            muted: muted,
            pageListenable: pageListenable,
            pageOf: pageOf,
            monthOfPage: monthOfPage,
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: l10n.monthViewNextMonth,
          ink: ink,
          onTap: onNextMonth,
        ),
        // 尾部固定槽位：本月留空（同宽），非本月放「今天」。
        // 标题的可用宽度因此恒定，不会因为多出/少掉一个按钮而左右跳。
        SizedBox(
          width: trailingSlotWidth,
          child: isCurrentMonth
              ? null
              : Center(
                  child: _TodayPill(
                    label: l10n.monthViewBackToCurrentMonthShort,
                    ink: ink,
                    onTap: onBackToCurrentMonth,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 圆形浅底箭头按钮。
///
/// 用 [InkResponse] 而不是 `IconButton`：后者的水波纹是矩形，在一个只有 40 高
/// 的行里看着像"一块方形亮斑"。这里给圆形 + 极淡静态底，静止时干净、
/// 按下有明确反馈。
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MonthViewToolbar.arrowSize,
      height: MonthViewToolbar.arrowSize,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: MonthViewToolbar.arrowSize / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 6% 的墨色：看得见"这里能按"，又不抢标题。
                color: ink.withValues(alpha: 0.06),
              ),
              child: Icon(icon, size: 22, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// 月份标题：**跟随翻页连续滑动**。
///
/// 有控制器时同时渲染「当前页 / 下一页」两段，按滑动比例横向平移 ——
/// 手指拖到一半能看到两个月份各露一半；没有控制器时就是一段静止文字。
class _MonthTitle extends StatelessWidget {
  const _MonthTitle({
    required this.year,
    required this.month,
    required this.ink,
    required this.muted,
    required this.pageListenable,
    required this.pageOf,
    required this.monthOfPage,
  });

  final int year;
  final int month;
  final Color ink;
  final Color muted;
  final Listenable? pageListenable;
  final double Function()? pageOf;
  final ({int year, int month}) Function(int page)? monthOfPage;

  @override
  Widget build(BuildContext context) {
    final listenable = pageListenable;
    final readPage = pageOf;
    final toMonth = monthOfPage;
    if (listenable == null || readPage == null || toMonth == null) {
      return Center(child: _labelText(year, month));
    }
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        // readPage 抛异常就整页崩（PageController 在 PageView 建好前访问会断言
        // 失败）。调用方本该自己保护，这里再兜一道：宁可标题少一帧过渡，
        // 也不能让页面白屏。
        double page;
        try {
          page = readPage();
        } catch (_) {
          return Center(child: _labelText(year, month));
        }
        final base = page.floor();
        // 滑到几成：只在 0..1 之间用，越界（回弹）时钳住，避免标题飞出容器。
        final frac = (page - base).clamp(0.0, 1.0);
        final current = toMonth(base);
        final next = toMonth(base + 1);
        return ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 当前月：随手指向左移出。
                  Transform.translate(
                    offset: Offset(-w * frac, 0),
                    child: SizedBox(
                      width: w,
                      child: Center(
                        child: _labelText(current.year, current.month),
                      ),
                    ),
                  ),
                  // 下一页：从右侧跟进来。
                  Transform.translate(
                    offset: Offset(w * (1 - frac), 0),
                    child: SizedBox(
                      width: w,
                      child: Center(child: _labelText(next.year, next.month)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// `2026年` + `10月`：年份弱色小一号，月份是主体。
  ///
  /// 系统日历的通行做法 —— 一眼要读的是"哪个月"，年份只是上下文。
  /// 文案本身仍拼自 l10n（不重排语序假设），只是把两个数字段分开放。
  Widget _labelText(int y, int m) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$y年',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.1,
          ),
          maxLines: 1,
        ),
        const SizedBox(width: 3),
        Text(
          '$m月',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

/// 「今天」药丸：非本月时出现，点一下回到本月。
class _TodayPill extends StatelessWidget {
  const _TodayPill({
    required this.label,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: ink.withValues(alpha: 0.08),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
