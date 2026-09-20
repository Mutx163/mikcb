import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/course_overview_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';
import 'package:university_timetable/widgets/home_top_menu_popup.dart';

/// 首页右上角菜单「点条目跳页面」时的收菜单时机。
///
/// 真机回归（2026-09-15）：菜单是浮在首页上的一层，先收菜单、再推页面，中间那
/// 一两帧里"菜单已经收了、新页面还没铺满"，底下的圆形按钮与爱心球就冒出来闪一下。
/// 现在收菜单等到新路由把首页盖满之后（见 `timetable_screen.dart` 的
/// `_requestCloseHomeMenu`），收起动作用户看不见。
void main() {
  /// 泵起首页（列表态菜单是默认形态）并返回 provider。
  Future<TimetableProvider> pumpHome(WidgetTester tester) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
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
    return provider;
  }

  /// 菜单当前是否处于展开态（读宿主下发的 `show`）。
  bool menuShown(WidgetTester tester) =>
      tester.widget<HomeTopMenuPopup>(find.byType(HomeTopMenuPopup)).show;

  testWidgets('点条目跳页面：菜单留到新页面盖满才收，不在转场中途先收掉', (tester) async {
    await pumpHome(tester);

    // 「更多」按钮是顶栏末尾那个 FHeaderAction（前面还有一个爱心球）。
    await tester.tap(find.byType(FHeaderAction).last);
    // 固定帧数推进：菜单展开动画走完即可，不用 pumpAndSettle
    // （首页另有常驻动画，settle 不必要也更容易超时）。
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(menuShown(tester), isTrue, reason: '点「更多」后菜单应展开');

    // 点一个会推页面的条目（课程总览）。
    await tester.tap(find.text('课程总览'));
    // 转场中途：菜单必须还开着 —— 提前收掉就会露出首页顶栏那两颗球。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      menuShown(tester),
      isTrue,
      reason: '新页面还没盖满时不能收菜单，否则底下的圆按钮 / 爱心球会闪现',
    );

    // 转场走完：新页面盖满首页（首页整层转 offstage），菜单应已收起。
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.byType(CourseOverviewScreen),
      findsOneWidget,
      reason: '菜单项应把页面推上来',
    );
    // 首页被盖住后整层是 offstage（find 默认跳过），所以这里要显式读 offstage
    // 那一层的 `show`：它必须是 false —— 菜单在"被盖满"之后才收。
    expect(
      tester
          .widget<HomeTopMenuPopup>(
            find.byType(HomeTopMenuPopup, skipOffstage: false),
          )
          .show,
      isFalse,
      reason: '新页面盖满后应收起菜单',
    );
  });

  testWidgets('缩放转场条目（外观编辑）必须当场推页：延后一帧会踩掉"盖满才收菜单"', (tester) async {
    // 上面那条保护的前提是**推页同步发生**：`_requestCloseHomeMenu` 靠
    // `Route.isCurrent` 判「这一项有没有当场跳页」，判到"没跳页"就立刻收菜单。
    // 曾经把 zoom 条目改成「`addPostFrameCallback` + `scheduleFrame`，下一帧再
    // 推」——那一刻首页还是栈顶，菜单被当成"不跳页"当场收起，下面那条老症状
    // （首页顶栏两颗球在新页盖满前露出来闪一下）就回来了。
    //
    // 这里钉的是那条前提本身，可观测事实是「`open()` 返回时新路由已经在栈上」：
    // 延后一帧的写法在这一句上必然是 canPop() == false。
    registerSettingsPages(
      settingsScreen: () => const SizedBox.shrink(),
      subpageById: (id) => id == 'appearanceEditor'
          ? const SizedBox.shrink(key: ValueKey('zoom-entry-page'))
          : null,
    );
    await pumpHome(tester);

    final entry = homeMenuEntryById('appearanceEditor');
    expect(entry, isNotNull, reason: '目录里必须有这条 zoom 条目');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse, reason: '首页是根路由');

    unawaited(
      entry!.open(tester.element(find.byType(TimetableScreen))),
    );
    expect(
      navigator.canPop(),
      isTrue,
      reason: 'zoom 条目必须当场推页：延后一帧会让"有没有跳页"的判定看错，菜单提前收起',
    );

    // 走完转场：推上来的确实是那条条目指向的页面（不是别的兜底）。
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.byKey(const ValueKey('zoom-entry-page'), skipOffstage: false),
      findsOneWidget,
      reason: '推上来的应是该条目解析出的页面',
    );
  });
}
