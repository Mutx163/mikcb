/// 柔光玻璃的用户可调参数（`lib/ui/hyperos/soft_glass/` 渲染链路消费）。
///
/// 与 [LiquidGlassTuning]（液态玻璃）同构：预设枚举 + 自定义参数对象，
/// 设置页「高级材质」在柔光档下露出同一套 预设选择 + 滑杆 的 UI。
///
/// 雾面与底色用**倍率**表达：柔光的模糊半径按表面配方分层（底栏 σ≈13.8 /
/// 弹窗 σ≈53.6，见 `SoftGlassRecipe`），绝对值会把轻配方一并拉爆；倍率保持
/// 「面板永远比底栏厚一层」的层级关系，只整体缩放。折射/色散是上游
/// `GlassRefractionSpec` 的绝对 dp 口径，厚度感与边缘高光是 0..1 权重。
///
/// 默认值 = 当前渲染链路的硬编码常量（`SoftGlassRefraction` /
/// `SoftGlassTokens`），保证接入调参前后默认观感逐像素一致；test/models/
/// soft_glass_tuning_test.dart 有字段级守卫，两边漂移会直接红。
enum SoftGlassPreset {
  /// 清透 — 薄雾淡底色，最接近裸壁纸。
  clear,

  /// 轻盈 — 比标准薄一档的雾面。
  light,

  /// 标准 — 与上游 Hyper-PiliPlus（Deadliner）默认档一致。
  standard,

  /// 浓雾 — 更厚的雾面与更强的折射。
  dense,

  /// 用户自定参数（保留最后一次滑杆值）。
  custom,
}

extension SoftGlassPresetX on SoftGlassPreset {
  String get value => switch (this) {
    SoftGlassPreset.clear => 'clear',
    SoftGlassPreset.light => 'light',
    SoftGlassPreset.standard => 'standard',
    SoftGlassPreset.dense => 'dense',
    SoftGlassPreset.custom => 'custom',
  };

  static SoftGlassPreset fromValue(String? value) {
    return SoftGlassPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SoftGlassPreset.standard,
    );
  }

  /// 内置观感（不含 [custom]）。
  static const List<SoftGlassPreset> builtIns = [
    SoftGlassPreset.clear,
    SoftGlassPreset.light,
    SoftGlassPreset.standard,
    SoftGlassPreset.dense,
  ];

  /// 该预设的推荐参数。[custom] 回落 [standard]。
  SoftGlassTuning get recommendedTuning => switch (this) {
    SoftGlassPreset.clear => SoftGlassTuning.presetClear,
    SoftGlassPreset.light => SoftGlassTuning.presetLight,
    SoftGlassPreset.standard => SoftGlassTuning.presetStandard,
    SoftGlassPreset.dense => SoftGlassTuning.presetDense,
    SoftGlassPreset.custom => SoftGlassTuning.presetStandard,
  };
}

/// 柔光玻璃参数（设置页滑杆 ↔ 渲染链路 1:1）。
class SoftGlassTuning {
  const SoftGlassTuning({
    this.blurRadiusMultiplier = defaultBlurRadiusMultiplier,
    this.tintAlphaMultiplier = defaultTintAlphaMultiplier,
    this.refraction = defaultRefraction,
    this.depthEffect = defaultDepthEffect,
    this.chromaticAberration = defaultChromaticAberration,
    this.edgeHighlight = defaultEdgeHighlight,
  });

  static const defaults = SoftGlassTuning();

  /// 标准（[SoftGlassPreset.standard]）。
  static const presetStandard = defaults;

  /// 清透 — 只动倍率与折射量。
  static const presetClear = SoftGlassTuning(
    blurRadiusMultiplier: 0.6,
    tintAlphaMultiplier: 0.55,
    refraction: 14,
    depthEffect: 0.5,
    chromaticAberration: 0.6,
    edgeHighlight: 0.8,
  );

  /// 轻盈。
  static const presetLight = SoftGlassTuning(
    blurRadiusMultiplier: 0.8,
    tintAlphaMultiplier: 0.75,
    refraction: 16,
    depthEffect: 0.55,
    chromaticAberration: 0.8,
    edgeHighlight: 0.9,
  );

  /// 浓雾。
  static const presetDense = SoftGlassTuning(
    blurRadiusMultiplier: 1.6,
    tintAlphaMultiplier: 1.3,
    refraction: 22,
    depthEffect: 0.7,
    chromaticAberration: 1.2,
    edgeHighlight: 1,
  );

  /// 按参数反查内置预设，不匹配任意一档即为 [SoftGlassPreset.custom]。
  static SoftGlassPreset matchPreset(SoftGlassTuning tuning) {
    for (final preset in SoftGlassPresetX.builtIns) {
      if (preset.recommendedTuning == tuning) {
        return preset;
      }
    }
    return SoftGlassPreset.custom;
  }

  // --- 默认值（= 渲染链路硬编码常量，漂移会被测试拦下） ---

  /// 雾面半径倍率：各表面配方（底栏 / 弹窗）blurRadiusDp 的整体缩放。
  static const double defaultBlurRadiusMultiplier = 1;
  static const double defaultTintAlphaMultiplier = 1;

