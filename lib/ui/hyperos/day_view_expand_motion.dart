import 'package:flutter/widgets.dart';

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
  /// 210ms（2026-10-21 由 420ms **减半**；此前 360ms → 420ms）。
  ///
  /// 用户口径（2026-10-21）：「动画速度，要调快一倍」。420 → 210 即字面意义上的
  /// 快一倍。
  ///
  /// ## 历史：为什么曾经是 420ms
  ///
  /// 上一版这条转场承担「**那一列向左右撑开、旁边的日子被让出来**」的语义，
  /// 需要「相邻两列各留 ≥15px 可见宽 ≥150ms」才读得出来，于是取 420ms。
  /// 那是**窗口收放**时代的约束；现在转场是「卡片对卡片」——每张卡从网格格位
  /// 长成议程卡，没有「旁边的日子露出来」这个阶段，那条约束随之失效。
  ///
  /// ## 现在的上限来自哪里
  ///
  /// 既有测试仍用 `pump() + pump(500ms)` 取样（`timetable_day_view_test.dart`
  /// 有 98 处），所以**上限仍是 500ms**；210ms 远低于它，取样时动画早已结束，
  /// 稳定性反而更好（中途取样的抖动不存在了）。
  ///
  /// ⚠️ 速度倍率仍然生效：`baseMilliseconds.scaledMs` 会按用户在「页面转场速度」
  /// 里的设置换算。
  static const int baseMilliseconds = 210;

  /// 展开曲线（2026-10-21 由 `Curves.easeInOutCubicEmphasized` → `easeInOut`；
  /// 2026-10-23 → `Cubic(0.25, 0, 0.75, 1)`）。
  ///
  /// ## 为什么不要「页面推入」那类曲线
  ///
  /// `easeInOutCubicEmphasized` 是 Flutter 为页面推入设计的
  /// （`ThreePointCubic((0.05,0),(0.133333,0.06),(0.166666,0.4),(0.208333,0.82),(0.25,1))`），
  /// 前 1/6 时间就跑完 40% 行程、50% 时间跑完 95%。换算成列宽
  /// （50px → 390px，360ms）：**50~100ms 那 50 毫秒里就冲掉 203px**，
  /// 用户看到的是一下弹开，中间没有「其他日期正在露出来」这个阶段。
  ///
  /// ## 为什么也不是 `easeInOut`
  ///
  /// `Curves.easeInOut`（`Cubic(0.42, 0, 0.58, 1)`）两端都太软：210ms 下前 33ms
  /// 只走 **5%**（约 18px）。60fps 下就是**前两帧几乎看不出动**，点下去先顿一下
  /// 再中段匀速推开 —— 用户口径「点了没反应」的那种迟滞就来自这里。
  ///
  /// ## 这一版的三条硬约束
  ///
  /// 1. **严格对称**：`f(1-x) === 1-f(x)`（实测偏差 4.4e-16）。展开与收起共用
  ///    同一个控制器，而**中途反向是可达路径** —— 展开到一半点关闭按钮
  ///    （`DayViewTransitionController.close` 在 `dayViewExpandValue > 0` 时就走
  ///    `reverse()`）。曲线不对称时同一个 `parent.value` 在正 / 反两向输出不同
  ///    进度，面板宽度会当帧跳一下：
  ///
  ///    | 曲线 | 中途反向的宽度跳变 |
  ///    |---|---|
  ///    | 对称贝塞尔（本档） | **0 px** |
  ///    | `easeInOutCubic` | 11 px（≈ 不可见） |
  ///    | `fastOutSlowIn` | 187 px（明显闪一下） |
  ///    | `easeOutCubic` | 255 px |
  ///
  /// 2. **起步要跟手**：210ms 下前 33ms 必须走出可感知的位移。`Cubic(0.25,…)`
  ///    在 33ms 走 8.6%（约 31px）、50ms 走 16.9% —— 第一帧就有动作，仍保持
  ///    「中段匀速推移、两端柔和」。
  ///
  /// 3. **中段不能过冲**：全程单调递增，不出现「先冲过头再回一点」的回弹。
  ///
  /// 代价：比 `easeInOut` 起步更快，所以**前 1/4 行程更急**——但这正是「点了
  /// 就有反应」需要的观感；收尾仍由对称性保证与正向镜像等价。
  ///
  /// 收起方向**直接用同一条曲线**（不配 `reverseCurve`）：对称性保证 `reverse()`
  /// 与正向镜像等价；配另一条反而会引入上面那张表里的跳变。
  ///
  /// ⚠️ 这条曲线同时改变 [HyperosMiuixNavigation.anchorExpandCornerSettleBand]
  /// 的有效窗口（圆角收束落在曲线慢尾里）——该常量的注释按旧曲线的慢尾推过，
  /// 换曲线后圆角收束的相对时机变了，**需真机确认圆角是否还在贴边后才消失**。
  static const Curve curve = Cubic(0.25, 0, 0.75, 1);

  /// 按当前速度换算出的实际时长。
  static Duration get duration => baseMilliseconds.scaledMs;

  /// 系统「减少动态效果」是否开启（`MediaQuery.disableAnimations`）。
  ///
  /// 开启时这条转场**不做逐帧形变**：直接落定。理由不是「少花点算力」—— 用户
  /// 打开这个开关是因为动效会引起不适（前庭功能障碍），任何「短一点的动画」
  /// 都还是动画，必须真的不动。
  ///
  /// 判据取 `disableAnimations` 而**不**取 `accessibleNavigation`：
  /// 后者在系统的无障碍菜单打开时也为真，但它表达的是「操作要更容易发现」，
  /// 不表示「不能有动效」（本仓 `liquid_glass_degradation.dart` 也按这个口径）。
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

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

  /// 展开（含「减少动态效果」分支）：开启时直接落定，不走形变。
  ///
  /// 放在这里而不是宿主里：宿主每多一行都要过行数棘轮，而这条判据属于
  /// 「转场怎么播」这件事本身。
  static Future<void> expand(
    BuildContext context,
    AnimationController controller,
  ) {
    if (reduceMotion(context)) {
      controller.value = 1;
      return Future<void>.value();
    }
    return forward(controller);
  }

  /// 收起（同上：减少动态效果时直接归零，不跑 reverse）。
  static Future<void> collapse(
    BuildContext context,
    AnimationController controller,
  ) {
    if (reduceMotion(context)) {
      controller.value = 0;
      return Future<void>.value();
    }
    return controller.reverse();
  }

  /// 重读时长（不只是登记值，见 [forward]）。
  static void syncBeforeForward(AnimationController controller) {
    if (controller.isAnimating) {
      return;
    }
    controller.duration = duration;
  }
}
