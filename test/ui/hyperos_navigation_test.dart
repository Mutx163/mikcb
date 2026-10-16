import 'dart:math' as math;

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
    // 末段连续收束（不是二值跳变）。
    final nearSettle = HyperosNavigation.transitionCornerRadiusFactor(0.99);
    expect(nearSettle, greaterThan(0));
    expect(nearSettle, lessThan(0.5));
    expect(
      HyperosNavigation.transitionCornerRadiusFactor(0.985),
      lessThan(HyperosNavigation.transitionCornerRadiusFactor(0.98)),
    );
  });

  test('corner notch fill sits on the entering page leading corners', () {
    // 补色开着；颜色是页面底色本身（见 `testWidgets` 那条）。
    expect(HyperosMiuixNavigation.fillCornerNotchWhileMoving, isTrue);

    const radius = 28.0;
    const width = 400.0;
    // LTR：角方块贴页面左缘（= 它的位移）。
    expect(
      HyperosNavigation.cornerNotchLeft(
        leadingSlidePx: 120,
        width: width,
        radius: radius,
        isRtl: false,
      ),
      120,
    );
    // RTL：贴页面右缘。
    expect(
      HyperosNavigation.cornerNotchLeft(
        leadingSlidePx: -120,
        width: width,
        radius: radius,
        isRtl: true,
      ),
      -120 + width - radius,
    );
    // 停稳（位移 0）时角方块落在屏幕边缘，且此刻裁切已被收掉。
    expect(
      HyperosNavigation.cornerNotchLeft(
        leadingSlidePx: 0,
        width: width,
        radius: radius,
        isRtl: false,
      ),
      0,
    );
    expect(HyperosNavigation.transitionCornerRadiusFactor(1), 0);
  });

  testWidgets('切口补的是页面底色（不是深色角阴影），位置贴着上层页面左缘', (
    tester,
  ) async {
    // 上面几条用例把用户倍速改成了 0.5，这里掰回 1 倍速，时长才可预期。
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    // 被覆盖页得**也是** HyperOS 路由：Flutter 只在被覆盖路由是
    // `MaterialRouteTransitionMixin` 时才把上层路由的动画接到它的
    // secondaryAnimation 上（`canTransitionTo`），而 `HyperosPageRoute` 是裸
    // `PageRoute`。所以「首页 / MaterialPageRoute 被盖住」这条路根本不产生覆盖
    // 动画，切口补色也不会出现；真机上出现切口的是**子页盖子子页**（用户报的就是
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

    final context = tester.element(find.byType(Scaffold).first);
    final radius = HyperosMotionPlatform.displayCornerRadiusDp;
    // 补色 = **页面底色本身**（画在压暗遮罩之下，由遮罩统一压暗），不是深色角阴影：
    // 真机第一版补的是「底色压暗 0.6」的定值，读成了「黑色的方角 + 圆角反复消失」。
    final patchColor = HyperosColors.scaffoldBackground(context);
    expect(patchColor.a, 1, reason: '补色必须不透明，否则挡不住被覆盖页的内容');

    // 页面底色这个颜色不止补色在用（视差补底那条也是同色、但铺满整页），所以
    // 按**角方块的尺寸**把它们挑出来，而不是只按颜色。
    List<Rect> notchRects() {
      final rects = <Rect>[];
      final candidates = find
          .byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == patchColor,
          )
          .evaluate();
      for (final element in candidates) {
        final rect = tester.getRect(
          find.byElementPredicate((candidate) => candidate == element),
        );
        if ((rect.width - radius).abs() < 0.01 &&
            (rect.height - radius).abs() < 0.01) {
          rects.add(rect);
        }
      }
      return rects;
    }

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;

    // 沿行程取三个点（含中段与末段），每点都要：补色各两块、贴着**上层页面实测
    // 左缘**（不是只跟公式对）、边长 = 设备屏幕圆角、一上一下贴屏幕边缘。
    for (final fraction in [0.25, 0.5, 0.75]) {
      await tester.pump(const Duration(milliseconds: 125));
      final rects = notchRects();
      expect(rects, hasLength(2), reason: '前缘左上、左下各补一块');
      final enteringLeft = tester.getRect(find.byKey(enteringKey)).left;
      // 上层页面此刻应该还在屏内（否则下面几条断言没意义）。
      expect(enteringLeft, greaterThan(0));
      expect(enteringLeft, lessThan(size.width));
      for (final rect in rects) {
        expect(
          rect.left,
          closeTo(enteringLeft, 0.01),
          reason: 't=$fraction：补色要跟上层页面左缘重合，不能自己漂',
        );
      }
      expect(rects.map((rect) => rect.top).reduce(math.min), 0);
      expect(
        rects.map((rect) => rect.bottom).reduce(math.max),
        closeTo(size.height, 0.01),
      );
    }
    expect(
      tester.getRect(find.byKey(enteringKey)).left,
      lessThan(size.width * 0.5),
      reason: '末段取样点应该已经滑过大半屏',
    );

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
