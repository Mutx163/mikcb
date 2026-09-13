import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/home_top_menu_popup.dart';

import '../../helpers_test_app.dart';

/// 屏级玻璃采样源宿主 / 注册表。
///
/// 真机回归（2026-09-13）：首页右上角菜单变透明、底下的字直接可见。根因是玻璃坞
/// 里被盖住的内嵌页（`TickerMode(enabled: false)` + `Visibility`）仍然挂着，按挂载
/// 顺序把首页从注册表栈顶顶掉；菜单按"栈顶"取采样源，拿到一屏**不再绘制**的
/// backdrop（快照为空）→ 上游玻璃退化成透明轮廓。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget hostWith({
    required HyperosGlassBackdropController controller,
    required Widget child,
  }) => TestApp(
    home: HyperosGlassBackdropHost(controller: controller, child: child),
  );

  testWidgets('有玻璃 acquire 才录帧，全部释放即停（零开销）', (tester) async {
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: const SizedBox(width: 200, height: 120),
      ),
    );

    // 没人采样 → 不录帧，backdrop 里没有快照。
    expect(controller.capturing, isFalse);

    controller.acquire();
    await tester.pump();
    await tester.pump();
    expect(controller.capturing, isTrue);
    expect(
      controller.backdrop.snapshot,
      isNotNull,
      reason: '开启录帧后当帧末应写入一张快照',
    );

    controller.acquire();
    controller.release();
    expect(controller.capturing, isTrue, reason: '还有一个消费者在采样');

    controller.release();
    expect(controller.capturing, isFalse);
  });

  testWidgets('玻璃在构建期 acquire 不再触发 setState during build', (tester) async {
    // 真机回归：首页内容在构建期连续重建（分页/滚动中）时，采样源开关被
    // 通知 → 若标记重建不在当前构建链上的祖先，会抛
    // 若标记重建不在当前构建链上的祖先，会抛
    // "setState() or markNeedsBuild() called during build"。开关只重绘捕获节点。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: const Stack(
          children: <Widget>[
            SizedBox.expand(),
            // 兄弟子树里的玻璃表面：靠注册表拿到同一份采样源。
            SoftGlassSurface(child: SizedBox(width: 80, height: 40)),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.capturing, isTrue, reason: '表面挂载即请求录帧');
  });

  testWidgets('被 TickerMode 停掉的屏不占注册表栈顶（菜单不会再采到空 backdrop）', (
    tester,
  ) async {
    final first = HyperosGlassBackdropController();
    final second = HyperosGlassBackdropController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget tree({required bool secondLive}) => TestApp(
      home: Stack(
        children: <Widget>[
          HyperosGlassBackdropHost(
            controller: first,
            child: const SizedBox.expand(),
          ),
          TickerMode(
            enabled: secondLive,
            child: HyperosGlassBackdropHost(
              controller: second,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );

    // 第二屏已挂载但节拍停了（Visibility 盖住）→ 不能顶掉在跑的那一屏。
    await tester.pumpWidget(tree(secondLive: false));
    await tester.pumpAndSettle();
    expect(HyperosGlassBackdropRegistry.active, same(first));

    // 它活了 → 成为栈顶（modal 里的玻璃应采到它）。
    await tester.pumpWidget(tree(secondLive: true));
    await tester.pumpAndSettle();
    expect(HyperosGlassBackdropRegistry.active, same(second));

    // 再停掉 → 栈顶回到第一屏。
    await tester.pumpWidget(tree(secondLive: false));
    await tester.pumpAndSettle();
    expect(HyperosGlassBackdropRegistry.active, same(first));
  });

  testWidgets('内层宿主不登记：外层（含壁纸的那一屏）才是采样源', (tester) async {
    final outer = HyperosGlassBackdropController();
    final inner = HyperosGlassBackdropController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);

    await tester.pumpWidget(
      hostWith(
        controller: outer,
        child: Stack(
          children: [
            const SizedBox.expand(),
            // 屏里套屏：例如首页里包住 HyperosRootPage 的那一层。
            HyperosGlassBackdropHost(
              controller: inner,
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      HyperosGlassBackdropRegistry.active,
      same(outer),
      reason: '内层采不到外层壁纸，不能顶掉外层',
    );
  });

  testWidgets('菜单用自己的屏级采样源渲染玻璃（显式传入优先于注册表）', (tester) async {
    final menuBackdrop = MiuixLayerBackdrop();
    addTearDown(menuBackdrop.dispose);
    final anchor = MiuixGlassPopupAnchor();
    addTearDown(anchor.dispose);

    await tester.pumpWidget(
      TestApp(
        home: HomeTopMenuPopup(
          show: false,
          backdrop: menuBackdrop,
          anchor: anchor,
          anchorContent: const Icon(Icons.more_vert_rounded),
          entries: const [],
          hasAvailableUpdate: false,
          onDismissRequest: () {},
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    final popup = tester.widget<MiuixGlassTransformPopup>(
      find.byType(MiuixGlassTransformPopup),
    );
    expect(popup.backdrop, same(menuBackdrop));
  });

  testWidgets('玻璃在捕获子树内也不会自激重绘（静止后不再排帧）', (tester) async {
    // 真机现象：外观与配色页静止也吃满一个核。玻璃就在捕获子树里时，
    // 录帧 → 通知消费者 → 玻璃重绘 → 捕获节点（最近的重绘边界）被标脏 →
    // 再录一次 …… 变成 60fps 永远排下一帧。修好后静止即停。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: const Stack(
          children: <Widget>[
            SizedBox.expand(),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                height: 60,
                child: SoftGlassSurface(child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
    );

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.capturing, isTrue);
    expect(controller.zones, isNotEmpty, reason: '玻璃要登记自己占哪一块');
    expect(
      controller.zones.first.image,
      isNotNull,
      reason: '采样源要真的录到快照',
    );
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: '静止后不应继续排帧（自激重绘）',
    );
  });

  testWidgets('快照只覆盖玻璃那块窄带，不是整屏（性能红线）', (tester) async {
    // 整屏快照在 2.75x 的 1280×2772 上是 ~100MB 级离屏目标，每帧一次会直接烧掉
    // 一个核（真机 106~129% CPU）。捕获必须按玻璃矩形裁剪。
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: const Stack(
          children: <Widget>[
            SizedBox.expand(),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 200,
                height: 60,
                child: SoftGlassSurface(child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final image = controller.zones.first.image!;
    final dpr = tester.view.devicePixelRatio;
    final full = 400 * dpr * 800 * dpr;
    final captured = image.width * image.height;
    expect(
      captured,
      lessThan(full * 0.4),
      reason: '快照面积必须远小于整屏（贴在玻璃那条窄带上）',
    );
    expect(image.height, lessThan((800 * dpr * 0.6).round()));
  });

  testWidgets('分块满员时并入「最近」的一块，不把采样矩形撑成整屏高', (tester) async {
    // 回归背景：分块上限 4。超出时旧实现取 `_zones.last` —— 那是"最后创建的"，
    // 不是"最近的"。第 5 块玻璃若离它隔了整屏，并进去会把该块的采样矩形撑到接近
    // 整屏，恰好抵消分块要避免的那件事（整屏离屏目标每帧 ~100MB）。
    await tester.binding.setSurfaceSize(const Size(400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);

    Widget glassAt(double top) => Positioned(
      top: top,
      left: 100,
      child: const SizedBox(
        width: 200,
        height: 40,
        child: SoftGlassSurface(child: SizedBox.expand()),
      ),
    );

    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: Stack(
          children: [
            const SizedBox.expand(),
            // 挂载顺序 = 建块顺序。四块相隔 800（> joinGap 192），各自成块。
            glassAt(0),
            glassAt(800),
            glassAt(1600),
            glassAt(2400),
            // 第 5 块：离第一块最近（间距 260），离最后建的第四块最远（间距 2100）。
            glassAt(300),
          ],
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.zones.length, 4, reason: '分块上限就是 4');

    // 一块玻璃自身 40 高，并上最近的那块后跨度也远小于整屏（2600）。
    // 若误并入最远的那块，该块高度会逼近整屏 —— 这条断言就会挂。
    for (final zone in controller.zones) {
      final rect = controller.captureRectOf(zone);
      expect(rect, isNotNull);
      expect(
        rect!.height,
        lessThan(800),
        reason: '不相邻的玻璃不能并进同一块，否则采样矩形退化成整屏',
      );
    }
  });

  // 上游 `MiuixGlass` 契约（flutter_miuix 1.2.0 miuix_glass.dart:54）：
  //   "必须放在 backdrop 捕获子树之外，防止反馈采样。"
  // 本项目 os4_glass_backdrop.dart:13-14 也把这条抄了一遍。
  //
  // 但 HyperosGlassBackdropHost 的捕获节点包住了整个 widget.child，而页内玻璃
  // （顶栏带 / 玻璃坞 / 标签栏 / 卡片）就在 child 里 —— 玻璃既是采样者又是被采
  // 内容，采到的快照含它自己上一帧的渲染结果。弹层被正确地放在宿主之外
  // （timetable_screen.dart 的 Stack 第二子项），说明规则被理解了，只是没同步
  // 到页内玻璃。
  //
  // 修法是页面分层（背景层 / 玻璃层），属于架构改动，且是否在真机上可感知尚未
  // 验证 —— 详见 docs/component-migration-review-2026-09-13.md §4。
  // 修好之后去掉下面 group 的 skip，这条即成为守卫。
  group('捕获子树不含玻璃自身（上游契约，防反馈采样）', () {
    testWidgets('页内玻璃的采样登记节点应在捕获子树之外', (tester) async {
      final controller = HyperosGlassBackdropController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        hostWith(
          controller: controller,
          child: const Stack(
            children: <Widget>[
              SizedBox.expand(),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 60,
                  child: SoftGlassSurface(child: SizedBox.expand()),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // 去掉 skip 后实测：Found 1 widget with type "HyperosGlassBackdropReporter"
      // —— 页内玻璃确实落在捕获子树内，故当前为已知缺陷。
      expect(
        find.descendant(
          of: find.byType(HyperosLayerBackdropCapture),
          matching: find.byType(HyperosGlassBackdropReporter),
        ),
        findsNothing,
        reason: '玻璃的采样登记节点落在捕获子树内 = 玻璃采到自己，违反上游契约',
      );
    });
  }, skip: 'P0 已知缺陷：页内玻璃仍在捕获子树内（反馈采样），修法见审核报告 §4。');
}
