import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Opacity-oriented liquid-glass looks.
///
/// Built-ins only vary the package README's three primary knobs
/// (`thickness`, `blur`, `glassColor` alpha). All other fields stay at
/// [LiquidGlassSettings] constructor defaults.
///
/// [custom] keeps the last user-edited [LiquidGlassTuning] values.
enum LiquidGlassPreset {
  /// Very transparent — thin frost, low tint.
  clear,

  /// Light frost — still see-through.
  light,

  /// Package README medium glass (`thickness: 20`, `blur: 10`, `0x33FFFFFF`).
  standard,

  /// Dense milky glass — stronger frost and tint.
  dense,

  /// User-edited parameters.
  custom,
}

extension LiquidGlassPresetX on LiquidGlassPreset {
  String get value => switch (this) {
    LiquidGlassPreset.clear => 'clear',
    LiquidGlassPreset.light => 'light',
    LiquidGlassPreset.standard => 'standard',
    LiquidGlassPreset.dense => 'dense',
    LiquidGlassPreset.custom => 'custom',
  };

  static LiquidGlassPreset fromValue(String? value) {
    return LiquidGlassPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => LiquidGlassPreset.standard,
    );
  }

  /// Built-in looks only (excludes [custom]).
  static const List<LiquidGlassPreset> builtIns = [
    LiquidGlassPreset.clear,
    LiquidGlassPreset.light,
    LiquidGlassPreset.standard,
    LiquidGlassPreset.dense,
  ];

  /// Recommended tuning for this preset. [custom] falls back to [standard].
  LiquidGlassTuning get recommendedTuning => switch (this) {
    LiquidGlassPreset.clear => LiquidGlassTuning.presetClear,
    LiquidGlassPreset.light => LiquidGlassTuning.presetLight,
    LiquidGlassPreset.standard => LiquidGlassTuning.presetStandard,
    LiquidGlassPreset.dense => LiquidGlassTuning.presetDense,
    LiquidGlassPreset.custom => LiquidGlassTuning.presetStandard,
  };
}

/// User-tunable liquid-glass parameters (maps 1:1 to [LiquidGlassSettings]).
///
/// Defaults match the package README medium-glass example for the three
/// primary knobs, with remaining fields at [LiquidGlassSettings] defaults
/// (`lightIntensity` 0.5, `ambientStrength` 0, `saturation` 1.5, …).
class LiquidGlassTuning {
  const LiquidGlassTuning({
    this.thickness = defaultThickness,
    this.blur = defaultBlur,
    this.tintAlpha = defaultTintAlpha,
    this.lightIntensity = defaultLightIntensity,
    this.ambientStrength = defaultAmbientStrength,
    this.refractiveIndex = defaultRefractiveIndex,
    this.saturation = defaultSaturation,
    this.chromaticAberration = defaultChromaticAberration,
    this.lightAngleDegrees = defaultLightAngleDegrees,
    this.visibility = defaultVisibility,
  });

  static const defaults = LiquidGlassTuning();

  /// Package README medium glass (same as [defaults]).
  static const presetStandard = defaults;

  /// High transparency — only thickness / blur / tint vary.
  static const presetClear = LiquidGlassTuning(
    thickness: 12,
    blur: 2,
    tintAlpha: 0.05,
  );

  /// Light frost — only thickness / blur / tint vary.
  static const presetLight = LiquidGlassTuning(
    thickness: 16,
    blur: 4,
    tintAlpha: 0.10,
  );

  /// Dense milky glass — only thickness / blur / tint vary.
  static const presetDense = LiquidGlassTuning(
    thickness: 28,
    blur: 10,
    tintAlpha: 0.30,
  );

  /// Picks a built-in preset that matches [tuning], or [LiquidGlassPreset.custom].
  static LiquidGlassPreset matchPreset(LiquidGlassTuning tuning) {
    for (final preset in LiquidGlassPresetX.builtIns) {
      if (preset.recommendedTuning == tuning) {
        return preset;
      }
    }
    return LiquidGlassPreset.custom;
  }

