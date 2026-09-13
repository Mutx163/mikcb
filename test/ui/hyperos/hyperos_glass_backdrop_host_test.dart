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
    // 真机回归：首页内容每帧重建（开内置壁纸）时，采样源开关被通知 →
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
}
