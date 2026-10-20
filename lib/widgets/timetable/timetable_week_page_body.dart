import 'package:flutter/material.dart';

/// 周页的滚动/淡出壳（2026-10-19 从课表页 State 搬出）。
///
/// 只负责按滚动余量包 `SingleChildScrollView`、并在日视图展开时淡出网格；
/// 滚动 key/controller/physics、是否自适应与上报回调都由调用方注入。
class TimetableWeekPageBody extends StatelessWidget {
  final Widget grid;
  final double scrollRelief;
  final bool autoFit;
  final String scrollKey;
  final ScrollController? controller;
  final ScrollPhysics physics;
  final Animation<double> expandAnimation;
  final Widget Function(String key, Widget child) reportScroll;

  const TimetableWeekPageBody({
    super.key,
    required this.grid,
    required this.scrollRelief,
    required this.autoFit,
    required this.scrollKey,
    required this.controller,
    required this.physics,
    required this.expandAnimation,
    required this.reportScroll,
  });

  @override
  Widget build(BuildContext context) {
    final Widget weekGrid;
    if (scrollRelief > 0) {
      weekGrid = reportScroll(
        scrollKey,
        SingleChildScrollView(
          key: PageStorageKey<String>(scrollKey),
          controller: controller,
          // Explicit clamp: do not inherit HyperOS rubber-band here.
          // 下拉开着时冻结纵向滚动（见 TimetableHomePullFreezeScrollPhysics）：
          // 回拉取消只收下拉，不把列表一起滚走。
          physics: physics,
          child: Padding(
            padding: EdgeInsets.only(bottom: scrollRelief),
            child: grid,
          ),
        ),
      );
    } else if (autoFit) {
      weekGrid = grid;
    } else {
      weekGrid = reportScroll(
        scrollKey,
        SingleChildScrollView(
          key: PageStorageKey<String>(scrollKey),
          controller: controller,
          // 下拉开着时冻结纵向滚动（见 TimetableHomePullFreezeScrollPhysics）：
          // 回拉取消只收下拉，不把列表一起滚走。
          physics: physics,
          child: grid,
        ),
      );
    }
    // Drive visibility from the expand controller so open and close share the
    // same trigger. A boolean AnimatedOpacity snaps the grid away on open while
    // the panel still grows, which reads as "open has no transition".
    //
    // ⚠️ 透明度**只取 0 / 1**（2026-10-20 拆掉逐帧 Opacity）：网格里是成片的
    // `CourseSurface` 玻璃卡（BackdropFilter 实时采样），半透明层里它采不到
    // 身后内容 —— 磨砂塌成透明（CourseSurface 类注释的原文规则），透明度走到
    // 边界值、离屏层消失的瞬间磨砂又「啪」地弹回来：用户口径「展开/收完的
    // 瞬间变黑然后变白」。0/1 两值下 RenderOpacity 要么不建离屏层（1.0）、
    // 要么整棵跳过绘制（0），玻璃永远不进半透明层。交叉淡化由**面板自己的
    // 不透明背景逐帧盖过来**替代：展开时网格保持全保真被面板盖住、收起时
    // 随面板缩小逐帧露出，不再有「无磨砂的网格先淡入、落定才弹回磨砂」。
    return AnimatedBuilder(
      animation: expandAnimation,
      child: weekGrid,
      builder: (context, child) {
        final gridVisible = expandAnimation.value < 1.0;
        return IgnorePointer(
          // Same threshold as the old opacity ramp (< 0.02 ⇔ value > 0.98):
          // the grid stops taking input only when the day view is fully up.
          ignoring: !gridVisible,
          child: Opacity(
            // At 0 RenderOpacity skips painting the subtree, so day-view glass
            // samples wallpaper instead of a ghost grid.
            opacity: gridVisible ? 1.0 : 0.0,
            child: child,
          ),
        );
      },
    );
  }
}
