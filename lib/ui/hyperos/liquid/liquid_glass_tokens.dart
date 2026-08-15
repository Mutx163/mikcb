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
  /// 与 liquid_glass_widgets 官方默认观感对齐（blur 5、极淡白 tint），
  /// 保证弹窗/顶栏/菜单与玻璃坞切换栏视觉一致。
  static const sheetSettings = LiquidGlassSettings(
    thickness: 20,
    blur: 5,
    glassColor: Color(0x1AFFFFFF),
  );

  /// Dark-mode material — same thickness/blur, slightly lower white tint.
  static const sheetSettingsDark = LiquidGlassSettings(
    thickness: 20,
    blur: 5,
    glassColor: Color(0x14FFFFFF),
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
