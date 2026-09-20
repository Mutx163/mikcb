// HyperosZoomPageRoute + HyperosZoomShrinkScope：「首页整页缩小进新页」
// 的缩放转场（V 形编排 + 快照缩放）。
//
// 断言口径：
// * 缩放断言走 getRect（getTopLeft/getBottomRight 沿绘制链吃 Transform）；
// * 真机教训（2026-09-19「闪了四五次」）：活首页带玻璃/壁纸被逐帧缩放会
//   闪烁，所以转场期缩的是**首页快照**（RawImage），活首页停止绘制但不被
//   缩放——测试分别钉住两边；
// * 真机教训第二轮（同日「进场闪一下、返回后右上角球错位」）：活玻璃在
//   转场壳里的任何一帧绘制都会被烤成坏缓存并在落定后冻结，所以**全程**
//   停绘——退场倒放也用快照顶替，落定（dismissed）才交还活首页。
// * 查找一律 skipOffstage:false：zoom 路由 opaque:true，落定后首页被 theater
//   归入「不绘制但保留状态」区段，默认查找会当它不存在——那正是省电行为，
//   测试要能穿透看它。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screenW = 800.0; // widget 测试默认逻辑视口宽
  final homeFinder = find.text('HOME', skipOffstage: false);
  final snapshotFinder = find.byType(RawImage, skipOffstage: false);

  /// 一个已知落点：占位首页 + 落点矩形，用来量「首页有没有连续缩到落点」。
  ///
  /// 真机上这个矩形由外观编辑页实测上报（见
  /// `appearance_editor_layout_test` 的契约用例）；这里给死值是为了让几何
  /// 断言可复算。
  const landingRect = Rect.fromLTWH(150, 120, 500, 375);
  const landing = HyperosZoomLanding(rect: landingRect, radius: 18);

  Future<void> pumpHost(WidgetTester tester) async {
    hyperosZoomLanding.value = landing;
    addTearDown(() {
      hyperosZoomLanding.value = null;
      hyperosZoomHomeSnapshot.value = null;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: HyperosZoomShrinkScope(
          child: Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    );
  }

  NavigatorState navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  Future<void> pushEditor(WidgetTester tester) async {
    // ignore: unawaited_futures
    navigator(tester).push<void>(
      HyperosZoomPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('EDITOR'))),
      ),
    );
    await tester.pump(); // 路由安装，动画起点
  }

  double homeTextWidth(WidgetTester tester) =>
      tester.getRect(homeFinder).width;

  testWidgets('无 zoom 路由在飞时 scope 零包装、无快照', (tester) async {
    await pumpHost(tester);
    expect(
      find.ancestor(of: homeFinder, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(snapshotFinder, findsNothing);
  });

  testWidgets('进场发布首页快照必须帧末发：卡片那侧不抛「build 期间标脏」', (tester) async {
    // 回归钉（用户 2026-09-20 报错原文：「setState() or markNeedsBuild() called
    // during build. This AnimatedBuilder widget cannot be marked as needing to
    // build…」）。编辑页的预览卡片是**另一条路由**里的 AnimatedBuilder，监听
    // [hyperosZoomHomeSnapshot]；首页这半边曾在 build 里直接写那个 notifier
    // （`_ensureSnapshot` 烤完就发），于是那张卡片被标脏 —— 而它不在当前构建
    // 目标的后代里，框架当场抛错。探针定位在**进场第 0 帧**（烤出头一张图那帧）。
    await pumpHost(tester);
    // ignore: unawaited_futures
    navigator(tester).push<void>(
      HyperosZoomPageRoute<void>(
        builder: (_) => Scaffold(
          body: Center(
            child: AnimatedBuilder(
              animation: hyperosZoomHomeSnapshot,
              builder: (context, _) => const Text('CARD'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // 路由安装，动画起点：首页那半边在这一帧烤出头一张图
    expect(
      tester.takeException(),
      isNull,
      reason: 'build 期间发布快照会把另一条路由里的卡片标脏（用户报错原文）',
    );
    // 帧末那一发仍然要到：卡片下一帧就能拿到首页快照（延迟一帧，不是不发）。
    await tester.pump();
    expect(hyperosZoomHomeSnapshot.value, isNotNull);
  });

  testWidgets('进场：快照从整屏连续缩到上报的落点矩形，落定后就停在那里', (tester) async {
    // 用户 2026-09-20 口径：看起来要是「把主页连续缩进预览小屏」——所以快照的
    // 终点必须**四边都落在落点矩形上**（不是缩到屏幕中央的某个固定比例）。
    await pumpHost(tester);
    final initialWidth = homeTextWidth(tester);

    await pushEditor(tester);
    await tester.pump(const Duration(milliseconds: 150)); // 中段

    expect(find.text('EDITOR'), findsOneWidget);
    // 快照在缩（绘制矩形进入落点区间内）。
    final midRect = tester.getRect(snapshotFinder);
    expect(midRect.width, lessThan(screenW));
    expect(midRect.width, greaterThan(landingRect.width));
    // 活首页只是停止绘制，布局与尺寸原样（真机闪烁修法的钉）。
    expect(homeTextWidth(tester), initialWidth);

    await tester.pumpAndSettle();
    // 回归钉：终点四边 == 落点四边。改几何必须自觉重定这一组口径。
    final settled = tester.getRect(snapshotFinder);
    expect(settled.left, closeTo(landingRect.left, 1.0));
    expect(settled.top, closeTo(landingRect.top, 1.0));
    expect(settled.right, closeTo(landingRect.right, 1.0));
    expect(settled.bottom, closeTo(landingRect.bottom, 1.0));
  });

  test('出场分段口径：暗底在缩到位之后才动，chrome 比它更晚', () {
    // 用户口径「缩放结束以后，才显示页面上的按钮」——两段的分界与先后顺序
    // 就是这条的实现，改动即自觉重定。
    expect(HyperosZoomRoute.growT(HyperosZoomRoute.swapPoint), 0);
    expect(HyperosZoomRoute.chromeT(HyperosZoomRoute.swapPoint), 0);
    expect(HyperosZoomRoute.growT(1), 1);
    expect(HyperosZoomRoute.chromeT(1), 1);
    // chrome 全程落后于暗底（同一进度下它的值更小）。
    for (final p in const [0.5, 0.7, 0.9]) {
      expect(
        HyperosZoomRoute.chromeT(p),
        lessThan(HyperosZoomRoute.growT(p)),
        reason: 'p=$p：按钮必须在暗底之后才出场',
      );
    }
    // 首页缩小段在落点已经走满，且**收尾速度归零**（easeOut 整形，落地不顿）。
    expect(HyperosZoomRoute.shrinkT(HyperosZoomRoute.swapPoint), 1);
    expect(
      HyperosZoomRoute.shrinkT(HyperosZoomRoute.swapPoint * 0.9),
      greaterThan(0.9),
      reason: '落点前最后一成行程只走了不到一成的距离 = 减速滑入',
    );
  });

  testWidgets('退出倒放：全程快照顶替活首页、落定才切回并释放快照', (tester) async {
    await pumpHost(tester);
    final initialWidth = homeTextWidth(tester);

    await pushEditor(tester);
    await tester.pumpAndSettle();

    navigator(tester).pop();
    // 退场（倒放）第一帧：快照继续顶替，活首页仍被停绘——活玻璃在转场壳
    // 里的任何一帧绘制都会被烤成坏缓存并在落定后冻结（真机：返回后右上角
    // 球错位到左上角），一次绘制机会都不给。
    await tester.pump();
    expect(snapshotFinder, findsOneWidget);
    expect(
      tester
          .widget<Visibility>(
            find.ancestor(of: homeFinder, matching: find.byType(Visibility)),
          )
          .visible,
      isFalse,
    );
    expect(find.text('EDITOR'), findsOneWidget); // 编辑页还在倒放缩回途中

    await tester.pumpAndSettle();

    // 落定（壳已撤、动画已停）：快照释放、活首页在干净状态恢复。
    expect(find.text('EDITOR'), findsNothing);
    expect(snapshotFinder, findsNothing);
    expect(
      find.ancestor(of: homeFinder, matching: find.byType(Visibility)),
      findsNothing,
    );
    expect(homeTextWidth(tester), initialWidth);
    expect(hyperosZoomTopAnimation.value, isNull);
  });

  testWidgets('进场首帧必须是未缩小状态：路由的 offstage 占位动画不能当进度用', (tester) async {
    // 真机反馈（2026-09-20）：「点按钮那一刻先看到一个缩小并压暗的画面，接着又
    // 跳成满屏，然后才开始正常缩小」。
    //
    // 根因在上游、而且是**文档里明写**的行为：`ModalRoute` 的 offstage 文档原话是
    // 「On the first frame of a route's entrance transition, the route is built
    // Offstage using an animation progress of 1.0」，实现里 `set offstage` 直接把
    // `_animationProxy.parent` 换成恒为 1.0/completed 的 `kAlwaysCompleteAnimation`。
    // 首页这半边（`HyperosZoomShrinkScope`）在路由机制**之外**自己读那个动画，
    // 于是首帧把 1.0 当进度 → 直接画成终态（0.85 + 压暗）；下一帧代理换回真控制器、
    // 值掉回 0 → 画面又跳回满屏；之后才是正常缩小。
    //
    // 编辑页那半边反而没事：那一帧整条路由是 Offstage，根本不绘制。所以修法是把
    // 对外发布的进度源换成**控制器**（`HyperosZoomPageRoute.controller`），它不受
    // 代理影响。这条用例逐帧钉住：首帧满幅 + 之后单调收缩（不许回跳）。
    await pumpHost(tester);
    await pushEditor(tester); // 内部已 pump 一帧 = 进场首帧

    expect(
      tester.getRect(snapshotFinder).width,
      closeTo(screenW, 1.0),
      reason: '进场首帧不能已经是缩小终态（那是把 offstage 的占位 1.0 当成了进度）',
    );

    var previous = screenW;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final width = tester.getRect(snapshotFinder).width;
      expect(
        width,
        lessThanOrEqualTo(previous + 0.01),
        reason: '缩小过程必须单调：第 $i 帧回跳了，说明中途换了进度源',
      );
      previous = width;
    }
    expect(previous, lessThan(screenW), reason: '只要求单调还不够，得真的在缩');
  });

  testWidgets('进场时长与退出时长同用一套基数（同一动作正放倒放）、路由不透明', (tester) async {
    final route = HyperosZoomPageRoute<void>(builder: (_) => const SizedBox());
    expect(route.transitionDuration, HyperosZoomRoute.duration);
    expect(route.reverseTransitionDuration, HyperosZoomRoute.duration);
    expect(route.opaque, isTrue);
  });
}
