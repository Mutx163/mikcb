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
  ///
  /// [menuActions] 覆盖用户自定义的菜单排列（默认那八项里没有「外观编辑」，
  /// 测缩放转场那条路要自己把它排进去）。
  Future<TimetableProvider> pumpHome(
    WidgetTester tester, {
    List<String>? menuActions,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        homeGridMenuActions: menuActions,
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

  /// 按帧推进（首页另有常驻动画，`pumpAndSettle` 不必要也更容易超时）。
  Future<void> advance(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 「更多」那颗常驻玻璃球是否已经把图标交还回来。
  ///
  /// 判据用它的 `visible`：宿主传的是 `!锚点.contentHidden`，而 `contentHidden`
  /// 由弹层在**退场结束**（上游 `GlassPopupPresenter._finish`）才翻回 false ——
  /// 也就是「菜单真的没了」的那一刻，与 [HomeTopMenuPopup.show]（只是"开始收"）
  /// 差着一整段退场动画。
  bool moreBallIconBack(WidgetTester tester) =>
      tester.widget<FHeaderActionBall>(find.byType(FHeaderActionBall)).visible;

  /// 菜单面板当前有多宽（用面板里那一行的宽度量）。
  ///
  /// 收起时整张卡朝锚点那颗球缩，这条跟着缩：满幅 ≈65px，缩进球里 ≈12px。
  /// 弹层被整体摘掉（退场结束）时按 0 记。
  double menuPanelWidth(WidgetTester tester) {
    final row = find.text('外观编辑');
    return row.evaluate().isEmpty ? 0 : tester.getRect(row).width;
  }

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
    //
    // ⚠️ 只对**通用条目**成立。缩放转场那条走的是另一条时序（菜单先收完、再起
    // 缩小，见下一条用例）：它由宿主显式收菜单，根本不问 `isCurrent`，所以把
    // 「等菜单收起」写进 `open()`（把推页变成异步）只会同时踩坏这一条的前提。
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

  testWidgets('从菜单进外观编辑：菜单先收完（退场结束）才起首页缩小', (tester) async {
    // 用户 2026-09-26 口径：「右上角菜单消失后再开始缩小动画」。原先走通用那条
    // 「等新路由盖满首页再收菜单」——可缩放转场的新页整页不动（暗底要过 0.45 才
    // 淡入），根本没有"盖满"这一刻，于是菜单在整个缩小段里一直浮在缩小中的首页
    // 正上方，直到转场结束才消失。
    //
    // 钉的是**顺序**：菜单收起（视觉上缩回锚点那颗球）之后才允许推页；顺带钉住
    // 「别等太久」——菜单视觉收完约 240ms（见 `kHomeMenuCollapseBudget`），等成
    // 上游那条弹簧数学收敛（≈670ms）就是凭空加半秒空档。
    registerSettingsPages(
      settingsScreen: () => const SizedBox.shrink(),
      subpageById: (id) => id == 'appearanceEditor'
          ? const SizedBox.shrink(key: ValueKey('zoom-entry-page'))
          : null,
    );
    await pumpHome(
      tester,
      menuActions: const ['overview', 'appearanceEditor', 'settings'],
    );

    await tester.tap(find.byType(FHeaderAction).last);
    await advance(tester, 40);
    expect(menuShown(tester), isTrue, reason: '先正常打开菜单');
    expect(moreBallIconBack(tester), isFalse, reason: '菜单开着时球让位给形变球');
    // 菜单面板此刻是满幅的（下面按宽度读它缩没缩）。
    expect(menuPanelWidth(tester), greaterThan(40));

    // 判「有没有新页压上来」只能看**页面在不在树上**：`navigator.canPop()` 在
    // 菜单打开那一刻就是 true —— 弹层自己往根路由挂了一条 LocalHistoryEntry
    // （与本文件第三条用例同一个坑）。
    const editorPage = ValueKey('zoom-entry-page');
    bool editorPushed(WidgetTester tester) =>
        find.byKey(editorPage, skipOffstage: false).evaluate().isNotEmpty;
    expect(editorPushed(tester), isFalse, reason: '开场还没进编辑页');

    await tester.tap(find.text('外观编辑'));
    // 分发入口先让一帧（`Future.delayed(Duration.zero)`，等弹层那条路收工），
    // 两帧足够让「菜单开始收起」这件事落到树上。
    await advance(tester, 2);
    expect(
      menuShown(tester),
      isFalse,
      reason: '这一项不走"等盖满再收"：点下去菜单立刻开始收起',
    );
    expect(
      editorPushed(tester),
      isFalse,
      reason: '菜单还挂在屏幕上时不能起缩小动画',
    );

    // 逐帧推进到推页为止，顺带记下推页那一刻菜单缩成了多宽。
    var pushedAt = -1;
    var widthAtPush = -1.0;
    for (var i = 0; i < 90 && pushedAt < 0; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (editorPushed(tester)) {
        pushedAt = i;
        widthAtPush = menuPanelWidth(tester);
      }
    }
    expect(pushedAt, greaterThanOrEqualTo(0), reason: '菜单收起之后应当推上编辑页');
    expect(
      pushedAt,
      greaterThanOrEqualTo(12),
      reason: '菜单还在屏幕上时不能起缩小动画（≈200ms 之内不许推）',
    );
    expect(
      pushedAt,
      lessThan(30),
      reason: '也不能等太久：菜单视觉收完约 240ms（kHomeMenuCollapseBudget）',
    );
    expect(
      widthAtPush,
      lessThanOrEqualTo(20),
      reason: '推页那一刻菜单应已缩回锚点那颗球（12px 上下），而不是还浮在首页上',
    );
    // 顺带：图标交还不能等到上游那条弹簧收敛，否则缩小用的快照里「更多」球是空的。
    expect(
      moreBallIconBack(tester),
      isTrue,
      reason: '推页之前要把锚点球的图标交还回去（快照会拍下这一帧）',
    );

    // 走完转场：推上来的是那条缩放路由、指向的正是该条目解析出的页面。
    await advance(tester, 40);
    expect(find.byKey(editorPage, skipOffstage: false), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byKey(editorPage, skipOffstage: false))),
      isA<HyperosZoomPageRoute<void>>(),
      reason: '外观编辑走缩放转场，不是通用侧滑',
    );
  });

  testWidgets('菜单刚展开的那几帧点它的位置不该跳页（行还没显影）', (tester) async {
    // 真机回归（2026-09-23）：行按钮从入场第一帧起就摆好了位置、开了命中，而它的
    // 透明度要到入场动画末尾才是 1 —— 这段窗口里那几行完全看不见、却完全可点。
    // 快速连点「更多」时第二下正落在"将来那一行"的位置上，于是直接跳进了那一行
    // 对应的页面（点的是完全看不见的东西）。
    //
    // 修法在上游 fork（`GlassPopupPresenter`：内容没显影就不吃输入）。这条测试守的
    // 是**接线**：依赖被换回 pub.dev / 补丁在新 pin 上丢了，这里必须变红 ——
    // `dependency_guards_test.dart` 只钉「还是不是那个 fork」，不钉具体 commit。
    await pumpHome(tester);
    await tester.tap(find.byType(FHeaderAction).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(menuShown(tester), isTrue, reason: '菜单已经开了，只是内容还没显影');
    expect(
      find.text('课程总览').hitTestable(),
      findsNothing,
      reason: '入场显影之前，行按钮不该在命中测试里存在（看不见就点不到）',
    );

    // 快速连点的第二下：落在球上，而球正是这面板长出来的那一角。
    // ⚠️ 断言别用 `navigator.canPop()`：弹层自己往根路由挂了一条 LocalHistoryEntry，
    // 开菜单那一刻它就会变 true，与「有没有跳页」无关。
    await tester.tapAt(tester.getCenter(find.byType(FHeaderAction).last));
    await tester.pump();
    expect(
      ModalRoute.of(tester.element(find.byType(TimetableScreen)))!.isCurrent,
      isTrue,
      reason: '这一下不该把首页顶下去（也就是不该跳页）',
    );
    expect(
      menuShown(tester),
      isTrue,
      reason: '也不该顺带把菜单收了（点两下 = 关菜单也是误触）',
    );

    // 对照：显影之后同一行必须照旧可点 —— 证明上面那条 findsNothing 不是恒假。
    await advance(tester, 40);
    expect(find.text('课程总览').hitTestable(), findsOneWidget);
  });

  testWidgets('收起动画期间再点球能立刻重开（第二下不被动画吃掉）', (tester) async {
    // 真机回归（2026-09-23）：遮罩在收起期立刻停止拦截（上游既有行为），但锚点
    // 原先要等收起动画**播完**才收回点击 —— 整段收起动画期间那颗球既看不见、也
    // 点不动，「点空白收起、马上再点按钮重开」的第二下被静默丢掉，读起来是
    // 「点了没反应，要等一会儿才灵」。修法同样在 fork：视觉仍等动画播完交接，
    // 只把输入从收起第一帧起还给按钮。
    await pumpHome(tester);
    final ball = tester.getCenter(find.byType(FHeaderAction).last);

    await tester.tap(find.byType(FHeaderAction).last);
    await advance(tester, 40);
    expect(menuShown(tester), isTrue, reason: '先正常打开菜单');

    // 点空白收起，然后在收起动画**还没走完**时再点球。
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(menuShown(tester), isFalse, reason: '收起已经开始（这一帧动画还在放）');

    await tester.tapAt(ball);
    await tester.pump();
    expect(
      menuShown(tester),
      isTrue,
      reason: '收起动画期间那颗球必须立刻能再点开',
    );

    await advance(tester, 40);
  });
}
