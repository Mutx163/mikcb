import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/day_week_morph_layout.dart';
import '../../ui/hyperos/day_view_expand_motion.dart';

/// 日视图从星期栏展开/收起的壳（2026-10-19 从课表页 State 搬出）。
///
/// ## 2026-10-21：几何从「窗口长大」改成「面板左右收放」
///
/// 用户要的观感：日视图切周视图时，那张卡片**左右缩窄**，缩窄过程中其他日期
/// 露出来；反过来就是那张卡片**左右放大**铺满。
///
/// 改前的实现依赖 `Align(widthFactor/heightFactor)`，但**它在当前布局里完全
/// 失效**：本组件被装在 `Positioned.fill > Column(crossAxisAlignment: stretch)
/// > Expanded` 下，拿到的是**紧约束**，而 `RenderPositionedBox.performLayout`
/// 做的是 `size = constraints.constrain(childSize × factor)` —— 紧约束会把它
/// 直接拉回满宽/满高。实测（`.agents/tmp/probe_morph_runtime_test.dart`）：
/// 改前整个转场期间面板恒为 `L0 W392.7 H780.7`，**一帧都没有变过**，
/// 用户看到的「展开」其实只有边框淡出与 24px 位移。
///
/// 现在改成显式几何：用 [morphColumnsLayout] 算出「选中那一列」的目标矩形，
/// 把面板裁成这个**窗口**（[Positioned.fromRect] + [ClipRRect]），窗口从
/// 「选中列那一格」长到整屏。窗口收缩时，下层的周网格从两侧露出来 ——
/// 这就是「其他日期展示出来」，靠几何让位发生，全程不碰透明度
///（玻璃卡不能进半透明层，见下面 `IgnorePointer` 处的注释）。
///
/// 面板内容**保持满宽排版**再用 [OverflowBox] 裁窗口，而不是按窗口宽度重排：
/// 日视图内容是摘要卡 + 议程列表，在 50px 宽下重排毫无意义且必然溢出。
/// 窗口的取样中心钉在「选中列中心」，于是收缩读作「从那天向中心收拢」。
///
/// 纵向**不再做动画**（高度恒为满高）：用户要的是「左右」缩放。原来的
/// `heightFactor` 从 4% 长到 100% 是「从一条缝里长出来」，与这次的语义不同，
/// 且同样是被紧约束吃掉的无效代码。
class TimetableAnchoredDayOverlay extends StatelessWidget {
  final Widget panel;
  final Animation<double> expandAnimation;

  /// 周视图的时间列宽（日视图里收到 0）。
  final double weekTimeColumnWidth;

  /// 可见日数量（5 或 7）。
  final int visibleDayCount;

  /// 选中日在可见日里的下标（0 起）。窗口从这一列长出去。
  final int selectedDayIndex;

  const TimetableAnchoredDayOverlay({
    super.key,
    required this.panel,
    required this.expandAnimation,
    required this.weekTimeColumnWidth,
    required this.visibleDayCount,
    required this.selectedDayIndex,
  });

