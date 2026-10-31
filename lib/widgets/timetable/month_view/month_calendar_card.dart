import 'package:flutter/material.dart';

import 'month_grid_handle.dart';
import 'month_metrics.dart';

/// 月视图上半的**日历卡**：月份导航 + 星期表头 + 日期格 + 卡底拉杆（2026-10-23）。
///
/// ## 为什么月份导航要进这张卡（本轮的核心决定）
///
/// 用户口径：「顶部的 2026年10月、左右按钮、回今日区域，看看这些能不能和
/// 下面的日期做一下整体化」。
///
/// 改造前，页面竖向上并存**四种左沿、两种容器**：
///
/// | 层 | 左沿 | 容器 |
/// |---|---|---|
/// | 玻璃带（标题行 + 工具行） | 0（满宽） | 满宽带 |
/// | 工具行箭头 | 6 | 带内圆钮 |
/// | 日历白卡 | 8 | 浮卡（圆角 24） |
/// | 卡内文字 | 22 | — |
///
/// 而**月份导航控制的正是下面那张卡**：它切换的就是这张卡的日期格。
/// 把它放在满宽玻璃带里、与卡之间隔着一圈壁纸，读起来是"上面的仪表盘在
/// 遥控下面的表格"，两件事被拆成了两套视觉系统 —— 这就是"整体化"要解决的。
///
/// 专业做法（也是小米日历 / 系统日历的做法）：**导航是这张卡的表头**。
/// 于是现在卡片内部自上而下是：
///
/// ```text
/// ┌────────────────────────────┐
/// │ ‹      2026年 10月    ›  今天 │  ← 卡内导航行
/// │ 周一  周二  周三 ...          │  ← 星期表头
/// │  28   29   30   1   2 ...    │  ← 6 行日期格
/// │            ▬                │  ← 卡底拉杆
/// └────────────────────────────┘
/// ```
///
/// 一条左沿（22）、一个容器（这张卡）。玻璃带重新只负责"软件名 + 右上角菜单"，
/// 不再掺和日历，两种系统各自完整。
///
/// ## 拉杆为什么也在卡内
///
/// 它在视觉上属于这张日历卡（卡底那根条），所以放在卡的 ClipRRect 内部、
/// Column 的最后一项。拖它收放上面的日历表格 —— 归属没变，只是位置跟着卡走。
///
/// ## 高度账必须算清（这里踩过一次）
///
/// 卡片高度 = 导航行 + 表格内容 + 拉杆。页面给这张卡的高度是
/// `layout.gridHeight + MonthCalendarCard.chromeHeight`，其中
/// [chromeHeight] 同时含「卡底拉杆」与「卡顶导航行」两段 ——
/// **算漏任何一段，卡内 Column 都会 `RenderFlex overflowed`**
///（2026-10-23 实测过拉杆那段）。
class MonthCalendarCard extends StatelessWidget {
  const MonthCalendarCard({
    super.key,
    required this.child,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.navigator,
    this.contentTopPadding = MonthMetrics.cardPadding,
  });

  /// 卡片内容（星期表头 + 6 行日期格）。
  final Widget child;

  /// 卡顶的月份导航行（`‹ 2026年10月 › 今天`）。
  ///
  /// 由页面构建（它握着 pager 与回调），本组件只负责摆位置与分隔线。
  /// **null = 不画导航行**（组件级测试、或将来别的宿主不需要导航时用）——
  /// 此时卡片高度自动少 [navHeight]，不会留一条空白。
  final Widget? navigator;

  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  /// 导航行与表格之间的上边距。
  ///
  /// ⚠️ **默认不是 0**：卡片自己必须保证内容不贴卡边（2026-10-23 真机，
  /// 内容顶着 24 圆角读成"被裁过"）。页面传 `kMonthPageVerticalPadding`
  /// 覆盖它 —— 那笔账算的是 `monthGridLayout(topPadding:)` 里的同一段高度，
  /// 两处必须同值。
  final double contentTopPadding;

