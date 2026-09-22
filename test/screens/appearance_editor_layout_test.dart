// 「外观编辑」页的**布局回归钉**（按真机视口渲染，量的是几何而不是文字）。
//
// 为什么要有这一份：用户真机反馈过两类「看起来不对」——
// ① 顶部右边那颗按钮「跟左边不齐」，② 底栏那排按钮「乱」。
// 量化之后发现坐标其实是对称的，真正的原因是**视觉重量不一致**（完成用了纯白实心、
// 取消是半透明深色）与**多余的竖杠隔断**；这两条已在实现里改掉，本文件把它们钉住，
// 免得以后有人再把两枚胶囊做成不同形。
//
// 视口取真机实测值：1280×2772 @520dpi → 393.8×852.9 逻辑像素；安全区按状态栏
// 104 物理像素、手势条 84 物理像素给（与截图一致）。
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/preview_bake_boundary.dart';

import '../helpers_test_app.dart';

const _viewport = Size(393.8, 852.9);

void _seedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedPrefs();
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (c) async => null);
    }
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2772);
    tester.view.devicePixelRatio = 3.25;
    // 状态栏 104 物理像素 = 32 逻辑像素；手势条 84 物理像素 ≈ 25.8 逻辑像素。
    tester.view.padding = const FakeViewPadding(top: 104, bottom: 84);
    addTearDown(tester.view.reset);

    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('appearanceEditor')!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('缩略卡：保持整屏比例、左右居中、完整落在上下 chrome 之间', (
    tester,
  ) async {
    await pumpEditor(tester);

    // 量的是**卡片本体**（按 key），不是 `TimetableScreen`：烤图方案之后卡片
    // 显示的是快照图，页面里那份 TimetableScreen 是整屏 1:1 的渲染源、被钉在
    // 屏幕顶边 —— 量它量到的是全屏矩形，`top` 恒为 0，这条断言会永远不过。
    final card = tester.getRect(
      find.byKey(const ValueKey('appearance-editor-preview-card')),
    );
    // 等比：卡片宽高比 == 屏幕宽高比（所以是「原样缩小」而不是被拉扁/裁切）。
    expect(
      card.width / card.height,
      closeTo(_viewport.width / _viewport.height, 0.001),
      reason: '卡片必须与整屏同比（否则观感与首页不一致）',
    );
    // 左右留白相等。
    expect(card.left, closeTo(_viewport.width - card.right, 0.5));
    // 上下都在安全区加 chrome 的净空之内（不顶状态栏、不压手势条）。
    // 顶部只有**一行**（胶囊 + 日/周分段同排，2026-09-20 撤标题后收成一行）；
    // 底部那排圆钮往下挪了 10dp（26 → 16，净空里就是 34 → 24）。
    const topReserve = 32 + 16 + 40 + 18;
    const bottomReserve = 25.8 + 24 + 56 + 8 + 18;
    expect(card.top, greaterThanOrEqualTo(topReserve - 1));
    expect(card.bottom, lessThanOrEqualTo(_viewport.height - bottomReserve + 1));
    // 预览要够大（用户 2026-09-20 口径「把内部预览区域放大，这样好看」）：
    // 顶部收一行 + 底部下移之后，卡片占屏高约 72.6%；改之前是 65.3%。
    expect(
      card.height,
      greaterThan(_viewport.height * 0.70),
      reason: '纵向净空又被吃回去了 ⇒ 预览变小了',
    );
  });

  testWidgets('顶部两枚胶囊：同高、同尺寸、离两边等距（不许视觉上错位）', (
    tester,
  ) async {
    await pumpEditor(tester);

    final cancel = tester.getRect(find.text('取消'));
    final done = tester.getRect(find.text('完成'));

    // 同一高度（同一行基线）。
    expect(cancel.top, closeTo(done.top, 0.5));
    expect(cancel.bottom, closeTo(done.bottom, 0.5));
    // 中心到各自屏幕边缘的距离相等。
    expect(
      cancel.center.dx,
      closeTo(_viewport.width - done.center.dx, 0.5),
      reason: '左右两枚必须对称，否则真机上看就是「右边那颗错位」',
    );
    // 中间那格是日 / 周切换（2026-09-20：撤掉标题、把切换提到标题原来的位置），
    // 它必须落在屏幕正中（不被任何一枚胶囊挤偏），且页面里不再有标题。
    final segmented = tester.getRect(
      find.byKey(const ValueKey('appearance-editor-day-week')),
    );
    expect(segmented.center.dx, closeTo(_viewport.width / 2, 1));
    expect(
      segmented.center.dy,
      closeTo(cancel.center.dy, 1),
      reason: '切换与两枚胶囊同一行（都在那一行里垂直居中）',
    );
    expect(find.text('外观编辑'), findsNothing, reason: '标题已撤（那一行让给预览）');
  });

  testWidgets('底部一排：两个入口等距、整组居中、名字在安全区之上', (tester) async {
    await pumpEditor(tester);

    final wallpaper = tester.getRect(find.text('调整壁纸'));
    final material = tester.getRect(find.text('材质'));
    final groupCenter = (wallpaper.center.dx + material.center.dx) / 2;

    expect(groupCenter, closeTo(_viewport.width / 2, 1));
    // 两个名字的中心间距要够开（等距留白 40 + 圆钮 56）。
    expect(material.center.dx - wallpaper.center.dx, closeTo(96, 1));
    // 名字整体在底部安全区之上（不被手势条压住）。
    expect(wallpaper.bottom, lessThan(_viewport.height - 25.8));
    expect(material.bottom, lessThan(_viewport.height - 25.8));
  });

  // ── 缩放转场口径（首页缩进预览小屏）────────────────────────────────────────
  //
  // 用户 2026-09-20 口径：① 主页要连续缩进中间那块预览小屏；② 页面上的按钮不
  // 参与缩放、在缩放结束之后才出现。下面三条就是这口径的可测面：落点必须等于
  // 卡片的实测矩形、首页快照的终点必须与它重合、按钮的出场必须晚于缩放。

  /// 与 [pumpEditor] 同一套视口/依赖，但把编辑页**经真缩放转场**推起来。
  Future<void> pushEditorViaZoom(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2772);
    tester.view.devicePixelRatio = 3.25;
    tester.view.padding = const FakeViewPadding(top: 104, bottom: 84);
    addTearDown(tester.view.reset);
    addTearDown(() {
      hyperosZoomLanding.value = null;
      hyperosZoomHomeSnapshot.value = null;
    });

    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('appearanceEditor')!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: const TestApp(
          // 首页那半边只要在树上就行：落点由编辑页上报，量的是两者对不对得上。
          home: HyperosZoomShrinkScope(
            child: ColoredBox(color: Color(0xFF101010)),
          ),
        ),
      ),
    );
    await tester.pump();
    // ignore: unawaited_futures
    tester.state<NavigatorState>(find.byType(Navigator)).push<void>(
      HyperosZoomPageRoute<void>(builder: (_) => page),
    );
    await tester.pump(); // 路由安装、进场首帧
  }

  Rect cardRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('appearance-editor-preview-card')));

  Rect homeSnapshotRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      // ⚠️ 两处都要 skipOffstage:false：落定后首页被上层不透明路由盖住整层转
      // offstage，默认查找会当它不存在（而那正是"编辑页开着时首页不耗电"）。
      of: find.byType(HyperosZoomShrinkScope, skipOffstage: false),
      matching: find.byType(RawImage, skipOffstage: false),
    ),
  );

  /// 某个 chrome 元素（按文字找）**实际**会画出来的不透明度 = 它祖先里最不
  /// 透明的那一层（出场层用的是 Opacity）。
  double chromeAlpha(WidgetTester tester, String label) => tester
      .widgetList<Opacity>(
        find.ancestor(
          of: find.text(label, skipOffstage: false),
          matching: find.byType(Opacity, skipOffstage: false),
        ),
      )
      .fold<double>(1, (min, o) => math.min(min, o.opacity));

  /// 进场首帧整条路由是 Offstage（Flutter 的既定行为），所以找 chrome 一律带
  /// `skipOffstage: false`。
  Finder chromeText(String label) => find.text(label, skipOffstage: false);

  testWidgets('缩放转场：落点矩形就是预览卡片的实测矩形', (tester) async {
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();

    final card = cardRect(tester);
    final landing = hyperosZoomLanding.value;
    expect(landing, isNotNull, reason: '编辑页必须把卡片矩形上报给转场');
    // ⚠️ 这是「首页缩进小屏」这条口径的**唯一真源**：上报值必须就是卡片自己
    // 的矩形，否则首页会缩到别的地方去。
    expect(landing!.rect.left, closeTo(card.left, 0.5));
    expect(landing.rect.top, closeTo(card.top, 0.5));
    expect(landing.rect.width, closeTo(card.width, 0.5));
    expect(landing.rect.height, closeTo(card.height, 0.5));
    expect(landing.radius, greaterThan(0), reason: '落点要带圆角，否则落地时圆角会弹');
  });

  testWidgets('缩放转场：首页快照的终点与卡片矩形逐像素重合', (tester) async {
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();

    final card = cardRect(tester);
    final snapshot = homeSnapshotRect(tester);
    expect(snapshot.left, closeTo(card.left, 1.0));
    expect(snapshot.top, closeTo(card.top, 1.0));
    expect(snapshot.right, closeTo(card.right, 1.0));
    expect(snapshot.bottom, closeTo(card.bottom, 1.0));
  });

  testWidgets('缩放转场：卡片在自家烤图就绪前用首页快照顶替（落地不空一下）', (tester) async {
    await pushEditorViaZoom(tester);
    await tester.pump(const Duration(milliseconds: 150));

    // 落定前自家烤图**必然**还没有：渲染源本身就要等落定才挂载。所以这一刻
    // 卡片上有图，只可能是用了首页那一张快照 —— 这正是"出口从转场中点就能开始、
    // 且交接是同一张图"的实现方式。
    final image = tester
        .widget<RawImage>(
          find.descendant(
            of: find.byKey(
              const ValueKey('appearance-editor-preview-card'),
              skipOffstage: false,
            ),
            matching: find.byType(RawImage, skipOffstage: false),
          ),
        )
        .image;
    expect(
      image,
      isNotNull,
      reason: '图源没顶替的话，落地后卡片会先空一下再淡入正图',
    );
    expect(
      identical(image, hyperosZoomHomeSnapshot.value),
      isTrue,
      reason: '顶替用的必须就是首页那一张（同一张图，交接才逐像素无感）',
    );
  });

  testWidgets('缩放转场：中间那块小屏要等首页落到它身上才出现', (tester) async {
    // 用户 2026-09-20 复现：「缩放过程中，中间那一块小屏幕持续存在，这不合理」。
    // 卡片的图源就是首页那张快照，所以必须显式挡到首页缩到位那一帧；否则屏幕上
    // 会同时有一张静止的小屏 + 一张正在缩进去的首页（读起来像两个首页）。
    await pushEditorViaZoom(tester);
    await tester.pump(const Duration(milliseconds: 16));

    const cardKey = ValueKey('appearance-editor-preview-card');
    double cardAlpha() => tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byKey(cardKey, skipOffstage: false),
            matching: find.byType(Opacity, skipOffstage: false),
          ),
        )
        .fold<double>(1, (min, o) => math.min(min, o.opacity));

    expect(cardAlpha(), 0.0, reason: '进场首帧不该有卡片');

    // 首页还在缩的整段里，卡片必须一直是 0。
    var sawShrinking = false;
    for (var i = 0; i < 20; i++) {
      final snapshotWidth = homeSnapshotRect(tester).width;
      if (snapshotWidth > cardRect(tester).width + 0.5) {
        sawShrinking = true;
        expect(
          cardAlpha(),
          0.0,
          reason: '第 $i 帧：首页还在缩，中间那块小屏就已经摆出来了',
        );
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(sawShrinking, isTrue, reason: '这段里必须真的观察到"首页还在缩"');

    // 缩到位之后就交给卡片接管（此后恒为 1）。
    await tester.pumpAndSettle();
    expect(cardAlpha(), 1.0, reason: '首页落到卡片上之后，卡片要接管画面');
  });

  testWidgets('材质面板最多半屏、内容内部滚动（不许盖满屏把预览压掉）', (tester) async {
    // 用户口径 2026-09-20：「材质弹窗最多显示到半屏，不要显示到全屏，然后它可以
    // 内部滚动，不然全屏显示用户都看不到预览内容了」。
    // 改之前实测：面板占屏高 76%（649.8 / 852.9），内容 566 高、`maxScrollExtent`
    // 为 0 —— 它靠"长高"把内容全显示出来，正好把上面那张预览小屏盖掉。
    await pumpEditor(tester);
    await tester.tap(find.text('材质'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 面板本体 = 承载壳画的那层 surface（最外层 ClipRRect 就是它；2026-09-20 起
    // 注入面从 ClipPath 换成 ClipRRect —— 裁剪曲线改成与材质同源的那条正圆角）。
    final panelFinder = find.ancestor(
      of: find.byType(HyperosSheetFrame),
      matching: find.byType(ClipRRect),
    );
    expect(panelFinder, findsOneWidget, reason: '面板定位口径变了，这条要跟着改');
    final panel = tester.getRect(panelFinder);
    expect(
      panel.height,
      lessThanOrEqualTo(_viewport.height * 0.5 + 1),
      reason: '面板超过半屏，就会把它上面那张预览小屏压掉（面板的意义就是边改边看）',
    );
    // 预览小屏的上半部分必须露在面板外面（这正是用户要半屏的原因）。
    expect(
      panel.top,
      greaterThan(cardRect(tester).top),
      reason: '面板顶到屏幕顶了＝预览整块看不见',
    );
    // 超出的内容在面板内部滚动（不再靠长高来"全显示"）。
    //
    // ⚠️ 面板里第一个 `Scrollable` 是 2026-09-22 加的那层**横向翻页**（通用 /
    // 课程卡片两页），所以这里按页 key 指名取「通用」页自己的竖向滚动视图。
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('material-page-general')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '内容超出面板上限时必须能内部滚动，否则下面的设置项够不着',
    );
  });

  testWidgets('缩放转场：退出是进场的倒放 —— 首页从小屏连续长回全屏', (tester) async {
    // 用户 2026-09-20：「退出的时候，应该是反过来的放大效果，和进入是相反的」。
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();
    final card = cardRect(tester);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(); // 退场首帧

    // ① 渲染源必须**当场**卸掉。它是整屏 1:1 的一份首页，平时藏在"不透明底衬"
    //    后面；留到退场里，底衬一淡出它就整屏露出来，把"从小屏长回全屏"盖掉 ——
    //    观感就变成"编辑页淡掉、首页已经满屏在那儿了"。
    expect(
      find.byType(PreviewBakeBoundary, skipOffstage: false),
      findsNothing,
      reason: '退场一开始就要卸掉渲染源，否则它会先整屏露出来盖住放大过程',
    );

    // ② 首页快照从小屏矩形**连续长回**整屏：起点就是小屏大小，之后单调不缩。
    final widths = <double>[];
    for (var i = 0; i < 24; i++) {
      widths.add(homeSnapshotRect(tester).width);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(widths.first, closeTo(card.width, 1.0), reason: '长回的起点就该是小屏大小');
    for (var i = 1; i < widths.length; i++) {
      expect(
        widths[i],
        greaterThanOrEqualTo(widths[i - 1] - 0.01),
        reason: '第 $i 帧回缩了：退场必须是单调放大',
      );
    }
    expect(
      widths.last,
      greaterThan(widths.first * 1.2),
      reason: '这个过程得真的在长大，不能只是换了个图层',
    );

    // ③ 播完交还活首页（快照释放、驱动源清空）。
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HyperosZoomShrinkScope, skipOffstage: false),
        matching: find.byType(RawImage, skipOffstage: false),
      ),
      findsNothing,
      reason: '落定后必须交还活首页',
    );
    expect(hyperosZoomTopAnimation.value, isNull);
  });

  /// 退场那一帧被缩放的那张图（首页那半边画的就是它）。
  ui.Image scaledHomeImage(WidgetTester tester) => tester
      .widget<RawImage>(
        find.descendant(
          of: find.byType(HyperosZoomShrinkScope, skipOffstage: false),
          matching: find.byType(RawImage, skipOffstage: false),
        ),
      )
      .image!;

  testWidgets('缩放转场：退场放大的是编辑页那张"新观感"图（不是进页快照）', (tester) async {
    // 用户口径 2026-09-22：「换完壁纸点击完成的时候，为什么会显示回原本的壁纸，
    // 然后又闪回来」。根因是退场倒放沿用了**进页时**烤的快照（旧壁纸 / 旧材质），
    // 修法见 [hyperosZoomExitSource]：编辑页在「完成」退出前把自己那张整页烤图
    // 交出来，退场放大它。
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();

    final entrySnapshot = hyperosZoomHomeSnapshot.value;
    expect(entrySnapshot, isNotNull, reason: '进场那张旧快照还在（退场兜底要用）');
    expect(
      hyperosZoomExitSource.value,
      isNull,
      reason: '退场源只在「完成」退出前发布，编辑页开着时不该有',
    );

    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final exitSource = hyperosZoomExitSource.value;
    expect(exitSource, isNotNull, reason: '「完成」退出前要把当前烤图交给退场');
    expect(
      identical(exitSource, entrySnapshot),
      isFalse,
      reason: '退场源必须是编辑页新烤的那张，不是进页那张旧快照',
    );
    expect(
      identical(scaledHomeImage(tester), exitSource),
      isTrue,
      reason: '退场那一帧放的就是新观感那张（旧快照只作兜底）',
    );
  });

  testWidgets('缩放转场：编辑页里切过预览视图时，退场退回进页快照', (tester) async {
    // 缩尺预览的日 / 周是编辑页自己的状态，不改首页的浏览状态。两边视图不一致时
    // 拿预览那张去放大，落定处会跳一下 —— 所以那种情况不发布退场源。
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('日课表'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      hyperosZoomExitSource.value,
      isNull,
      reason: '预览视图与首页不一致 ⇒ 不发布退场源',
    );
    expect(
      identical(scaledHomeImage(tester), hyperosZoomHomeSnapshot.value),
      isTrue,
      reason: '退回进页那张旧快照',
    );
  });

  testWidgets('缩放转场：取消退出不发布退场源（回滚后旧画面本来就是对的）', (tester) async {
    await pushEditorViaZoom(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(hyperosZoomExitSource.value, isNull);
    expect(
      identical(scaledHomeImage(tester), hyperosZoomHomeSnapshot.value),
      isTrue,
    );
  });

  testWidgets('缩放转场：按钮不跟着缩放，且缩放没走完之前不出现', (tester) async {
    await pushEditorViaZoom(tester);

    // 进场首帧整条编辑页路由是 Offstage（Flutter 的既定行为），几何量不准，
    // 所以首帧只钉"完全透明"，几何从下一帧起逐帧记。
    expect(chromeText('完成'), findsOneWidget, reason: '只是透明，不能从树上摘掉');
    expect(chromeAlpha(tester, '完成'), 0.0);
    expect(chromeAlpha(tester, '材质'), 0.0);
    await tester.pump(const Duration(milliseconds: 16));

    final chromeRects = <Rect>[];
    final chromeAlphas = <double>[];
    final snapshotWidths = <double>[];
    for (var i = 0; i < 32; i++) {
      chromeRects.add(tester.getRect(chromeText('完成')));
      chromeAlphas.add(chromeAlpha(tester, '完成'));
      snapshotWidths.add(homeSnapshotRect(tester).width);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    // ① 按钮的矩形**全程不变**：不参与缩放，也不参与位移。
    final first = chromeRects.first;
    for (var i = 0; i < chromeRects.length; i++) {
      expect(
        chromeRects[i].left,
        closeTo(first.left, 0.01),
        reason: '第 $i 帧：按钮被转场带着横向移动了',
      );
      expect(
        chromeRects[i].top,
        closeTo(first.top, 0.01),
        reason: '第 $i 帧：按钮被转场带着纵向移动了',
      );
      expect(
        chromeRects[i].width,
        closeTo(first.width, 0.01),
        reason: '第 $i 帧：按钮被转场带着缩放了，正是用户否掉的那版',
      );
    }

    // ② 首页还在缩的时候，按钮必须一个都还没出现（用户口径：缩放结束以后才显示）。
    final settledCard = cardRect(tester);
    for (var i = 0; i < snapshotWidths.length; i++) {
      if (snapshotWidths[i] > settledCard.width + 0.5) {
        expect(
          chromeAlphas[i],
          0.0,
          reason: '第 $i 帧：首页还在缩，按钮就已经出现了',
        );
      }
    }

    // ③ 转场结束：按钮完全出场。
    expect(chromeAlpha(tester, '完成'), 1.0);
    expect(chromeAlpha(tester, '材质'), 1.0);
    expect(chromeText('完成'), findsOneWidget);
  });
}
