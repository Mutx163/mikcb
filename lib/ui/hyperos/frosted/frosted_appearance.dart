import 'package:flutter/material.dart';

import '../../../models/liquid_glass_tuning.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// User-tunable frosted glass appearance for home sheets and related surfaces.
/// Glass-surface rendering mode for frosted/Wallpaper-backgrounded sheets and cards.
enum FrostedGlassMode {
  /// Standard frosted glass (backdrop blur + milky tint overlay).
  frosted,

  /// Liquid-glass refraction (depth-based real-time shader).
  liquidGlass,

  /// Pure gaussian blur with minimal tint (thin, clear look).
  gaussian,

  /// Mist transparent frost — very light blur, almost clear.
  translucent,
}

extension FrostedGlassModeX on FrostedGlassMode {
  String get value => name;

  static FrostedGlassMode fromValue(String? value) {
    return FrostedGlassMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FrostedGlassMode.frosted,
    );
  }
}

class FrostedAppearance {
  const FrostedAppearance({
    required this.sheetBlurSigma,
    required this.sheetTintAlpha,
    required this.sheetBarrierAlpha,
    this.blurEnabled = kDefaultFrostedBlurEnabled,
    this.glassMode = FrostedGlassMode.frosted,
    this.liquidGlassTuning,
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

  /// Glass surface rendering mode.
  final FrostedGlassMode glassMode;

  /// Optional liquid-glass tuning (used when [glassMode] is [FrostedGlassMode.liquidGlass]).
  final LiquidGlassTuning? liquidGlassTuning;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrostedAppearance &&
          blurEnabled == other.blurEnabled &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha &&
          glassMode == other.glassMode &&
          liquidGlassTuning == other.liquidGlassTuning;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    sheetBlurSigma,
    sheetTintAlpha,
    sheetBarrierAlpha,
    glassMode,
    liquidGlassTuning,
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
