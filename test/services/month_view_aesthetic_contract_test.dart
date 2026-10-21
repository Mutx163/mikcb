import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/utils/page_wallpaper_luminance.dart';
import 'package:university_timetable/utils/wallpaper_luminance_profile.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_grid_handle.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_metrics.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_overview.dart';

/// 月视图**专业美学评审修复**的参数透传契约（2026-10-21）。
///
/// ## 为什么需要这一层
///
/// 判据本身在 `test/utils/month_cell_ink_test.dart` 里钉住了（逐行查询、
/// 4.5:1、圆点 3:1、拉杆满 alpha）。但那些全是纯函数测试 —— 它们证明
/// 「**如果**页面把逐行亮度传下来，就会判对」，却证明不了页面真的传了。
///
/// 本仓对这类漂移有过明确教训：删掉 `initialCourse` 的转发后，43 条存量
/// 用例照样全绿，因为它们只断言「页面打开了」，不看「页面拿到了什么」
/// （见 AGENTS.md 的「参数透传类改动」一节）。所以这里断言的是**收到的值**：
///
/// 1. `MonthGrid.rowLuminances` 长度是 6 —— 页面必须按行算，不是传个空表；
/// 2. `MonthGridHandle` 拿到了与页面同一套左轴常量对应的内边距；
/// 3. 面板左右的缩进落在唯一左轴上（不是旧的 6）。
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

  group('页面把「逐行亮度」真的传给了网格', () {
    testWidgets('rowLuminances 恒为 6 项（按行算，不是整屏一个数）', (tester) async {
      // ⚠️ 测试宿主机没有壁纸，剖面永远是 null —— 此时页面返回**空表**，
      // 网格与格子回落到整屏带（改动前的行为）。所以这里钉的是**契约形状**：
      // 要么空表（回落），要么恰好 6 项（逐行）；绝不能是"长度 1 的整屏值"
      // —— 那正是有人把逐行改回整屏时的写法。
      await pumpScreen(tester);
      final grids = tester.widgetList<MonthGrid>(find.byType(MonthGrid));
      expect(grids, isNotEmpty, reason: '至少要有一页网格在树上');
      for (final grid in grids) {
        expect(
          grid.rowLuminances.isEmpty || grid.rowLuminances.length == 6,
          isTrue,
          reason: 'rowLuminances 只能为空（回落）或恰好 6 项（逐行）。'
              '拿到 ${grid.rowLuminances.length} 项说明有人又把它退回"整屏一个数"了',
        );
      }
    });

    testWidgets('塞一份人造剖面后，网格真的收到 6 项（逐行判墨走得通）', (tester) async {
      // ⚠️ 这条是**咬合探针**：把页面里那行 `rowLuminances: _rowLuminances(...)`
      // 删掉（或改成常量空表），本条立即变红。没有它，上面那条"空表或 6 项"
      // 的断言在测试环境里永远不会因为漏传而失败 —— 因为两条路径都返回空表。
      MonthViewScreen.debugSeedLuminance = PageWallpaperLuminance(
        key: 'seeded',
        top: 0.55,
        body: 0.35,
        profile: WallpaperLuminanceProfile(
          rowLuminances: List<double>.generate(
            64,
            (i) => 0.58 - 0.42 * (i / 63),
          ),
        ),
      );
      await pumpScreen(tester);

      final grid = tester.widget<MonthGrid>(find.byType(MonthGrid).first);
      expect(
        grid.rowLuminances.length,
        6,
        reason: '有剖面时页面必须按行算 6 个亮度并传给网格。'
            '拿到 ${grid.rowLuminances.length} 项 —— 页面没有把逐行数据传下来，'
            '42 个格子又退回"整屏一个数"了',
      );
      expect(
        grid.rowLuminances.every((r) => r != null),
        isTrue,
        reason: '6 项都必须查得出值（null 说明网格顶边的定位算歪了）',
      );
      // 人造剖面自上而下变暗 ⇒ 行亮度必须递减。
      for (var i = 1; i < grid.rowLuminances.length; i++) {
        expect(
          grid.rowLuminances[i],
          lessThan(grid.rowLuminances[i - 1]!),
          reason: '第 $i 行不低于上一行 —— 说明 6 行查到的是同一段',
        );
      }
    });

    testWidgets('没有剖面时回落到空表（不是塞 6 个 null 冒充逐行数据）', (tester) async {
      await pumpScreen(tester);
      final grid = tester.widget<MonthGrid>(find.byType(MonthGrid).first);
      expect(
        grid.rowLuminances,
        isEmpty,
        reason: '测试环境没有壁纸 ⇒ 剖面不可得 ⇒ 必须是空表。'
            '若这里非空，说明页面在拿假数据判墨',
      );
    });
  });

  group('左轴只有一条（旧的四条已收）', () {
    test('网格内边距 + 格缝 = 面板内边距：卡片填充边同轴', () {
      expect(
        MonthGrid.horizontalPadding + MonthMetrics.cellGap,
        closeTo(MonthMetrics.panelInset, 0.001),
        reason: '网格卡片填充边与面板卡片填充边必须落在同一条竖线上。'
            '旧实现是 11.5dp 与 6dp —— 差 5.5dp，眼睛一眼能看出两根线',
      );
    });

    test('分区标题缩进后落在唯一左轴上', () {
      expect(
        MonthMetrics.panelInset + MonthMetrics.sectionTitleInset,
        closeTo(MonthMetrics.axisInset, 0.001),
        reason: '分区标题的文字墨迹要落在 axisInset 上（与品牌名同轴）',
      );
    });

    test('卡片填充边比文字轴外扩 2dp（光学对齐）', () {
      expect(
        MonthMetrics.axisInset - MonthMetrics.panelInset,
        closeTo(MonthMetrics.cardOpticalOutdent, 0.001),
        reason: '实心色块与文字左对齐时要往外让 2dp，否则读作"文字缩进了色块里"',
      );
    });
  });

  group('拉杆：按自己那段壁纸判色', () {
    test('给了壁纸亮度就按它判黑白（不再用整屏带墨色 × 0.32）', () {
      const ink = Color(0xFF1A1A1A);
      // 暗壁纸（拉杆压在深色水面上）：必须给出白条。
      expect(
        MonthGridHandle.resolveBarColor(
          inkColor: ink,
          wallpaperLuminance: 0.09,
        ).computeLuminance(),
        greaterThan(0.9),
        reason: '拉杆压 0.09 的暗壁纸时必须用白条；'
            '旧实现给深墨 32% alpha，实测 1.22:1 —— 用户根本看不见这里可以上滑',
      );
      // 亮壁纸：给出深条。
      expect(
        MonthGridHandle.resolveBarColor(
          inkColor: ink,
          wallpaperLuminance: 0.75,
        ).computeLuminance(),
        lessThan(0.1),
      );
    });

    test('没有壁纸亮度时才退回半透明墨色', () {
      const ink = Color(0xFF1A1A1A);
      final fallback = MonthGridHandle.resolveBarColor(
        inkColor: ink,
        wallpaperLuminance: null,
      );
      expect(
        fallback.a,
        lessThan(1.0),
        reason: '没有壁纸（纯色页）时那条细条压在页面底色上，半透明是对的',
      );
    });
  });

  group('概览卡与列表卡同族（不再是"面板同色的一块留白"）', () {
    testWidgets('概览卡底色 ≠ 面板底色（否则卡根本不存在）', (tester) async {
      await pumpScreen(tester);
      final panelFinder = find.byType(MonthPanelOverview);
      expect(panelFinder, findsOneWidget);

      // 面板底色：整页 Scaffold 的 surface。
      final scheme = Theme.of(
        tester.element(panelFinder),
      ).colorScheme;
      expect(
        scheme.surfaceContainerHighest,
        isNot(scheme.surface),
        reason: '若这两个色值相同，概览卡就没有实体 —— 旧实现正是这样：'
            '卡底色传 surface，与面板逐位相同，三个数字看起来是悬空的',
      );
    });
  });
}
