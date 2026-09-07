import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 首页下拉快捷导入的「位置门控」回归。
///
/// 背景：玻璃坞形态会给自适应周课表注入底部滚动余量（药丸占用 62px），
/// 网格由此变成可滚动的 SingleChildScrollView。若此时仍叠加原始竖向
/// 拖拽探测器（_HomePullVerticalDragDetector），任何「向下」手势都会
/// 不计滚动位置地直接把下拉进度累计进快捷导入——用户从页面中部向下
/// 滑、还没把课表滚回顶部，快捷导入（更新）就被触发。
///
/// 修复：有余量（存在可滚动课表）时不再上探测器，改由 Overscroll
/// 通知（自带 atTop 判定）驱动下拉。
void main() {
  // 拆分后设置页由库侧登记（生产在 main() 启动时完成）；测试环境直接
  // 调用一次，保证玻璃坞「课表设置」内嵌入口可解析。
  registerSettingsPages(
    settingsScreen: () => const TimetableSettingsScreen(),
    subpageById: settingsSubpageById,
  );

  Future<TimetableProvider> pumpHome({
    required WidgetTester tester,
    required HomeNavigationForm form,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: form,
        glassDockActions: const ['week'],
        // 自适应节高：玻璃坞下网格 + 底部余量 = 可滚动的周课表。
        timetableAutoFitSectionHeight: true,
        homePullQuickImportEnabled: true,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
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
    return provider;
  }

  /// 当前周（第 1 周）的纵向周课表滚动视图。
  Finder weekScroll() => find.byKey(const PageStorageKey<String>('week-scroll-1'));

  testWidgets('玻璃坞+自适应：网格未回顶部的小幅下拉不应触发快捷导入', (
    tester,
  ) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);

    // 先上滑把课表滑到底部（玻璃余量 62px 全部吃满）。
    await tester.drag(weekScroll(), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 此刻网格并不在顶部；向下小幅拖动 60px（不足以把课表滚回顶部，
    // 也就不会产生顶部 overscroll）。
    await tester.drag(weekScroll(), const Offset(0, 60));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 修复后：这次下拉只用于把滚动位置推回顶部，不应打开快捷导入药丸。
    // 修复前：原始探测器不计位置直接累计下拉，药丸当场弹出。
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '未滑动到顶部的下拉不应触发首页快捷导入（更新）',
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：位于顶部时下拉仍能正常打开快捷导入药丸', (
    tester,
  ) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);

    // 从顶部直接下拉：回到顶部的 overscroll 应照常驱动下拉药丸。
    await tester.drag(weekScroll(), const Offset(0, 100));
    await tester.pump();

    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '处于顶部时下拉仍应打开快捷导入药丸（修复不能破坏既有入口）',
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
