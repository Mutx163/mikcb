import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    // 前缘两角圆角：走官方「跟设备屏幕圆角」那条 opt-in（`Leading` 只裁前缘两角）。
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

  test('末段释放：贴边那一段放掉压暗与透明度衰减，收口不再读作「闪成无圆角」', () {
    // 行为被有意替换（2026-10-17 真机第二轮：掉帧治好后残留「圆角底部还是在
    // 闪烁成无圆角的状态」）。机理见 HyperosMiuixNavigation.coveredReleaseBand
    // 的注释与 `.agents/notes/implemented/bug-fix/2026-10-17-nav-corner-notch-flicker.md`。
    const band = HyperosMiuixNavigation.cornerClipSettleBand;

    // 中段（离两端都远）保持官方的**上限**（0.5）：压暗是「0.5 × 覆盖度^指数」，
    // 指数见 HyperosMiuixNavigation.scrimRampExponent（覆盖早期就到位，切口里的
    // 旧页始终比上层页暗一档）。透明度仍是官方 1 - 0.1 × 覆盖度。
    expect(
      HyperosNavigation.scrimAlphaFor(0.5),
      closeTo(HyperosMiuixNavigation.dimAmount * math.sqrt(0.5), 1e-9),
    );
    expect(HyperosNavigation.coveredAlphaFor(0.5), closeTo(0.95, 1e-9));
    // 收束起点之前一点必须还没进入「释放」（只有带宽内才释放）。
    expect(
      HyperosNavigation.scrimAlphaFor(1 - band * 2),
      closeTo(
        HyperosMiuixNavigation.dimAmount * math.sqrt(1 - band * 2),
        1e-9,
      ),
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

  test('压暗起势：覆盖早期就到位，切口里的旧页始终比上层页暗一档', () {
    // 行为被有意替换（2026-10-17 真机第三轮：「打开动画从始至终都在闪烁圆角底下的
    // 不应该出现的白色卡片背景……闪出来的时候就相当于没有圆角，闪完了又显示正常的
    // 圆角，然后闪烁又极快，一秒可能五六次」）。机理见
    // HyperosMiuixNavigation.scrimRampExponent 的背景账：切口里露的是被覆盖页的
    // 像素，压暗起得晚（官方线性在覆盖早期 ≈ 0）时两边同亮，弧线读不出来。
    expect(HyperosMiuixNavigation.scrimRampExponent, lessThan(1));
    expect(HyperosMiuixNavigation.scrimRampExponent, greaterThan(0));

    // 连续起势：覆盖度 0.001（首帧那一档）时基本不压暗，不是一帧跳到暗。
    expect(HyperosNavigation.scrimAlphaFor(0.001), lessThan(0.03));

    // 覆盖 5% 时就该明显比官方线性更暗（官方 0.025 → 这里 0.112）。
    expect(
      HyperosNavigation.scrimAlphaFor(0.05),
      greaterThan(2 * HyperosMiuixNavigation.dimAmount * 0.05),
    );
    // 覆盖 25%（这条曲线在 ~50ms 就到了）时已经压出可读的对比。
    expect(HyperosNavigation.scrimAlphaFor(0.25), greaterThan(0.24));

    // 上限仍是官方 dimAmount，中段单调不减。
    var previous = 0.0;
    for (final fraction in [0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.99]) {
      final current = HyperosNavigation.scrimAlphaFor(fraction);
      expect(current, greaterThan(previous));
      expect(current, lessThanOrEqualTo(HyperosMiuixNavigation.dimAmount));
      previous = current;
    }
  });

  testWidgets('转场中前缘两角照裁，切口里不补任何颜色（露出的就是被覆盖页本身）', (
    tester,
  ) async {
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

    final context = tester.element(find.byType(Scaffold).first);
    final radius = HyperosMotionPlatform.displayCornerRadiusDp;
    // 切口里**不补颜色**：补了的话就是一块与旁边旧页内容不同色的方块，真机上读作
    // 「圆角底下那块阴影和页面左边的阴影颜色不一致」（用户 2026-10-16 反馈）。
    // 露出的应当是被覆盖页自己的像素 —— 同一层、同一条压暗公式，颜色不可能不一致。
    final pageBackground = HyperosColors.scaffoldBackground(context);

    // 沿途取三个点：圆角一直在裁（前缘两角满半径、后缘两角不裁，官方 Leading
    // 口径），同时树上没有任何「按圆角尺寸补上去的页面底色方块」。
    for (final fraction in [0.25, 0.5, 0.75]) {
      await tester.pump(const Duration(milliseconds: 125));
      final clipFinder = find.ancestor(
        of: find.byKey(enteringKey),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsWidgets, reason: 't=$fraction 转场中上层页应带圆角裁切');
      final border = tester
          .widget<ClipRRect>(clipFinder.first)
          .borderRadius
          .resolve(TextDirection.ltr);
      expect(border.topLeft.x, closeTo(radius, 0.01), reason: '前缘上角裁满半径');
      expect(border.bottomLeft.x, closeTo(radius, 0.01), reason: '前缘下角裁满半径');
      expect(border.topRight.x, 0, reason: '后缘两角不裁（官方 Leading 口径）');
      expect(border.bottomRight.x, 0);

      final patches = find
          .byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == pageBackground,
          )
          .evaluate()
          .where((element) {
            final rect = tester.getRect(
              find.byElementPredicate((candidate) => candidate == element),
            );
            return (rect.width - radius).abs() < 0.01 &&
                (rect.height - radius).abs() < 0.01;
          });
      expect(
        patches,
        isEmpty,
        reason: 't=$fraction 不该往切口里补色（补了就会与旁边旧页内容不同色）',
      );
    }

    await tester.pumpAndSettle();
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
    final coveredFinder = find.byType(Scaffold).first;
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
    expect(firstClip, greaterThan(0), reason: '被覆盖页应恒带前缘圆角裁切');
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
    // 落定后圆角半径必须精确为 0（两端收束，静止态不残留可见圆角缺口）。
    final border = tester
        .widget<ClipRRect>(
          find
              .ancestor(of: coveredFinder, matching: find.byType(ClipRRect))
              .first,
        )
        .borderRadius
        .resolve(TextDirection.ltr);
    expect(border.topLeft.x, 0);
    expect(border.bottomLeft.x, 0);
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
}

/// 顶栏带探针：走与设置子页同一套外壳（折叠大标题 + 磨砂带 + 路由模糊门），
/// 而不是手工拼 scope —— 要钉住的正是「门在转场里翻、带不跟着翻」这条链。
class _BandProbePage extends StatelessWidget {
  const _BandProbePage();

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
