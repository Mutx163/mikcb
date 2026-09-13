/// 柔光玻璃的用户可调参数（`SoftGlassSurface` 消费，作用到 flutter_miuix 的
/// OS4 玻璃材质上）。
///
/// 与 [LiquidGlassTuning]（液态玻璃）同构：预设枚举 + 自定义参数对象，
/// 设置页「高级材质」在柔光档下露出同一套 预设选择 + 滑杆 的 UI。
///
/// 雾面与底色用**倍率**表达：材质只有一个配方（`SoftGlassRecipe.standard`，
/// 上游默认 radius 92 → σ ≈ 53.6），档位的粗细完全由这里的倍率决定，最终写到
/// 上游 `MiuixGlassMaterial.blurRadius`；底色倍率缩放上游颜色层不透明度；
/// 边缘高光作用于上游 OS4 描边的三处高光。
///
/// 自研折射链路（`SoftGlassRefraction` shader）已删除，历史上存过的
/// refraction / depthEffect / chromaticAberration 字段在 [SoftGlassTuning.fromJson]
/// 里被忽略（旧备份导入不会报错）。
///
/// **档位阶梯的绝对量（改动前先看这张表）**：
/// | 档位 | 倍率 | radius | sigma |
/// |---|---|---|---|
/// | 清透 clear | 0.6 | 55.2 | ≈ 32.4 |
/// | 轻盈 light | 0.8 | 73.6 | ≈ 43.0 |
/// | **标准 standard** | 1.0 | 92 | ≈ 53.6 |
/// | 浓雾 dense | 1.6 | 147.2 | ≈ 85.5 |
/// | 滑杆上限 | 2.7 | 248.4 | ≈ 144.0 |
///
/// 上限 2.7 = 上游 radius 天花板 256 ÷ 基准 92（≈2.78）向下取余量。
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
    this.edgeHighlight = defaultEdgeHighlight,
  });

  static const defaults = SoftGlassTuning();

  /// 标准（[SoftGlassPreset.standard]）。
  static const presetStandard = defaults;

  /// 清透 — 只动倍率与折射量。
  static const presetClear = SoftGlassTuning(
    blurRadiusMultiplier: 0.6,
    tintAlphaMultiplier: 0.55,
    edgeHighlight: 0.8,
  );

  /// 轻盈。
  static const presetLight = SoftGlassTuning(
    blurRadiusMultiplier: 0.8,
    tintAlphaMultiplier: 0.75,
    edgeHighlight: 0.9,
  );

  /// 浓雾。
  static const presetDense = SoftGlassTuning(
    blurRadiusMultiplier: 1.6,
    tintAlphaMultiplier: 1.3,
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

  /// rim 高光强度（作用于上游 OS4 描边的三处高光）。
  static const double defaultEdgeHighlight = 0.95;

  // --- 滑杆范围 ---
  static const double minBlurRadiusMultiplier = 0;

  /// 滑杆上限。上游 radius 天花板 256 ÷ 材质基准 92（≈2.78），取 2.7 留余量：
  /// 拉满 = radius 248.4 → σ ≈ 144，仍在上游允许的半径内。
  ///
  /// 此前是 3.0——那是「轻盈档基线（radius 23）」时代的旧值，换成标准基线后
  /// 会算出 radius 276 > 256，越界，故随本轮档位重测收紧。
  static const double maxBlurRadiusMultiplier = 2.7;
  static const double minTintAlphaMultiplier = 0;
  static const double maxTintAlphaMultiplier = 2;
  static const double minEdgeHighlight = 0;
  static const double maxEdgeHighlight = 1;

  /// 雾面半径倍率（0 = 无模糊纯底色，1 = 配方半径原样）。
  final double blurRadiusMultiplier;

  /// 底色不透明度倍率（作用于各表面配方的最终底色 alpha 之上）。
  final double tintAlphaMultiplier;

  /// rim 高光强度（作用于上游 OS4 描边的三处高光）。
  final double edgeHighlight;

  SoftGlassTuning copyWith({
    double? blurRadiusMultiplier,
    double? tintAlphaMultiplier,
    double? edgeHighlight,
  }) {
    return SoftGlassTuning(
      blurRadiusMultiplier: blurRadiusMultiplier ?? this.blurRadiusMultiplier,
      tintAlphaMultiplier: tintAlphaMultiplier ?? this.tintAlphaMultiplier,
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
      edgeHighlight: edgeHighlight.clamp(minEdgeHighlight, maxEdgeHighlight),
    );
  }

  Map<String, dynamic> toJson() => {
    'blurRadiusMultiplier': blurRadiusMultiplier,
    'tintAlphaMultiplier': tintAlphaMultiplier,
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
          edgeHighlight == other.edgeHighlight;

  @override
  int get hashCode =>
      Object.hash(blurRadiusMultiplier, tintAlphaMultiplier, edgeHighlight);
}
