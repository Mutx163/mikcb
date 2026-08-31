import 'package:flutter/material.dart';

import 'frosted_appearance.dart';

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
  ///
  /// 用户手动开关（减弱玻璃效果）与系统无障碍信号取并集：任一命中即
  /// 降级。开关经全局 [FrostedAppearanceScope] 下发，未挂 Scope 时按
  /// 关闭处理，保持与旧行为一致。
  static bool shouldDegrade(BuildContext context) {
    final scope = FrostedAppearanceScope.maybeOf(context);
    if (scope != null && scope.appearance.reducedTransparency) {
      return true;
    }
    return shouldDegradeFor(MediaQuery.of(context));
  }

  /// Pure core that does not depend on [BuildContext], for unit tests.
  static bool shouldDegradeFor(MediaQueryData mq) =>
      mq.disableAnimations || mq.highContrast;
}