  /// 折射带宽度与最大位移（dp，两者共用一值——上游两者同为 18dp，
  /// 透镜剖面在任意带宽下形状一致）。
  static const double defaultRefraction = 18;

  /// 厚度感：法线里径向分量的权重（shader 内 clamp 0..1）。
  static const double defaultDepthEffect = 0.60;

  /// 色散偏移（dp）。
  static const double defaultChromaticAberration = 1;

  /// rim 高光强度（暗色另有 0.20 折减，见 SoftGlassTokens.edgeAlphaOf）。
  static const double defaultEdgeHighlight = 0.95;

  // --- 滑杆范围 ---
  static const double minBlurRadiusMultiplier = 0;
  static const double maxBlurRadiusMultiplier = 3;
  static const double minTintAlphaMultiplier = 0;
  static const double maxTintAlphaMultiplier = 2;
  static const double minRefraction = 0;
  static const double maxRefraction = 30;
  static const double minDepthEffect = 0;
  static const double maxDepthEffect = 1;
  static const double minChromaticAberration = 0;
  static const double maxChromaticAberration = 3;
  static const double minEdgeHighlight = 0;
  static const double maxEdgeHighlight = 1;

  /// 雾面半径倍率（0 = 无模糊纯底色，1 = 当前默认，3 = 最厚）。
  final double blurRadiusMultiplier;

  /// 底色不透明度倍率（作用于各表面配方的最终底色 alpha 之上）。
  final double tintAlphaMultiplier;

  /// 折射带宽度 / 最大位移（dp，绝对值）。
  final double refraction;

  /// 厚度感：折射法线的径向权重，越大越像实心厚玻璃。
  final double depthEffect;

  /// 边缘色散偏移（dp）。
  final double chromaticAberration;

  /// rim 高光强度（shader 方向性高光 + Dart 0.5dp 描边共用）。
  final double edgeHighlight;

  SoftGlassTuning copyWith({
    double? blurRadiusMultiplier,
    double? tintAlphaMultiplier,
    double? refraction,
    double? depthEffect,
    double? chromaticAberration,
    double? edgeHighlight,
  }) {
    return SoftGlassTuning(
      blurRadiusMultiplier: blurRadiusMultiplier ?? this.blurRadiusMultiplier,
      tintAlphaMultiplier: tintAlphaMultiplier ?? this.tintAlphaMultiplier,
      refraction: refraction ?? this.refraction,
      depthEffect: depthEffect ?? this.depthEffect,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      edgeHighlight: edgeHighlight ?? this.edgeHighlight,
    );
  }

  SoftGlassTuning clamped() {
    return SoftGlassTuning(
      blurRadiusMultiplier: blurRadiusMultiplier.clamp(
        minBlurRadiusMultiplier,
        maxBlurRadiusMultiplier,
      ),
      tintAlphaMultiplier: tintAlphaMultiplier.clamp(
        minTintAlphaMultiplier,
        maxTintAlphaMultiplier,
      ),
      refraction: refraction.clamp(minRefraction, maxRefraction),
      depthEffect: depthEffect.clamp(minDepthEffect, maxDepthEffect),
      chromaticAberration: chromaticAberration.clamp(
        minChromaticAberration,
        maxChromaticAberration,
      ),
      edgeHighlight: edgeHighlight.clamp(minEdgeHighlight, maxEdgeHighlight),
    );
  }

  Map<String, dynamic> toJson() => {
    'blurRadiusMultiplier': blurRadiusMultiplier,
    'tintAlphaMultiplier': tintAlphaMultiplier,
    'refraction': refraction,
    'depthEffect': depthEffect,
    'chromaticAberration': chromaticAberration,
    'edgeHighlight': edgeHighlight,
  };

  factory SoftGlassTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }
    return SoftGlassTuning(
      blurRadiusMultiplier:
          (json['blurRadiusMultiplier'] as num?)?.toDouble() ??
          defaultBlurRadiusMultiplier,
      tintAlphaMultiplier:
          (json['tintAlphaMultiplier'] as num?)?.toDouble() ??
          defaultTintAlphaMultiplier,
      refraction: (json['refraction'] as num?)?.toDouble() ?? defaultRefraction,
      depthEffect:
          (json['depthEffect'] as num?)?.toDouble() ?? defaultDepthEffect,
      chromaticAberration:
          (json['chromaticAberration'] as num?)?.toDouble() ??
          defaultChromaticAberration,
      edgeHighlight:
          (json['edgeHighlight'] as num?)?.toDouble() ?? defaultEdgeHighlight,
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoftGlassTuning &&
          blurRadiusMultiplier == other.blurRadiusMultiplier &&
          tintAlphaMultiplier == other.tintAlphaMultiplier &&
          refraction == other.refraction &&
          depthEffect == other.depthEffect &&
          chromaticAberration == other.chromaticAberration &&
          edgeHighlight == other.edgeHighlight;

  @override
  int get hashCode => Object.hash(
    blurRadiusMultiplier,
    tintAlphaMultiplier,
    refraction,
    depthEffect,
    chromaticAberration,
    edgeHighlight,
  );
}
