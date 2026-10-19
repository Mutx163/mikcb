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
    // Drive opacity from the expand controller so open and close share the
    // same curve. A boolean AnimatedOpacity snaps the grid away on open while
    // the panel still grows, which reads as "open has no transition".
    return AnimatedBuilder(
      animation: expandAnimation,
      child: weekGrid,
      builder: (context, child) {
        final gridOpacity = (1.0 - expandAnimation.value).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: gridOpacity < 0.02,
          child: Opacity(
            // At 0 RenderOpacity skips painting the subtree, so day-view glass
            // samples wallpaper instead of a ghost grid.
            opacity: gridOpacity,
            child: child,
          ),
        );
      },
    );
  }
}
