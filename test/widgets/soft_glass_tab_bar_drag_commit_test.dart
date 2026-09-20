import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_tab_bar.dart';

/// 底栏拖拽提交后，**指示器的静止位置必须等于 `selectedIndex`**。
///
/// 背景（用户 2026-09-20 报告）：玻璃坞可以横向拖动指示器切换页面。拖到一个
/// **会推入新路由**的页面入口（如「外观编辑」）时，父级并不会把该槽变成
/// `selectedIndex` —— 那不是常驻内嵌页，底栏不该停在那格。可返回后页面已回到
/// 原来的日/周视图，指示器却还停在「外观编辑」那一格，高亮与页面不一致。
///
/// 根因：指示器的视觉位置（`AnimationController _position`）在拖动期间被直接
/// 写走，而 `didUpdateWidget` 只在 `selectedIndex` **变化**时才回同步；父级不
/// 接管这次选择 → `selectedIndex` 没变 → 指示器留在手指离开的位置。
void main() {
  // 指示器的 Positioned；读它的 `left`（布局值）比量渲染矩形可靠 —— 拖动按压
  // 与速度拉伸都会给指示器套 `Transform` 缩放，矩形的量值会被污染。
  const indicatorKey = ValueKey('soft-glass-tab-indicator');

  /// 三槽底栏。`onTabSelected` 决定「父级接不接管」这次选择。
  ///
  /// 每次调用都换一个 [barKey]：State 被复用时会从旧位置 spring 到新的
  /// `selectedIndex`，量到的是动画中间值；换 key 得到全新 State，指示器直接
  /// 落在 `selectedIndex` 上，读数才是一次干净的标定。
  Future<void> pumpBar(
    WidgetTester tester, {
    required Key barKey,
    required int selectedIndex,
    required ValueChanged<int> onTabSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SoftGlassTabBar(
              key: barKey,
              tabs: const [
                SoftGlassTab(icon: Icon(Icons.circle_outlined), label: 'A'),
                SoftGlassTab(icon: Icon(Icons.square_outlined), label: 'B'),
                SoftGlassTab(icon: Icon(Icons.star_outline), label: 'C'),
              ],
              selectedIndex: selectedIndex,
              onTabSelected: onTabSelected,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 指示器当前的布局左边界（`itemWidth × 位置 − 溢出`）。
  double indicatorLeft(WidgetTester tester) =>
      tester.widget<Positioned>(find.byKey(indicatorKey)).left!;

  /// 把弹簧动画推到静止。`pump(duration)` 只投一帧，弹一次不够 —— 指示器的
  /// 落点要靠**连续多帧**的积分才收敛，这里按 32ms 步长推约 2 秒。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  /// 从**当前选中槽**的标签处起拖：拖动起手点必须落在当前选中格内
  /// （见 `_onPointerDown` 的闸门），否则不会进入拖动。
  ///
  /// 不从指示器本身起拖 —— 指示器被上面那层 `HitTestBehavior.opaque` 的
  /// `Listener` 盖住，`drag()` 会报「找不到可命中的目标」。
  Future<void> dragIndicator(
    WidgetTester tester,
    String fromLabel,
    double dx,
  ) async {
    await tester.drag(find.text(fromLabel), Offset(dx, 0));
  }

  testWidgets('拖动提交到「父级不接管」的槽：指示器必须弹回 selectedIndex', (tester) async {
    // 标定三个槽各自的落点（父级接管时指示器就停在这）。
    final restingLeft = <double>[];
    for (var i = 0; i < 3; i++) {
      await pumpBar(
        tester,
        barKey: ValueKey('calibrate-$i'),
        selectedIndex: i,
        onTabSelected: (_) {},
      );
      restingLeft.add(indicatorLeft(tester));
    }
    expect(
      restingLeft[0],
      lessThan(restingLeft[1]),
      reason: '标定应给出递增的三个落点',
    );
    expect(restingLeft[1], lessThan(restingLeft[2]));
    // 相邻落点差 = 一格宽（用于把拖动距离换算成「拖过几格」）。
    final cellWidth = restingLeft[1] - restingLeft[0];

    // 真实场景：当前停在槽 0，拖到槽 2 —— 而槽 2 是「推入新路由」的页面
    // 入口，父级的 selectedIndex 永远是 0（不接管）。
    await pumpBar(
      tester,
      barKey: const ValueKey('repro'),
      selectedIndex: 0,
      onTabSelected: (_) {},
    );
    await dragIndicator(tester, 'A', cellWidth * 2);
    await tester.pump();
    await settle(tester);

    expect(
      indicatorLeft(tester),
      closeTo(restingLeft[0], 0.5),
      reason: '父级没接管这次选择，指示器不能停在手指离开的槽上，必须弹回真实所在页',
    );
  });

  testWidgets('父级接管这次选择：指示器停在目标槽（不能被回弹规则误伤）', (tester) async {
    final restingLeft = <double>[];
    for (var i = 0; i < 3; i++) {
      await pumpBar(
        tester,
        barKey: ValueKey('calibrate-$i'),
        selectedIndex: i,
        onTabSelected: (_) {},
      );
      restingLeft.add(indicatorLeft(tester));
    }
    final cellWidth = restingLeft[1] - restingLeft[0];

    // 真实场景：拖到槽 2，父级接住（setState 把 selectedIndex 改成 2）。
    var selected = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SoftGlassTabBar(
                  tabs: const [
                    SoftGlassTab(icon: Icon(Icons.circle_outlined), label: 'A'),
                    SoftGlassTab(icon: Icon(Icons.square_outlined), label: 'B'),
                    SoftGlassTab(icon: Icon(Icons.star_outline), label: 'C'),
                  ],
                  selectedIndex: selected,
                  onTabSelected: (index) =>
                      rebuild(() => selected = index),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await dragIndicator(tester, 'A', cellWidth * 2);
    await tester.pump();
    await settle(tester);

    expect(
      indicatorLeft(tester),
      closeTo(restingLeft[2], 0.5),
      reason: '父级接管后指示器应停在目标槽，回弹规则不得把它拽回来',
    );
  });
}
