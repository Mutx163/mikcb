import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_motion.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';

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
    expect(HyperosMiuixNavigation.coveredParallaxFraction, 0.25);
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
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.forward),
      isTrue,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.reverse),
      isTrue,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.completed),
      isFalse,
    );
    expect(
      HyperosNavigation.isPrimaryTransitionActive(AnimationStatus.dismissed),
      isFalse,
    );
  });

  test('parallax bleed covers exit slide fraction', () {
    expect(HyperosNavigation.parallaxBleedWidth(400), 500);
    expect(
      HyperosNavigation.parallaxBleedWidth(400),
      400 * (1 + HyperosMiuixNavigation.exitSlideFraction),
    );
  });
}
