import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_drag_area.dart';

/// 月视图面板滑动的**一体化**判据（2026-10-21 第三轮）。
///
/// ## 前两版为什么都废了（这段是本轮最有价值的部分）
///
/// **第一版**：外层 `Listener` 判归属、一个布尔"闸门"挡住列表。
/// 实测列表照样每次滚 416px。死因是**事件派发顺序**：`Listener` 是
/// `Scrollable` 的**祖先**，Flutter 指针事件按 hit-test 路径**最深者先收到**，
/// 等 Listener 改闸门时列表早把这一帧处理完了。
///
/// **第二版**：判据搬进自定义 `ScrollPhysics`（还补了 `applyTo` 重写）。
/// 单测全绿、真机仍然各滚各的。死因更隐蔽：
///
/// > 网格收起 ⇒ 面板变高 ⇒ 列表 `viewportDimension` 变大 ⇒
/// > `maxScrollExtent` 变小 ⇒ 缩到 0 时 `Scrollable` 判定不可滚动，
/// > **当场 `goBallistic` 结束整次拖动**。
///
/// 真实页面上实测到的轨迹（拖动中逐步采样）：`max: 61 → 36 → 11 → 0`，
/// 同一帧发出 `ScrollEndNotification`，此后指针怎么动、physics 一次都不再
/// 被调用 —— 网格停在半收起、抬手弹回全展开。用户看到的正是
/// 「上面收不起来、两个滚动各干各的」。
///
/// ## 本版的结构结论
///
/// 「面板高度在同一次手势里变化」与「`Scrollable` 自己接管拖动」**不可共存**。
/// 所以列表的用户滚动整个关掉（`NeverScrollableScrollPhysics`），位移一律由
/// `MonthPanelDragArea` 算好 `jumpTo` 进去：一个指针源驱动两块，一体化是结构
/// 保证的，而不是靠调参数。
///
/// ⚠️ 真实页面上的端到端验证在 `month_view_gesture_contract_test`（那条会在
/// 真实页面上拖、并断言网格真的收到 0）；本文件负责**组件级**的四条顺序与
/// 生命周期判据。
void main() {
  /// 组件级 harness：一个能滚的列表 + 可变的"网格还能不能收"。
  ///
  /// [absorbBudget] 是网格还能吃多少位移（模拟展开进度），每吃一次递减；
  /// 递减到 0 就表示"网格已收到底"，此后位移该交给列表。
  Widget harness({
    required ScrollController controller,
    required MonthPanelDragState dragState,
    required List<double> collapseDeltas,
    double? absorbBudget,
    int itemCount = 30,
  }) {
    dragState.gridCanAbsorb = (dy) {
      if (dy >= 0) {
        return false; // 本 harness 只测收起方向
      }
      return absorbBudget == null || absorbBudget! > 0;
    };
    dragState.onCollapseStart = () {};
    dragState.onCollapseUpdate = (d) {
      collapseDeltas.add(d);
      if (absorbBudget != null) {
        absorbBudget = (absorbBudget! + d).clamp(0.0, double.infinity);
      }
    };
    dragState.onCollapseEnd = (_) {};

    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: MonthPanelDragArea(
            scrollController: controller,
            dragState: dragState,
            child: SingleChildScrollView(
              controller: controller,
              // ⚠️ 必须是这个：让 Scrollable 自己滚就会在面板变高时
              // 结束拖动（见文件头第二版死因）。
              physics: const NeverScrollableScrollPhysics(),
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

  group('collapseTakesPriority：哪段归谁', () {
    test('向上拖（看下面）：网格还没收完就先收网格，与列表能否滚无关', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: -20,
          listCanScroll: true, // 列表明明能滚 —— 旧行为会把这位移给列表
          gridCanAbsorb: true,
        ),
        isTrue,
        reason: '用户口径：下滑要先收起上面为一行，再滚下面的信息',
      );
    });

    test('向上拖且网格已收到底：交给列表', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: -20,
          listCanScroll: true,
          gridCanAbsorb: false,
        ),
        isFalse,
      );
    });

    test('向下拖且列表不在顶部：先让列表回退', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 20,
          listCanScroll: true,
          gridCanAbsorb: true,
        ),
        isFalse,
      );
    });

    test('向下拖且列表已在顶部：转成网格展开', () {
      expect(
        MonthPanelDragState.collapseTakesPriority(
          dy: 20,
          listCanScroll: false,
          gridCanAbsorb: true,
        ),
        isTrue,
      );
    });

    test('dy == 0：不归任何人', () {
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

  group('一个指针源驱动两块（同一条手势）', () {
    testWidgets('网格还能收：往上拖只收网格，列表一像素不动', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('row 0'), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty, reason: '这段位移该归网格');
      expect(
        deltas.every((d) => d <= 0),
        isTrue,
        reason: '向上拖的 delta 是负的（收起方向）',
      );
      expect(
        controller.offset,
        0,
        reason: '网格还没收完时列表**不许**跟着滚 —— 这正是用户抱怨的行为',
      );
    });

    testWidgets('网格收到底后：同一次手势里接着滚列表（一体化）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
          absorbBudget: 60, // 网格还能吃 60px
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row 0')),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // 前 3 步吃掉网格预算，之后必须交给列表 —— 全程同一条手势。
      expect(deltas, isNotEmpty, reason: '前半段收网格');
      expect(
        controller.offset,
        greaterThan(0),
        reason: '网格吃到底后，同一次手势剩下的位移必须交给列表，'
            '不该要求用户抬手重来（"一体化"就是这个意思）',
      );
    });

    testWidgets('往下拖且列表不在顶部：只动列表，网格不展开', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpTo(300);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(MonthPanelDragArea), const Offset(0, 100));
      await tester.pumpAndSettle();

      expect(
        deltas,
        isEmpty,
        reason: '列表还没回到顶部时，下拉只该收列表，网格不许动',
      );
      expect(controller.offset, lessThan(300), reason: '列表应回退了');
    });

    testWidgets('列表在顶部 + 网格未满：往下拖展开网格', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];
      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
        ),
      );
      await tester.pumpAndSettle();

      // ⚠️ 必须在 pump 之后再改：harness() 内部会给 gridCanAbsorb 赋一个
      // "只测收起方向"的默认实现，先设会被它覆盖掉。
      dragState.gridCanAbsorb = (_) => true;

      await tester.drag(find.text('row 0'), const Offset(0, 100));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty, reason: '列表已在顶部，下拉应展开网格');
      expect(
        deltas.every((d) => d >= 0),
        isTrue,
        reason: '向下拖的 delta 是正的（展开方向）',
      );
      expect(controller.offset, 0, reason: '列表已在顶部，不该被推动');
    });

    testWidgets('抬手后列表按速度补惯性', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final dragState = MonthPanelDragState();
      final deltas = <double>[];

      await tester.pumpWidget(
        harness(
          controller: controller,
          dragState: dragState,
          collapseDeltas: deltas,
        ),
      );
      await tester.pumpAndSettle();

      // 网格恒不可收 → 位移全给列表，快速上甩应带出一段额外滚动。
      dragState.gridCanAbsorb = (_) => false;
      await tester.fling(find.text('row 0'), const Offset(0, -120), 1200);
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        greaterThan(0),
        reason: '列表自己的滚动必须能走（用户滚动关掉了，位移得由我们落进去）',
      );
    });
  });
}
