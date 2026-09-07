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