  /// 导航行高度。
  ///
  /// 与 `MonthMetrics.calendarNavHeight` 同一个数（页面算布局时要用）。
  /// 40 是月视图工具行的历史高度，与周/日视图的星期栏同值 —— 换高度会让
  /// 三个视图的顶栏分家（用户 2026-10-20 报过）。
  static const double navHeight = MonthMetrics.calendarNavHeight;

  /// 卡底那条拉杆占的额外高度（3 + 24 + 3 = 30）。
  static const double chromeHeight =
      MonthGridHandle.extent + MonthMetrics.cellGap * 2;

  /// 导航行与表格之间那条 1dp 分隔线。
  static const double dividerHeight = 1;

  /// 卡片内部**不属于表格**的全部高度 = 导航行 + 分隔线 + 卡底拉杆。
  ///
  /// ## 这个常量必须同时用在两个地方（否则必然溢出）
  ///
  /// 1. `monthGridLayout(handleHeight:)` —— 网格行高预算要扣掉它；
  /// 2. `SizedBox(height: layout.gridHeight + cardChrome)` —— 卡片实际高度。
  ///
  /// 两处只要有一处漏了，症状就是 `RenderFlex overflowed by N pixels`
  ///（2026-10-23 实测：导航搬进卡后只扣了拉杆 → 溢出 41px，正好是 40 + 1）。
  ///
  /// 所以**不要**在调用方自己拼 `navHeight + chromeHeight` —— 用这一个常量。
  static const double cardChrome = navHeight + dividerHeight + chromeHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(MonthMetrics.calendarCardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: radius,
        // 与信息卡同一套柔和投影：白卡压在彩色壁纸上，没有投影时边界只能靠
        // 色差读，在浅色壁纸上会"糊进背景"（信息卡那边一直有这个投影）。
        // 2026-10-23 真机：上半没有投影、下半有，同一屏两种浮起高度。
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: MonthMetrics.cardShadowAlpha),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        // 必须裁：格子选中态是 primary 色块，若不裁，第一列/最后一列的
        // 圆角方块会在卡片圆角外面露出直角。
        borderRadius: radius,
        child: Column(
          children: [
            // ── 卡顶导航行：与下面的日历**同属一张卡** ──
            if (navigator != null) ...[
              SizedBox(height: navHeight, child: navigator),
              // 导航行与表格之间一条极淡的分隔：告诉眼睛"导航在上、表格在下"，
              // 但不切出一块独立区域（用 6% 而不是分割线样式）。
              SizedBox(
                height: 1,
                child: ColoredBox(
                  color: colorScheme.onSurface.withValues(alpha: MonthInk.fill),
                ),
              ),
            ],
            // ⚠️ 表格必须 `Expanded`：里面的 `PageView` 是**横向** viewport，
            // 它要求纵向高度有界。Column 默认给子节点无界高度 ——
            // 直接摆进去会撞 `Horizontal viewport was given unbounded height`
            //（2026-10-23 实测）。Expanded 把「卡总高 − 导航 − 拉杆」定下来。
            Expanded(
              child: Padding(
                // 卡片**自己的**内边距：表头/日期格不能贴到卡片边缘。
                // 2026-10-23 第一版漏了这一段（只靠网格那层 1.5dp），
                // 表头直接顶着圆角，读成"内容溢出的图片被裁了一刀"。
                padding: EdgeInsets.fromLTRB(
                  MonthMetrics.gridInnerPadding - MonthMetrics.cellGap,
                  contentTopPadding,
                  MonthMetrics.gridInnerPadding - MonthMetrics.cellGap,
                  0,
                ),
                child: child,
              ),
            ),
            // 卡底那根拉杆。它在卡片内部、并且总是卡片最下面一项 ——
            // 拖它收放的是上面这张表（回调由页面接到网格收放控制器）。
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MonthMetrics.cellGap,
              ),
              child: MonthGridHandle(
                barColor: colorScheme.onSurface.withValues(alpha: MonthInk.hairline),
                onDragStart: onDragStart,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
