import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:university_timetable/screens/import/warehouse/warehouse_shared.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

/// 回归测试（2026-10-10）：字母条跳转后，顶部**可折叠大标题**必须像手动滑动
/// 那样收成小标题。
///
/// 真因：`ItemScrollController.jumpTo` 走的是 ScrollablePositionedList 的
/// 「视口锚点」——先把内部 ScrollController 归零，再用 viewport `anchor` 把目标
/// item 摆到位（见 scrollable_positioned_list 的 `_jumpTo`）。整个过程
/// `ScrollPosition.pixels` 始终是 0，`jumpTo(0)` 又因为 `pixels == value` 跳过
/// 通知分发，于是**一个滚动通知都不发**。页面壳的可折叠大标题只认滚动通知
/// （hyperos_page.dart 的 `_handleBodyScrollForBlur` →
/// `HyperosExitUntilCollapsedScrollBehavior.handleScroll`），跳转后大标题不收、
/// 正文却已经滚到它下面去 —— 用户看到「页面顶部很奇怪」。
///
/// 修法：跳转后借列表真实的滚动位补发一条滚动通知
/// （[warehouseResyncCollapsibleTitleFromListScroll]）。
///
/// 判据是**顶栏实际渲染高度**（`HyperosCollapsibleTopAppBar` 的盒子高）：
/// 展开 ≈ 折叠行 52 + 大标题 38.4 + 下边距 4，折叠 ≈ 52 + 4。两者差 38.4px，
/// 与系统字号联动，比「文本在不在」更贴近用户看到的那件事。
const String _kTitle = '教务系统导入';

