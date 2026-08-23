import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../hyperos_tokens.dart';

/// Fallback [liquid_glass_renderer] settings for mikcb liquid glass.
///
/// Sheet defaults match the package README medium-glass example
/// (`thickness: 20`, `blur: 10`, `glassColor: 0x33FFFFFF`). Every liquid glass
/// surface uses the same material so headers, sheets, menus, popups and course
/// cards do not drift in brightness or refraction.
///
/// Kept separate from HyperOS solid surfaces so gaussian blur tuning stays untouched.
abstract final class MikcbLiquidGlassTokens {
  /// Single liquid-glass material for every surface.
  ///
  /// 与 GlassTabBar 内部默认（kBottomBarGlassDefaults，iOS 26 Apple
  /// News/Safari tab bar 调校）保持一致：深折射、微模糊、24% 白、
  /// 135° 左上光源。全 app 玻璃统一为同一套观感。
  static const sheetSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.3,
    lightIntensity: 0.6,
    refractiveIndex: 1.59,
    saturation: 0.7,
    ambientStrength: 1,
    lightAngle: 0.75 * 3.14159265358979,
    glassColor: Color(0x3DFFFFFF),
  );

  /// Dark-mode material — same tuned look (matches the bar defaults).
  static const sheetSettingsDark = LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.3,
    lightIntensity: 0.6,
    refractiveIndex: 1.59,
    saturation: 0.7,
    ambientStrength: 1,
    lightAngle: 0.75 * 3.14159265358979,
    glassColor: Color(0x3DFFFFFF),
  );

  /// liquid_glass_widgets 底栏官方默认材质（kBottomBarGlassDefaults）镜像。
  ///
  /// 原常量在包内 `src/widgets/surfaces/tab_bar_bottom_internal.dart`，
  /// 未从包级导出，故按值复制；升级包版本时需与上游核对同步。
  ///
  /// 用途：玻璃坞「原版材质」形态下，bar 与 GlassButton 不传 settings
  /// 时各自回退到**不同**的内部默认（bar→kBottomBarGlassDefaults；
  /// button→DefaultButtonSettings/主题回退档），并排会呈现明显的玻璃
  /// 材质断层。把这份官方底栏材质同时显式传给药丸本体与右侧浮钮，
  /// 即可在「零自定义参数」的前提下保证两块玻璃完全同质。
  static const LiquidGlassSettings stockBottomBarGlass = LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.3,
    lightIntensity: 0.6,
    refractiveIndex: 1.59,
    saturation: 0.7,
    ambientStrength: 1,
    lightAngle: 0.75 * 3.14159265358979,
    glassColor: Color(0x3DFFFFFF),
  );

  /// 玻璃坞拖拽透镜（GlassTabBar.bottom 的 [LiquidGlassSettings]）。
  ///
  /// 用在 [GlassTabBar.bottom] 的 indicatorSettings 上：长按底栏滑出的
  /// 那颗「果冻玻璃」专用材质。包内默认（AnimatedGlassIndicator 的
  /// baseIndicatorSettings）是刻意调淡的 iOS 26 校准值——折射率仅
  /// 1.10、厚度 20、色散 0，在纯色壁纸/同色底上几乎看不出折射，观感
  /// 「跟底色一样平」。产品要求拖起时给最强的光折射，因此这里拉满：
  /// - refractiveIndex: 1.5 —— 应用「液态玻璃调校」滑杆的上限（≈玻璃），
  ///   远高于包默认的 1.10；
  /// - thickness: 36 —— 比 bar 本体（30）更厚，小透镜曲率更大，
  ///   边缘弯折更夸张；
  /// - chromaticAberration: 0.6 —— 明显的彩虹色散边，强化「真玻璃」
  ///   光学感（包默认 0 = 无色散；iOS 26 药丸默认也只有 0.15）；
  /// - ambientRim: 0 —— 不加边缘光环：光环会把整颗透镜罩上一层灰白，
  ///   看起来「和底下同色连成一体」。产品要求全透明只靠折射反射，
  ///   glassColor 保持构造默认的全透明；
  /// - blur: 0 —— 保持透镜内容锐利，只有折弯没有雾化。
  ///
  /// 注意合并语义：AnimatedGlassIndicator 会把 indicatorSettings 里
  /// 「不等于 LiquidGlassSettings() 构造默认值」的字段叠到
  /// baseIndicatorSettings 上。这里每个字段都不同于构造默认
  /// （thickness≠20、blur≠5、aberration≠0.01、ambientRim≠0、
  /// refractiveIndex≠1.2），因此全部会生效。
  ///
  /// 刻意不跟随「液态玻璃调校」（[LiquidGlassTuning]）：这是瞬时交互
  /// 强调件而非持久表面，固定最强档保证任何调校下拖起都有戏剧化的
  /// 折射反馈。
  static const dragLensSettings = LiquidGlassSettings(
    thickness: 36,
    blur: 0,
    chromaticAberration: 0.6,
    refractiveIndex: 1.5,
  );

  /// Squircle radius matching HyperOS card chrome when possible.
  static double sheetBorderRadius() => HyperosTokens.cardRadius;

  static double nestedTileBorderRadius() => HyperosTokens.cardRadius;

  /// Prefer [tuning] when provided; otherwise fall back to static presets.
  static LiquidGlassSettings sheetSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return brightness == Brightness.dark ? sheetSettingsDark : sheetSettings;
  }

  static LiquidGlassSettings nestedTileSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return sheetSettingsFor(brightness);
  }

  /// Course-card settings use the same material as every other surface.
  static LiquidGlassSettings courseCardSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return sheetSettingsFor(brightness);
  }
}
