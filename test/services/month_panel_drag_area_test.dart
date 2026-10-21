import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_drag_area.dart';

/// 面板纵向拖拽的**优先级**判据（2026-10-21 第二轮，语义已反转）。
///
/// ## 用户两次口径，方向是反的
///
/// 第一次：「底部信息区域，应该支持在任意位置上下滑动，可以操作日期表格的
/// 上下收起展开」—— 那一轮实现成「列表能滚就先滚列表，滚到边界才收表格」。
///
/// 第二次（本轮）：「如果想看月视图下面的信息区域，在下滑的时候应该是**先
/// 收起上面为一行**，**然后再是下面信息区域滚动**向下」。
///
/// 所以现在的心智是**一根滚动轴两段内容**（Material 折叠头那套）：往下看 →
/// 先压缩上面的网格，压到底才滚下面；往上看 → 先让下面退回顶部，到顶才把
/// 网格展开回来。
///
/// ## 两层测试
///
/// 1. **纯函数** [MonthPanelDragArea.collapseTakesPriority]：「哪段归谁」
///    是这里唯一容易改错的地方（上一轮就改反过），必须能单测；
/// 2. **真实手势**：走 `Listener` + 闸门 + physics 的整条链路，钉住「一次
///    连续拖动里先收网格、再滚列表」和「列表不会同时跟着动」。
void main() {
  group('collapseTakesPriority：哪段归谁（纯函数）', () {
    test('向上拖（dy < 0，要看下面）：网格还没收完就先收网格', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: -20,
          // 列表明明还能滚 —— 上一轮的实现会把这位移给列表，正是要改的点。
          listCanScroll: true,
          gridCanAbsorb: true,
        ),
        isTrue,
        reason: '用户口径：下滑要先收起上面为一行，再滚下面的信息',
      );
    });

    test('向上拖且网格已收到底：位移交给列表', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: -20,
          listCanScroll: true,
          gridCanAbsorb: false,
        ),
        isFalse,
        reason: '网格已经收成一行了，再拖必须滚列表（否则手指在动画面不动）',
      );
    });

    test('向上拖且网格已收到底、列表也到底：谁都不动（交给边界回弹）', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: -20,
          listCanScroll: false,
          gridCanAbsorb: false,
        ),
        isFalse,
      );
    });

    test('向下拖（dy > 0，往回看）且列表不在顶部：先让列表退回顶部', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 20,
          listCanScroll: true,
          gridCanAbsorb: true,
        ),
        isFalse,
        reason: '往回看时先把内容收回去（列表先回到顶部），网格最后才展开',
      );
    });

    test('向下拖且列表已在顶部：位移转成网格展开', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 20,
          listCanScroll: false,
          gridCanAbsorb: true,
        ),
        isTrue,
        reason: '内容已经在顶部了，继续往下拖就该把上面的网格展回来',
      );
    });

    test('向下拖且网格已完全展开：谁都不动', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 20,
          listCanScroll: false,
          gridCanAbsorb: false,
        ),
        isFalse,
      );
    });

    test('dy == 0：不归任何人（避免零位移被当成一次收放起点）', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 0,
          listCanScroll: true,
          gridCanAbsorb: true,
        ),
        isFalse,
      );
    });
  });

  group('真实手势：一根轴两段内容', () {
    /// [itemCount] × 80 决定内容能不能滚（视口 300）。
    /// [gridCanAbsorb] 决定"网格还能不能收放"，默认恒真（= 永不收到底）。
    Widget harness({
      required ScrollController controller,
      required MonthPanelDragState dragState,
      required List<double> collapseDeltas,
      required int itemCount,
      bool Function(double dy)? gridCanAbsorb,
    }) {
      dragState.gridCanAbsorb = gridCanAbsorb ?? (_) => true;
      dragState
        ..onCollapseStart = () {}
        ..onCollapseUpdate = collapseDeltas.add
        ..onCollapseEnd = (_) {};
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: MonthPanelDragArea(
              dragState: dragState,
              child: SingleChildScrollView(
                controller: controller,
                physics: MonthPanelScrollPhysics(dragState: dragState),
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

    testWidgets('网格还能收：往上拖只收网格，列表一个像素都不动', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          itemCount: 20,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('row 0'), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty, reason: '这段位移应该归网格收放');
      expect(
        deltas.every((d) => d <= 0),
        isTrue,
        reason: '向上拖的 delta 是负的（收起方向）',
      );
      expect(
        controller.offset,
        0,
        reason: '网格还没收完时，列表**不许**跟着滚 —— 这正是本轮要修的行为'
            '（上一轮是列表先滚、网格不动）',
      );
    });

    testWidgets('网格收到底之后：同一次手势里接着滚列表', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      // 用一个可变的开关模拟"网格吃到边界"：第一次问还能收，之后就不能了。
      var absorbRemaining = 60.0;
      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          itemCount: 20,
          gridCanAbsorb: (dy) {
            if (dy < 0) {
              return absorbRemaining > 0;
            }
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      // 模拟网格在吃掉 60px 后到底：用一次拖拽，拖动过程中递减预算。
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row 0')),
      );
      var consumed = 0.0;
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        consumed += 20;
        if (consumed >= absorbRemaining) {
          absorbRemaining = 0;
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty, reason: '前半段应该收了网格');
      expect(
        controller.offset,
        greaterThan(0),
        reason: '网格吃到底后，**同一次手势**剩下的位移必须交给列表 —— '
            '不该要求用户抬手重来',
      );
    });

    testWidgets('往回看：列表不在顶部时先退回列表，网格展开靠后', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          itemCount: 20,
        ),
      );
      await tester.pumpAndSettle();

      // 先把列表滚下去一点（模拟"已经看了一段内容"）。
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      final collapseBefore = deltas.length;

      // 拖容器中心而不是某一行：offset=200 时 row 10 已经滚出可视区，
      // 拿它当拖动起点会命中不到（本仓实测 delta 一直为 0）。
      await tester.drag(
        find.byType(MonthPanelDragArea),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();

      expect(
        deltas.length,
        collapseBefore,
        reason: '列表还没回到顶部时，往下拖应该先收列表，不该同时展开网格',
      );
      expect(
        controller.offset,
        lessThan(200),
        reason: '这段位移归列表（内容往回收）',
      );
    });

    testWidgets('列表已在顶部、网格还没全展开：往下拖展开网格', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          itemCount: 20,
        ),
      );
      await tester.pumpAndSettle();

      // 已在顶部，直接往下拖。
      await tester.drag(find.text('row 0'), const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty, reason: '内容已在顶部，继续下拉 = 展开网格');
      expect(
        deltas.every((d) => d >= 0),
        isTrue,
        reason: '向下拖的 delta 是正的（展开方向）',
      );
      expect(controller.offset, 0, reason: '列表已在顶部，不该被这段位移推动');
    });

    testWidgets('闸门开着时抬手不起惯性（不会自己滑走一截）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          itemCount: 20,
        ),
      );
      await tester.pumpAndSettle();

      // 快速上甩：网格全程消费这段位移（gridCanAbsorb 恒真）。
      await tester.fling(find.text('row 0'), const Offset(0, -150), 1200);
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty);
      expect(
        controller.offset,
        0,
        reason: '这次手势的位移全归网格，列表不该在抬手后带着惯性滑走',
      );
    });
  });
}
