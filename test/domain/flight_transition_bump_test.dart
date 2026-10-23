import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/flight_transition_glue.dart';

/// 转场「升空」与「收起」**都要开新代数**（2026-10-23 审核补）。
///
/// ## 为什么这条必须单独钉
///
/// 上一版 `FlightTransitionGlue._onStatus` 只在 `AnimationStatus.forward` 时
/// 调 `onTransitionStart`（= `FlightTargetCache.bump`），`reverse` 不调。
///
/// 配合 `MeasureFlightTarget` 的「尺寸没变 + 代数没变就直接早退」，
/// 结果是：用户在日视图**滚动过议程列表**再关闭时，缓存里还是打开那一刻的
/// 旧矩形 —— 卡片朝一个空位置飞回去。
///
/// 现有的日视图测试全部是「打开」路径（点星期栏 → 断言面板出现），
/// **没有任何一条**在「滚动后关闭」这条路径上，所以这个 bug 活着。
///
/// 这里用最小装配直接驱动控制器的状态跃迁 —— 不依赖整个首页，
/// 因此能精确钉住「reverse 也要 bump」这一条。
void main() {
  Widget harness() => const Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 200, height: 200),
  );

  testWidgets('forward 与 reverse 都会请求换代', (tester) async {
    late AnimationController controller;
    var bumps = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          controller = AnimationController(
            vsync: tester,
            duration: const Duration(milliseconds: 100),
          );
          final glue = FlightTransitionGlue(
            expandController: controller,
            surfaceKey: GlobalKey(),
            rebuild: () {},
          )..onTransitionStart = (() => bumps++);
          addTearDown(glue.dispose);
          addTearDown(controller.dispose);
          return harness();
        },
      ),
    );

    expect(bumps, 0, reason: '刚开始不该换代');

    controller.forward();
    await tester.pump();
    expect(
      bumps,
      1,
      reason: '打开（forward）必须换代 —— 这是原有逻辑，不能被删',
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.isAnimating, isFalse, reason: '前提：打开动画已结束');

    controller.reverse();
    await tester.pump();
    expect(
      bumps,
      2,
      reason:
          '关闭（reverse）**也必须**换代。不换代的话，日视图里滚动过议程列表'
          '（终点位置已变）再关闭，缓存还是旧矩形 —— 卡片飞向空位置。'
          '`MeasureFlightTarget` 的「代数没变就早退」会把重测一并挡掉，'
          '连下一帧自愈的机会都没有。',
    );
    // 让 ticker 停下再结束测试（否则 "A Ticker was active at the end"）。
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('completed / dismissed 不换代（转场已结束，没有落点要算）', (tester) async {
    late AnimationController controller;
    var bumps = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          controller = AnimationController(
            vsync: tester,
            duration: const Duration(milliseconds: 50),
          );
          final glue = FlightTransitionGlue(
            expandController: controller,
            surfaceKey: GlobalKey(),
            rebuild: () {},
          )..onTransitionStart = (() => bumps++);
          addTearDown(glue.dispose);
          addTearDown(controller.dispose);
          return harness();
        },
      ),
    );

    controller.forward();
    await tester.pump();
    final afterForward = bumps;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      bumps,
      afterForward,
      reason: '落地（completed）不该再换代 —— 那时没有飞行卡要落点',
    );

    controller.reverse();
    await tester.pump();
    final afterReverse = bumps;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      bumps,
      afterReverse,
      reason: '收起完成（dismissed）不该再换代',
    );
  });
}