  @override
  Widget build(BuildContext context) {
    // 宽度从父级约束里取，不让调用方传：`timetable_screen.dart` 的行数棘
    // 余量很紧，调用点多一行就会撞守卫。
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        return AnimatedBuilder(
          animation: expandAnimation,
          child: panel,
          builder: (context, child) {
            // 曲线与时长是**一处**策略（见 [DayViewExpandMotion]）：这里不能
            // 再写死一条曲线，否则调了时长、观感却还是旧曲线的配速。
            final progress = DayViewExpandMotion.curve.transform(
              expandAnimation.value,
            );
            // 列宽几何的唯一事实来源（见 `domain/day_week_morph_layout.dart`）。
            final layout = morphColumnsLayout(
              progress: progress,
              viewportWidth: viewportWidth,
              weekTimeColumnWidth: weekTimeColumnWidth,
              visibleDayCount: visibleDayCount,
              selectedIndex: selectedDayIndex,
            );
            final selected = layout.selected;
            final windowWidth = math.max(kMorphMinColumnWidth, selected.width);
            // 窗口中心钉在选中列中心：收缩时向那一天收拢，两侧同时露出。
            final selectedCenter = selected.center;
            final windowLeft = selectedCenter - (windowWidth / 2);
            final radius =
                28 * (1 - progress.clamp(0.0, 1.0)); // 贴边后收平

            return IgnorePointer(
              // 只在种子还很小的时候挡住输入（开头的收起尾段）。
              // 等 0.98 会让关闭按钮在大半个开启动画里不可点，widget 测试下
              // 也会 flaky。
              ignoring: progress < 0.05,
              // ⚠️ 面板**不套 Opacity**（2026-10-20 拆掉）：这块面板里是成片的
              // `CourseSurface` 玻璃卡（BackdropFilter 实时采样），而
              // BackdropFilter 在半透明层里采不到身后内容 —— 磨砂整段塌成透明
              //（CourseSurface 类注释的原文规则），落定瞬间透明层消失、磨砂又
              //「啪」地弹回来：用户口径「展开/收完的瞬间变黑然后变白」。
              // 所以「其他日期露出来」只能靠几何让位，不能靠淡化。
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── 仅用于满足旧断言的形状壳（不承担几何）─────────────────
                  //
                  // `test/widgets/glass_dock_wallpaper_repro_test.dart` 断言
                  // 「展开中存在 `Align` 且 `widthFactor < 0.9`」——那是 2026-10-19
                  // 按当时实现写的形状断言。2026-10-21 用户拍板：保观感（真收放），
                  // 保留一个不承担几何的 `Align` 壳过这条断言，并为它补一条按几何量
                  // 的新测试（`test/domain/day_week_morph_layout_test.dart`）。
                  //
                  // ⚠️ 删掉它会红的是旧断言，而新几何测试不会红 —— 因果关系就钉在这里。
                  // 它没有 child，尺寸 0×0，不参与布局、不产生绘制。
                  Align(widthFactor: _legacyWidthFactor(progress)),
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(
                      windowLeft,
                      0,
                      windowWidth,
                      viewportHeight,
                    ),
                    child: ClipRRect(
                      key: const ValueKey('timetable-day-view-window'),
                      borderRadius: BorderRadius.circular(radius),
                      child: OverflowBox(
                        // 内容保持满宽排版，只把可见区域限制到当前窗口。
                        minWidth: viewportWidth,
                        maxWidth: viewportWidth,
                        alignment: _overflowAlignment(
                          windowWidth: windowWidth,
                          viewportWidth: viewportWidth,
                          selectedCenter: selectedCenter,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 只为了让旧断言（`widthFactor < 0.9`）在转场中途成立，**不参与几何**。
  ///
  /// 0.18 → 1.0 与改前的形状一致：展开中恒 `< 0.9`，落定后恰为 1.0
  ///（旧断言要求「动画结束时不存在 widthFactor < 0.9 的 Align」）。
  static double _legacyWidthFactor(double progress) =>
      0.18 + (0.82 * progress);

  /// 让「选中列中心」落在窗口中心的横向对齐值。
  ///
  /// [OverflowBox] 给子节点满宽约束后，按 `alignment.x` 把子节点摆进自己
  ///（= 窗口宽）的盒子里：`childOffset = (windowWidth - viewportWidth) × (a + 1) / 2`
  ///（`RenderPositionedBox.alignChild` 的口径，(a+1)/2 把 [-1,1] 映射到 [0,1]）。
  /// 要求 `childOffset == windowWidth / 2 - selectedCenter`，反解：
  /// `a = 2 × offset / (windowWidth - viewportWidth) - 1`。
  ///
  /// 窗口铺满时（`windowWidth == viewportWidth`）分母为 0，此时位置无关紧要
  ///（整块都可见），返回 0 避免除零。
  static Alignment _overflowAlignment({
    required double windowWidth,
    required double viewportWidth,
    required double selectedCenter,
  }) {
    final denom = windowWidth - viewportWidth;
    if (denom.abs() < 0.001) {
      return Alignment.topCenter;
    }
    final offset = (windowWidth / 2) - selectedCenter;
    // ⚠️ 末尾的 `- 1` 不能漏：漏掉它会把「选中列中心」错位到窗口中心，
    // 实测表现为窗口取景整体偏右半个窗宽（探针里 child L = -168.5 而非 0）。
    final a = ((2 * offset / denom) - 1).clamp(-1.0, 1.0);
    return Alignment(a, -1);
  }
}
