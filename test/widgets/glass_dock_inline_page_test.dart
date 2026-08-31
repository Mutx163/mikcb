import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/course_statistics_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 玻璃坞内嵌页触觉与再点口径回归。
///
/// 背景：3e41ac20 曾把底栏触觉统一在分发顶层（真实切换即震、重复点击
/// 静音），8833fcd2 重构底栏时连同旧分发器一起丢失，页面分支（开/换
/// 内嵌页、推路由、圆钮）此后全程静音；且 986e4f44 把「再点当前内嵌页」
/// 定为 toggle 收回，与 日/周 Tab 的重复点击无动作守卫不一致（用户报告：
/// 再点统计页会退回课表，而反复点日课表不动）。修复后：
/// - 真实切换（切视图/开页/换页/收页/推路由）各震一次 selectionClick；
/// - 再点当前内嵌页 Tab 无动作、零震动（收页走切视图或系统返回）；
/// - 圆钮保留 toggle 收回（无选中态指示，按钮式「再点撤销」成立），
///   开/收各震一次。
void main() {
  // 拆分后设置页由库侧登记（生产在 main() 启动时完成）；测试环境直接
  // 调用一次，保证玻璃坞「课表设置」内嵌入口可解析。
  registerSettingsPages(
    settingsScreen: () => const TimetableSettingsScreen(),
    subpageById: settingsSubpageById,
  );
  TestWidgetsFlutterBinding.ensureInitialized();

  List<MethodCall> installHapticLog() {
    final log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      log.add(call);
      return null;
    });
    return log;
  }

  int selectionClicks(List<MethodCall> log) {
    return log
        .where(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.selectionClick',
        )
        .length;
  }

  /// 读取底栏指示器当前 tabIndex（TabIndicator 由包内部提供）。
  int? currentIndicatorIndex() {
    final finder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TabIndicator',
    );
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return (finder.evaluate().first.widget as dynamic).tabIndex as int?;
  }

  Future<TimetableProvider> pumpDockApp(
    WidgetTester tester, {
    required List<String> dockActions,
    String? roundButtonEntryId,
    bool roundButtonVisible = false,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: dockActions,
        glassDockButtonEntryId: roundButtonEntryId ?? 'addCourse',
        glassDockShowAddButton: roundButtonVisible,
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

  testWidgets('底栏页面 Tab：真实切换各震一次，再点当前页无动作零震动', (tester) async {
    final hapticLog = installHapticLog();
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // 排列：日(0) / 课程统计(1) / 课表设置(2) / 周(3)。
    await pumpDockApp(
      tester,
      dockActions: ['day', 'statistics', 'settings', 'week'],
    );

    // 周→日：切视图，_toggleDayView 内部震一次（既有基线）。
    var before = selectionClicks(hapticLog);
    await tester.tap(find.text('日课表').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsOneWidget,
    );
    expect(currentIndicatorIndex(), 0);
    expect(selectionClicks(hapticLog) - before, 1, reason: '周→日应震一次');

    // 日→打开统计页：真实切换（修复点：此前全程静音）。
    before = selectionClicks(hapticLog);
    await tester.tap(dockTab('课程统计'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '打开内嵌页不应有异常');
    expect(currentIndicatorIndex(), 1, reason: '统计页打开后高亮应跟随内嵌 id');
    expect(selectionClicks(hapticLog) - before, 1, reason: '打开内嵌页应震一次');

    // 再点当前内嵌页 Tab：无动作、零震动（修复点：原 toggle 会把页面
    // 收走退回课表）。
    before = selectionClicks(hapticLog);
    await tester.tap(dockTab('课程统计'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(currentIndicatorIndex(), 1, reason: '再点当前页应保持打开');
    expect(find.byType(CourseStatisticsScreen), findsOneWidget);
    expect(selectionClicks(hapticLog) - before, 0, reason: '再点当前页应静音');

    // 统计→设置：换页是真实切换，震一次。
    before = selectionClicks(hapticLog);
    await tester.tap(dockTab('课表设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '换到设置页不应有异常');
    expect(currentIndicatorIndex(), 2);
    expect(find.byType(TimetableSettingsScreen), findsOneWidget);
    expect(selectionClicks(hapticLog) - before, 1, reason: '内嵌页之间换页应震一次');

    // 从内嵌页点 周（底层为周课表）：收页落回同视图，震一次（修复点：
    // 原路径静音）；直接重复点周 Tab 仍由既有守卫静音。
    before = selectionClicks(hapticLog);
    await tester.tap(dockTab('周课表'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: '收页回周课表不应有异常');
    expect(currentIndicatorIndex(), 3);
    expect(find.byType(TimetableSettingsScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('timetable-day-view-panel')),
      findsNothing,
      reason: '落回的应是周课表',
    );
    expect(selectionClicks(hapticLog) - before, 1, reason: '内嵌页收回落周课表应震一次');

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('圆钮：保留 toggle 收回，开/收各震一次', (tester) async {
    final hapticLog = installHapticLog();
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // 底栏 Tab 只有 日/周，圆钮绑统计页：bar_chart 图标在坞上唯一。
    await pumpDockApp(
      tester,
      dockActions: ['day', 'week'],
      roundButtonEntryId: 'statistics',
      roundButtonVisible: true,
    );
    final roundButton = find.byIcon(Icons.bar_chart_rounded);
    expect(roundButton, findsOneWidget);

    // 点圆钮开统计页：真实切换，震一次。
    var before = selectionClicks(hapticLog);
    await tester.tap(roundButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: '圆钮打开内嵌页不应有异常');
    expect(find.byType(CourseStatisticsScreen), findsOneWidget);
    expect(selectionClicks(hapticLog) - before, 1, reason: '圆钮开页应震一次');

    // 再点同钮：收回（保留 toggle），真实切换，震一次。
    before = selectionClicks(hapticLog);
    // 统计页自身可能含同名图标，坞层合并槽在树序上位于页面内容之后。
    await tester.tap(find.byIcon(Icons.bar_chart_rounded).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CourseStatisticsScreen), findsNothing);
    expect(selectionClicks(hapticLog) - before, 1, reason: '圆钮收页应震一次');

    await tester.pump(const Duration(seconds: 9));
  });
}
