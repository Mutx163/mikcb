import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';

/// 条目面板顶部的**拖拽拉杆**（2026-10-21，照用户截图）。
///
/// 用户口径：「下面显示一个拉杆，就像截图这样」。截图里那根是宽约 60、
/// 高 5、圆头、半透明灰的横条，居中贴在面板上沿内侧。
///
/// ## 它为什么必须可拖
///
/// 用户还要「下面的条目视图不支持左右滑动，只支持上下滑动，上下滑动操作的就是
/// 这个收起操作」。而条目列表本身需要纵向滚动 —— 两者都是纵向，只能在**拉杆**
/// 这个明确的把手上区分：拉杆上拖 = 收放网格，列表上拖 = 滚列表。
///
/// 所以拉杆不是装饰，是**唯一的手势归属点**：命中区比视觉大一圈（[hitHeight]），
/// 手指落在它附近就能拖，不必精准点在 5px 的细条上。
class MonthPanelHandle extends StatelessWidget {
  const MonthPanelHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.inkColor,
    super.key,
  });

  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  /// 拉杆颜色基色（壁纸上的判定墨色；面板内是卡面，所以按卡面墨色给）。
  final Color inkColor;

  /// 视觉高度（用户截图里那根细条）。
  static const double barHeight = 5;

  /// 视觉宽度。截图里约 60（屏宽 393 的 15%），取固定值比取比例好读。
  static const double barWidth = 60;

  /// 手势命中高度：比视觉高得多，手指不必精准点在 5px 上。
  static const double hitHeight = 28;

  /// 整块的高度（面板顶部预留）。
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
              // 半透明墨色：面板底色上的"凹陷"把手，不用主题色（会被误读成可点按钮）。
              color: inkColor.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板当前的吸附状态（供无障碍与外部读取）。
///
/// 收起 = 网格只露一行；展开 = 网格六行全露。
bool monthPanelIsExpanded(double progress) =>
    progress >= (1 - kMonthGridFlipTravel / 2);
