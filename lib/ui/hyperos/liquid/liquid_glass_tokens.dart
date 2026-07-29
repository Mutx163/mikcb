import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../hyperos_tokens.dart';

/// Fallback [liquid_glass_renderer] settings for mikcb liquid glass.
///
/// Sheet defaults match the package README medium-glass example
/// (`thickness: 20`, `blur: 10`, `glassColor: 0x33FFFFFF`). Nested tiles only
/// reduce those three knobs so stacked glass still reads as separate layers.
///
/// Kept separate from HyperOS solid surfaces so gaussian blur tuning stays untouched.
abstract final class MikcbLiquidGlassTokens {
  /// Sheet / dialog panel — package README medium glass.
  static const sheetSettings = LiquidGlassSettings(
    thickness: 20,
    blur: 10,
    glassColor: Color(0x33FFFFFF),
  );

  /// Nested menu tiles over a liquid sheet — thinner on the three primary knobs.
  static const nestedTileSettings = LiquidGlassSettings(
    thickness: 14,
    blur: 8,
    glassColor: Color(0x28FFFFFF),
  );

  /// Dark-mode sheet — same thickness/blur, slightly lower white tint.
  static const sheetSettingsDark = LiquidGlassSettings(
    thickness: 20,
    blur: 10,
    glassColor: Color(0x28FFFFFF),
  );

  static const nestedTileSettingsDark = LiquidGlassSettings(
    thickness: 14,
    blur: 8,
    glassColor: Color(0x1FFFFFFF),
  );

  /// Timetable course cards — lighter frost than sheets.
  ///
  /// Dense grids share one [LiquidGlassLayer] per day column. Keep blur /
  /// thickness below sheet levels so multi-shape real refraction stays affordable.
  static const courseCardSettings = LiquidGlassSettings(
    thickness: 12,
    blur: 5,
    glassColor: Color(0x28FFFFFF),
    chromaticAberration: 0,
    lightIntensity: 0.35,
    ambientStrength: 0,
    saturation: 1.2,
  );

  static const courseCardSettingsDark = LiquidGlassSettings(
    thickness: 12,
    blur: 5,
    glassColor: Color(0x1FFFFFFF),
    chromaticAberration: 0,
    lightIntensity: 0.30,
    ambientStrength: 0,
    saturation: 1.15,
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
      return tuning.toNestedTileSettings(brightness: brightness);
    }
    return brightness == Brightness.dark
        ? nestedTileSettingsDark
        : nestedTileSettings;
  }

  /// Course-card settings: user tuning scaled down for multi-instance grids.
  static LiquidGlassSettings courseCardSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toCourseCardSettings(brightness: brightness);
    }
    return brightness == Brightness.dark
        ? courseCardSettingsDark
        : courseCardSettings;
  }
}
