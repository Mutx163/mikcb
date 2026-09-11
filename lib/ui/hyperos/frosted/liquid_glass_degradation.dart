import 'package:flutter/widgets.dart';

import 'frosted_appearance.dart';

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

  /// 「液态玻璃作用范围」关闭某个表面家族后，该表面是否应直接退化为
  /// **不透明实体卡片**。
  ///
  /// 语义（2026-09-11 定稿）：作用范围开关是「**要不要液态玻璃**」的开关，
  /// 不是「要不要玻璃」的开关。关掉 = 这面改为实体卡片，而不是降一级去用
  /// 高斯磨砂。理由：
  ///
  /// 1. 磨砂档走实时 BackdropFilter，而液态档走包内隔离组 + 稳定整页
  ///    捕获。降级到磨砂后，入场/揭示动画期间 BackdropFilter 采不到稳定
  ///    背景（动画中的层尚未落到屏幕上），面板在整段动画里渲染为透明，
  ///    动画结束才「啪」地出现——读起来就是**弹窗没有动画**。实体卡片
  ///    不依赖背景采样，动画全程正常（同一机制记在
  ///    `hyperos_select.dart` 的 Transform.scale 注释里）。
  /// 2. 全局「玻璃模式」已经提供实体卡片 / 高斯模糊 / 柔光玻璃 / 液态玻璃
  ///    四个档位。用家族开关再退化一层材质，等于两个地方控制同一件事，
  ///    且第二处的行为（磨砂）与它的标签（关闭液态）不符。
  ///
  /// 例外：**首页玻璃带**有自己的「玻璃材质」三选一（渐进模糊 / 高斯模糊 /
  /// 液态玻璃），其家族开关只在液态与用户选定的那档之间切换，不适用本
  /// 判定——否则关掉液态会把顶栏玻璃整个拿掉。
  static bool familyFallsBackToSolid(
    BuildContext context, {
    required bool liquidGlassFamilyEnabled,
  }) {
    if (shouldDegrade(context)) {
      // 系统降级（减动效 / 高对比 / WebView 平台视图）本就落实底，
      // 与家族开关无关；一并返回 true 让调用方走同一条分支。
      return true;
    }
    final scope = FrostedAppearanceScope.maybeOf(context);
    final mode = scope?.appearance.glassMode;
    if (mode != FrostedGlassMode.liquidGlass) {
      // 非液态全局材质（实体卡片 / 高斯 / 柔光）：家族开关本就不参与，
      // 各自走自己的既有分支。
      return false;
    }
    // 全局液态 + 该家族关闭 → 实体卡片。
    return !liquidGlassFamilyEnabled;
  }

  /// Platform-view gate depth, exposed as a notifier so
  /// [LiquidGlassDegradationScope] (and every registered glass surface) rebuilds
  /// whenever it changes.
  static final ValueNotifier<int> _platformViewUnsafeDepth = ValueNotifier<int>(
    0,
  );

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
  static void beginPlatformViewUnsafeSurface() => _platformViewUnsafeDepth.value++;

  /// Ends the unsafe window; other overlapping marks keep it unsafe. Fires the
  /// notifier so every dependent glass surface rebuilds with blur restored -
  /// this ends the stuck-degraded state even though the route's dispose runs
  /// at the end of the frame.
  static void endPlatformViewUnsafeSurface() {
    if (_platformViewUnsafeDepth.value > 0) {
      _platformViewUnsafeDepth.value--;
    }
  }
}
