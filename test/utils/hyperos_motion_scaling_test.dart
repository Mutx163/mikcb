// 「动画时长必须跟随页面转场速度」的单元测试。
//
// 覆盖三件事（2026-10-20 用户口径：设置要覆盖全软件所有动画）：
//  1. `int.scaledMs` 与 `HyperosMotionPlatform.scaledDuration` 同源同值；
//  2. 速度变更后**长命控制器**（登记过的）时长跟着变；
//  3. 控制器 dispose 后登记被摘掉（不泄漏）。

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/android_animation_scale_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_motion.dart';

void main() {
  // `controller.forward()` 要走 SchedulerBinding，必须先初始化 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  // 用户速度是全局静态，跨用例污染（同 hyperos_navigation_test 的教训）。
  tearDown(() {
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    HyperosMotionPlatform.debugClearBoundControllers();
  });

  setUp(() {
    // 桥接是 app 启动时接的；测试里手动接成同一个实现。
    HyperosMotionPlatform.durationScaler =
        AndroidAnimationScaleService.scaledDuration;
    AndroidAnimationScaleService.setUserTransitionSpeed(1);
    HyperosMotionPlatform.debugClearBoundControllers();
  });

  test('scaledMs 与 scaledDuration 同源：1.0× 保持原值', () {
    expect(180.scaledMs, const Duration(milliseconds: 180));
    expect(
      HyperosMotionPlatform.scaledDuration(180),
      const Duration(milliseconds: 180),
    );
  });

  test('scaledMs 跟随速度：2.0× 减半、0.5× 加倍', () {
    AndroidAnimationScaleService.setUserTransitionSpeed(2);
    expect(180.scaledMs, const Duration(milliseconds: 90));

    AndroidAnimationScaleService.setUserTransitionSpeed(0.5);
    expect(180.scaledMs, const Duration(milliseconds: 360));
  });

  test('登记的长命控制器在速度变更后跟着改时长', () {
    final controller = AnimationController(
      vsync: _FakeVsync(),
      duration: const Duration(milliseconds: 360),
    );
    addTearDown(controller.dispose);

    HyperosMotionPlatform.bindController(controller, 360);
    expect(controller.duration, const Duration(milliseconds: 360));

    // 模拟用户在设置里拖到 2.0×，并触发全局刷新。
    AndroidAnimationScaleService.setUserTransitionSpeed(2);
    notifyHyperosMotionChanged();
    expect(controller.duration, const Duration(milliseconds: 180));

    AndroidAnimationScaleService.setUserTransitionSpeed(0.5);
    notifyHyperosMotionChanged();
    expect(controller.duration, const Duration(milliseconds: 720));
  });

  test('正在播放的控制器不被中途改时长（避免画面跳变）', () {
    final controller = AnimationController(
      vsync: _FakeVsync(),
      duration: const Duration(milliseconds: 360),
    );
    addTearDown(controller.dispose);

    HyperosMotionPlatform.bindController(controller, 360);
    controller.forward();

    AndroidAnimationScaleService.setUserTransitionSpeed(2);
    HyperosMotionPlatform.refreshBoundControllers();

    // 仍是从登记时的 1.0× 换算出来的 360ms，不是 180ms。
    expect(controller.duration, const Duration(milliseconds: 360));
  });

  test('unbind 之后登记表不再持有该控制器', () {
    final controller = AnimationController(
      vsync: _FakeVsync(),
      duration: const Duration(milliseconds: 360),
    );
    HyperosMotionPlatform.bindController(controller, 360);
    expect(HyperosMotionPlatform.debugBoundControllerCount, 1);

    HyperosMotionPlatform.unbindController(controller);
    expect(HyperosMotionPlatform.debugBoundControllerCount, 0);
    controller.dispose();
  });
}

/// 最简 TickerProvider：测试里只用来构造 AnimationController。
class _FakeVsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
