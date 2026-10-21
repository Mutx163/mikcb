import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/month_grid_collapse.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid_handle.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_drag_area.dart';

/// 月视图**手势分区**的契约测试（2026-10-21）。
///
/// ## 为什么必须有一条这样的测试
///
/// 用户连续两次报同一件事：
/// 1. 第一次：「条目视图不支持左右滑动，只支持上下滑动」；
/// 2. 第二次（改完仍然）：「我刚刚说的你有没有完全实现啊，为什么我现在在日期
///    表格的拉杆下面，还能左右滑动啊」。
///
/// 第一次只把拉杆移出了面板容器 —— 但**横向翻月那层 PageView 仍然包着整页**，
/// 于是整个下半屏都能左右翻月。外观改了、行为没改。
///
/// 所以这条测试钉的是**结构**：整页只能有**一个**横向可滚的 PageView，
/// 而且拉杆必须在它外面。
///
/// 纯逻辑测不出这件事（这是 widget 树结构），所以放 `test/services/`
/// —— `test/widgets/` 按 TEST-POLICY 不再新增。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
  });

  tearDown(() => provider.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthViewScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('整页只有一个横向 PageView（下半屏不可能左右翻月）', (tester) async {
    await pumpScreen(tester);
    expect(
      find.byType(PageView),
      findsOneWidget,
      reason:
          '月视图只能有一个 PageView（网格那一层）。'
          '第二个（包住整页的）会让拉杆与条目面板也能左右翻月 —— '
          '用户 2026-10-21 两次报的就是这个。',
    );
  });

  testWidgets('拉杆不在 PageView 子树里（横向手势到不了它）', (tester) async {
    await pumpScreen(tester);
    final handle = find.byType(MonthGridHandle);
    expect(handle, findsOneWidget, reason: '拉杆必须存在');

    final pagerElement = tester.element(find.byType(PageView));
    var insidePager = false;
    handle.evaluate().single.visitAncestorElements((ancestor) {
      if (identical(ancestor, pagerElement)) {
        insidePager = true;
        return false;
      }
      return true;
    });
    expect(
      insidePager,
      isFalse,
      reason:
          '拉杆被包进了 PageView 子树，横向手势会被外层的横向滚动抢走。'
          '拉杆是表格的把手，必须在 PageView 外面。',
    );
  });

  testWidgets('PageView 的高度没有霸占整屏（面板与拉杆在它外面）', (tester) async {
    await pumpScreen(tester);
    final pagerBox = tester.renderObject<RenderBox>(find.byType(PageView));
    final screenHeight = tester.getSize(find.byType(MonthViewScreen)).height;
    expect(
      pagerBox.size.height,
      lessThan(screenHeight * 0.85),
      reason: 'PageView 若接近整屏高，说明它又包住了面板区域（回归成旧结构）',
    );
  });

  // ── 面板列表的用户滚动必须关掉（2026-10-21 第三轮）──
  //
  // 第二版把判据放进自定义 ScrollPhysics，单测全绿、真机仍然各滚各的。
  // 根因是机制冲突，不是参数问题：
  //
  //   网格收起 ⇒ 面板变高 ⇒ 列表 viewportDimension 变大 ⇒ maxScrollExtent
  //   变小 ⇒ 缩到 0 时 Scrollable 判定不可滚动、当场 goBallistic 结束拖动。
  //
  // 实测轨迹 max: 61 → 36 → 11 → 0 + ScrollEndNotification，此后指针怎么动
  // 都不再被处理。所以必须让 Scrollable 完全别管用户滚动。
  testWidgets('面板列表挂的是 NeverScrollableScrollPhysics（Scrollable 不参与拖拽）', (
    tester,
  ) async {
    await pumpScreen(tester);
    final scrollView = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(MonthPanelDragArea),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(
      scrollView.physics,
      isA<NeverScrollableScrollPhysics>(),
      reason: '让 Scrollable 自己滚，它会在"面板变高使 maxScrollExtent 缩到 0"'
          '的瞬间结束整次拖动 —— 这是第二版真机上失效的死因',
    );
  });

  // ── 面板滑动的一体化（2026-10-21 第三轮，必须跑在真实页面上）──
  //
  // 前两版都栽在"单测绿、真机废"：测试搭自己接线的 harness，测的是我以为的
  // 机制。所以这条直接在真实页面上拖，断言的是**用户能看到的两件事**：
  // 网格真的收到 0，然后是列表真的滚了 —— 而且全程同一条手势。
  testWidgets('真实页面：一次长拖先把网格收成一行，再滚列表', (tester) async {
    await pumpScreen(tester);

    final area = find.byType(MonthPanelDragArea);
    expect(area, findsOneWidget, reason: '面板拖拽区必须存在');
    final controller = tester
        .widget<SingleChildScrollView>(
          find.descendant(
            of: area,
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .controller!;

    double collapse() =>
        tester.widget<MonthGrid>(find.byType(MonthGrid)).collapseProgress;

    expect(collapse(), 1.0, reason: '进入时网格应完全展开');

    // 一条连续手势：网格必须真的走到底（第二版到第 4 步就被掐断了）。
    final gesture = await tester.startGesture(tester.getCenter(area));
    var gridMoved = false;
    var listMovedWhileGridOpen = false;
    var prevT = collapse();
    var prevOffset = controller.offset;
    for (var step = 0; step < 20; step++) {
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      final nextT = collapse();
      final nextOffset = controller.offset;
      if (nextT < prevT - 1e-9) {
        gridMoved = true;
      }
      if (nextT > 0.001 && (nextOffset - prevOffset).abs() > 0.5) {
        listMovedWhileGridOpen = true;
      }
      prevT = nextT;
      prevOffset = nextOffset;
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      gridMoved,
      isTrue,
      reason: '拖面板必须驱动网格收放 —— 上一版这里整段没反应',
    );
    expect(
      collapse(),
      0.0,
      reason: '一次足够长的上拖必须把网格收成一行。'
          '若停在中间（实测旧版停在 0.67），说明拖动被 Scrollable 掐断了',
    );
    expect(
      listMovedWhileGridOpen,
      isFalse,
      reason: '网格没收到底之前列表不许跟着滚：'
          '这正是用户抱怨的「它可以直接下滑信息区域滚动，而不是先收起上面的东西」',
    );
  });

  test('网格 + 把手 + 面板 正好铺满可用高度（把手不被挤掉）', () {
    final layout = monthGridLayout(
      t: 1,
      availableHeight: 800,
      headerHeight: MonthGrid.headerHeight,
      horizontalPadding: MonthGrid.horizontalPadding,
      availableWidth: 360,
      weekNumberColumnVisible: true,
      weekLabelWidth: MonthGrid.weekLabelWidth,
      minRowHeight: MonthGrid.minRowHeight,
      maxRowHeight: MonthGrid.maxRowHeight,
      keptRow: 0,
      handleHeight: MonthGridHandle.extent,
    );
    expect(
      layout.gridHeight + MonthGridHandle.extent + layout.panelHeight,
      closeTo(800, 1e-9),
      reason: '网格 + 把手 + 面板 必须正好铺满，多出来就会把面板顶出屏幕',
    );
    expect(MonthGridHandle.extent, greaterThan(0));
  });
}
