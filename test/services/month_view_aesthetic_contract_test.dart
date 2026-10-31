import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/day_view/day_view_agenda_surface.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_calendar_card.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid_handle.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_metrics.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_drag_area.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_overview.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_surface.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_view_toolbar.dart';

/// 月视图**版式**的结构契约（2026-10-23 重写）。
///
/// ## 用户口径（这一轮的原话）
///
/// > 「感觉有点丑呢，你能不能改成我截图的这个小米日历的，就是拉杆区域，
/// > 还有框框区域像这样，下面的信息区域的也改成这样，单独的卡片，而不是一个
/// > 整体大卡片」
///
/// 拆成三条可断言的结构：
///
/// 1. **日历是一张白卡**：网格外面套一层 [MonthCalendarCard]；
/// 2. **拉杆在日历卡内部、卡底**（不在信息区，也不在两者之间的夹缝里）；
/// 3. **信息区是一列独立的卡**：不再有一整块通栏白板包着它们。
///
/// 三条都是"树结构 + 几何"，纯逻辑测不出来，所以放 `test/services/`
/// （TEST-POLICY：`test/widgets` / `test/screens` 不再新增）。
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

  tearDown(() {
    MonthViewScreen.debugSeedLuminance = null;
    provider.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: MonthViewScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  group('上半：日历是一张白卡，拉杆在卡里', () {
    testWidgets('网格外面套着 MonthCalendarCard', (tester) async {
      await pumpScreen(tester);

      expect(
        find.byType(MonthCalendarCard),
        findsOneWidget,
        reason:
            '用户口径「框框区域像这样」—— 小米日历的表格是一张白卡。'
            '没有这层卡，42 个格子的边框会直接铺在壁纸上（就是上一版"有点丑"的版面）',
      );
      expect(
        find.descendant(
          of: find.byType(MonthCalendarCard),
          matching: find.byType(MonthGrid),
        ),
        findsOneWidget,
        reason: '网格必须在这张卡里面（卡是它的底）',
      );
    });

    testWidgets('月份导航在日历卡内部（不在玻璃带里）', (tester) async {
      // 用户口径（2026-10-23）：「顶部的 2026年10月，左右按钮，回今日区域，
      // 看看这些能不能和下面的日期做一下整体化」。
      //
      // 判据是**结构**：工具行必须作为 `MonthCalendarCard` 的后代出现。
      // 若有人把它塞回 `TimetablePageChromeShell(toolbar: ...)`，它会脱离卡片，
      // 与本条断言立刻冲突 —— 这正是要守住的那条"整体化"。
      await pumpScreen(tester);
      final toolbar = find.byType(MonthViewToolbar);
      expect(toolbar, findsOneWidget, reason: '导航必须存在');

      expect(
        find.descendant(of: find.byType(MonthCalendarCard), matching: toolbar),
        findsOneWidget,
        reason:
            '月份导航必须在日历卡内部。它控制的正是这张卡 —— '
            '放回满宽玻璃带里就又变成"上面的仪表盘遥控下面的表格"',
      );

      // 几何补充：导航在表格之上。
      final navRect = tester.getRect(toolbar);
      final gridRect = tester.getRect(find.byType(MonthGrid).first);
      expect(navRect.bottom, lessThanOrEqualTo(gridRect.top + 1));
    });

    testWidgets('拉杆在日历卡内部，且贴着卡的底部', (tester) async {
      await pumpScreen(tester);
      final handle = find.byType(MonthGridHandle);
      expect(handle, findsOneWidget, reason: '拉杆必须存在');

      // ① 祖先链里必须有 MonthCalendarCard —— 这是"拉杆属于这张卡"的结构证据。
      final insideCalendar = find.descendant(
        of: find.byType(MonthCalendarCard),
        matching: handle,
      );
      expect(
        insideCalendar,
        findsOneWidget,
        reason:
            '拉杆必须在日历卡**内部**（用户口径：小米日历那根条属于那张表）。'
            '放在卡外面 —— 不管是夹在网格与信息区之间，还是放进信息区 —— '
            '归属都会讲反',
      );

      // ② 几何：拉杆在网格底边之下、卡底边附近（卡底正中那根条）。
      final handleRect = tester.getRect(handle);
      final gridRect = tester.getRect(find.byType(MonthGrid).first);
      final cardRect = tester.getRect(find.byType(MonthCalendarCard));
      expect(
        handleRect.top,
        greaterThanOrEqualTo(gridRect.bottom - 0.5),
        reason: '拉杆必须在网格下方（不能压在日期格上）',
      );
      expect(
        handleRect.center.dy,
        greaterThan(cardRect.center.dy),
        reason: '拉杆应在日历卡下半部、贴着卡底',
      );
    });

    testWidgets('拉杆颜色是面板墨色的半透明档（不是壁纸判出的黑/白）', (tester) async {
      await pumpScreen(tester);
      final handle = tester.widget<MonthGridHandle>(
        find.byType(MonthGridHandle),
      );
      expect(
        handle.barColor.a,
        lessThan(1),
        reason:
            '拉杆压在白色日历卡上，应为半透明墨色。'
            '满 alpha 的黑/白是"画在照片上"的口径（2026-10-21），卡一变白就过重',
      );
    });
  });

  group('下半：信息区是一列独立的卡，不是一整块白板', () {
    testWidgets('拖动区与卡片之间没有那块通栏白板的裁剪层', (tester) async {
      await pumpScreen(tester);

      // 旧版式的结构证据：`MonthPanelDragArea`（拖拽/滚动区）与信息内容之间夹着
      // 一层 `ClipPath`（`MonthPanelTopCurveClipper`）+ 一块白底 ColoredBox
      // —— 那就是"整块大卡片"。现在卡片直接浮在壁纸上，中间只剩滚动视图。
      expect(
        find.descendant(
          of: find.byType(MonthPanelDragArea),
          matching: find.byType(ClipPath),
        ),
        findsNothing,
        reason:
            '信息区外面还套着 ClipPath ⇒ 那块通栏白板又回来了。'
            '用户口径是「单独的卡片，而不是一个整体大卡片」',
      );
    });

    // ⚠️ 「卡与卡之间有空隙」那条放在 `month_panel_style_test.dart`：那边给的是
    // **有课程的月份**（概览卡 + 预览卡 ≥2 张）。整页 fixture 用的是空 provider，
    // 信息区只有一张空态卡，量不出卡间缝隙 —— 在这里写只会变成"前置就红"。

    testWidgets('信息卡与日历卡共用同一条外沿（左右对齐）', (tester) async {
      await pumpScreen(tester);
      final calendar = tester.getRect(find.byType(MonthCalendarCard));
      final firstCard = tester.getRect(
        find
            .descendant(
              of: find.byType(MonthPanelOverview),
              matching: find.byType(DayViewAgendaSurface),
            )
            .first,
      );
      expect(
        firstCard.left,
        closeTo(calendar.left, 2),
        reason:
            '信息卡与日历卡的左沿必须落在同一条线上 —— '
            '两种卡左右错开是"拼装感"的来源（2026-10-21 评审量过四条左边线）',
      );
      expect(firstCard.right, closeTo(calendar.right, 2));
    });

    testWidgets('信息卡填充色 = 日历卡填充色（上下两种卡同一套）', (tester) async {
      await pumpScreen(tester);
      final context = tester.element(find.byType(MonthPanelOverview));
      final scheme = Theme.of(context).colorScheme;
      expect(
        monthInfoCardFill(context).toARGB32(),
        scheme.surface.toARGB32(),
        reason:
            '信息卡取 surface（白）—— 与上半那张日历卡同色。'
            '旧口径取 surfaceContainerHighest 是因为当时卡片躺在白色面板里、'
            '必须与板底拉开；面板没了，再用灰卡就读成两种语言',
      );
    });
  });

  group('左轴只有一条（由卡片外沿推出来）', () {
    test('卡片外沿 + 卡片内边距 = 文字左轴', () {
      expect(
        MonthMetrics.axisInset,
        closeTo(MonthMetrics.cardInset + MonthMetrics.cardPadding, 0.001),
        reason:
            '文字左轴必须由卡片外沿推出来（轴一改卡片就跟着走），'
            '不能两处各写一个数',
      );
    });

    test('网格内边距让格子填充边落在文字轴上', () {
      expect(
        MonthMetrics.gridHorizontalPadding,
        closeTo(MonthMetrics.axisInset - MonthMetrics.cellGap, 0.001),
        reason:
            '格子自己还带一圈 Padding(cellGap)，两者相加才是格子填充边的位置；'
            '两处不同源会算歪"正方形行高"',
      );
    });

    test('网格左右内边距与卡片外沿同源（不另写常数）', () {
      for (final value in [
        MonthMetrics.cardInset,
        MonthMetrics.cardPadding,
        MonthMetrics.axisInset,
        MonthMetrics.gridHorizontalPadding,
      ]) {
        expect(value, greaterThan(0));
      }
      expect(
        MonthMetrics.cardInset,
        lessThan(MonthMetrics.axisInset),
        reason: '外沿必须比文字轴小（中间隔着卡片内边距）',
      );
    });
  });
}
