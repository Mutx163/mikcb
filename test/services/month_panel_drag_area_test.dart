import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_drag_area.dart';

/// 面板「任意位置上下拖动 = 收放日期表格」的分流判据（2026-10-21 晚）。
///
/// 用户口径：「底部信息区域，应该支持在任意位置上下滑动，可以操作日期表格的
/// 上下收起展开」。
///
/// 两半都要钉住：只喂列表 ⇒ 面板收不起来；只收放 ⇒ 长列表永远看不到底部。
void main() {
  /// [itemCount] × 80 决定内容能不能滚（视口 300）。
  Widget harness({
    required ScrollController controller,
    required List<double> collapseDeltas,
    required int itemCount,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: MonthPanelDragArea(
            scrollController: controller,
            onCollapseStart: () {},
            onCollapseUpdate: collapseDeltas.add,
            onCollapseEnd: (_) {},
            child: SingleChildScrollView(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  for (var i = 0; i < itemCount; i++)
                    SizedBox(height: 80, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('列表还能滚时：只滚列表，不触发收放', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final deltas = <double>[];
    await tester.pumpWidget(
      harness(controller: controller, collapseDeltas: deltas, itemCount: 20),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('row 0'), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(
      controller.offset,
      greaterThan(0),
      reason: '列表还有可滚空间时，这段位移必须给列表',
    );
    expect(
      deltas,
      isEmpty,
      reason: '列表能滚就不该同时收放表格（否则拖一下收一半，互相打架）',
    );
  });

  testWidgets('列表已到底、继续往上拖：位移转成表格收起', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final deltas = <double>[];
    await tester.pumpWidget(
      harness(controller: controller, collapseDeltas: deltas, itemCount: 20),
    );
    await tester.pumpAndSettle();

    // 直接拉到列表底部（20×80=1600 内容、300 视口 ⇒ 可滚 1300）。
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final before = deltas.length;

    await tester.drag(find.text('row 19'), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      deltas.length,
      greaterThan(before),
      reason: '列表到底后继续拖，必须开始收放表格（这正是"任意位置"的含义）',
    );
    expect(
      deltas.skip(before).every((d) => d <= 0),
      isTrue,
      reason: '向上拖的 delta 是负的（收起方向）',
    );
  });

  testWidgets('列表已在顶、继续往下拖：位移转成表格展开', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final deltas = <double>[];
    await tester.pumpWidget(
      harness(controller: controller, collapseDeltas: deltas, itemCount: 20),
    );
    await tester.pumpAndSettle();

    // 已停在顶部，再往下拖。
    await tester.drag(find.text('row 0'), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(deltas, isNotEmpty, reason: '已在顶部继续下拉 = 展开表格');
    expect(
      deltas.every((d) => d >= 0),
      isTrue,
      reason: '向下拖的 delta 是正的（展开方向）',
    );
  });

  testWidgets('内容不足一屏（列表不能滚）：任何方向都直接收放', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final deltas = <double>[];
    await tester.pumpWidget(
      harness(controller: controller, collapseDeltas: deltas, itemCount: 2),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('row 0'), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      deltas,
      isNotEmpty,
      reason: '列表没有可滚空间时，拖拽应当立刻转为收放（而不是"拖了没反应"）',
    );
  });
}
