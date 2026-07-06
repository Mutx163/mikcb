import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';

/// User-tunable frosted glass appearance for home sheets and related surfaces.
class FrostedAppearance {
  const FrostedAppearance({
    required this.sheetBlurSigma,
    required this.sheetTintAlpha,
    required this.sheetBarrierAlpha,
    this.blurEnabled = TimetableSettings.defaultFrostedBlurEnabled,
  });

  static const defaults = FrostedAppearance(
    sheetBlurSigma: TimetableSettings.defaultFrostedSheetBlurSigma,
    sheetTintAlpha: TimetableSettings.defaultFrostedSheetTintAlpha,
    sheetBarrierAlpha: TimetableSettings.defaultFrostedSheetBarrierAlpha,
  );

  factory FrostedAppearance.fromSettings(TimetableSettings settings) {
    return FrostedAppearance(
      sheetBlurSigma: settings.frostedSheetBlurSigma,
      sheetTintAlpha: settings.frostedSheetTintAlpha,
      sheetBarrierAlpha: settings.frostedSheetBarrierAlpha,
      blurEnabled: settings.frostedBlurEnabled,
    );
  }

  /// BackdropFilter sigma for frosted panels (logical pixels).
  final double sheetBlurSigma;

  /// Light-mode milky frosted overlay strength (0 = clear glass, higher = brighter).
  final double sheetTintAlpha;

  /// Modal barrier dimming behind frosted home sheets.
  final double sheetBarrierAlpha;

  /// Global backdrop blur master switch.
  final bool blurEnabled;
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
  bool updateShouldNotify(FrostedAppearanceScope oldWidget) {
    return appearance.sheetBlurSigma != oldWidget.appearance.sheetBlurSigma ||
        appearance.sheetTintAlpha != oldWidget.appearance.sheetTintAlpha ||
        appearance.sheetBarrierAlpha !=
            oldWidget.appearance.sheetBarrierAlpha ||
        appearance.blurEnabled != oldWidget.appearance.blurEnabled;
  }
}
