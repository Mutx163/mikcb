import 'package:flutter/material.dart';

import '../../../models/header_blur_style.dart';
import '../../../models/liquid_glass_tuning.dart';

/// Default frosted-glass tuning (aligned with app timetable defaults).
const kDefaultFrostedBlurEnabled = true;
const kDefaultFrostedSheetBlurSigma = 15.0;
const kDefaultFrostedSheetTintAlpha = 0.70;
const kDefaultFrostedSheetBarrierAlpha = 0.20;

/// 顶栏玻璃带的默认模糊材质：渐进模糊（inspire_blur）。
const kDefaultHeaderBlurStyle = HeaderBlurStyle.inspire;

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
const kDefaultLiquidGlassPickerButtonsEnabled = true;

/// User-tunable frosted glass appearance for home sheets and related surfaces.
/// Glass-surface rendering mode for frosted/Wallpaper-backgrounded sheets and cards.
enum FrostedGlassMode {
  /// 非液态磨砂的内部中性值：模型默认值、存量数据兜底（旧 translucent /
  /// gaussian 值经 [FrostedGlassModeX.fromValue] 归一，渲染完全等价）、
  /// 以及设置页「实体卡片」档的存储落点。渲染上与 [gaussian] 走同一条
  /// BackdropFilter + tint 链路，设置页不再作为独立档位暴露。
  frosted,

  /// Liquid-glass refraction (depth-based real-time shader).
  liquidGlass,

  /// 设置页「高斯模糊」档的存储标记：渲染与 [frosted] 同一链路，仅用于
  /// 标记用户显式选择过该档。
  gaussian,
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
    this.headerBlurStyle = kDefaultHeaderBlurStyle,
    this.liquidGlassTuning,
    this.liquidGlassPopupEnabled = kDefaultLiquidGlassPopupEnabled,
    this.liquidGlassSelectSheetEnabled = kDefaultLiquidGlassSelectSheetEnabled,
    this.liquidGlassSheetDialogEnabled = kDefaultLiquidGlassSheetDialogEnabled,
    this.liquidGlassHomeChromeEnabled = kDefaultLiquidGlassHomeChromeEnabled,
    this.liquidGlassDockEnabled = kDefaultLiquidGlassDockEnabled,
    this.liquidGlassPickerButtonsEnabled =
        kDefaultLiquidGlassPickerButtonsEnabled,
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

  /// 顶栏玻璃带（首页玻璃带 + 子页顶栏）的模糊材质风格。
  ///
  /// 只影响顶栏：卡片、弹窗等表面仍按 [glassMode] 渲染。两档都由
  /// inspire_blur 的渐进模糊实现，见 `lib/ui/hyperos/inspire/`。
  final HeaderBlurStyle headerBlurStyle;

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

  /// 液态玻璃作用范围：壁纸位置选择页悬浮在壁纸上的玻璃按钮。
  final bool liquidGlassPickerButtonsEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrostedAppearance &&
          blurEnabled == other.blurEnabled &&
          headerBlurStyle == other.headerBlurStyle &&
          sheetBlurSigma == other.sheetBlurSigma &&
          sheetTintAlpha == other.sheetTintAlpha &&
          sheetBarrierAlpha == other.sheetBarrierAlpha &&
          glassMode == other.glassMode &&
          liquidGlassTuning == other.liquidGlassTuning &&
          liquidGlassPopupEnabled == other.liquidGlassPopupEnabled &&
          liquidGlassSelectSheetEnabled ==
              other.liquidGlassSelectSheetEnabled &&
          liquidGlassSheetDialogEnabled ==
              other.liquidGlassSheetDialogEnabled &&
          liquidGlassHomeChromeEnabled == other.liquidGlassHomeChromeEnabled &&
          liquidGlassDockEnabled == other.liquidGlassDockEnabled &&
          liquidGlassPickerButtonsEnabled ==
              other.liquidGlassPickerButtonsEnabled;

  @override
  int get hashCode => Object.hash(
    blurEnabled,
    headerBlurStyle,
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
    liquidGlassPickerButtonsEnabled,
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