/// 造一个够长的列表：跳转目标放在第 20 项，保证 target 前面有足够多的内容，
/// 让 viewport `anchor` 把 `minScrollExtent` 压成很负的值（这正是折叠判断的依据）。
Future<ItemScrollController> _pumpPage(WidgetTester tester) async {
  final controller = ItemScrollController();
  await tester.pumpWidget(
    TestApp(
      home: HyperosSubpage(
        title: const Text(_kTitle),
        child: ScrollablePositionedList.builder(
          itemCount: 200,
          itemScrollController: controller,
          itemBuilder: (context, index) =>
              SizedBox(height: 60, child: Text('item $index')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

double _headerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(HyperosCollapsibleTopAppBar)).height;

double _itemTop(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('jumpTo 本身不发滚动通知，大标题不收（守 bug 原型）', (tester) async {
    final controller = await _pumpPage(tester);

    // 进入页面：大标题展开。
    final expandedHeight = _headerHeight(tester);
    expect(expandedHeight, greaterThan(80), reason: '展开态应含大标题那一截');

    // 跳到第 20 项 —— 字母条跳转走的同一条路。
    controller.jumpTo(index: 20, alignment: 0.2);
    await tester.pumpAndSettle();

    // 内容确实滚过去了（否则这条测试什么都没测）。
    expect(find.text('item 20'), findsOneWidget);
    // 但标题没收 —— 这就是用户报的「顶部很奇怪」。
    expect(
      _headerHeight(tester),
      expandedHeight,
      reason: 'jumpTo 走视口锚点、不发滚动通知，大标题原封不动',
    );
  });

  testWidgets('跳转后补同步，大标题像手动滑动那样收起来', (tester) async {
    final controller = await _pumpPage(tester);
    final expandedHeight = _headerHeight(tester);

    controller.jumpTo(index: 20, alignment: 0.2);
    await tester.pumpAndSettle();

    final topBefore = _itemTop(tester, 'item 20');
    expect(_headerHeight(tester), expandedHeight, reason: '同步前标题仍展开');

    // 修法本体：取到列表的滚动位，补发一条滚动通知。
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(
      warehouseResyncCollapsibleTitleFromListScroll(scrollable),
      isTrue,
      reason: '滚动位应当在界内，能补发通知',
    );
    await tester.pumpAndSettle();

    // 大标题收起 —— 与手动滑动到同一位置的终态一致。
    expect(
      _headerHeight(tester),
      lessThan(expandedHeight - 30),
      reason: '折叠后应比展开态矮一整个大标题（≈38.4px）',
    );
    // 正文没有被额外平移：内容还是停在跳转换算出来的落点上。
    expect(
      _itemTop(tester, 'item 20'),
      closeTo(topBefore, 0.5),
      reason: '折叠同步不该让正文位移（delta 恒为 0）',
    );
    expect(find.text('item 20'), findsOneWidget);
  });

  testWidgets('没有锚点偏移的普通列表补同步，标题不会被误收起', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          title: const Text(_kTitle),
          child: ListView(
            children: const [
              SizedBox(height: 2000, child: Text('list')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expandedHeight = _headerHeight(tester);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    // 普通 ListView：pixels == minScrollExtent == 0，没有任何东西滚到顶栏之下，
    // 此时补同步只是把「已滚动量 0」如实告诉页面壳，标题该是展开就还是展开。
    warehouseResyncCollapsibleTitleFromListScroll(scrollable);
    await tester.pumpAndSettle();

    expect(_headerHeight(tester), expandedHeight);
  });

  testWidgets('下滑→滑回第一组→再下滑，第二次也要收起（用户实机序列）', (tester) async {
    final controller = await _pumpPage(tester);
    final expandedHeight = _headerHeight(tester);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    // ① 下滑到第 20 项：第一次，正常收起。
    controller.jumpTo(index: 20, alignment: 0.2);
    await tester.pumpAndSettle();
    expect(warehouseResyncCollapsibleTitleFromListScroll(scrollable), isTrue);
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), lessThan(expandedHeight - 30));
    final firstDownHeight = _headerHeight(tester);

    // ② 滑回第一组（index 0）。这一跳 anchor 为正、pixels 会越过
    //    minScrollExtent，滚动位自己开弹簧回弹，补同步按设计不发通知。
    controller.jumpTo(index: 0, alignment: 0.2);
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), expandedHeight, reason: '回到第一组应重新展开');

    // ③ 再下滑到第 20 项：第二次，也必须收起。
    controller.jumpTo(index: 20, alignment: 0.2);
    await tester.pumpAndSettle();
    expect(
      warehouseResyncCollapsibleTitleFromListScroll(scrollable),
      isTrue,
      reason: '第二次下滑后滚动位仍在界内，必须能补发通知',
    );
    await tester.pumpAndSettle();

    expect(
      _headerHeight(tester),
      firstDownHeight,
      reason: '第二次下滑后大标题必须和第一次一样收起',
    );
    expect(find.text('item 20'), findsOneWidget);
  });

  testWidgets('post-frame 回调里补同步，第二次下滑也要收起', (tester) async {
    final controller = await _pumpPage(tester);
    final expandedHeight = _headerHeight(tester);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    // 真实页面的接线方式：跳转后不直接同步，而是排一个 post-frame 回调
    // （anchor 要下一帧布局才生效）。这条测试钉住那条链路的终态。
    void jumpAndSync(int index) {
      controller.jumpTo(index: index, alignment: 0.2);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        warehouseResyncCollapsibleTitleFromListScroll(scrollable);
      });
    }

    jumpAndSync(20);
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), lessThan(expandedHeight - 30));
    final firstDownHeight = _headerHeight(tester);

    // 滑回第一组后重新展开，再下滑第二次。
    jumpAndSync(0);
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), expandedHeight);

    jumpAndSync(20);
    await tester.pumpAndSettle();
    expect(
      _headerHeight(tester),
      firstDownHeight,
      reason: 'post-frame 链路上第二次下滑也必须收起',
    );
    expect(find.text('item 20'), findsOneWidget);
  });

  testWidgets('手指连续滑动（中间不落定）跨过第一组再折返，也要收起', (tester) async {
    // 真实手势里手指划过一串字母，每个 actionUpdate 都是一次 jumpTo，
    // 中间没有 pumpAndSettle：跳到第一组会开一段回弹弹簧，弹簧还没跑完
    // 手指已经折返下滑、把弹簧中途掐死。这条测试复现这个时序。
    final controller = await _pumpPage(tester);
    final expandedHeight = _headerHeight(tester);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    void jumpAndSync(int index) {
      controller.jumpTo(index: index, alignment: 0.2);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        warehouseResyncCollapsibleTitleFromListScroll(scrollable);
      });
    }

    // ① 下滑：正常收起。
    jumpAndSync(20);
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), lessThan(expandedHeight - 30));
    final collapsedHeight = _headerHeight(tester);

    // ② 滑上去：一路划回第一组（不 settle，弹簧中途被掐死的时序）。
    for (var i = 19; i >= 0; i--) {
      jumpAndSync(i);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), expandedHeight, reason: '回到第一组应重新展开');

    // ③ 再下滑第二次：也必须收起。
    for (var i = 1; i <= 20; i++) {
      jumpAndSync(i);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      _headerHeight(tester),
      collapsedHeight,
      reason: '连续手势折返后，第二次下滑大标题必须照常收起',
    );
    expect(find.text('item 20'), findsOneWidget);
  });
}
