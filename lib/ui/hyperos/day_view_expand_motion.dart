import 'package:flutter/animation.dart';

import 'hyperos_motion.dart';

/// 日视图「锚点展开 / 收起」动画的时长策略（2026-10-20）。
///
/// 这个控制器是**长命**的：随首页 State 一起创建、全程复用。而
/// `AnimationController.duration` 是构造时写死的字段 —— 用户如果在它存活
/// 期间去「通用 → 页面转场速度」改倍率，不重新赋值就要杀进程才生效。
/// 用户 2026-10-20 的口径是「那个调节应该要覆盖整个软件所有的动画」，
/// 日视图缩放正是他最初发现「没被改到」的那一处。
///
/// 抽成独立文件而不是塞进 `_TimetableScreenState`：`timetable_screen.dart`
/// 有行数棘轮（只减不增，见 `test/architecture/timetable_screen_size_guard_test.dart`），
/// 而「什么时候该重读时长」这件事本身有先后约束（见 [syncBeforeForward]），
/// 放在能单独测的地方比埋在 State 里稳妥。
abstract final class DayViewExpandMotion {
  /// 官方 miuix 量级（与页面转场同一档）：360ms。
  ///
  /// 日视图是「锚点小面板长成整屏」，比标准推页多一段窗口形变；再长就拖沓。
  static const int baseMilliseconds = 360;

  /// 按当前速度换算出的实际时长。
  static Duration get duration => baseMilliseconds.scaledMs;

  /// 建控制器：已按当前速度设好时长，并登记到全局刷新表。
  ///
  /// 登记用的是弱引用（见 [HyperosMotionPlatform.bindController]），控制器
  /// 销毁后条目自动消失，所以这里不需要配对的反注册。
  static AnimationController createController(TickerProvider vsync) =>
      HyperosMotionPlatform.bindController(
        AnimationController(vsync: vsync),
        baseMilliseconds,
      );

  /// 展开：**起飞前**重读时长再 forward。
  ///
  /// [HyperosMotionPlatform.refreshBoundControllers] 会跳过正在播放的控制器
  /// （中途改 duration 会让 value 与已走过的行程错位、画面跳一下）。于是
  /// 「动画播放期间改的速度」要等到下一次起飞才生效 —— 这个函数就是那个生效点。
  static Future<void> forward(AnimationController controller) {
    syncBeforeForward(controller);
    return controller.forward();
  }

  /// 重读时长（不只是登记值，见 [forward]）。
  static void syncBeforeForward(AnimationController controller) {
    if (controller.isAnimating) {
      return;
    }
    controller.duration = duration;
  }
}
