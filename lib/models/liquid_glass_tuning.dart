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
///
/// 唯一的例外是 `edgeAbsorption` / `fresnelStrength`：这两个量**不是**用户
/// 参数，而是由 [thickness] 折算出来的可见光学量（见
/// [visibleThicknessOptics]）——当前全 app 跑 standard 渲染档，厚度在那里
/// 只剩不可辨的边缘 rim，必须靠这两个通道把「厚度」重新变成看得见的调节。
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
  ///
  /// 注意 thickness 24 低于枢轴 30：standard 档下这会**降低**边缘高光
  /// （比标准档更「薄片」），与它「清澈」的定位一致。
  static const presetClear = LiquidGlassTuning(
    thickness: 24,
    blur: 2,
    tintAlpha: 0.08,
  );

  /// Light frost — only thickness / blur / tint vary.
  static const presetLight = LiquidGlassTuning(
    thickness: 26,
    tintAlpha: 0.16,
  );

  /// Dense milky glass — only thickness / blur / tint vary.
  static const presetDense = LiquidGlassTuning(
    thickness: 36,
    blur: 6,
    tintAlpha: 0.40,
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
  static const double defaultThickness = 30;
  static const double defaultBlur = 3;
  static const double defaultTintAlpha = 0.24; // Color(0x3DFFFFFF).a
  static const double defaultLightIntensity = 0.6;
  static const double defaultAmbientStrength = 1;
  // 默认折射率与滑杆上限(maxRefractiveIndex=1.5)对齐：原默认 1.59
  // 超出上限，fromJson 经 clamp() 后持久化值漂移到 1.5，与内存默认
  // 不一致（首次保存前后观感跳变）。取上限值本身，行为可预期。
  static const double defaultRefractiveIndex = 1.5;
  static const double defaultSaturation = 0.7;
  // 默认色差与滑杆上限对齐（原 0.3 超出上限 0.12 → 真机表现为玻璃边缘
  // 一条彩虹描边）。成因与上面 refractiveIndex 那次同型：构造默认落在
  // 自己的滑杆区间外，UI 显示与内存默认脱节，且用户把滑杆拖到最左也关不
  // 干净（clamp 到 0.12 仍有 1.4dp 级 RGB 分离）。取上限值本身：既保留
  // iOS 26 药丸的色散手感，又让滑杆两端都能真正到达。
  static const double defaultChromaticAberration = 0.12;
  static const double defaultLightAngleDegrees = 135; // 0.75 * pi rad（官方默认，左上光源）
  static const double defaultVisibility = 1;

  // --- Slider ranges ---
  static const double minThickness = 0;
  static const double maxThickness = 40;
  static const double minBlur = 0;
  static const double maxBlur = 24;
  static const double minTintAlpha = 0;
  static const double maxTintAlpha = 0.55;
  static const double minLightIntensity = 0;
  static const double maxLightIntensity = 2;
  static const double minAmbientStrength = 0;
  static const double maxAmbientStrength = 1;
  static const double minRefractiveIndex = 1;
  static const double maxRefractiveIndex = 1.5;
  static const double minSaturation = 0.5;
  static const double maxSaturation = 2;
  static const double minChromaticAberration = 0;
  static const double maxChromaticAberration = 0.12;
  static const double minLightAngleDegrees = 0;
  static const double maxLightAngleDegrees = 360;
  static const double minVisibility = 0;
  static const double maxVisibility = 1;

  // --- 厚度 → 可见光学量映射（standard 档补偿）---
  // 当前全 app 统一跑 GlassQuality.standard（MikcbLiquidGlassTokens.defaultQuality），
  // 包内走 lightweight_glass.frag，而它的折射位移只在 PATH A（拿到了背景纹理、
  // uBackgroundSize.x > 1）里执行；本项目从未安装 LiquidGlassScope / 传
  // backgroundKey，故恒走 PATH B——thickness 在那里只剩「边缘 rim 透明度
  // ±0.3」，肉眼基本不可辨，滑杆 0..40 拉满观感不变（真机症状：「透明高斯
  // 模糊、没有玻璃效果」）。
  //
  // 修法：把归一化厚度同时映射到 PATH B 里真正生效的两个光学量，让「厚度」
  // 重新有连续的可见反馈，而不必退回 premium（那一档曾把首页拖到 60fps）：
  //   edgeAbsorption  —— 边缘光吸收，弧面越厚边缘越沉（厚度存在感）
  //   fresnelStrength —— 掠射角边缘高光，浅色模式下 rimFade≈0.08 压不住它，
  //                      是浅色/深色都看得见的通道
  // 两个量在 premium 档同样会被消费，映射在两种档位下都成立。
  //
  // 关键：默认厚度 30/40 是**枢轴点**，此处两个量恰好等于 LiquidGlassSettings
  // 的构造默认（0.0 / 1.0），因此出厂默认观感与历史版本逐字段一致；只有用户
  // 主动偏离默认厚度才会看到补偿。

  /// 枢轴厚度占比 = [defaultThickness] / [maxThickness]（30 / 40）。
  static const double thicknessPivotFraction = 0.75;

  /// 达到 [maxThickness] 时的边缘光吸收上限（包文档推荐 0.10–0.20 物理厚度区间）。
  static const double maxThicknessEdgeAbsorption = 0.20;

  /// 达到 [maxThickness] 时掠射角边缘高光的放大倍率。
  static const double maxThicknessFresnelBoost = 0.6;

  /// Glass surface thickness — higher = stronger refraction.
  ///
  /// 同时驱动两个渲染档的可见反馈：
  /// - premium / 拿到背景纹理的档：直接就是几何厚度 = 折射位移；
  /// - standard 档（当前）：折射位移不执行，改由 [visibleThicknessOptics]
  ///   折算的边缘吸收与掠射高光承载，默认厚度 30 为枢轴（观感不变）。
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

  /// 把当前厚度折算成 standard 档真正可见的两个光学量。
  ///
  /// 见 [thicknessPivotFraction] 一节的说明。口径按**有效厚度**
  /// （[thickness] × [visibility]）计算，与包内
  /// `effectiveThickness` 同源，因此「可见性」拉低时厚度观感一起变薄，
  /// 两个滑杆不会互相矛盾。
  ///
  /// 返回值恒在包内 clamp 窗口内（absorption 0..1、fresnel 0..4），
  /// 且对有效厚度单调不减：
  /// - 0  → absorption 0.0 / fresnel 0.0（完全无边缘，纸片感）
  /// - 30（默认，枢轴）→ 0.0 / 1.0（= 包构造默认，出厂观感不变）
  /// - 40（上限）→ [maxThicknessEdgeAbsorption] / 1 + [maxThicknessFresnelBoost]
  ({double edgeAbsorption, double fresnelStrength}) visibleThicknessOptics() {
    final double effective = (thickness * visibility).clamp(
      minThickness,
      maxThickness,
    );
    final double fraction = (effective / maxThickness).clamp(0.0, 1.0);
    // 枢轴以上：越厚越沉越亮。
    final double thicker = ((fraction - thicknessPivotFraction) /
            (1 - thicknessPivotFraction))
        .clamp(0.0, 1.0);
    // 枢轴以下：越薄越平，0 厚度时边缘高光完全消失。
    final double thinner =
        ((thicknessPivotFraction - fraction) / thicknessPivotFraction)
            .clamp(0.0, 1.0);
    return (
      edgeAbsorption: maxThicknessEdgeAbsorption * thicker,
      fresnelStrength: 1.0 +
          maxThicknessFresnelBoost * thicker -
          thinner,
    );
  }

  /// Builds official [LiquidGlassSettings] for sheet / dialog panels.
  ///
  /// **不在本方法里做厚度补偿**：厚度折算成 edgeAbsorption / fresnelStrength
  /// 只在 PATH B（没拿到背景纹理、折射位移不执行）下才是必要的，而这属于
  /// **渲染路径**的信息，应当由表面层决定。HyperosLiquidGlassSurface 会按
  /// usesRefractingPath 二选一调用 withThicknessOptics（PATH A，只留真实折
  /// 射）/ withoutThicknessOptics（PATH B，把折算量写进来）。若在此处无条件
  /// 写入，PATH A 表面就会双重计数（真实折射 + 边缘变沉变亮），且
  /// `tuning == null` 的兜底档拿不到同一处理，两条路观感分叉。
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
