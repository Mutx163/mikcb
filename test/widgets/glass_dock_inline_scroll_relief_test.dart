import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 玻璃坞内嵌页底部滚动余量回归（满屏悬浮对全部底栏页面生效）。
///
/// 背景：93bed6b 移除「内容避让」布局后，玻璃坞固定满屏悬浮，日/周
/// 课表无条件获得底部滚动余量（药丸占用 + 底部安全区），下滑到底后
/// 最后一项停在药丸上方；但底栏内嵌页（考试安排、课程统计等）的列表
/// 只有 HyperosListView 默认 24px 底距，末尾内容压在悬浮药丸后面无法
/// 滑出来看。修复后由内嵌宿主注入 [GlassDockScrollReliefScope]，
/// HyperosListView 自动把底部内边距提升到余量（不小于默认底距）——
/// 新增内嵌页按惯例用 HyperosListView 即自动适配，无须逐页处理。
void main() {
  // 拆分后设置页由库侧登记（生产在 main() 启动时完成）；测试环境直接
  // 调用一次，保证玻璃坞「课表设置」内嵌入口可解析。
  registerSettingsPages(
    settingsScreen: () => const TimetableSettingsScreen(),
    subpageById: settingsSubpageById,
  );

  /// 玻璃坞药丸固定占用高度（与屏幕源码 _glassDockPillOccupancy 一致；
  /// 测试环境无系统底部安全区，余量即 62）。
  const double kGlassDockPillOccupancy = 62.0;

  /// HyperosListView 默认底距（HyperosMiuixSpec.listPadding.bottom）。
  const double kDefaultListBottom = 24.0;

  Future<TimetableProvider> pumpDockApp(
    WidgetTester tester, {
    required List<String> dockActions,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: dockActions,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance.defaults,
            child: TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(GlassTabBar), findsOneWidget);
    return provider;
  }

  Finder dockTab(String label) => find
      .descendant(of: find.byType(GlassTabBar), matching: find.text(label))
      .first;

  /// 内嵌课表设置页主列表（pageStorageKey 定位）的底部内边距。
  double inlineSettingsListBottom(WidgetTester tester) {
    final listView = tester.widget<ListView>(
      find.byKey(const PageStorageKey<String>('timetable-settings-main')),
    );
    return (listView.padding as EdgeInsets).resolve(TextDirection.ltr).bottom;
  }

  testWidgets('底栏内嵌页：列表底部滚动余量兜底药丸占用，末尾可滑到药丸上方', (tester) async {
    await pumpDockApp(tester, dockActions: ['day', 'settings', 'week']);

    await tester.tap(dockTab('课表设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '打开内嵌设置页不应有异常');
    expect(find.byType(TimetableSettingsScreen), findsOneWidget);

    expect(
      inlineSettingsListBottom(tester),
      closeTo(kGlassDockPillOccupancy, 0.5),
      reason: '内嵌页列表底距应提升到药丸占用（62），末尾内容可整体滑出药丸',
    );

    // 上滑：列表可滚动区间至少包含余量，末尾不再被药丸盖住。
    await tester.drag(
      find.byKey(const PageStorageKey<String>('timetable-settings-main')),
      const Offset(0, -120),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HyperosListView 消费余量：取 max(默认底距, 余量)，坞外行为不变', (
    tester,
  ) async {
    Future<double> pumpListBottom({
      double? inset,
      EdgeInsetsGeometry? padding,
    }) async {
      Widget list = HyperosListView(
        includeHeaderInset: false,
        padding: padding,
        itemCount: 1,
        itemBuilder: (context, index) => const SizedBox(height: 20),
      );
      if (inset != null) {
        list = GlassDockScrollReliefScope(inset: inset, child: list);
      }
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: list)));
      final listView = tester.widget<ListView>(find.byType(ListView));
      return (listView.padding as EdgeInsets).resolve(TextDirection.ltr).bottom;
    }

    // 坞外（无 scope）：保持默认底距，普通推入路由不受影响。
    expect(await pumpListBottom(), kDefaultListBottom);
    // 余量小于默认底距时不生效。
    expect(await pumpListBottom(inset: 10), kDefaultListBottom);
    // 坞内：底距提升到余量。
    expect(
      await pumpListBottom(inset: kGlassDockPillOccupancy),
      kGlassDockPillOccupancy,
    );
    // 页面自带更大底距时不被压缩。
    expect(
      await pumpListBottom(
        inset: kGlassDockPillOccupancy,
        padding: const EdgeInsets.only(bottom: 100),
      ),
      100,
    );
  });
}