  // --- Defaults ---
  // Primary three: liquid_glass_renderer README medium glass example.
  // Remaining: LiquidGlassSettings constructor defaults (0.2.0-dev.4).
  static const double defaultThickness = 20;
  static const double defaultBlur = 5;
  static const double defaultTintAlpha = 0.0;
  static const double defaultLightIntensity = 0.5;
  static const double defaultAmbientStrength = 0;
  static const double defaultRefractiveIndex = 1.20;
  static const double defaultSaturation = 1.5;
  static const double defaultChromaticAberration = 0.01;
  static const double defaultLightAngleDegrees = 90; // 0.5 * pi rad
  static const double defaultVisibility = 1.0;

  // --- Slider ranges ---
  static const double minThickness = 0;
  static const double maxThickness = 40;
  static const double minBlur = 0;
  static const double maxBlur = 24;
  static const double minTintAlpha = 0;
  static const double maxTintAlpha = 0.55;
  static const double minLightIntensity = 0;
  static const double maxLightIntensity = 2.0;
  static const double minAmbientStrength = 0;
  static const double maxAmbientStrength = 1.0;
  static const double minRefractiveIndex = 1.0;
  static const double maxRefractiveIndex = 1.5;
  static const double minSaturation = 0.5;
  static const double maxSaturation = 2.0;
  static const double minChromaticAberration = 0;
  static const double maxChromaticAberration = 0.12;
  static const double minLightAngleDegrees = 0;
  static const double maxLightAngleDegrees = 360;
  static const double minVisibility = 0;
  static const double maxVisibility = 1;

  /// Glass surface thickness — higher = stronger refraction.
  final double thickness;

  /// Frost blur of the glass surface.
  final double blur;

  /// White tint opacity (maps to [LiquidGlassSettings.glassColor] alpha).
  final double tintAlpha;

  /// Specular highlight strength.
  final double lightIntensity;

  /// Ambient light contribution.
  final double ambientStrength;

  /// Refraction index (≈1.0 air … ≈1.5 glass).
  final double refractiveIndex;

  /// Background saturation through glass (1 = unchanged).
  final double saturation;

  /// Color fringe amount (chromatic aberration).
  final double chromaticAberration;

  /// Light direction in degrees (0–360), converted to radians for the shader.
  final double lightAngleDegrees;

  /// Global scale for thickness-related shader properties (0–1).
  final double visibility;

  LiquidGlassTuning copyWith({
    double? thickness,
    double? blur,
    double? tintAlpha,
    double? lightIntensity,
    double? ambientStrength,
    double? refractiveIndex,
    double? saturation,
    double? chromaticAberration,
    double? lightAngleDegrees,
    double? visibility,
  }) {
    return LiquidGlassTuning(
      thickness: thickness ?? this.thickness,
      blur: blur ?? this.blur,
      tintAlpha: tintAlpha ?? this.tintAlpha,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      ambientStrength: ambientStrength ?? this.ambientStrength,
      refractiveIndex: refractiveIndex ?? this.refractiveIndex,
      saturation: saturation ?? this.saturation,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      lightAngleDegrees: lightAngleDegrees ?? this.lightAngleDegrees,
      visibility: visibility ?? this.visibility,
    );
  }

  LiquidGlassTuning clamped() {
    return LiquidGlassTuning(
      thickness: thickness.clamp(minThickness, maxThickness),
      blur: blur.clamp(minBlur, maxBlur),
      tintAlpha: tintAlpha.clamp(minTintAlpha, maxTintAlpha),
      lightIntensity: lightIntensity.clamp(
        minLightIntensity,
        maxLightIntensity,
      ),
      ambientStrength: ambientStrength.clamp(
        minAmbientStrength,
        maxAmbientStrength,
      ),
      refractiveIndex: refractiveIndex.clamp(
        minRefractiveIndex,
        maxRefractiveIndex,
      ),
      saturation: saturation.clamp(minSaturation, maxSaturation),
      chromaticAberration: chromaticAberration.clamp(
        minChromaticAberration,
        maxChromaticAberration,
      ),
      lightAngleDegrees: lightAngleDegrees.clamp(
        minLightAngleDegrees,
        maxLightAngleDegrees,
      ),
      visibility: visibility.clamp(minVisibility, maxVisibility),
    );
  }

