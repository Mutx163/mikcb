import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'month_metrics.dart';

/// 月视图导航行的历史名字（**已迁到卡内**，2026-10-23）。
///
/// 它原本是"外壳工具行"的高度。导航搬进 `MonthCalendarCard` 之后，页面不再
/// 用它算顶栏几何（玻璃带只剩标题行），但**值仍然是 40** ——
/// 与周/日视图的星期栏同高，三个视图的顶栏才不会分家
/// （用户 2026-10-20 报过「为什么和日视图周视图的顶栏不一样高」）。
///
/// 保留这个名字只为一件事：既有契约测试按它钉住"40"这条口径。
/// 新的调用方请用 `MonthMetrics.calendarNavHeight` / `MonthCalendarCard.navHeight`。
const double kMonthViewToolbarHeight = MonthMetrics.calendarNavHeight;

/// 月视图的**月份切换行**：`‹  2026年10月  ›`（非本月时尾部再加「今天」）。
///
/// ## 2026-10-23：从"玻璃带上的一条工具行"改成"日历卡的表头"
///
/// 用户口径：「顶部的 2026年10月，左右按钮，回今日区域，看看这些能不能和下面的
/// 日期做一下整体化」。
///
/// 它原先住在满宽玻璃带里，与下面那张 8dp 外沿 + 24 圆角的日历白卡之间隔着一圈
/// 壁纸。而它控制的正是那张卡 —— 读起来是"上面的仪表盘在遥控下面的表格"。
/// 现在它被摆进 `MonthCalendarCard` 的卡顶，成为卡的一部分：
///
/// * 左右内边距与卡内内容同一条轴（[MonthMetrics.cardPadding]），
/// * 墨色跟**卡面**走（不再走 `HomePageChromeInk` 的壁纸极性 —— 卡是白的），
/// * 箭头不再是"圆底按钮"，改成**无底**的点击区：卡内已经有明确边界，
///   再叠一圈圆底会在白卡上画出一排灰点。
///
/// ## 保留的设计（2026-10-21 的成果，不要回退）
///
/// * 标题**跟着手指连续滑动**（读 [pageListenable]）：滑到一半能看到两个月份
///   各露一半，翻页不是突变；
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

  /// 导航行高度。与 `MonthCalendarCard.navHeight` 必须同值。
  static const double height = MonthMetrics.calendarNavHeight;

  /// 左右箭头的**命中**尺寸（正方形）。
  ///
  /// 视觉图标只有 20，但命中区 40 —— 卡内导航不需要圆形底，同时不能缩小
  /// 可点范围（手指点 20dp 的图标很容易点空）。
  static const double arrowSize = 40;

  /// 尾部槽位宽度：「今天」药丸与箭头同宽，本月空着时也不会让标题偏移。
  static const double trailingSlotWidth = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // ⚠️ 卡内墨色：**跟卡面走**，不走 `HomePageChromeInk`。
    // 那个作用域回答的是"字压在壁纸上该黑还是白"，而这一行现在躺在白卡里 ——
    // 暗壁纸下它会给出白字，白压白直接看不见（2026-10-21 同族事故）。
    final ink = colorScheme.onSurface;
    final muted = ink.withValues(alpha: MonthInk.tertiary);

    return Padding(
      // 与卡内内容同一条左轴（22 = 卡外沿 8 + 卡内边距 14）。
      padding: const EdgeInsets.symmetric(horizontal: MonthMetrics.cardPadding),
      child: Row(
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
      ),
    );
  }
}

/// 卡内箭头：**无底**的可点图标。
///
/// 旧版是 40dp 的圆形浅底。进了白卡之后，卡本身已经是一块明确的容器，
/// 再给箭头垫一圈灰底会在白卡顶部画出一排"灰点"，把卡切碎 ——
/// 小米日历 / 系统日历在这一行都是裸箭头。
///
/// 命中区仍是 40×40（`SizedBox`），只是视觉不再有底色。
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
            child: Icon(
              icon,
              size: 20,
              // 比正文淡一档：箭头是导航，不该和月份标题抢注意力。
              color: ink.withValues(alpha: MonthInk.tertiary),
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
    final l10n = AppLocalizations.of(context)!;
    final listenable = pageListenable;
    final readPage = pageOf;
    final toMonth = monthOfPage;
    if (listenable == null || readPage == null || toMonth == null) {
      return Center(child: _labelText(l10n, year, month));
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
          return Center(child: _labelText(l10n, year, month));
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
                        child: _labelText(l10n, current.year, current.month),
                      ),
                    ),
                  ),
                  // 下一页：从右侧跟进来。
                  Transform.translate(
                    offset: Offset(w * (1 - frac), 0),
                    child: SizedBox(
                      width: w,
                      child: Center(
                        child: _labelText(l10n, next.year, next.month),
                      ),
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
  /// 两段都来自 l10n（`monthViewYearSegment` / `monthViewMonthSegment`），
  /// 语序与后缀由各语言自己决定：中文「2026年 / 10月」、英文「2026/ / 10」。
  Widget _labelText(AppLocalizations l10n, int y, int m) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          l10n.monthViewYearSegment(y),
          maxLines: 1,
          style: TextStyle(
            fontSize: MonthType.body,
            fontWeight: FontWeight.w600,
            color: muted,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          l10n.monthViewMonthSegment(m),
          maxLines: 1,
          style: TextStyle(
            fontSize: MonthType.display,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: 0.2,
          ),
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
            // 卡内墨色的 8%：白卡上这只药丸要"能按"，但不能像第二个按钮组。
            color: ink.withValues(alpha: MonthInk.fill),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: MonthType.body,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
