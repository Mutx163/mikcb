import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';

/// **日期表格的拖拽把手**（2026-10-21 第二轮修正）。
///
/// ## 归属修正（这是本类最重要的一件事）
///
/// 用户口径：「那个拉杆，不应该是下面弹窗拉杆，拉杆的内容，应该是反向的，
/// 内容应该是顶上的日期表格」。
///
/// 首版把这根横条放在**条目面板的实底容器内部**，读起来就是「底部弹窗的
/// 拖拽把手」（iOS bottom sheet 的既有心智：拉杆属于那个从下面升起的面板）。
/// 但这里被拖动的其实是**上面的日期表格** —— 上滑收的是日历、下滑放的是日历，
/// 下方条目只是跟着让位。把把手放在弹窗里，手势归属就讲反了。
///
/// 所以现在：把手画在**日期表格的下沿**、属于表格这一侧（由网格外层的
/// Column 直接摆放，不在面板的 Container 里），视觉上贴着表格底边，
/// 读作「这张表格可以往上收」。
///
/// ## 它为什么必须可拖
///
/// 下方条目列表自己需要纵向滚动，而收放网格也是纵向 —— 两者方向相同，只能在
/// **明确的把手**上区分：把手上拖 = 收放表格，列表上拖 = 滚列表。
/// 命中区比视觉大得多（[hitHeight] vs [barHeight]），手指不必精准点在 5px 上。
class MonthGridHandle extends StatelessWidget {
  const MonthGridHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.inkColor,
    super.key,
  });

  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  /// 拉杆颜色基色。画在**表格外沿**（壁纸 / 玻璃带上），所以用顶栏那套
  /// 按壁纸亮度判好的墨色，而不是面板内卡面的墨色。
  final Color inkColor;

  /// 视觉高度（用户截图里那根细条）。
  static const double barHeight = 5;

  /// 视觉宽度。截图里约 60（屏宽 393 的 15%），取固定值比取比例好读。
  static const double barWidth = 60;

  /// 手势命中高度：比视觉高得多，手指不必精准点在 5px 上。
  static const double hitHeight = 24;

  /// 整块高度（表格下方、面板上方那一条）。
  static const double extent = hitHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onDragStart(),
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: SizedBox(
        height: extent,
        child: Center(
          child: Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              // 半透明墨色：画在表格外沿的"凹陷"把手，不用主题色
              // （主题色会被误读成可点按钮）。
              color: inkColor.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表格当前的吸附状态（供无障碍与外部读取）。
///
/// 收起 = 只露一行；展开 = 六行全露。
bool monthGridIsExpanded(double progress) =>
    progress >= (1 - kMonthGridFlipTravel / 2);
