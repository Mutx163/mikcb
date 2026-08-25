import 'package:flutter/material.dart';

import '../../../models/liquid_glass_tuning.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// 液态玻璃作用范围默认值（外观与配色页可逐表面开关）。
///
/// 全局玻璃模式为「液态玻璃」时，各表面家族是否跟随折射材质；关闭的
/// 家族回退高斯磨砂（模糊总开关关闭时回落实底）。默认值：锚定下拉小
/// 弹窗开；对话式全屏选择面板关——大面积折射在长列表上偏炫且更费电，
/// 预设主题等选择弹窗默认保持经典磨砂；其余家族维持既有行为（开）。
const kDefaultLiquidGlassPopupEnabled = true;
const kDefaultLiquidGlassSelectSheetEnabled = false;
const kDefaultLiquidGlassSheetDialogEnabled = true;
const kDefaultLiquidGlassHomeChromeEnabled = true;
const kDefaultLiquidGlassDockEnabled = true;

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
    this.liquidGlassPopupEnabled = kDefaultLiquidGlassPopupEnabled,
    this.liquidGlassSelectSheetEnabled =
        kDefaultLiquidGlassSelectSheetEnabled,
    this.liquidGlassSheetDialogEnabled =
        kDefaultLiquidGlassSheetDialogEnabled,
    this.liquidGlassHomeChromeEnabled = kDefaultLiquidGlassHomeChromeEnabled,
    this.liquidGlassDockEnabled = kDefaultLiquidGlassDockEnabled,
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

  /// 液态玻璃作用范围：锚定下拉选择小弹窗（玻璃模式等设置行弹出的气泡）。
  final bool liquidGlassPopupEnabled;

  /// 液态玻璃作用范围：对话式全屏选择面板（预设主题/字体等长列表选择弹窗）。
  final bool liquidGlassSelectSheetEnabled;

  /// 液态玻璃作用范围：底部弹窗与对话框（showHyperosSheet 系材质）。
  final bool liquidGlassSheetDialogEnabled;

  /// 液态玻璃作用范围：首页玻璃带（标题栏与星期栏的玻璃背景）。
  final bool liquidGlassHomeChromeEnabled;

  /// 液态玻璃作用范围：玻璃坞导航（底部悬浮药丸与加课圆钮）。
  final bool liquidGlassDockEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrostedAppearance &&
          blurEnabled == other.blurEnabled &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha &&
          glassMode == other.glassMode &&
          liquidGlassTuning == other.liquidGlassTuning &&
          liquidGlassPopupEnabled == other.liquidGlassPopupEnabled &&
          liquidGlassSelectSheetEnabled == other.liquidGlassSelectSheetEnabled &&
          liquidGlassSheetDialogEnabled == other.liquidGlassSheetDialogEnabled &&
          liquidGlassHomeChromeEnabled == other.liquidGlassHomeChromeEnabled &&
          liquidGlassDockEnabled == other.liquidGlassDockEnabled;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    sheetBlurSigma,
    sheetTintAlpha,
    sheetBarrierAlpha,
    glassMode,
    liquidGlassTuning,
    liquidGlassPopupEnabled,
    liquidGlassSelectSheetEnabled,
    liquidGlassSheetDialogEnabled,
    liquidGlassHomeChromeEnabled,
    liquidGlassDockEnabled,
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
