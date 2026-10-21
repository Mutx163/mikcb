import 'package:flutter/animation.dart';

import 'hyperos_motion.dart';

/// 日视图「锚点展开 / 收起」动画的时长与曲线策略（2026-10-20 建，2026-10-21 调参）。
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
  /// 420ms（2026-10-21 由 360ms 上调）。
  ///
  /// 为什么要动：这条转场现在承担「**那一列向左右撑开、旁边的日子被让出来**」
  /// 的语义（见 `timetable_anchored_day_overlay.dart`）。要让「其他日期露出来」
  /// 这件事被看见，相邻两列各留 ≥15px 可见宽的时间必须 ≥150ms（人眼能读出
  /// 一个四分之一秒级变化的经验下限）。
  ///
  /// 按 [curve] 实测该窗口：
  ///
  /// | 时长 | `easeInOutCubicEmphasized`（改前） | `easeInOut`（改后） |
  /// |---|---|---|
  /// | 360ms | **131ms**（读不出） | 275ms |
  /// | 420ms | 153ms（勉强） | **324ms** |
  ///
  /// 上限由既有测试卡住：`test/widgets/timetable_day_view_test.dart` 有 98 处
  /// `_pumpTimetableFrame` = `pump() + pump(500ms)`，另有
  /// `glass_dock_wallpaper_repro_test.dart` 在 600ms 后断言动画已结束。
  /// **超过 500ms 会让一批断言在动画中途取样**，所以 500ms 是硬顶，420ms 取
  /// 它下面留一档余量。
  static const int baseMilliseconds = 420;

  /// 展开曲线（2026-10-21 由 `Curves.easeInOutCubicEmphasized` 改为此）。
  ///
  /// **换曲线的理由不是审美，是这条转场读不出过程**：
  /// `easeInOutCubicEmphasized` 是 Flutter 为「页面推入」设计的
  /// （`ThreePointCubic((0.05,0),(0.133333,0.06),(0.166666,0.4),(0.208333,0.82),(0.25,1))`），
  /// 前 1/6 时间就跑完 40% 行程、50% 时间跑完 95%。换算成列宽
  /// （50px → 390px，360ms）：**50~100ms 那 50 毫秒里就冲掉 203px**，
  /// 用户看到的是一下弹开，中间没有「其他日期正在露出来」这个阶段。
  ///
  /// 选 [Curves.easeInOut]（`Cubic(0.42, 0.0, 0.58, 1.0)`）而不是别的，是因为
  /// 它同时满足这条转场的两个硬需求：
  ///
  /// 1. **严格对称**：`f(1-x) === 1-f(x)`（实测偏差 4.4e-16）。展开与收起共用
  ///    同一个控制器，而**中途反向是可达路径** —— 展开到一半时点关闭按钮
  ///    （`DayViewTransitionController.close` 在 `dayViewExpandValue > 0` 时就走
  ///    `reverse()`）。曲线不对称时同一个 `parent.value` 在正 / 反两向输出不同
  ///    进度，面板宽度会当帧跳一下：
  ///
  ///    | 曲线 | 中途反向的宽度跳变 |
  ///    |---|---|
  ///    | `easeInOut` | **0 px** |
  ///    | `easeInOutCubic` | 11 px（≈ 不可见） |
  ///    | `fastOutSlowIn` | 187 px（明显闪一下） |
  ///    | `easeOutCubic` | 255 px |
  ///
  /// 2. **露出窗口最长**：420ms 下相邻日期各留 ≥15px 可见宽的时间 ——
  ///    `easeInOut` 324ms > `easeInOutCubic` 295ms > `fastOutSlowIn` 262ms
  ///    > `easeOutCubic` 222ms。判据是 ≥150ms 才读得出（人眼对四分之一秒级
  ///    变化的经验下限）。
  ///
  /// 代价：起步偏缓（100ms 只走 11.7% 行程，约 40px）。换来的是中段匀速推移、
  /// 两端都柔和 —— 正是「卡片在持续变宽 / 变窄」而不是「弹开」的观感。
  ///
  /// 收起方向**直接用同一条曲线**（不配 `reverseCurve`）：对称性保证 `reverse()`
  /// 与正向镜像等价；配另一条反而会引入上面那张表里的跳变。
  ///
  /// ⚠️ 这条曲线同时改变 [HyperosMiuixNavigation.anchorExpandCornerSettleBand]
  /// 的有效窗口（圆角收束落在曲线慢尾里）——该常量的注释按旧曲线的慢尾推过，
  /// 换曲线后圆角收束的相对时机变了，**需真机确认圆角是否还在贴边后才消失**。
  static const Curve curve = Curves.easeInOut;

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
