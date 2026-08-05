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
/// - [MediaQueryData.accessibleNavigation] — TalkBack / VoiceOver active.
/// - [MediaQueryData.disableAnimations] — system "remove animations".
/// - [MediaQueryData.highContrast] — high-contrast accessibility.
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
      shouldDegradeFor(MediaQuery.of(context));

  /// Pure core that does not depend on [BuildContext], for unit tests.
  static bool shouldDegradeFor(MediaQueryData mq) =>
      mq.accessibleNavigation || mq.disableAnimations || mq.highContrast;
}
