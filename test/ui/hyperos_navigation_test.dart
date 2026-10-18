import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  test('AOSP 基准时长常量保持不变（页面转场已改用 miuix-nav 的 500ms）', () {
    // applyUserTransitionSpeed now requires BuildContext; duration base is static.
    expect(HyperosMiuixNavigation.transitionDurationMs, 300);
    expect(
      AndroidAnimationScaleService.scaledDuration(
        HyperosMiuixNavigation.transitionDurationMs,
      ).inMilliseconds,
      300,
    );
  });

  test('user transition speed scales page transition duration', () {
    AndroidAnimationScaleService.setUserTransitionSpeed(2);
    expect(
      AndroidAnimationScaleService.scaledDuration(300).inMilliseconds,
      150,
    );
    AndroidAnimationScaleService.setUserTransitionSpeed(0.5);
    expect(
      AndroidAnimationScaleService.scaledDuration(300).inMilliseconds,
      600,
    );
  });

  test('page transition uses the official miuix-nav numbers', () {
    // 官方 NavDriverSpec.PROGRAMMATIC_DURATION_MILLIS（程序化 push/pop 整步）。
    expect(HyperosMiuixNavigation.programmaticDurationMs, 500);
    expect(HyperosNavigation.transitionDuration.inMilliseconds, 500);
    // 官方 NavTransitions.MiuixDefault：被覆盖页视差 1/4 屏宽 + 0.1 透明度衰减。
    // **视差取 0 —— 本仓唯一有意偏离官方的一处，理由是流畅**：被覆盖页每帧位移
    // 会让页面顶部那条实时磨砂带（`BackdropFilter`）每帧重新采样、重算模糊；
    // 视差 0 时旧页在屏幕坐标里不动，这一层可以复用。2026-10-18 第十八轮实测：
    // 改成官方 0.25 后用户立刻反馈「之前那个版本（`8afe191a`，视差 0）特别流畅」。
    expect(HyperosMiuixNavigation.coveredParallaxFraction, 0);
    expect(HyperosMiuixNavigation.coveredAlphaFalloff, 0.1);
    // 官方 NavDisplayEffects.Default.dimAmount（全屏压暗上限）。
    expect(HyperosMiuixNavigation.dimAmount, 0.5);
    // 前缘两角圆角：**关掉**（2026-10-18 第十八轮用户定案）。
    // 官方 `NavCornerClipMode.Leading` 是「动的时候才裁、停稳不裁」的二值开关，
    // 在本机型上被真机反复读成「圆角闪现消失 / 变直角」；用户要求不再纠结这个
    // 效果，页面转场全程保持完整矩形，圆角只由系统的机身边角提供。
    expect(HyperosMiuixNavigation.clipLeadingCornersWhileMoving, isFalse);
  });

  test('corner radius tapers to zero instead of toggling', () {
    const fallback = HyperosMiuixNavigation.pageCornerRadiusFallback;
    expect(fallback, greaterThan(0), reason: '跟随屏幕圆角得有个非零半径');
    // 两端精确为 0：静止态不可能残留圆角缺口（也就不会「啪」一下消失）。
    expect(HyperosNavigation.transitionCornerRadiusFactor(0), 0);
    expect(HyperosNavigation.transitionCornerRadiusFactor(1), 0);
    // 中段满半径。
    expect(HyperosNavigation.transitionCornerRadiusFactor(0.5), 1);
    expect(HyperosNavigation.transitionCornerRadiusFactor(0.3), 1);
    // 起始阈值按**离落点还剩多少屏宽**定：带宽 = 缓动后进度带宽 = 剩余距离的比例。
    // 用户口径「应该在贴边以后再变」，所以阈值必须远小于「看得出没贴边」的量：
    // 0.004 在 400dp 屏上是 1.6px。
    // 2026-10-18 第十三轮真机：「左上角接近边缘时一直是直角，能看到圆角转变的
    // 过程」—— 根因就是末段把被覆盖页的压暗/透明度释放回原色，切口里的颜色和
    // 新页拉平，圆角在贴边前就肉眼消失。释放包络撤回，全程走官方线性。
    expect(HyperosNavigation.scrimAlphaFor(0.5), closeTo(0.25, 1e-9));
    expect(HyperosNavigation.coveredAlphaFor(0.5), closeTo(0.95, 1e-9));
    expect(HyperosNavigation.scrimAlphaFor(0), 0);
    expect(HyperosNavigation.coveredAlphaFor(0), 1);

    // 末端必须**保持**压暗与降透明度（不再归零）—— 切口里始终有对比。
    expect(
      HyperosNavigation.scrimAlphaFor(1),
      closeTo(HyperosMiuixNavigation.dimAmount, 1e-9),
      reason: '贴边那一刻被覆盖页仍是满压暗：切口里的对比不能提前消失',
    );
    expect(
      HyperosNavigation.coveredAlphaFor(1),
      closeTo(1 - HyperosMiuixNavigation.coveredAlphaFalloff, 1e-9),
      reason: '同理，透明度衰减也不回弹',
    );

    // 全程单调递增、没有末段回弹。
    var previous = HyperosNavigation.scrimAlphaFor(0);
    for (var i = 1; i <= 20; i++) {
      final current = HyperosNavigation.scrimAlphaFor(i / 20);
      expect(current, greaterThanOrEqualTo(previous));
      previous = current;
    }    expect(HyperosNavigation.morphCornerRadiusFactor(1), 0);

    // 锚点展开（日视图从锚点长成整屏）单独一条带宽：那条转场的面板底边内缩
    // 正好是 `(1 - 进度) × 屏高`，所以带宽按屏高定 —— 850dp 屏上起收时底边
    // 还差 1.7px，与滑动转场的 1.6px 同口径。
    const expandBand = HyperosMiuixNavigation.anchorExpandCornerSettleBand;
    expect(expandBand, greaterThan(0));
    expect(expandBand, lessThanOrEqualTo(0.002), reason: '850dp 屏上 ≤1.7px');
    for (final progress in <double>[0, 0.3, 0.5, 0.8, 0.9, 0.95]) {
      expect(
        HyperosNavigation.morphCornerRadiusFactor(progress, band: expandBand),
        1,
        reason: '进度 $progress 时面板还差 ${(1 - progress) * 100}% 屏高，半径不能提前收',
      );
    }
    expect(HyperosNavigation.morphCornerRadiusFactor(1, band: expandBand), 0);
    // 带宽 0 = 只在终点收平（官方二值行为的形变版，留作对照旋钮），不炸。
    expect(HyperosNavigation.morphCornerRadiusFactor(0.5, band: 0), 1);
    expect(HyperosNavigation.morphCornerRadiusFactor(1, band: 0), 0);

    // 两条整圆角包装（`timetable_screen.dart` 的调用点各一行，所以参数烘焙在这里）：
    // 卡片形变 22dp、锚点展开 28dp，两端与中段的形状都要对。
    for (final radius in <double>[22, 28]) {
      expect(HyperosNavigation.morphRadius(0, radius).topLeft.x, radius);
      expect(HyperosNavigation.morphRadius(0.6, radius).topLeft.x, radius);
    }
    expect(HyperosNavigation.morphRadius(1, 22), BorderRadius.zero);
    expect(HyperosNavigation.anchorExpandRadius(0).topLeft.x, 28);
    expect(HyperosNavigation.anchorExpandRadius(0.9).topLeft.x, 28);
    expect(HyperosNavigation.anchorExpandRadius(1), BorderRadius.zero);
  });

  test('形变类转场：圆角只收尾、不起头（贴边后才收平）', () {
    // 行为被有意替换（2026-10-17 真机）：卡片形变与日视图锚点展开此前都**从 0 起
    // 就按进度线性收**半径（`22 × (1 - 进度)` / `28 × (1 - 进度)`）—— 进度 0.8 时
    // 只剩 4.4dp / 5.6dp，而页面/面板还差一成屏宽没贴边。用户原话：「页面还没有
    // 完全贴边，没有完全打开的时候，圆角就已经消失变成直角了，时机比其他页面早
    // 多了」。取值推导见 HyperosMiuixNavigation.morphCornerSettleBand 的注释。
    //
    // 起手是满半径：源按钮 / 种子面板本身就是一张圆角卡片，这里不能收。
    expect(HyperosNavigation.morphCornerRadiusFactor(0), 1);

    // 判别点：中段与 0.8 必须是满半径（旧实现在这两处只剩 0.5 / 0.2）。
    expect(HyperosNavigation.morphCornerRadiusFactor(0.5), 1);
    expect(HyperosNavigation.morphCornerRadiusFactor(0.8), 1);

    const band = HyperosMiuixNavigation.morphCornerSettleBand;
    expect(band, greaterThan(0), reason: '0 = 退回二值，贴边那一帧会闪');
    expect(
      band,
      lessThanOrEqualTo(0.02),
      reason: '起收时必须已经在贴边内（400dp 屏上位移残差 ≤5px）',
    );
    // 带宽起点之前一点必须还没动。
    expect(HyperosNavigation.morphCornerRadiusFactor(1 - band * 2), 1);
    // 末段连续收束（不是二值跳变）：越靠近落点越小，落点前仍非 0。
    final nearSettle = HyperosNavigation.morphCornerRadiusFactor(1 - band / 4);
    expect(nearSettle, greaterThan(0));
    expect(nearSettle, lessThan(0.5));
    expect(
      HyperosNavigation.morphCornerRadiusFactor(1 - band / 8),
      lessThan(nearSettle),
    );
    var previous = 1.0;
    for (var i = 0; i <= 4; i++) {
      final current = HyperosNavigation.morphCornerRadiusFactor(
        1 - band + band * i / 4,
      );
      expect(current, greaterThanOrEqualTo(0));
      expect(current, lessThanOrEqualTo(previous + 1e-9));
      previous = current;
    }
    // 终点精确为 0：静止态不能残留圆角缺口（页面已贴边，圆角该锁进屏幕边缘）。
    expect(previous, 0);
    expect(HyperosNavigation.morphCornerRadiusFactor(1), 0);

    // 锚点展开（日视图从锚点长成整屏）单独一条带宽：那条转场的面板底边内缩
    // 正好是 `(1 - 进度) × 屏高`，所以带宽按屏高定 —— 850dp 屏上起收时底边
    // 还差 1.7px，与滑动转场的 1.6px 同口径。
    const expandBand = HyperosMiuixNavigation.anchorExpandCornerSettleBand;
    expect(expandBand, greaterThan(0));
    expect(expandBand, lessThanOrEqualTo(0.002), reason: '850dp 屏上 ≤1.7px');
    for (final progress in <double>[0, 0.3, 0.5, 0.8, 0.9, 0.95]) {
      expect(
        HyperosNavigation.morphCornerRadiusFactor(progress, band: expandBand),
        1,
        reason: '进度 $progress 时面板还差 ${(1 - progress) * 100}% 屏高，半径不能提前收',
      );
    }
    expect(HyperosNavigation.morphCornerRadiusFactor(1, band: expandBand), 0);
    // 带宽 0 = 只在终点收平（官方二值行为的形变版，留作对照旋钮），不炸。
    expect(HyperosNavigation.morphCornerRadiusFactor(0.5, band: 0), 1);
    expect(HyperosNavigation.morphCornerRadiusFactor(1, band: 0), 0);

    // 两条整圆角包装（`timetable_screen.dart` 的调用点各一行，所以参数烘焙在这里）：
    // 卡片形变 22dp、锚点展开 28dp，两端与中段的形状都要对。
    for (final radius in <double>[22, 28]) {
      expect(HyperosNavigation.morphRadius(0, radius).topLeft.x, radius);
      expect(HyperosNavigation.morphRadius(0.6, radius).topLeft.x, radius);
    }
    expect(HyperosNavigation.morphRadius(1, 22), BorderRadius.zero);
    expect(HyperosNavigation.anchorExpandRadius(0).topLeft.x, 28);
    expect(HyperosNavigation.anchorExpandRadius(0.9).topLeft.x, 28);
    expect(HyperosNavigation.anchorExpandRadius(1), BorderRadius.zero);
  });

  test('压暗与透明度全程单调、末段不再释放（切口里必须一直有对比）', () {
    // 2026-10-18 第十三轮真机：「左上角接近边缘时一直是直角，能看到圆角转变的
    // 过程」—— 根因是末段把被覆盖页的压暗/透明度释放回原色，切口里的颜色与新页
    // 拉平，圆角在贴边前就肉眼消失。释放包络撤回，全程走官方线性。
    expect(HyperosNavigation.scrimAlphaFor(0.5), closeTo(0.25, 1e-9));
    expect(HyperosNavigation.coveredAlphaFor(0.5), closeTo(0.95, 1e-9));
    expect(HyperosNavigation.scrimAlphaFor(0), 0);
    expect(HyperosNavigation.coveredAlphaFor(0), 1);
    expect(
      HyperosNavigation.scrimAlphaFor(1),
      closeTo(HyperosMiuixNavigation.dimAmount, 1e-9),
      reason: '贴边那一刻仍有满压暗：切口里的对比不能提前消失',
    );
    expect(
      HyperosNavigation.coveredAlphaFor(1),
      closeTo(1 - HyperosMiuixNavigation.coveredAlphaFalloff, 1e-9),
      reason: '透明度衰减也不回弹',
    );

    // 全程单调递增、没有末段回弹。
    var previous = HyperosNavigation.scrimAlphaFor(0);
    for (var i = 1; i <= 20; i++) {
      final current = HyperosNavigation.scrimAlphaFor(i / 20);
      expect(current, greaterThanOrEqualTo(previous));
      previous = current;
    }
  });


  testWidgets('转场全程结构恒定：裁切 / 补底 / 压暗蒙层 / 透明度不随进度摘挂', (tester) async {
    // 2026-10-17 定案的回归（deactivate 探针之外的第二道保险，锁**层数指纹**）：
    // 这四层曾经都是二值开关（`coverValue > 0.001` 挂补底、`scrimAlpha <= 0.001`
    // 拆 Stack、`moving && radius > 0.5` 挂 ClipRRect、`alpha < 1` 挂 Opacity），
    // 每翻转一次就是一次子树 reparent = 整页重新构建 + 重新布局。现在它们必须
    // 恒在、只调参数 —— 层数在转场全程一个都不能变。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);

    const enteringKey = ValueKey('entering-page');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: HyperosColors.scaffoldBackground(context),
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (coveredContext) => Scaffold(
                    key: const ValueKey('covered-page'),
                    backgroundColor: HyperosColors.scaffoldBackground(
                      coveredContext,
                    ),
                    body: Center(
                      child: Builder(
                        builder: (inner) => ElevatedButton(
                          onPressed: () => HyperosNavigation.push(
                            inner,
                            builder: (_) => const Scaffold(
                              key: enteringKey,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          child: const Text('push2'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 先推一层并停稳，让第二层 push 时的被覆盖页是 HyperOS 路由（与上面
    // 「切口不补色」用例同口径：只有 HyperOS 路由被盖住时才有覆盖动画）。
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('push2'));
    await tester.pump();
    // 首帧门槛：push 动画在新页首帧画完前锁 0，下一帧才锚定起点。
    await tester.pump(const Duration(milliseconds: 1));

    // 被覆盖页（第一层）身上的结构指纹：ClipRRect / Opacity 恒在，
    // Stack 数恒定（压暗蒙层不靠 Stack，改用 RenderProxyBox 直画）。
    // 三种层数任何一种在转场中变化 = 子树 reparent。
    final coveredFinder = find.byKey(const ValueKey('covered-page'), skipOffstage: false);
    int clipCount() => find
        .ancestor(of: coveredFinder, matching: find.byType(ClipRRect))
        .evaluate()
        .length;
    int opacityCount() => find
        .ancestor(of: coveredFinder, matching: find.byType(Opacity))
        .evaluate()
        .length;
    // Stack 层数包含路由 / Scaffold 自己的布局 Stack：恒挂蒙层设计下它是常数；
    // 若有人退回「按 scrimAlpha 拆 Stack」的旧结构，起步帧会 +1。
    int stackCount() => find
        .ancestor(of: coveredFinder, matching: find.byType(Stack))
        .evaluate()
        .length;

    final firstClip = clipCount();
    final firstOpacity = opacityCount();
    final firstStack = stackCount();
    // 2026-10-18 第十八轮：前缘圆角已撤（用户定案按官方样式走，不再自定义），
    // 页面在转场里是完整矩形 —— 被覆盖页身上**不该有**裁切层，而且全程都是 0。
    expect(firstClip, 0, reason: '前缘不裁角：转场里不存在裁切层（用户 2026-10-18 定案）');
    // 2026-10-18 第十九轮：被覆盖页身上**不再有 `Opacity`** —— 那层每帧一次
    // 全屏离屏合成（saveLayer），性能版日志实测 avgRaster 9~13ms 就是它。
    // 淡出现在由 `_MiuixNavParallaxBleed` 用页面底色叠一层纯色实现，判据换成
    // 下面的 Stack 层数恒定。
    expect(
      firstOpacity,
      0,
      reason: '被覆盖页不做整页离屏合成（透明淡出改纯色叠层）',
    );

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 45));
      expect(
        clipCount(),
        firstClip,
        reason: 'f$i 圆角裁切层数变了 = 子树 reparent（掉帧 / 闪烁源）',
      );
      expect(
        opacityCount(),
        firstOpacity,
        reason: 'f$i 透明度层数变了 = 子树 reparent（掉帧 / 闪烁源）',
      );
      expect(
        stackCount(),
        firstStack,
        reason: 'f$i Stack 层数变了 = 压暗蒙层在按 alpha 拆装（掉帧 / 闪烁源）',
      );
    }

    await tester.pumpAndSettle();
    // 2026-10-18 定案：前缘不再裁角 —— 停稳后身上也不该有裁角层（旧行为会在
    // 停稳时把半径收成 0，那一下在重页面上就是「圆角闪现消失」）。
    expect(
      find.ancestor(of: coveredFinder, matching: find.byType(ClipRRect)),
      findsNothing,
    );
  });

  testWidgets('转场全程顶栏磨砂带参数恒定：tint 不随路由动画翻', (tester) async {
    // 2026-10-17 定案的回归：tint 曾经的判据带着 `scope.blurEnabled`，而页面壳
    // 喂给它的是 `HyperosRouteBlurGate.backdropBlurEnabled`（= 动画停稳且过了
    // settle 帧数）—— push 起步翻 false、pop 收尾后过 2 帧才翻回 true。翻的
    // 不只是颜色：tint 同时决定衬底那一层的绘制方式（磨砂色 ↔ 页面底色，整条
    // 带重新栅格化），翻的时刻正好是转场起步 / 页面刚停稳 —— 读作「标题栏闪
    // 一下」。现在判据里不许再出现路由动画状态，只看 `underHeader`。
    //
    // 场景必须是**内容已压到带下**的子页（滚动过）：未滚动的子页 `underHeader`
    // 恒为 false、tint 两边都是页面底色，那条路探不到翻转（探针实测过）。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    // widget 测试宿主（Windows）`liveBlurSupported` 恒为 false，得掰成 true，
    // 否则 `bandOverhangs` 恒 false，这条测试整条短路。
    HyperosBlurredHeader.liveBlurSupportedOverride = true;
    addTearDown(() => HyperosBlurredHeader.liveBlurSupportedOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (_) => const _BandProbePage(),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    // 滚动让内容压到带下（underHeader=true），静止 tint 必须是磨砂色。
    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();

    String fingerprint() {
      // 转场落定后 Navigator 会把被盖住的路由包进 Offstage —— 参数恒定恰恰
      // 要在「被盖住也挂着」的这段里读，所以 finder 必须不跳过 offstage。
      final shells = find
          .byType(FrostedHeaderBackground, skipOffstage: false)
          .evaluate()
          .toList();
      if (shells.isEmpty) {
        return 'no-band';
      }
      final w = shells.first.widget as FrostedHeaderBackground;
      return 'blur=${w.blurEnabled} tint=${w.tint} '
          'opaque=${w.opaqueAtRest} overhang=${w.bottomOverhang}';
    }

    final initial = fingerprint();
    expect(initial, isNot('no-band'), reason: '子页顶栏应带磨砂带外壳');

    // 盖一层普通页面，逐帧读被覆盖页的带：磨砂色必须全程不翻。
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      HyperosNavigation.route<void>(
        builder: (_) => const Scaffold(backgroundColor: Colors.white),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        fingerprint(),
        initial,
        reason: 'cover f$i 顶栏带参数变了 = 衬底绘制方式换了 = '
            '整条带重栅格化（转场中闪一下）',
      );
    }
    await tester.pumpAndSettle();

    // 弹回露出这一页，再逐帧读：pop 收尾 settle 帧也不许翻。
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        fingerprint(),
        initial,
        reason: 'pop f$i 顶栏带参数变了 = 页面刚停稳整条带重栅格化（返回闪一下）',
      );
    }
    await tester.pumpAndSettle();
    expect(fingerprint(), initial, reason: '落定后也必须与转场中一致');
  });

  test('programmatic curve reproduces the baked spring step response', () {
    const curve = HyperosMiuixNavProgrammaticCurve();
    // 端点必须精确：末值归一化后停在整 1，否则停稳后边缘会留一条缝。
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    // 官方注释口径：约 20% 时长处已走完约 48%（中段轻快、尾段很长）。
    expect(curve.transform(0.2), closeTo(0.48, 0.01));
    // 单调递增：官方说首次越过 1 落在播放窗口之外，所以整段不回弹。
    var previous = 0.0;
    for (var step = 1; step <= 20; step++) {
      final value = curve.transform(step / 20);
      expect(value, greaterThan(previous));
      previous = value;
    }
  });

  test('primary transition active only while forward or reverse', () {
    // 2026-10-17：结构恒定化之后，widget 树不再读动画状态（ClipRRect 出没），
    // 这个判据回到了它唯一的正式用户 [HyperosRouteBlurGate.isRouteTransitioning]
    // 所在的 collaborators 文件里（`hyperosIsRouteTransitioning`）。这里把
    // 「forward / reverse 之外都算停稳」的语义钉住，防止哪天有人拿动画**数值**
    // 阈值替代状态判断（阈值判据在端点附近抖动，正是当年圆角闪烁的来源）。
    bool active(AnimationStatus status) =>
        status == AnimationStatus.forward || status == AnimationStatus.reverse;

    expect(active(AnimationStatus.forward), isTrue);
    expect(active(AnimationStatus.reverse), isTrue);
    expect(active(AnimationStatus.completed), isFalse);
    expect(active(AnimationStatus.dismissed), isFalse);
  });

  test('parallax bleed covers exit slide fraction', () {
    expect(HyperosNavigation.parallaxBleedWidth(400), 500);
    expect(
      HyperosNavigation.parallaxBleedWidth(400),
      400 * (1 + HyperosMiuixNavigation.exitSlideFraction),
    );
  });


  testWidgets('快照滑入：转场中屏上是首帧快照，落定换回真页', (tester) async {
    // 2026-10-18 第十八轮：快照滑入默认关闭（用户偏好「不要固定照片」）。
    // 本条覆盖机制本身，所以临时打开、用完复位。
    HyperosMiuixNavigation.snapshotTransitionEnabled = true;
    addTearDown(() => HyperosMiuixNavigation.snapshotTransitionEnabled = false);
    // 2026-10-17「还没贴边就变直角」的治本路径：转场中重页的异步内容到位 /
    // 列表填充会把框架的页面缓存作废、逼引擎每帧重栅格化整页（50~80ms/帧），
    // 观感是「半路冻住 → 跳到位 + 圆角收平」。快照模式把这些帧挪到屏外：
    // 屏上是首帧的拷贝（RawImage），落定才显形真页。
    //
    // 本用例在 widget 层钉住三件事：
    // 1. 转场中页面本体是 Offstage（每帧不再重栅格化 —— 省钱的唯一方式），
    //    屏上可见的是 RawImage 快照；
    // 2. 内容在快照期间变化不会出现在滑动画面里（快照不跟着重画）；
    // 3. 落定后真页显形、快照释放（变化可见）。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    const enteringKey = ValueKey('snapshot-entering');
    const contentKey = ValueKey('snapshot-content');
    late StateSetter setRootState;
    var contentLabel = 'initial';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (_) => StatefulBuilder(
                    builder: (context, setState) {
                      setRootState = setState;
                      return Scaffold(
                        key: enteringKey,
                        body: Center(
                          child: Text(
                            contentLabel,
                            key: contentKey,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('push'));
    await tester.pump();
    // 首帧门槛 + 快照拍照都在帧末了结，下一帧解锁并锚定起点。
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 80));

    // 1) 转场中：页面本体必须**不画**（屏上是快照 RawImage）。
    // 判据读到闸门那层 `HyperosSnapshotPageSurface.skipPaint`：2026-10-18 第十七轮
    // 起它只跳过绘制，不再用 `Offstage`（`Offstage` 会连命中测试一起关掉，
    // 滑入到一半就摸不动页面）。
    expect(
      _pagePaintSkipped(tester, contentKey),
      isTrue,
      reason: '转场中页面本体必须不画 —— 快照叠在真页上面一分钱都省不下',
    );
    // 页面不能挂在「offstage = true」的祖先下面 —— `Offstage` 会连命中测试一起
    // 关掉，转场里就摸不动页面。框架自己的 `_ModalScope` 也有一层 `Offstage`
    // （平时是 false），所以判据取「没有任何一层是 true」。
    var hiddenByOffstage = false;
    tester
        .element(find.byKey(contentKey, skipOffstage: false))
        .visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) {
        hiddenByOffstage = true;
      }
      return true;
    });
    expect(
      hiddenByOffstage,
      isFalse,
      reason: '页面本体不能挂在 offstage 里 —— 那会连命中测试一起关掉（摸不动）',
    );
    final snapshotImage = tester.widget<RawImage>(
      find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null,
        skipOffstage: false,
      ),
    );
    expect(snapshotImage.image, isNotNull, reason: '快照层应在屏上参与滑动');

    // 照片必须是**完整的页面像素**（2026-10-18 第十八轮：前缘圆角已撤，
    // 用户定案按官方样式走、不再自定义）。本断言此前在「圆角烤进照片」与
    // 「照片不带切口」之间来回翻转过两次 —— 现在它守的是另一件事：
    // 照片不能有任何透明区域，否则滑入中会直接露出下一层，读作闪烁。
    final snapshotBytes = await tester.runAsync(
      () => snapshotImage.image!.toByteData(),
    );
    final snapshotWidth = snapshotImage.image!.width;
    final snapshotHeight = snapshotImage.image!.height;
    int snapshotAlphaAt(int x, int y) =>
        snapshotBytes!.getUint8((y * snapshotWidth + x) * 4 + 3);
    expect(
      snapshotAlphaAt(1, 1),
      255,
      reason: '照片四角必须是不透明页面像素（转场里页面是完整矩形）',
    );
    expect(
      snapshotAlphaAt(1, snapshotHeight - 1),
      255,
      reason: '左下角同理',
    );

    // 2) 快照期间内容变化：真页跟着重建，但屏幕上是照片 —— 新文本不会被画出来。
    //    2026-10-18 第十八轮：判据从「树上找不到」改成「真页不画」。真页现在仍在
    //    树上（并且可命中，转场里才摸得动），所以只能读 `skipPaint`。
    setRootState(() => contentLabel = 'updated');
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.text('updated', skipOffstage: false),
      findsOneWidget,
      reason: '真页照常重建（异步内容到位的等价物）',
    );
    expect(
      _pagePaintSkipped(tester, contentKey),
      isTrue,
      reason: '快照模式下真页不画 —— 内容变化不能出现在滑动画面里',
    );

    // 3) 预热（进度 ≥ 0.99）→ 撤快照（收束带起点）：两段式退休
    //    （2026-10-18 第二轮定案）。预热帧真页放回屏下（快照仍盖着），攒下
    //    的变化显形；撤快照是纯合成操作，之后圆角收平在已预热的活像素上
    //    连续播放 —— 顺序必须是「内容先落位 → 圆角再收平」。
    await tester.pumpAndSettle();
    expect(find.text('updated'), findsOneWidget,
        reason: '预热后真页在屏（快照盖着不可见 / 撤除后直接可见），'
            '快照期间攒下的内容变化显形');
    expect(
      find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null,
        skipOffstage: false,
      ),
      findsNothing,
      reason: '退休后快照必须释放（不留常驻图片层）',
    );
  });

  testWidgets('快照退休点：收平段仍在照片上，动画结束才换回真页', (tester) async {
    // 2026-10-18 第十八轮：快照滑入默认关闭（用户偏好「不要固定照片」）。
    // 本条覆盖机制本身，所以临时打开、用完复位。
    HyperosMiuixNavigation.snapshotTransitionEnabled = true;
    addTearDown(() => HyperosMiuixNavigation.snapshotTransitionEnabled = false);
    // 2026-10-18 真机第一轮反馈的回归：快照若撑到停稳才退休，末段 85ms 的
    // 圆角收束被烤死的满值切口顶住、停稳一帧蹦直角 —— 用户读作「圆角比别的
    // 页早收、变更快」。退休判据必须与 transitionCornerRadiusFactor 的收束带
    // 同一条（**缓动后**进度 ≥ 1 - cornerClipSettleBand）。
    //
    // 2026-10-18 真机第三轮补的教训：两条判据的进度必须是**缓动后**的。路由
    // 动画本身是时间线性的，0.99 / 0.996 落在线性轴的 495ms / 498ms；视觉上的
    // 预热点在 371ms、收束带起点在 415ms —— 差出来的 80~125ms 让照片顶着满值
    // 圆角撑过整段收平（用户：「还是能明显看到圆角闪现消失」）。所以本用例按
    // **缓动后进度**驱动：旧实现（判据读原始动画值）会在「缓动值 0.99」这一
    // 段就提前退休/或不该有快照时仍有快照，两种都会红。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    const enteringKey = ValueKey('retire-entering');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (_) => const Scaffold(
                    key: enteringKey,
                    body: Center(child: Text('retire')),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bool hasSnapshot() => find
        .byWidgetPredicate(
          (w) => w is RawImage && w.image != null,
          skipOffstage: false,
        )
        .evaluate()
        .isNotEmpty;
    /// 闸门判据用的进度：缓动后（与位移 / 圆角 / 压暗同一条曲线）。
    double easedProgress() => HyperosNavigation.transitionCurve.transform(
          ModalRoute.of(
            tester.element(find.byKey(enteringKey, skipOffstage: false)),
          )!
              .animation!
              .value,
        );

    await tester.tap(find.text('push'));
    await tester.pump();
    // 首帧门槛 + 快照拍照在帧末了结，下一帧解锁锚定。
    await tester.pump(const Duration(milliseconds: 1));

    // 逐 10ms 步进到缓动值越过 0.5（滑入中段）：此刻必须仍在快照模式，
    // 且真页仍离屏（预热点 0.99 未到）。
    while (easedProgress() < 0.5) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(hasSnapshot(), isTrue, reason: '滑入中段（收束带外）快照应在屏参与滑动');
    // 2026-10-18 第十八轮：判据从「树上找不到真页」（旧 `Offstage` 语义）改成
    // 「真页不画」—— 快照期间真页现在仍在树上（并且可命中），只是跳过绘制，
    // 否则转场里摸不到页面。
    expect(
      _pagePaintSkipped(tester, enteringKey),
      isTrue,
      reason: '中段真页必须不画（快照模式下 paint 全跳过 —— 省钱的唯一方式）',
    );

    // 预热点（缓动后 0.99 ≈ 371ms）：真页放回屏下（被快照盖住，可见树上找得到），
    // 快照仍在。
    while (easedProgress() <
        HyperosMiuixNavigation.snapshotWarmupProgress) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    // 预热在帧末回调里置位，再走一帧才生效。
    await tester.pump(const Duration(milliseconds: 2));
    expect(hasSnapshot(), isTrue, reason: '预热阶段快照仍盖在真页上面');
    expect(
      _pagePaintSkipped(tester, enteringKey),
      isFalse,
      reason: '预热点后真页必须重新开始画（建好栅格缓存，重活落在画面几乎不动的时刻）',
    );

    // 收束带（缓动后 1 - cornerClipSettleBand ≈ 415ms）：**仍在照片上**。
    // 2026-10-18 真机第十五轮：「接近屏幕边缘时圆角提前变直角」，就发生在
    // 快照退休那一帧。现在照片撑到动画结束，收平段全程是照片（由同一层裁切 +
    // 前缘轮廓共同决定形状），换层发生在落定之后。
    const band = HyperosMiuixNavigation.cornerClipSettleBand;
    while (easedProgress() < 1 - band) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    await tester.pump(const Duration(milliseconds: 2));
    expect(
      hasSnapshot(),
      isTrue,
      reason: '进入收束带后照片仍应在屏：换层必须发生在落定之后',
    );
    await tester.pumpAndSettle();
    expect(hasSnapshot(), isFalse, reason: '停稳后快照必须释放');
  });

  testWidgets('撤快照不重画页面：换层是纯合成操作', (tester) async {
    // 2026-10-18 第十八轮：快照滑入默认关闭（用户偏好「不要固定照片」）。
    // 本条覆盖机制本身，所以临时打开、用完复位。
    HyperosMiuixNavigation.snapshotTransitionEnabled = true;
    addTearDown(() => HyperosMiuixNavigation.snapshotTransitionEnabled = false);
    // 2026-10-18 真机第三轮：撤快照那一帧只翻闸门的 Offstage 布尔，Stack 会
    // 重画。若真页没有自己的栅格边界，这次重画会把整棵页面子树再 paint 一遍
    // （重页面 50~80ms），正好压在圆角收平段的起点 —— 用户读作「圆角闪现
    // 消失」。闸门里给真页挂了一层 RepaintBoundary 之后，页面在一次转场里
    // 只该被 paint 一次（首帧 / 预热帧），退休帧必须复用那张栅格。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    final paints = ValueNotifier<int>(0);
    addTearDown(paints.dispose);
    const enteringKey = ValueKey('paint-entering');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (_) => Scaffold(
                    key: enteringKey,
                    body: Center(
                      child: _PaintCountingBox(
                        counter: paints,
                        child: const SizedBox(width: 120, height: 120),
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double easedProgress() => HyperosNavigation.transitionCurve.transform(
          ModalRoute.of(
            tester.element(find.byKey(enteringKey, skipOffstage: false)),
          )!
              .animation!
              .value,
        );

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    // 走到预热点之后：真页回到屏下画一帧（若快照期间有内容变化，重活落在
    // 这里 —— 画面几乎不动、且被快照盖住）。
    while (easedProgress() <
        HyperosMiuixNavigation.snapshotWarmupProgress) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    await tester.pump(const Duration(milliseconds: 2));
    final paintsBeforeRetire = paints.value;

    // 走完收束带 + 停稳：退休帧不许再 paint 页面。
    await tester.pumpAndSettle();
    expect(
      paints.value,
      paintsBeforeRetire,
      reason: '撤快照必须是纯合成操作 —— 退休帧重画一次页面，重页面上就是'
          '50~80ms 的卡顿正好压在圆角收平里（用户读作「圆角闪现消失」）',
    );
    expect(paintsBeforeRetire, greaterThan(0), reason: '页面至少应被画过一次');
  });

  testWidgets('豁免页：snapshotTransition=false 的路由全程真页参与滑动', (tester) async {
    // 2026-10-18 第十八轮：快照滑入默认关闭（用户偏好「不要固定照片」）。
    // 本条覆盖机制本身，所以临时打开、用完复位。
    HyperosMiuixNavigation.snapshotTransitionEnabled = true;
    addTearDown(() => HyperosMiuixNavigation.snapshotTransitionEnabled = false);
    // WebView 等平台视图页拍不进快照（拍出来是黑块），推入点显式豁免。
    // 豁免页不得出现快照层，页面本体全程在屏。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    const enteringKey = ValueKey('exempt-entering');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  HyperosPageRoute<void>(
                    snapshotTransition: false,
                    builder: (_) => const Scaffold(
                      key: enteringKey,
                      body: Center(child: Text('exempt')),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null,
        skipOffstage: false,
      ),
      findsNothing,
      reason: '豁免页不得拍快照',
    );
    expect(
      find.byKey(enteringKey),
      findsOneWidget,
      reason: '豁免页页面本体全程在屏（可交互内容照常绘制）',
    );
    await tester.pumpAndSettle();
  });


  testWidgets('转场中页面能摸：滑入一半按下就落在真页上，快照立刻退休', (tester) async {
    // 2026-10-18 第十八轮：快照滑入默认关闭（用户偏好「不要固定照片」）。
    // 本条覆盖机制本身，所以临时打开、用完复位。
    HyperosMiuixNavigation.snapshotTransitionEnabled = true;
    addTearDown(() => HyperosMiuixNavigation.snapshotTransitionEnabled = false);
    // 2026-10-18 第十七轮真机反馈：「进入一半的时候我就滑动页面，但是现在
    // 滑不动了」。原因是快照模式用 `Offstage` 藏真页 —— 它连命中测试一起关掉，
    // 手指落在照片上、事件到不了真页的滚动视图。
    //
    // 现在只跳过绘制（`_SnapshotPageSurface`）：摸到的就是照片显示的那个页面；
    // 按下第一帧快照退休换成活像素，滚动立刻跟手。这条用例钉住两件事：
    // 按下有效、按下后快照已退休。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    var presses = 0;
    const buttonKey = ValueKey('interactive-button');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: HyperosNavigation.pageTransitionsTheme,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => HyperosNavigation.push(
                  context,
                  builder: (_) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: buttonKey,
                        onPressed: () => presses++,
                        child: const Text('tap me'),
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    // 等页面真正进屏（首帧门槛 + 前重曲线）：按钮跑到屏内才谈得上「摸着」。
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (var i = 0; i < 10; i++) {
      final center = tester.getCenter(
        find.byKey(buttonKey, skipOffstage: false),
      );
      if (center.dx < logicalWidth * 0.7) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 40));
    }

    final snapshotFinder = find.byWidgetPredicate(
      (w) => w is RawImage && w.image != null,
      skipOffstage: false,
    );
    expect(snapshotFinder, findsOneWidget, reason: '前提：滑入中段应当在快照模式');

    await tester.tap(find.byKey(buttonKey), warnIfMissed: false);
    await tester.pump();
    expect(
      presses,
      1,
      reason: '滑入到一半按下必须作用到真页 —— 否则整段转场「摸不动」',
    );
    expect(
      snapshotFinder,
      findsNothing,
      reason: '按下第一帧快照就退休（换回活像素），滚动才会跟手',
    );
    await tester.pumpAndSettle();
  });
}

