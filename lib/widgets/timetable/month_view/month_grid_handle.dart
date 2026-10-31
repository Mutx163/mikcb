import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';
import 'month_metrics.dart';

/// **日历卡的拖拽把手**：卡底正中那根 5dp 小横条（2026-10-21 立，两轮改位置）。
///
/// ## 位置沿革（两次都是用户指的）
///
/// | 时间 | 位置 | 用户口径 |
/// |---|---|---|
/// | 2026-10-21 | 网格与信息板之间的夹缝（画在壁纸上） | 无（首版） |
/// | 2026-10-23 上午 | 白色信息区**顶部** | 「拉杆改到下面的白色区域里面去」 |
/// | 2026-10-23 下午 | **日历白卡**内部、卡底正中 | 「拉杆区域像小米日历这样」 |
///
/// 第三次是最终形态：小米日历那根条的语义是「**这张卡**可以往上收」，
/// 而它属于上半那张日历卡。信息区改成独立卡片之后，拉杆若留在信息区顶部就会
/// 读成"信息列表的把手"，归属又错了 —— 所以跟着日历卡走。
///
/// ## 归属（拖动时收放的是上面的表格）
///
/// 上滑收日历、下滑放日历，下方信息卡只是跟着让位。`onDrag*` 全部由页面接到
/// 网格收放控制器（`_beginGridDrag` 等），与本组件的位置无关。
///
/// ## 命中区比视觉大得多
///
/// 视觉 60×5，命中高 [hitHeight]（24）—— 手指不可能精准点在 5dp 上。
/// 卡片底部另留 [MonthMetrics.calendarHandleHeight] 的空白，让这根条不贴着
/// 卡边（贴着会被圆角切掉一半，读起来像渲染错误）。
class MonthGridHandle extends StatelessWidget {
  const MonthGridHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.barColor,
    super.key,
  });

  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  /// 拉杆那条细条的颜色。
  ///
  /// 2026-10-23 起把手压在**白色日历卡**上（不画在壁纸上），所以颜色由调用方
  /// 从**卡片墨色**取半透明档传入 —— 与卡内文字同源。旧口径（按壁纸亮度判
  /// 满 alpha 黑白）是为"画在照片上"服务的，卡一变白就不适用了。
  final Color barColor;

  /// 视觉高度（用户截图里那根细条）。
  static const double barHeight = 5;

  /// 视觉宽度。截图里约 60（屏宽 393 的 15%），取固定值比取比例好读。
  static const double barWidth = 60;

  /// 手势命中高度：比视觉高得多，手指不必精准点在 5px 上。
  static const double hitHeight = 24;

  /// 整块高度（卡底那一条）。
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
              color: barColor,
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
