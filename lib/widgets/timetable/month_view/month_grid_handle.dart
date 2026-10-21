import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';
import '../../../utils/card_surface_ink.dart';

/// **日期表格的拖拽把手**（2026-10-21 第二轮修正，第三轮修可读性）。
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
/// ## 可读性修正（2026-10-21 专业评审 P0-3）
///
/// 拉杆是全页唯一教用户「这张表可以上滑」的控件，实测却只有 **1.22:1** ——
/// 等于没有。两个原因叠在一起：
///
/// 1. 旧实现取整屏主体带的墨色再乘 **0.32** alpha。主体带平均 0.356 判成深墨，
///    而拉杆实际压着的那段水面只有 0.09 —— 深墨 32% 压上去就没了；
/// 2. 柔和的观感是拿对比度换的，而这个控件本来就没有多余的对比度可换。
///
/// 现在：① 判据换成**拉杆自己那段**壁纸的亮度（由页面按它的屏幕位置采样）；
/// ② 用满 alpha 的黑/白两档 —— 黑白对任一亮度的对比度都不低于 ~4.1:1，
/// 不需要再靠半透明"柔和"；③ 视觉上仍是一条 5dp 的细条，观感不变。
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
    this.wallpaperLuminance,
    super.key,
  });

  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  /// 拉杆颜色基色。画在**表格外沿**（壁纸 / 玻璃带上），所以用顶栏那套
  /// 按壁纸亮度判好的墨色，而不是面板内卡面的墨色。
  ///
  /// [wallpaperLuminance] 为 null 时原样用它（没有壁纸 / 还没采到的兜底）。
  final Color inkColor;

  /// **拉杆正下方那段**壁纸的亮度（页面按它的屏幕位置采样）。
  ///
  /// 给了就按它自行判黑白，不再用整屏带判出的 [inkColor] —— 两者可以差很远
  /// （实测主体带 0.356 判深墨，拉杆那段只有 0.09，深墨直接消失）。
  final double? wallpaperLuminance;

  /// 视觉高度（用户截图里那根细条）。
  static const double barHeight = 5;

  /// 视觉宽度。截图里约 60（屏宽 393 的 15%），取固定值比取比例好读。
  static const double barWidth = 60;

  /// 手势命中高度：比视觉高得多，手指不必精准点在 5px 上。
  static const double hitHeight = 24;

  /// 整块高度（表格下方、面板上方那一条）。
  static const double extent = hitHeight;

  /// 拉杆最终画出来的颜色。
  ///
  /// [wallpaperLuminance] 有值时按它判黑白（满 alpha），否则退回 [inkColor]。
  /// 抽成静态纯函数是为了能单测：这是「功能存在但用户不知道」那类缺陷的
  /// 唯一判据。
  static Color resolveBarColor({
    required Color inkColor,
    required double? wallpaperLuminance,
  }) {
    final luminance = wallpaperLuminance;
    if (luminance == null) {
      return inkColor.withValues(alpha: 0.32);
    }
    return bestCardInkForLuminance(luminance);
  }

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
              // 满 alpha 的黑/白：拉杆压在纹理复杂的照片上，对比度本来就不多，
              // 再乘一个 alpha 就没了（旧实现实测 1.22:1）。
              color: resolveBarColor(
                inkColor: inkColor,
                wallpaperLuminance: wallpaperLuminance,
              ),
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
