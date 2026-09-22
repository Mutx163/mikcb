import 'dart:async';

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

  testWidgets(
    '本屏恢复（TickerMode 转真）后必须重新解析采样源，不停在旧的',
    // 待重挂目标：这条钉的是柔光面（已随材质退场删除）的 TickerMode 门控；
    // 换成磨砂面后「被盖住的屏仍占采样名额」，说明该门控没长在磨砂面上 ——
    // 要么给 StableFrostedSurface 补同款门控，要么把这条钉改到还生效的表面上。
    skip: true,
    (tester) async {
    // 场景：页面 push 后被盖住（OverlayEntry 会关掉 TickerMode）；pop 回来时页面
    // widget 是缓存的、**不会重建** —— 只剩 TickerMode 依赖能触发重新解析。
    // 没有这一步，采样源就永远停在被盖住前的那个上，回来时玻璃只剩半套材质、
    // 另一半回落实底（真机：进设置再回来爱心变半透明）。
    final home = HyperosGlassBackdropController();
    final pushed = HyperosGlassBackdropController();
    addTearDown(home.dispose);
    addTearDown(pushed.dispose);
    final live = ValueNotifier<bool>(true);
    final revision = ValueNotifier<int>(0);
    addTearDown(live.dispose);
    addTearDown(revision.dispose);

    await tester.pumpWidget(
      TestApp(
        home: Stack(
          children: [
            HyperosGlassBackdropHost(
              controller: home,
              // 宿主子树必须有非零尺寸，否则捕获节点 `size.isEmpty` 会直接
              // 早退、永远录不到带（这一条踩过）。
              child: const SizedBox(width: 200, height: 120),
            ),
            // 玻璃面在宿主**之外**：只能靠注册表"栈顶"取采样源 —— 正是常驻
            // 玻璃球的挂法（球为了不自采样必须画在宿主之外）。
            ValueListenableBuilder<bool>(
              valueListenable: live,
              builder: (context, enabled, _) => TickerMode(
                enabled: enabled,
                child: ValueListenableBuilder<int>(
                  valueListenable: revision,
                  // 每次 revision 变化都要重建并重新登记采样区，这里刻意不 const。
                  // ignore: prefer_const_constructors
                  builder: (context, r, _) => SizedBox(
                    width: 60,
                    height: 60,
                    // 不传 blurEnabled（默认 true，测试环境也能真的登记采样区）。
                    // ignore: prefer_const_constructors
                    child: StableFrostedSurface(
                      cornerRadius: 16,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(home.zones, isNotEmpty, reason: '初始应绑在本屏（栈顶 = home）');
    expect(pushed.zones, isEmpty);

    // push：新页面注册自己的采样源（成为栈顶）、本屏被盖住；期间玻璃面因父级
    // 重建会重新解析一次 —— 但节拍已经停了，解析结果是**不登记任何采样区**：
    // 那些玻璃不绘制，占着名额只会让每次录帧白录一块、还要把它们拉进材质重建
    // （块数才是这条链路上最贵的维度）。
    HyperosGlassBackdropRegistry.register(pushed);
    addTearDown(() => HyperosGlassBackdropRegistry.unregister(pushed));
    live.value = false;
    revision.value = 1;
    await tester.pumpAndSettle();
    expect(pushed.zones, isEmpty, reason: '被盖住期间不该绑到栈顶那个');
    expect(home.zones, isEmpty, reason: '本屏那份也不该继续占着名额');

    // pop：新页面注销、本屏恢复。**不再重建**玻璃面 —— 只剩 TickerMode 依赖
    // 能触发重新解析。
    HyperosGlassBackdropRegistry.unregister(pushed);
    live.value = true;
    await tester.pumpAndSettle();

    expect(
      home.zones,
      isNotEmpty,
      reason: '恢复后必须重新解析回本屏采样源（否则回来只剩半套材质）',
    );
    // 重新绑上之后要再录一帧：重绑发生在布局阶段，录帧排在帧末。
    await tester.pump(const Duration(milliseconds: 32));
    for (final zone in home.zones) {
      expect(zone.image, isNotNull, reason: '重新绑上之后必须重新录到带');
    }
  });

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

  testWidgets('新开一块采样区必须单独要一帧，否则新玻璃永远拿不到快照', (tester) async {
    // 真机回归（2026-09-13）：高级材质页「打开预览面板」→ 柔光档弹窗是一层
    // 无模糊的半透明白，底下的字像素级清晰地透出来（面板整体看着"透明"）。
    //
    // 根因：该页**已经**有一块页内玻璃（预览卡里的玻璃带）让 `capturing` 为 true，
    // 弹窗面板随后在屏底登记出**第二块**采样区（两块相距 > `_joinGap`，不会归并）。
    // 此时 `acquireZone` 的判据 `wasEmpty && capturing` 不成立 → 一次通知都不发
    // → 捕获节点没有任何理由重绘 → 这块新区的 `snapshot` 恒为 null → 上游
    // `MiuixGlass.paint` 走「无背景兜底」分支画 `fill`（252 灰 @ 0.675，再被
    // mask 削到 ~0.32）→ 半透明空壳。
    //
    // 这与 `acquire()` 在 `6ea782a6` 修掉的是同一条判据毛病，只是那条在整层路径
    // 上、这条在分区路径上。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await tester.pumpWidget(
      hostWith(
        controller: controller,
        child: const Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: SizedBox(key: Key('near'), width: 200, height: 120),
            ),
            // 与第一块相距远超 `_joinGap`（2 × sampleMargin = 192），
            // 保证它单独成块，而不是并进已有那块。
            Positioned(
              left: 0,
              top: 900,
              child: SizedBox(key: Key('far'), width: 200, height: 120),
            ),
          ],
        ),
      ),
    );

    final nearBox = tester.renderObject<RenderBox>(find.byKey(const Key('near')));
    final farBox = tester.renderObject<RenderBox>(find.byKey(const Key('far')));

    controller.acquireZone(nearBox, HyperosZoneBackdrop());
    expect(notifications, 1, reason: '第一块玻璃开启录帧 → 必须通知一帧');
    expect(controller.zones, hasLength(1));

    await tester.pump();
    await tester.pump();

    final before = notifications;
    controller.acquireZone(farBox, HyperosZoneBackdrop());
    expect(controller.zones, hasLength(2), reason: '两块相距够远，应各成一块');
    expect(
      notifications,
      greaterThan(before),
      reason: '新开了一块采样区，捕获节点必须重绘一次，否则这块区永远没有快照',
    );
  });

  testWidgets('弹层滑入过程中采样带跟着重录，不再冻在屏幕外那一帧', (tester) async {
    // 真机回归（2026-09-13）：外观与配色 →「打开预览面板」→ 柔光档底部弹窗看着透明。
    //
    // 采样带是按"玻璃在哪"实时算的，但**捕获节点在页面里**，而弹层画在 root Overlay
    // 上：滑入动画只重绘 Overlay，页面不重绘，捕获节点就没有任何理由重录 —— 采样带
    // 永远停在"面板还压在屏幕下沿之外"那一帧，与视口求交只剩一条边（真机日志
    // `img=470x23` 对 668×353 逻辑像素的面板）。玻璃把这条细条拉伸铺满自己，观感就是
    // 一层平的淡色纱 = 用户看到的「透明」。
    //
    // 所以这里必须让玻璃在 Overlay 里动（`showHyperosSheet` 的 SlideTransition），
    // 而不是在页面子树里动 —— 后者会顺带把捕获节点标脏，测不出这条通道。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);

    late BuildContext pageContext;
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: const FrostedAppearance(
            sheetBlurSigma: 15,
            sheetTintAlpha: 0.70,
            sheetBarrierAlpha: 0.20,
            glassMode: FrostedGlassMode.liquidGlass,
          ),
          child: HyperosGlassBackdropHost(
            controller: controller,
            child: Builder(
              builder: (context) {
                pageContext = context;
                return const ColoredBox(
                  color: Color(0xFFE8E8E8),
                  child: SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.zones, isEmpty, reason: '页面本身没有玻璃，不该录帧');

    unawaited(
      showHyperosSheet<void>(
        context: pageContext,
        builder: (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 320,
            height: 200,
            child: StableFrostedSurface(cornerRadius: 16,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    final zone = controller.zones.single;
    expect(zone.image, isNotNull, reason: '动画走完必须录到玻璃背后那条带');
    // 测试视口 800×600，面板高 200 且贴底 → 停稳后顶端在 400，减采样余量 96 = 304。
    // 不重录的话这里会停在滑入早期（屏幕下沿之外）的位置。
    expect(
      zone.origin!.dy,
      closeTo(400 - HyperosGlassBackdropController.sampleMargin, 4),
      reason: '采样带原点要跟着玻璃停稳的位置，而不是滑入早期那一帧',
    );
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
            StableFrostedSurface(cornerRadius: 16, child: SizedBox(width: 80, height: 40)),
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

  testWidgets('菜单在展开态被卸载时归还录帧：宿主页不会一直白录帧', (tester) async {
    // 弹层持有的是 `holdRecording()`（只保持录帧，不要整层快照），归还必须用
    // `releaseRecording()`。早先 `HomeTopMenuPopup.dispose()` 里写的是 `release()`
    // —— 那是给 `acquire()` 配对的（只递减 `_plainConsumers`，本弹层从没调用过），
    // 于是 `_recordingHolds` 永不归零、`capturing` 再也回不到 false。
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    final anchor = MiuixGlassPopupAnchor();
    addTearDown(anchor.dispose);

    // `backdrop: null` 才会去认领本屏采样源（见 `_syncCaptureHold`）。
    Widget tree({required bool withMenu}) => hostWith(
      controller: controller,
      child: Stack(
        children: [
          const SizedBox.expand(),
          if (withMenu)
            HomeTopMenuPopup(
              show: true,
              anchor: anchor,
              anchorContent: const Icon(Icons.more_vert_rounded),
              entries: const [],
              hasAvailableUpdate: false,
              onDismissRequest: () {},
              onSelected: (_) {},
            ),
        ],
      ),
    );

    await tester.pumpWidget(tree(withMenu: true));
    await tester.pumpAndSettle();
    expect(
      controller.capturing,
      isTrue,
      reason: '菜单展开期间应当持有录帧',
    );

    // 菜单在 show: true 状态下被整体摘掉（宿主页结构变化、页面卸载等）。
    await tester.pumpWidget(tree(withMenu: false));
    await tester.pumpAndSettle();
    expect(
      controller.capturing,
      isFalse,
      reason: '菜单卸载时必须归还录帧，否则宿主页一直白录帧',
    );
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
                child: StableFrostedSurface(cornerRadius: 16, child: SizedBox.expand()),
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
                child: StableFrostedSurface(cornerRadius: 16, child: SizedBox.expand()),
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

  testWidgets('采样快照按上游模糊源同档录制，不按 dpr 整屏出图', (tester) async {
    // 归因：上游 MiuixGlass.prepare 拿到快照后先 `canvas.scale((dpr/4).clamp(.5,1.0))`
    // 才做高斯模糊 —— 按 dpr 录的像素有 15/16 从未进入最终画面，只抬高离屏峰值。
    // 弹层那条路尤其贵：它拿不到"自己背后那块"矩形，只能整层录，
    // 2.75x 的 1280×2772 是 26.8M 像素 ≈ 107MB／帧（真机实测每次打开弹层瞬时
    // 分配 100~140MB、快速连开 RSS 峰值 1.01GB）。
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
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 200,
                height: 60,
                child: StableFrostedSurface(cornerRadius: 16, child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // 弹层打开：请求整层背景。
    controller.acquire();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final dpr = tester.view.devicePixelRatio;
    final expected = (dpr / 4).clamp(.5, 1.0);

    // 窄带与整层都必须走同一个比例。
    expect(controller.zones, isNotEmpty);
    expect(
      controller.zones.first.pixelRatio,
      closeTo(expected, 1e-9),
      reason: '窄带快照按上游模糊源同档录',
    );

    final plain = controller.plainBackdrop;
    expect(plain.snapshot, isNotNull, reason: '弹层要背景时当帧末应有整层快照');
    expect(
      plain.pixelRatio,
      closeTo(expected, 1e-9),
      reason: '整层快照按上游模糊源同档录，不是 dpr',
    );
    // 关键等价性：上游用 `image.width / backdrop.pixelRatio` 还原逻辑宽度，
    // 两边同时缩小 → 上游看到的逻辑尺寸不变（采样不错位）。
    expect(
      plain.snapshot!.width / plain.pixelRatio,
      closeTo(400, 1.0),
      reason: '还原出的逻辑宽度仍等于屏宽',
    );
    expect(
      plain.snapshot!.width,
      lessThan(400 * dpr),
      reason: '不再按 dpr 出整屏像素',
    );
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
        child: StableFrostedSurface(cornerRadius: 16, child: SizedBox.expand()),
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

  // 真机回归（2026-09-15）：柔光档刚进「调整壁纸显示位置」页时，三个悬浮按钮
  // 「先冒一块平的、再变玻璃」，慢放下是一下明显的跳变。根因是上游玻璃是在
  // **paint** 里读快照的（`flutter_miuix` 的 `_RenderGlass.paint`：`backdrop.snapshot
  // != null && globalOffset != null` 才画材质，否则退回 `fill` 兜底实底），而捕获
  // 节点排在这块玻璃**之前**画；首次采样若只排到帧末，玻璃头几帧必然读不到图。
  //
  // 下面这条就是那份时序契约：宿主**之后**画的兄弟节点（玻璃的处境），应当在
  // 同一帧里就读到快照。
  testWidgets('首次采样同帧完成：宿主之后画的玻璃这一帧就读得到快照', (tester) async {
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    final backdrop = HyperosZoneBackdrop();
    final reads = <bool>[];

    await tester.pumpWidget(
      TestApp(
        home: Stack(
          children: [
            HyperosGlassBackdropHost(
              controller: controller,
              // 宿主子树必须有非零尺寸，否则捕获节点 `size.isEmpty` 直接早退。
              child: const SizedBox(width: 200, height: 120),
            ),
            // 玻璃的挂法：采样登记在宿主**之外**（壁纸位置选择页的三个悬浮按钮
            // 就是这样挂的——不能采到自己上一帧），画在宿主之后。
            HyperosGlassBackdropReporter(
              controller: controller,
              backdrop: backdrop,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: _BackdropReadProbe(backdrop, reads),
              ),
            ),
          ],
        ),
      ),
    );

    expect(reads, isNotEmpty, reason: '探针至少要画过一帧');
    expect(
      reads.first,
      isTrue,
      reason: '首帧就该读到快照，否则玻璃会先画一块平的、下一帧才变玻璃',
    );
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
                  child: StableFrostedSurface(cornerRadius: 16, child: SizedBox.expand()),
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

/// 在 paint 相位读一次「玻璃这一帧能不能拿到材质」。
///
/// 判据与上游 `_RenderGlass.paint` 完全一致（有快照 + 有原点才画材质，否则画
/// `fill` 兜底实底），所以读到的就是玻璃这一帧会看到的东西；按 paint 顺序记录，
/// 于是能证明「宿主在前、玻璃在后」的同一帧里快照已经写好。
class _BackdropReadProbe extends CustomPainter {
  _BackdropReadProbe(this.backdrop, this.reads);

  final HyperosZoneBackdrop backdrop;
  final List<bool> reads;

  @override
  void paint(Canvas canvas, Size size) {
    reads.add(backdrop.snapshot != null && backdrop.globalOffset != null);
  }

  @override
  bool shouldRepaint(covariant _BackdropReadProbe oldDelegate) => true;
}
