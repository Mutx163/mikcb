import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Inherited scope that makes [LiquidGlassDegradation] reactive.
///
/// Placed above the app's route stack (see MyApp.builder inside lib/main.dart).
/// Every [LiquidGlassDegradation.shouldDegrade] call registers a dependency on
/// this scope, so whenever the platform-view gate flips (a WebView route is
/// pushed or disposed), every glass surface rebuilds immediately instead of
/// waiting for an unrelated rebuild.
///
/// Without this, [LiquidGlassDegradation.endPlatformViewUnsafeSurface] ran
/// silently from the WebView route's dispose() at end of frame - after the page
/// revealed underneath had already painted its final degraded frame - leaving
/// the home screen stuck on the solid fallback until the next arbitrary
/// rebuild. That is exactly the 'quick import succeeded, back home, glass not
/// restored' regression.
class LiquidGlassDegradationScope
    extends InheritedNotifier<ValueNotifier<int>> {
  const LiquidGlassDegradationScope({
    super.key,
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  /// Registers the calling build as a dependent of the gate notifier, if the
  /// scope is present. Safe to call from any BuildContext during build.
  static void dependOn(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LiquidGlassDegradationScope>();
  }
}

/// System conditions that warrant downgrading glass to an opaque solid surface.
///
/// Mirrors the Windows 11 Mica/Acrylic degradation matrix and the Android 12+
/// window-blur guidance: when the user asks for less motion, higher contrast or
/// reduced transparency, blur is suppressed to keep content legible and to save
/// GPU. Returning true here makes
/// [HyperosBlurredHeader.backdropBlurEnabled] false and every liquid-glass
/// surface fall back to its solid material - frosted sheets, popups, the home
/// chrome band and course cards all downgrade in one place.
///
/// The signals are the Flutter-accessible ones (no platform channel required):
/// - [MediaQueryData.disableAnimations] - system remove-animations.
/// - [MediaQueryData.highContrast] - high-contrast accessibility.
///
/// [MediaQueryData.accessibleNavigation] is deliberately NOT part of the
/// matrix: on MIUI/HyperOS the screenshot overlay session turns on system
/// touch exploration, which the Flutter Android engine reports as
/// accessibleNavigation=true while the floating preview exists - degrading on
/// it would flip every glass surface to solid during screenshots
/// (upstream: https://github.com/flutter/flutter/issues/128409). The two
/// signals above already cover the visually-driven cases that benefit most
/// from disabling blur, and they are pure-Dart so the whole policy is
/// unit-testable.
///
/// Power-saver mode would need a platform channel and is intentionally left as
/// a future hook (TODO: power-saver).
///
/// References:
/// - Windows 11 materials degradation matrix:
///   https://learn.microsoft.com/en-us/windows/apps/develop/ui/materials
/// - Android cross-window blur runtime disablement:
///   https://source.android.com/docs/core/display/window-blurs
abstract final class LiquidGlassDegradation {
  /// Whether glass surfaces should downgrade to an opaque solid right now.
  ///
  /// Registers this call as a dependent of [LiquidGlassDegradationScope] so the
  /// glass toggles take effect on the NEXT frame: pushing a WebView route
  /// degrades the glass immediately, popping it restores the frosted surfaces
  /// the moment the route is disposed - no arbitrary rebuild required.
  static bool shouldDegrade(BuildContext context) {
    LiquidGlassDegradationScope.dependOn(context);
    return platformViewSurfaceUnsafe || shouldDegradeFor(MediaQuery.of(context));
  }

  /// Pure core that does not depend on [BuildContext], meant for unit tests.
  static bool shouldDegradeFor(MediaQueryData mq) =>
      mq.disableAnimations || mq.highContrast;

  /// 某个表面家族「要不要液态玻璃」的开关关掉时，它是否应退化为**不透明实体
  /// 卡片**。
  ///
  /// 语义（2026-09-11 定稿）：这把开关是「**要不要液态玻璃**」的开关。关掉 =
  /// 这面改为实体卡片，而不是降一级去用高斯磨砂。理由：
  ///
  /// 1. 磨砂档走实时 BackdropFilter，而液态档走包内隔离组 + 稳定整页捕获。
  ///    降级到磨砂后，入场/揭示动画期间 BackdropFilter 采不到稳定背景
  ///    （动画中的层尚未落到屏幕上），面板在整段动画里渲染为透明，动画结束才
  ///    「啪」地出现——读起来就是**弹窗没有动画**。实体卡片不依赖背景采样，
  ///    动画全程正常（同一机制记在 `hyperos_select.dart` 的 Transform.scale
  ///    注释里）。
  /// 2. 全局「默认材质」已经提供实体卡片 / 液态玻璃两档。用家族开关再退化
  ///    一层材质，等于两个地方控制同一件事。
  ///
  /// 2026-09-30 高斯模糊档退场后，这把开关成了液态档下**唯一**能让某个表面
  /// 退回磨砂 / 实体的口子（此前高斯档也管这件事，那条路已合并到本函数）。
  ///
  /// **判据只看「系统有没有降级 + 家族开关有没有开」**。
  ///
  /// 例外：**首页玻璃带**有自己的「玻璃材质」档位（跟随全局 / 实体 / 液态），
  /// 不走本函数——否则这把开关会顺手把顶栏带整个拿掉。
  static bool familyFallsBackToSolid(
    BuildContext context, {
    required bool advancedFamilyEnabled,
  }) {
    if (shouldDegrade(context)) {
      // 系统降级（减动效 / 高对比 / WebView 平台视图）本就落实底，
      // 与家族开关无关；一并返回 true 让调用方走同一条分支。
      return true;
    }
    return !advancedFamilyEnabled;
  }

  /// Platform-view gate depth, exposed as a notifier so
  /// [LiquidGlassDegradationScope] (and every registered glass surface) rebuilds
  /// whenever it changes.
  static final ValueNotifier<int> _platformViewUnsafeDepth =
      _FrameSafeGateNotifier(0);

  /// Whether a route hosting a visible Android platform view (WebView) is
  /// currently active. Glass captures cannot include platform-view content -
  /// sampled regions render black or transparent - so every glass surface
  /// above it must fall back to its solid material. Counter-nested because
  /// screens stay in the tree during transitions and dialogs outlive order
  /// races.
  static bool get platformViewSurfaceUnsafe => _platformViewUnsafeDepth.value > 0;

  /// Notifier backing the platform-view gate; wire this into
  /// [LiquidGlassDegradationScope.notifier] at the app root.
  static ValueNotifier<int> get platformViewUnsafeDepthNotifier =>
      _platformViewUnsafeDepth;

  /// Marks the window unsafe for glass while a platform-view route is on top.
  ///
  /// 置位发生在被推路由的 `initState` 里 —— 那正是**构建阶段**。写入本身没问题
  /// （同一次构建里后续读 `shouldDegrade` 的表面立刻拿到新值，这正是要的），
  /// 通知由 [_FrameSafeGateNotifier] 挪到帧末。
  static void beginPlatformViewUnsafeSurface() => _platformViewUnsafeDepth.value++;

  /// Ends the unsafe window; other overlapping marks keep it unsafe. Fires the
  /// notifier so every dependent glass surface rebuilds with blur restored -
  /// this ends the stuck-degraded state even though the route's dispose runs
  /// at the end of the frame.
  ///
  /// 与 [beginPlatformViewUnsafeSurface] 对称：`dispose` 跑在
  /// `BuildOwner.finalizeTree` 的锁定窗口里，通知同样由
  /// [_FrameSafeGateNotifier] 挪到帧末。
  static void endPlatformViewUnsafeSurface() {
    if (_platformViewUnsafeDepth.value > 0) {
      _platformViewUnsafeDepth.value--;
    }
  }
}

/// 平台视图闸门的通知器：**值同步写，通知躲出本帧的构建窗口**。
///
/// 闸门只有两个写点，两个都在框架不许 `markNeedsBuild()` 的时刻：
///
/// - 置位在被推路由的 `initState` —— `Navigator` 是在**构建阶段**把新路由装进
///   树的，`initState` 因此跑在构建里。此时通知会让挂在路由之上的
///   [LiquidGlassDegradationScope] 撞上 `setState() or markNeedsBuild() called
///   during build`（红屏）。它不是「正在构建的祖先」，所以框架不放行。
/// - 归零在该路由的 `dispose` —— 路由销毁跑在 `BuildOwner.finalizeTree` 的
///   锁定窗口（`lockState(_inactiveElements._unmountAll)`）里，撞上
///   `... called when widget tree was locked`。
///
/// 为什么挪到帧末不改变可见行为：`InheritedNotifier` 收到通知后只是把自己标脏，
/// 依赖方要等**下一帧**构建时才被通知（`_InheritedNotifierElement._handleUpdate`
/// → `markNeedsBuild`）。也就是说「这一帧写、下一帧重建」本来就是它的语义，
/// 延后通知等于把一次非法调用换成一次合法调用，一帧都不多等。
///
/// 帧末只补一次通知：窗口内多次改值（begin 紧跟 end 之类）合并成一次，依赖方
/// 重建时读到的自然是最新值。
class _FrameSafeGateNotifier extends ValueNotifier<int> {
  _FrameSafeGateNotifier(super.value);

  /// 已排了一个帧末通知（合并窗口内的重复通知）。
  bool _flushScheduled = false;

  /// 正在帧末补发，此时不能再排下一次，否则通知会永远推不出去。
  bool _flushing = false;

  @override
  void notifyListeners() {
    if (_flushing) {
      super.notifyListeners();
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      super.notifyListeners();
      return;
    }
    if (_flushScheduled) {
      return;
    }
    _flushScheduled = true;
    // postFrameCallbacks 在解锁之后才跑（锁只包住 finalizeTree 里的 unmount），
    // 所以这里通知是合法的；此刻正处在一帧之内，这一帧的帧末必定会执行到。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      _flushing = true;
      try {
        super.notifyListeners();
      } finally {
        _flushing = false;
      }
    });
  }
}
