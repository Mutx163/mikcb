/// 柔光玻璃的用户可调参数（`SoftGlassSurface` 消费，作用到 flutter_miuix 的
/// OS4 玻璃材质上）。
///
/// 与 [LiquidGlassTuning]（液态玻璃）同构：预设枚举 + 自定义参数对象，
/// 设置页「高级材质」在柔光档下露出同一套 预设选择 + 滑杆 的 UI。
///
/// 雾面与底色用**倍率**表达：材质只有一个配方（`SoftGlassRecipe.standard`，
/// 基线 = 首页菜单 / 选择弹层那份上游材质 `popupViewGlass`，radius 60），档位的
/// 粗细完全由这里的倍率决定，最终写到上游 `MiuixGlassMaterial.blurRadius`；
/// 底色倍率缩放上游颜色层不透明度；边缘高光作用于上游 OS4 描边的三处高光。
///
/// 自研折射链路（`SoftGlassRefraction` shader）已删除，历史上存过的
/// refraction / depthEffect / chromaticAberration 字段在 [SoftGlassTuning.fromJson]
/// 里被忽略（旧备份导入不会报错）。
///
/// **档位阶梯的绝对量（改动前先看这张表）**：
/// | 档位 | 倍率 | radius |
/// |---|---|---|
/// | 清透 clear | 0.6 | 36 |
/// | 轻盈 light | 0.8 | 48 |
/// | **标准 standard** | 1.0 | 60（= 菜单 / 选择弹层同款） |
/// | 浓雾 dense | 1.6 | 96 |
/// | 滑杆上限 | 2.7 | 162 |
///
/// **`tintAlphaMultiplier` 作用在哪儿（调档位前先看这条）**：它线性缩放上游
/// `popupViewGlass` 的**三层颜色层** alpha——
/// | 层 | 颜色 | α | 模式 |
/// |---|---|---|---|
/// | first | `0x05000000` | 0.020 | plusDarker |
/// | second | `0x99FFFFFF` | 0.600 | softLight |
/// | third | `0x66FFFFFF` | 0.400 | hardLight |
///
/// 首层 α 只有 0.02，**乘任何倍率都看不出来**；档位的可见差异几乎全部来自
/// 第二、三层。所以"清透 ↔ 浓雾"的观感强弱，实质等于
/// 「0.6α / 0.4α 两层被乘了多少」——调参时盯这两层，不要指望首层。
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

  /// 清透 — 三个倍率一起压低（雾度 0.6 / 底色 0.55 / 描边 0.8）。
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
    // edgeHighlight 同默认值 1（= 上游描边原样），不必重复写。
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

  /// 雾面半径倍率：上游玻璃材质 blurRadius 的整体缩放（1 = 菜单同款）。
  static const double defaultBlurRadiusMultiplier = 1;
  static const double defaultTintAlphaMultiplier = 1;

  /// rim 高光强度（作用于上游 OS4 描边的三处高光）。
  ///
  /// **必须是 1.0**：标准档的对外承诺是"= 首页菜单 / 选择弹层原样"，
  /// 而 1.0 才是"不缩放上游描边"。历史上这里是 0.95（自研链路
  /// `SoftGlassTokens.edgeHighlightAlpha` 的数值），迁到上游后它变成
  /// **给菜单同款描边额外乘 0.95**，于是标准档其实比菜单暗一档，
  /// 与「标准档 = 菜单原样」的注释和测试用例名矛盾。
  static const double defaultEdgeHighlight = 1;

  // --- 滑杆范围 ---
  static const double minBlurRadiusMultiplier = 0;

  /// 滑杆上限：拉满 = 材质基线 60 × 2.7 = radius 162，远低于上游半径天花板 256。
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
