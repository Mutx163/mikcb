// 点「非本月」的补位格 = 翻到那个月并选中它。
//
// ## 为什么必须单独钉这条
//
// 旧实现把 `_selectedDate` 设成邻月日期，而下半屏的判据是
// `selectedInThisMonth`（year + month 都要对上）—— 于是点下去**什么都不发生**：
// 下半屏仍是本月概览，格子也不高亮，看起来像点了个死按钮。
//
// 2026-10-22 在真页面实测到的证据：点 `month-day-cell-2026-09-28` → 议程 0、
// 概览 1。这条用例就是那个读数转成的断言。
//
// 放 `test/services/`：按 TEST-POLICY，`test/screens` 不再新增。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_day_agenda.dart';
import 'package:university_timetable/widgets/timetable/month_view/month_panel_overview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;

  setUp(() async {
    StorageService().resetForTesting();
    // 与 `month_view_panel_content_test.dart` 同一条初始化路径：走 forTesting
    // 的存储 + 空 mock 偏好，不碰真实平台通道（否则会挂在 MissingPluginException）。
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

  /// 本月 42 格里第一行的首格 = 上月补位。用它当「灰色日期」的样本。
  ValueKey<String> firstRowLeadingKey() {
    final now = DateTime.now();
    // 上一个月的 28 号一定落在本月网格的第一行（42 格从周一开始、
    // 前 3 格必是上月尾部），且日期数字可寻址。
    final prev = DateTime(now.year, now.month - 1, 28);
    return ValueKey(
      'month-day-cell-${prev.year}-${prev.month.toString().padLeft(2, '0')}-28',
    );
  }

  testWidgets('点灰色补位格：下半屏从「本月概览」切到「那天的议程」', (tester) async {
    await pumpScreen(tester);

    expect(
      find.byType(MonthPanelOverview),
      findsOneWidget,
      reason: '一开始没选日期，下半屏应是本月概览',
    );
    expect(find.byType(MonthDayAgenda), findsNothing);

    final key = firstRowLeadingKey();
    expect(
      find.byKey(key, skipOffstage: false),
      findsWidgets,
      reason: '网格里必须存在这个补位格（${key.value}），否则本用例测的是空气',
    );

    await tester.tap(find.byKey(key, skipOffstage: false).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(MonthDayAgenda),
      findsOneWidget,
      reason:
          '点邻月的日子，用户想看的就是那天的安排。旧实现把 _selectedDate 设成'
          '邻月日期，而面板判据要求 year+month 都对上，于是停在本月概览 —— '
          '点了等于没点（实测：议程 0 / 概览 1）。',
    );
    expect(find.byType(MonthPanelOverview), findsNothing);
  });

  testWidgets('点本月内的日子仍然正常选中（没被上面的改动带坏）', (tester) async {
    await pumpScreen(tester);
    final now = DateTime.now();
    final key = ValueKey<String>(
      'month-day-cell-${now.year}-${now.month.toString().padLeft(2, '0')}-15',
    );

    expect(find.byKey(key, skipOffstage: false), findsWidgets);

    await tester.tap(find.byKey(key, skipOffstage: false).first, warnIfMissed: false);
    await tester.pump();

    expect(find.byType(MonthDayAgenda), findsOneWidget);
    expect(find.byType(MonthPanelOverview), findsNothing);
  });
}
