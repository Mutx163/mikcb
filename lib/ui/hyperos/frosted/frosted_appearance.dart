import 'package:flutter/material.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// User-tunable frosted glass appearance for home sheets and related surfaces.
class FrostedAppearance {
  const FrostedAppearance({
    required this.sheetBlurSigma,
    required this.sheetTintAlpha,
    required this.sheetBarrierAlpha,
    this.blurEnabled = kDefaultFrostedBlurEnabled,
  });

  static const defaults = FrostedAppearance(
    sheetBlurSigma: kDefaultFrostedSheetBlurSigma,
    sheetTintAlpha: kDefaultFrostedSheetTintAlpha,
    sheetBarrierAlpha: kDefaultFrostedSheetBarrierAlpha,
  );

  /// BackdropFilter sigma for frosted panels (logical pixels).
  final double sheetBlurSigma;

  /// Light-mode milky frosted overlay strength (0 = clear glass, higher = brighter).
  final double sheetTintAlpha;

  /// Modal barrier dimming behind frosted home sheets.
  final double sheetBarrierAlpha;

  /// Global backdrop blur master switch.
  final bool blurEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrostedAppearance &&
          blurEnabled == other.blurEnabled &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    sheetBlurSigma,
    sheetTintAlpha,
    sheetBarrierAlpha,
  );
}

/// Provides [FrostedAppearance] to frosted HyperOS widgets.
class FrostedAppearanceScope extends InheritedWidget {
  const FrostedAppearanceScope({
    required this.appearance,
    required super.child,
    super.key,
  });

  final FrostedAppearance appearance;

  static FrostedAppearance of(BuildContext context) {
    return maybeOf(context)?.appearance ?? FrostedAppearance.defaults;
  }

  static FrostedAppearanceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FrostedAppearanceScope>();
  }

  @override
  bool updateShouldNotify(covariant FrostedAppearanceScope oldWidget) {
    return appearance != oldWidget.appearance;
  }
}
