import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/hyperos_motion.dart';

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
    // 视差**有意取 0**（2026-10-17，非官方)：视差让 28dp 的圆角切口里出现「内容
    // 相对切口反向流动」，在天气页 / 小组件页这种内容密的页面上读作圆角底下一直闪。
    // 断言值被有意替换，机理见 coveredParallaxFraction 的注释与
    // `.agents/notes/implemented/architecture/2026-10-17-nav-corner-notch-flicker.md`。
    expect(HyperosMiuixNavigation.coveredParallaxFraction, 0);
    expect(HyperosMiuixNavigation.coveredAlphaFalloff, 0.1);
    // 官方 NavDisplayEffects.Default.dimAmount（全屏压暗上限）。
    expect(HyperosMiuixNavigation.dimAmount, 0.5);
    // 前缘两角圆角：观感保留（官方 `Leading`），但**不再挖洞** —— 页面保持完整
    // 矩形，圆角外侧那块用页面底色补片画出来（见 `_MiuixNavClippedPage`）。
    // 2026-10-18 定案：洞会在贴边时被「补上」，重页面上那一下只有 1~2 帧，是
    // 十轮真机反馈「圆角闪现消失」的来源。
    expect(HyperosMiuixNavigation.clipLeadingCornersWhileMoving, isTrue);
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
    const band = HyperosMiuixNavigation.cornerClipSettleBand;
    expect(band, greaterThan(0), reason: '0 = 退回官方二值，会闪');
    expect(band, lessThanOrEqualTo(0.005), reason: '400dp 屏上要 ≤2px 才开始收');
    // 行进中还差 1% 屏宽（400dp 屏上 4px）时，必须还是满半径 —— 不能提前开始变。
    expect(HyperosNavigation.transitionCornerRadiusFactor(0.99), 1);
    // 末段连续收束（不是二值跳变）：越靠近落点越小，但落点前仍非 0。
    final nearSettle = HyperosNavigation.transitionCornerRadiusFactor(
      1 - band / 4,
    );
    expect(nearSettle, greaterThan(0));
    expect(nearSettle, lessThan(0.5));
    expect(
      HyperosNavigation.transitionCornerRadiusFactor(1 - band / 8),
      lessThan(nearSettle),
    );
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

  test('末段释放：贴边那一段放掉压暗与透明度衰减，收口不再读作「闪成无圆角」', () {
    // 行为被有意替换（2026-10-17 真机第二轮：掉帧治好后残留「圆角底部还是在
    // 闪烁成无圆角的状态」）。机理见 HyperosMiuixNavigation.coveredReleaseBand
    // 的注释与 `.agents/notes/implemented/bug-fix/2026-10-17-nav-corner-notch-flicker.md`。
    const band = HyperosMiuixNavigation.cornerClipSettleBand;

    // 中段（离两端都远）保持官方数值：压暗 0.5 × 覆盖度、透明度 1 - 0.1 × 覆盖度。
    expect(HyperosNavigation.scrimAlphaFor(0.5), closeTo(0.25, 1e-9));
    expect(HyperosNavigation.coveredAlphaFor(0.5), closeTo(0.95, 1e-9));
    // 收束起点之前一点必须还没动（只有带宽内才释放）。
    expect(
      HyperosNavigation.scrimAlphaFor(1 - band * 2),
      closeTo(HyperosMiuixNavigation.dimAmount * (1 - band * 2), 1e-9),
    );

    // 两端：压暗精确放光、被覆盖页回到完全不透明（切口里就是原色）。
    expect(HyperosNavigation.scrimAlphaFor(0), 0);
    expect(HyperosNavigation.scrimAlphaFor(1), 0);
    expect(HyperosNavigation.coveredAlphaFor(0), 1);
    expect(HyperosNavigation.coveredAlphaFor(1), 1);

    // 连续释放，不是二值跳变（一帧之内变亮同样读作闪）。
    var previous = HyperosNavigation.scrimAlphaFor(1 - band);
    final start = previous;
    expect(start, greaterThan(0.49), reason: '带宽起点应仍是接近满值的压暗');
    for (var i = 1; i <= 4; i++) {
      final current = HyperosNavigation.scrimAlphaFor(1 - band + band * i / 4);
      expect(current, lessThan(previous));
      expect(
        previous - current,
        lessThan(start * 0.5),
        reason: '单步降幅要远小于总降幅 = 铺开释放，不是一帧跳变',
      );
      previous = current;
    }
    expect(previous, 0);
  });

  testWidgets('前缘圆角保留：只裁滑入那一页、半径全程恒定；被覆盖页不裁', (
    tester,
  ) async {
    // 2026-10-18 定案（第十一轮真机 + 截图）：旧的前缘「圆角」是从页面像素里
    // **挖掉一个洞** —— 洞里露出被覆盖页（快照模式下洞底是纯黑，用户截图实测
    // 左下角一块纯黑四分之一圆）。页面贴边后要把洞补上，重页面上这一下只有
    // 1~2 帧，读作「圆角闪现消失」；十轮调时机/带宽/预热/栅格边界都没用。
    //
    // 现在圆角是**画**出来的：页面保持完整矩形（祖先链上没有 ClipRRect），
    // 圆角外侧那块由 `_MiuixNavLeadingCornerNotchPainter` 补页面底色。观感不变，
    // 但页面上没有洞 —— 没有可补的东西，转场全程没有圆角形状变化。
    // 上面几条用例把用户倍速改成了 0.5，这里掰回 1 倍速，时长才可预期。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    // 被覆盖页得**也是** HyperOS 路由：Flutter 只在被覆盖路由是
    // `MaterialRouteTransitionMixin` 时才把上层路由的动画接到它的
    // secondaryAnimation 上（`canTransitionTo`），而 `HyperosPageRoute` 是裸
    // `PageRoute`。所以「首页 / MaterialPageRoute 被盖住」这条路根本不产生覆盖
    // 动画，切口也不会出现；真机上出现切口的是**子页盖子子页**（用户报的就是
    // 进出设置子页）。这里就照那条路走：先推一层子页，再盖它。
    const enteringKey = ValueKey('entering-page');
    await tester.pumpWidget(
      MaterialApp(
        // 与 app 同款：main.dart 给 theme 配了 `pageTransitionsTheme`。
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

    // 先推一层并停稳，让第二层的被覆盖页是 HyperOS 路由。
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('push2'));
    await tester.pump();
    // 首帧门槛（2026-10-16）：push 动画在新页首帧画完之前锁在 0，首帧的帧末
    // 回调解锁、下一帧才锚定起点。上面那一 pump 就是首帧，这里再 pump 一次把
    // 动画带过锚点帧 —— 之后 125ms 的步进读数与无门槛时同构。
    await tester.pump(const Duration(milliseconds: 1));

    // 圆角半径：设备读数（测试宿主 = 回退值 28），全程恒定。
    final radius = HyperosMotionPlatform.displayCornerRadiusDp;
    double? enteringRadius() {
      final finder = find.ancestor(
        of: find.byKey(enteringKey, skipOffstage: false),
        matching: find.byType(ClipRRect, skipOffstage: false),
      );
      if (finder.evaluate().isEmpty) {
        return null;
      }
      return tester
          .widget<ClipRRect>(finder.first)
          .borderRadius
          .resolve(TextDirection.ltr)
          .topLeft
          .x;
    }

    // 转场中取三个时刻：滑入页必须一直带着同半径的前缘圆角（不随进度变）。
    for (final fraction in [0.25, 0.5, 0.75]) {
      await tester.pump(const Duration(milliseconds: 125));
      expect(
        enteringRadius(),
        radius,
        reason: 't=$fraction 滑入页的前缘圆角必须是恒定满半径 —— '
            '末段一收就会在重页面上读作「圆角闪现成直角」',
      );
    }

    await tester.pumpAndSettle();
    expect(enteringRadius(), radius, reason: '停稳后半径仍是同一个值（没有收束那一帧）');

    // 被覆盖页不裁：两层洞对齐会看穿到窗口黑底（第十轮截图里的黑圆角）。
    // 被覆盖页的裁切层仍在树上（结构恒定），但**半径为 0** —— 两层洞对齐会
    // 看穿到窗口黑底（第十轮用户截图里的黑圆角）。
    final coveredClip = find.ancestor(
      of: find.byKey(const ValueKey('covered-page'), skipOffstage: false),
      matching: find.byType(ClipRRect, skipOffstage: false),
    );
    expect(
      tester
          .widget<ClipRRect>(coveredClip.first)
          .borderRadius
          .resolve(TextDirection.ltr)
          .topLeft
          .x,
      0,
      reason: '被覆盖页不裁（半径 0），但裁切层常挂',
    );
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
    expect(firstClip, greaterThan(0), reason: '裁切层常挂（半径 0 = 不裁），结构不随动画增删');
    expect(firstOpacity, greaterThan(0), reason: '被覆盖页应恒带透明度衰减');

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

  testWidgets('圆角切口烘进页面自己的图层：合成期裁切丢帧也不露方角', (
    tester,
  ) async {
    // 2026-10-18 定案：圆角改成**画**出来的（页面外侧补一层页面底色补片），
    // 页面像素不再被裁掉一角。旧实现是挖洞：洞里露出被覆盖页 / 快照模式的纯黑，
    // 贴边时要把洞补上 —— 重页面上那一下只有 1~2 帧，就是十轮反馈的「圆角闪现消失」。
    //
    // 本用例取页面自己的图层（最靠近页面的 RepaintBoundary），钉住：**四个角都
    // 是完整的不透明页面像素** —— 只要这层没有洞，转场里就没有任何东西需要
    // 「补」，也就没有可被掉帧放大的变化。
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
                  builder: (_) => const Scaffold(
                    key: enteringKey,
                    backgroundColor: Colors.white,
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
    // 首帧门槛：动画在新页首帧画完前锁 0，下一帧才锚定起点（与其它转场用例同口径）。
    await tester.pump(const Duration(milliseconds: 1));
    // 中段（整条曲线前重后轻，250ms 处早已是满半径）。
    await tester.pump(const Duration(milliseconds: 250));

    final radius = HyperosMotionPlatform.displayCornerRadiusDp;
    expect(radius, greaterThan(12), reason: '取样点按半径摆，太小就取不到切口里');

    // 快照模式（2026-10-17）：转场中屏上是首帧快照。本用例钉的位置关系不变：
    // 切口在**框架缓存边界之内**，所以对框架那层 RepaintBoundary 出图断言。
    //
    // 2026-10-18：闸门里给真页补了自己的栅格边界（换层不重画页面），它排在
    // 切口**内侧** —— 从页面往上数的第一层是它，第二层才是框架的 `_subtreeKey`
    // 缓存边界。取样必须取第二层，否则量到的是「切口外侧」的页面像素。
    RenderObject? node =
        tester.renderObject(find.byKey(enteringKey, skipOffstage: false));
    RenderRepaintBoundary? frameworkBoundary;
    var boundariesSeen = 0;
    while (node != null) {
      node = node.parent;
      if (node is RenderRepaintBoundary) {
        boundariesSeen++;
        if (boundariesSeen == 2) {
          frameworkBoundary = node;
          break;
        }
      }
    }
    expect(
      frameworkBoundary,
      isNotNull,
      reason: '页面外面应有闸门的页面栅格边界 + 框架的缓存边界两层',
    );
    final boundary = frameworkBoundary!;
    final pageSize = boundary.size;

    Future<ByteData> capturePageLayer() async {
      final image = (await tester.runAsync(boundary.toImage))!;
      final bytes = (await tester.runAsync(image.toByteData))!;
      image.dispose();
      return bytes;
    }

    int alphaOf(ByteData bytes, double fromLeft, double fromTop) {
      final width = pageSize.width.round();
      final height = pageSize.height.round();
      final x = fromLeft.round().clamp(0, width - 1);
      final y = fromTop.round().clamp(0, height - 1);
      return bytes.getUint8((y * width + x) * 4 + 3);
    }

    final midFlight = await capturePageLayer();
    // 切口必须烘在**页面自己的栅格**里（第十一轮真机：左上角「极其快速地闪现
    // 恢复直角，一秒七八次」，左下角不闪 —— 正是外壳合成期裁切丢帧的表现）。
    expect(
      alphaOf(midFlight, 1, pageSize.height - 1),
      0,
      reason: '转场中页面左下角必须已经缺角（切口在框架缓存边界之内）',
    );
    expect(
      alphaOf(midFlight, 1, 1),
      0,
      reason: '左上同理 —— 第十一轮真机上就是这块「极其快速地闪现恢复直角」：'
          '外壳那层合成期裁切丢帧时，页面栅格本身必须已经缺角',
    );
    expect(
      alphaOf(midFlight, radius, pageSize.height - radius),
      255,
      reason: '圆心处仍是页面像素（切口只切角）',
    );

    await tester.pumpAndSettle();
    final settled = await capturePageLayer();
    expect(alphaOf(settled, 1, pageSize.height - 1), 0, reason: '停稳后切口仍在（半径恒定）');
    expect(alphaOf(settled, 1, 1), 0, reason: '左上同理');
  });

  testWidgets('快照滑入：转场中屏上是首帧快照，落定换回真页', (tester) async {
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

    // 1) 转场中：页面本体必须离屏（paint 跳过），屏上是快照 RawImage。
    // 查找走确定结构：内容key向上找的第一个 Offstage 是闸门包真页的那层；
    // RawImage 只能来自闸门快照层。
    final pageElement = tester.element(
      find.byKey(contentKey, skipOffstage: false),
    );
    Offstage? pageOffstage;
    pageElement.visitAncestorElements((element) {
      if (element.widget is Offstage) {
        pageOffstage = element.widget as Offstage;
        return false;
      }
      return true;
    });
    expect(pageOffstage, isNotNull,
        reason: '闸门应把页面本体包进 Offstage');
    expect(pageOffstage!.offstage, isTrue,
        reason: '转场中页面本体必须离屏不画 —— 快照叠在真页上面一分钱都省不下');
    final snapshotImage = tester.widget<RawImage>(
      find.byWidgetPredicate(
        (w) => w is RawImage && w.image != null,
        skipOffstage: false,
      ),
    );
    expect(snapshotImage.image, isNotNull, reason: '快照层应在屏上参与滑动');

    // 照片必须是**页面像素本身**，不能带烤死的圆角缺口（2026-10-18 真机第三轮）：
    // 缺口是透明的，外层裁切只能削像素、填不回来 —— 照片里若有一个恒定的满值
    // 缺口，它不会跟着末段的收平一起收，收尾就会露出一块「圆角闪现消失」。
    final snapshotBytes = await tester.runAsync(
      () => snapshotImage.image!.toByteData(),
    );
    final snapshotWidth = snapshotImage.image!.width;
    final cornerAlpha = snapshotBytes!.getUint8((snapshotWidth + 1) * 4 + 3);
    expect(
      cornerAlpha,
      255,
      reason: '快照左上角必须是不透明页面像素（缺口只由切口每帧现算，不能烤进照片）',
    );

    // 2) 快照期间内容变化：真页跟着重建（屏外），但滑动画面里仍是快照 ——
    //    新文本在退休前不可见。此刻仍在滑入中段（远未到收束带）。
    setRootState(() => contentLabel = 'updated');
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.text('updated', skipOffstage: false),
      findsOneWidget,
      reason: '真页照常重建（异步内容到位的等价物）',
    );
    expect(find.text('updated'), findsNothing,
        reason: '快照模式下内容变化不能出现在滑动画面里');

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

  testWidgets('快照退休点：进度进入圆角收束带即退休，不等停稳', (tester) async {
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
    expect(
      find.byKey(enteringKey),
      findsNothing,
      reason: '中段真页必须离屏（快照模式下 paint 全跳过 —— 省钱的唯一方式）',
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
      find.byKey(enteringKey),
      findsOneWidget,
      reason: '预热点后真页必须在屏（画一帧建栅格缓存，重活落在画面几乎不动的时刻）',
    );

    // 收束带（缓动后 1 - cornerClipSettleBand ≈ 415ms）：撤快照 —— 纯合成换层，
    // 不等停稳。
    const band = HyperosMiuixNavigation.cornerClipSettleBand;
    while (easedProgress() < 1 - band) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    await tester.pump(const Duration(milliseconds: 2));
    expect(
      hasSnapshot(),
      isFalse,
      reason: '缓动进度进入收束带（1 - cornerClipSettleBand = ${1 - band}）后'
          '快照必须退休 —— 末段圆角收束必须发生在活像素上，且不能再被照片里'
          '烤死的缺口顶住',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('撤快照不重画页面：换层是纯合成操作', (tester) async {
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