/// 页面本体当前是否「只跳过绘制」（快照模式）。判据读闸门那层
/// [HyperosSnapshotPageSurface] 的 `skipPaint` —— 2026-10-18 第十八轮起不再用
/// `Offstage`（它会连命中测试一起关掉，转场里就摸不动页面）。
bool _pagePaintSkipped(WidgetTester tester, Key key) {
  var skipped = false;
  tester.element(find.byKey(key, skipOffstage: false)).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is HyperosSnapshotPageSurface) {
      skipped = widget.skipPaint;
      return false;
    }
    return true;
  });
  return skipped;
}

/// 顶栏带探针：走与设置子页同一套外壳（折叠大标题 + 磨砂带 + 路由模糊门），
/// 而不是手工拼 scope —— 要钉住的正是「门在转场里翻、带不跟着翻」这条链。
class _BandProbePage extends StatelessWidget {  const _BandProbePage();

  @override
  Widget build(BuildContext context) {
    return HyperosSubpage(
      title: const Text('设置'),
      onBack: () => Navigator.pop(context),
      child: HyperosListView(
        itemCount: 30,
        itemBuilder: (context, index) => HyperosListTile(
          icon: Icons.settings_outlined,
          title: '行 $index',
        ),
      ),
    );
  }
}

/// 画一次计一次数的探针（`_PaintCountingBox` 的渲染对象）。
///
/// 用途：钉住「撤快照不重画页面」—— 闸门撤照片那一帧若没有页面自己的栅格
/// 边界，`Stack` 重画会把整棵页面子树再 paint 一遍，重页面上正好卡在圆角
/// 收平段（2026-10-18 真机第三轮）。
class _PaintCountingBox extends SingleChildRenderObjectWidget {
  const _PaintCountingBox({required this.counter, super.child});

  final ValueNotifier<int> counter;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintCountingBoxRender(counter);
}

class _PaintCountingBoxRender extends RenderProxyBox {
  _PaintCountingBoxRender(this.counter);

  final ValueNotifier<int> counter;

  @override
  void paint(PaintingContext context, Offset offset) {
    counter.value++;
    super.paint(context, offset);
  }
}