  /// Builds official [LiquidGlassSettings] for sheet / dialog panels.
  LiquidGlassSettings toSheetSettings({required Brightness brightness}) {
    final tint = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: (tintAlpha * 0.85).clamp(0.0, 1.0))
        : Colors.white.withValues(alpha: tintAlpha.clamp(0.0, 1.0));
    return LiquidGlassSettings(
      thickness: thickness,
      blur: blur,
      glassColor: tint,
      lightIntensity: lightIntensity,
      ambientStrength: ambientStrength,
      refractiveIndex: refractiveIndex,
      saturation: saturation,
      chromaticAberration: chromaticAberration,
      lightAngle: lightAngleDegrees * math.pi / 180.0,
      visibility: visibility,
    );
  }

  /// Same material as sheets; nested tiles no longer scale the primary knobs.
  LiquidGlassSettings toNestedTileSettings({required Brightness brightness}) {
    return toSheetSettings(brightness: brightness);
  }

  /// Same material as sheets; course cards no longer get a separate glass look.
  LiquidGlassSettings toCourseCardSettings({required Brightness brightness}) {
    return toSheetSettings(brightness: brightness);
  }

  Map<String, dynamic> toJson() => {
    'thickness': thickness,
    'blur': blur,
    'tintAlpha': tintAlpha,
    'lightIntensity': lightIntensity,
    'ambientStrength': ambientStrength,
    'refractiveIndex': refractiveIndex,
    'saturation': saturation,
    'chromaticAberration': chromaticAberration,
    'lightAngleDegrees': lightAngleDegrees,
    'visibility': visibility,
  };

  factory LiquidGlassTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }
    return LiquidGlassTuning(
      thickness: (json['thickness'] as num?)?.toDouble() ?? defaultThickness,
      blur: (json['blur'] as num?)?.toDouble() ?? defaultBlur,
      tintAlpha: (json['tintAlpha'] as num?)?.toDouble() ?? defaultTintAlpha,
      lightIntensity:
          (json['lightIntensity'] as num?)?.toDouble() ?? defaultLightIntensity,
      ambientStrength:
          (json['ambientStrength'] as num?)?.toDouble() ??
          defaultAmbientStrength,
      refractiveIndex:
          (json['refractiveIndex'] as num?)?.toDouble() ??
          defaultRefractiveIndex,
      saturation: (json['saturation'] as num?)?.toDouble() ?? defaultSaturation,
      chromaticAberration:
          (json['chromaticAberration'] as num?)?.toDouble() ??
          defaultChromaticAberration,
      lightAngleDegrees:
          (json['lightAngleDegrees'] as num?)?.toDouble() ??
          defaultLightAngleDegrees,
      visibility: (json['visibility'] as num?)?.toDouble() ?? defaultVisibility,
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassTuning &&
          thickness == other.thickness &&
          blur == other.blur &&
          tintAlpha == other.tintAlpha &&
          lightIntensity == other.lightIntensity &&
          ambientStrength == other.ambientStrength &&
          refractiveIndex == other.refractiveIndex &&
          saturation == other.saturation &&
          chromaticAberration == other.chromaticAberration &&
          lightAngleDegrees == other.lightAngleDegrees &&
          visibility == other.visibility;

  @override
  int get hashCode => Object.hash(
    thickness,
    blur,
    tintAlpha,
    lightIntensity,
    ambientStrength,
    refractiveIndex,
    saturation,
    chromaticAberration,
    lightAngleDegrees,
    visibility,
  );
}
