// 转场期间「本页玻璃降级」作用域的回归。
//
// 背景：路由转场（HyperosPageRoute 的滑入 shell）期间，页面一直在移动，
// BackdropFilter 采不到稳定背景（整段动画渲染为透明，见
// LiquidGlassDegradation 的说明），而且每帧都要重做一次全屏背景采样。
// 为此 buildSharedAxisTransition 在转场进行时把本页套进
// LiquidGlassRouteTransitionScope(active: true)，让该页玻璃回落实体材质，
// settle 后置回 false 恢复玻璃。
//
// 关键约束：作用域**只覆盖正在滑动的那一页**。下层路由（首页玻璃带 /
// 玻璃坞）必须落在作用域之外，否则每次推页它们都会闪一下实体。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';

void main() {
  bool anyActiveScope(WidgetTester tester) => tester
      .widgetList<LiquidGlassRouteTransitionScope>(
        find.byType(LiquidGlassRouteTransitionScope),
      )
      .any((scope) => scope.active);

  testWidgets('转场进行中本页降级作用域激活，settle 后关闭', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HyperosNavigation.buildSharedAxisTransition(
          animation: controller,
          secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
          child: const ColoredBox(color: Color(0xFF101010)),
        ),
      ),
    );
    expect(anyActiveScope(tester), isFalse, reason: '静止时不应降级玻璃');

    controller.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(anyActiveScope(tester), isTrue, reason: '转场进行中应把本页玻璃降级为实体');

    await tester.pumpAndSettle();
    expect(anyActiveScope(tester), isFalse, reason: 'settle 后应恢复玻璃');
  });

  testWidgets('作用域只覆盖本页，域外 isActive 恒为 false', (tester) async {
    late bool outside;
    late bool insideActive;
    late bool insideInactive;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Builder(
              builder: (context) {
                outside = LiquidGlassRouteTransitionScope.isActive(context);
                return const SizedBox.shrink();
              },
            ),
            LiquidGlassRouteTransitionScope(
              active: true,
              child: Builder(
                builder: (context) {
                  insideActive = LiquidGlassRouteTransitionScope.isActive(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            LiquidGlassRouteTransitionScope(
              active: false,
              child: Builder(
                builder: (context) {
                  insideInactive = LiquidGlassRouteTransitionScope.isActive(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(outside, isFalse, reason: '作用域外不得被判为转场中');
    expect(insideActive, isTrue);
    expect(insideInactive, isFalse);
  });

  testWidgets('作用域激活时 shouldDegrade 为真（玻璃走实体材质）', (tester) async {
    late bool degradedInActive;
    late bool degradedInInactive;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            LiquidGlassRouteTransitionScope(
              active: true,
              child: Builder(
                builder: (context) {
                  degradedInActive = LiquidGlassDegradation.shouldDegrade(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            LiquidGlassRouteTransitionScope(
              active: false,
              child: Builder(
                builder: (context) {
                  degradedInInactive = LiquidGlassDegradation.shouldDegrade(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(degradedInActive, isTrue, reason: '转场中玻璃应回落实体材质');
    expect(degradedInInactive, isFalse, reason: '非转场不应无端降级玻璃');
  });
}
