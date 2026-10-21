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

  // ── 面板列表必须真的接上那份 physics（2026-10-21 第二轮）──
  //
  // 用户口径：「下滑的时候应该先收起上面为一行，然后再是下面信息区域滚动」。
  //
  // 判据住进了 physics（`MonthPanelScrollPhysics`），但那要靠**页面把它传给
  // 列表**才生效。接线漏了的话：physics 写得再对，列表也照旧自己滚 —— 而且
  // 单测 `month_panel_drag_area_test` 是拿 harness 自己接的线，**抓不到漏接**。
  // 所以必须在真实页面里钉一次"列表身上挂的就是这份 physics"。
  testWidgets('面板列表挂的是 MonthPanelScrollPhysics（不是默认 physics）', (tester) async {
    await pumpScreen(tester);
    final scrollView = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(MonthPanelDragArea),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(
      scrollView.physics,
      isA<MonthPanelScrollPhysics>(),
      reason: '列表没挂上游 physics 的话，拖拽判据一趟都不跑，'
          '会退回"列表先滚、网格不动"的旧行为',
    );
    // 挂上的那份必须与页面里那个 dragState 是同一个实例：
    // 两个实例 = 状态各记一份，判据永远读到"网格不能收"。
    final physics = scrollView.physics! as MonthPanelScrollPhysics;
    final area = tester.widget<MonthPanelDragArea>(
      find.byType(MonthPanelDragArea),
    );
    expect(
      identical(physics.dragState, area.dragState),
      isTrue,
      reason: 'physics 与 DragArea 必须共用一个 dragState（状态各记一份就永远对不上）',
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
