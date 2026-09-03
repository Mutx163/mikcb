import 'package:flutter/material.dart';

/// System conditions that warrant downgrading glass to an opaque solid surface.
///
/// Mirrors the Windows 11 Mica/Acrylic degradation matrix and the Android 12+
/// window-blur guidance: when the user asks for less motion, higher contrast or
/// reduced transparency, blur is suppressed to keep content legible and to save
/// GPU. Returning `true` here makes
/// [HyperosBlurredHeader.backdropBlurEnabled] `false` and every liquid-glass
/// surface fall back to its solid material — frosted sheets, popups, the home
/// chrome band and course cards all downgrade in one place.
///
/// The signals are the Flutter-accessible ones (no platform channel required):
/// - [MediaQueryData.disableAnimations] — system "remove animations".
/// - [MediaQueryData.highContrast] — high-contrast accessibility.
///
/// [MediaQueryData.accessibleNavigation] is deliberately NOT part of the
/// matrix: on MIUI/HyperOS the screenshot overlay session turns on system
/// touch exploration, which the Flutter Android engine reports as
/// `accessibleNavigation=true` while the floating preview exists — degrading
/// on it made every glass surface flip to solid during screenshots
/// (upstream: https://github.com/flutter/flutter/issues/128409). The two
/// signals above already cover the visually-driven cases that benefit most
/// from disabling blur, and they are pure-Dart so the whole policy is
/// unit-testable.
///
/// Power-saver mode would need a platform channel and is intentionally left as
/// a future hook (TODO: power-saver); the three signals above already cover the
/// accessibility-driven cases that benefit most from disabling blur, and they
/// are pure-Dart so the whole policy is unit-testable.
///
/// References:
/// - Windows 11 materials degradation matrix:
///   https://learn.microsoft.com/en-us/windows/apps/develop/ui/materials
/// - Android cross-window blur runtime disablement:
///   https://source.android.com/docs/core/display/window-blurs
abstract final class LiquidGlassDegradation {
  /// Whether glass surfaces should downgrade to an opaque solid right now.
  static bool shouldDegrade(BuildContext context) =>
      platformViewSurfaceUnsafe || shouldDegradeFor(MediaQuery.of(context));

  /// Pure core that does not depend on [BuildContext], for unit tests.
  static bool shouldDegradeFor(MediaQueryData mq) =>
      mq.disableAnimations || mq.highContrast;

  static int _platformViewUnsafeDepth = 0;

  /// Whether a route hosting a visible Android platform view (WebView) is
  /// currently active. Glass captures cannot include platform view content —
  /// sampled regions render black / transparent — so every glass surface
  /// above it must fall back to its solid material. Counter-nested because
  /// screens overlap during transitions and dialogs outlive order races.
  static bool get platformViewSurfaceUnsafe => _platformViewUnsafeDepth > 0;

  /// Marks the window unsafe for glass while a platform-view route is on top.
  static void beginPlatformViewUnsafeSurface() => _platformViewUnsafeDepth++;

  /// Ends the unsafe window; other overlapping marks keep it unsafe.
  static void endPlatformViewUnsafeSurface() {
    if (_platformViewUnsafeDepth > 0) {
      _platformViewUnsafeDepth--;
    }
  }
}
