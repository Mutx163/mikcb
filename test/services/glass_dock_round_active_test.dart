import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/more_features_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_tab_bar.dart';

/// 玻璃坞圆钮的「选中态」，以及它与药丸高亮的归属（2026-10-24）。
///
/// 用户口径：「底栏打开右边那个圆按钮的时候……切换成页面的时候，为什么按钮激活
/// 状态还是左边的底栏上面，不是右边圆按钮」。
///
/// 机制：药丸那格高亮是**每帧按「当前内嵌页能否在药丸槽位里找到同一格」重算**的
/// （`_dockSelectedIndex`）。圆钮绑的页面按定义不在药丸槽位里 ⇒ 高亮落回日/周那一格，
/// 而圆钮自己**不画任何选中态** —— 于是「页面真的换了、按钮毫无表示，亮着的却是一格
/// 根本没打开的日/周」。修复后的判据（用户逐条拍板）：
/// - 圆钮把它那一页就地打开 ⇒ 圆钮亮（`glass-dock-round-active`）**且药丸整栏不亮**
///   （`selectedIndex == -1`）：不许再替一个没开的日/周页假亮；
/// - 同一页既排进药丸槽位、又绑给圆钮 ⇒ **只亮药丸那一格**，圆钮不亮；
/// - 只有「就地换页」才亮：添加课程弹层那一档永远不亮；
/// - 药丸整栏不亮期间点任意一格必须能恢复正常态（不出现卡死在 -1）。
void main() {
  /// 圆钮的选中底：存在即亮（不亮时整块不构建）。
  const activeKey = ValueKey('glass-dock-round-active');

  Future<void> pumpDock(
    WidgetTester tester, {
    required List<String> dockActions,
    required String roundButtonEntryId,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: dockActions,
        glassDockButtonEntryId: roundButtonEntryId,
        // 圆钮默认不显示（settings 默认 false），要显式打开。
        glassDockShowAddButton: true,
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
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  /// 底栏当前选中槽（-1 = 整栏不亮）。
  int pillIndex(WidgetTester tester) =>
      (tester.widget(find.byType(SoftGlassTabBar)) as SoftGlassTabBar)
          .selectedIndex;

  /// 坞上那颗圆钮。
  ///
  /// 按 key 找，不按图标：圆钮图标由设置项决定（用户可自选 Miuix 矢量图标），而
  /// 「全部功能」那颗 `apps_rounded` 与顶栏「更多」常驻球**同形** —— 按图标找会撞。
  Finder roundButton(WidgetTester tester) {
    final finder = find.byKey(const ValueKey('glass-dock-round-button'));
    expect(finder, findsOneWidget, reason: '坞层必须恰好有一颗圆钮');
    return finder;
  }

  /// 药丸里某一格的文本。**必须**限定在 `SoftGlassTabBar` 子树内找：内嵌页
  /// （如「全部功能」）里也可能出现同名文本，树序 `.first`/`.last` 两头都靠不住。
  Finder pillTab(WidgetTester tester, String label) => find.descendant(
    of: find.byType(SoftGlassTabBar),
    matching: find.text(label),
  );

  testWidgets('圆钮打开「全部功能」：自己亮 + 药丸整栏不亮；收回后一起复原', (tester) async {
    // 「全部功能」正是用户实际设的那一档：可内嵌，但不在药丸槽位里。
    await pumpDock(
      tester,
      dockActions: const ['day', 'week'],
      roundButtonEntryId: 'more',
    );
    expect(find.byKey(activeKey), findsNothing, reason: '未开页时圆钮不该亮');
    expect(pillIndex(tester), 1, reason: '常态应亮周课表那一格');

    await tester.tap(roundButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MoreFeaturesScreen), findsOneWidget);
    expect(
      find.byKey(activeKey),
      findsOneWidget,
      reason: '圆钮把它那一页开着，圆钮自己必须亮',
    );
    expect(
      pillIndex(tester),
      -1,
      reason: '圆钮亮时药丸不许替一个没开的日/周页假亮',
    );
    // -1 态的三条硬要求（配合 soft_glass_tab_bar 的 -1 支持）：指示器**不构建**
    // （画出来就又是假亮）、横拖**不提交**（没有当前选中格就没有拖动起点）、
    // 点按**照常**（下一条用例覆盖）。
    expect(
      find.byKey(const ValueKey('soft-glass-tab-indicator')),
      findsNothing,
      reason: '整栏不亮时不得画出指示器',
    );
    await tester.drag(pillTab(tester, '周课表'), const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      pillIndex(tester),
      -1,
      reason: '-1 态的横拖不得提交到任何一格',
    );
    expect(find.byKey(activeKey), findsOneWidget, reason: '横拖不该影响圆钮表态');

    // 再点同钮收回（圆钮保留 toggle 收回）：页面没了，亮必须跟着灭，
    // 药丸高亮回到真实所在的周课表槽。
    await tester.tap(roundButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MoreFeaturesScreen), findsNothing);
    expect(
      find.byKey(activeKey),
      findsNothing,
      reason: '收页后还亮着就是假信号',
    );
    expect(pillIndex(tester), 1, reason: '回到课表后药丸该重新亮周课表');

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('内嵌页开着时点药丸任意一格：收页并恢复该格高亮', (tester) async {
    // 覆盖「整栏不亮」这个新状态的出口：不能卡死在 -1。
    await pumpDock(
      tester,
      dockActions: const ['day', 'week'],
      roundButtonEntryId: 'more',
    );
    await tester.tap(roundButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(pillIndex(tester), -1);

    await tester.tap(pillTab(tester, '日课表'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MoreFeaturesScreen), findsNothing, reason: '应收起内嵌页');
    expect(find.byKey(activeKey), findsNothing, reason: '页面收走后圆钮必须灭');
    expect(pillIndex(tester), 0, reason: '高亮应回到日课表那一格');

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('同一页既是药丸槽位又绑给圆钮：只亮药丸，圆钮不亮', (tester) async {
    await pumpDock(
      tester,
      dockActions: const ['day', 'week', 'more'],
      roundButtonEntryId: 'more',
    );

    await tester.tap(roundButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MoreFeaturesScreen), findsOneWidget);
    expect(pillIndex(tester), 2, reason: '该页有对应槽位，高亮归药丸那一格');
    expect(
      find.byKey(activeKey),
      findsNothing,
      reason: '药丸已经说了这件事，圆钮不该再亮一遍',
    );

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('圆钮设成「添加课程」（弹层、不换页）：永不亮、药丸不动', (tester) async {
    await pumpDock(
      tester,
      dockActions: const ['day', 'week'],
      roundButtonEntryId: 'addCourse',
    );

    await tester.tap(roundButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('添加课程'), findsOneWidget, reason: '弹层应照常拉起');
    expect(
      find.byKey(activeKey),
      findsNothing,
      reason: '开弹层不是「切到一页」，圆钮不该据此常驻亮着',
    );
    expect(pillIndex(tester), 1, reason: '药丸该继续亮周课表');
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 9));
  });
}
