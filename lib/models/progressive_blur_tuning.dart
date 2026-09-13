/// 渐进（渐变）模糊的用户可调参数（顶栏玻璃带的 inspire 档消费）。
///
/// 与 `SoftGlassTuning` / `LiquidGlassTuning` 同构：预设枚举 + 自定义参数对象，
/// 设置页「高级材质」里露出同一套 预设选择 + 滑杆 的 UI。
///
/// 三个轴都直接对应渲染链路（`InspireHeaderBlur` → `InspireBlurConfig`）：
/// - [sigma]：模糊强度上限（高斯 sigma，逻辑像素），自顶边向下按 [extent] 衰减；
/// - [extent]：**渐变延伸**——模糊自顶边衰减到 0 的位置占玻璃带宽度的比例。
///   1.0 = 完全清晰正好落在带底（与课表衔接处无残留模糊切边）；
///   <1 收得更早（带子下半段更清）；>1 则到带底仍有残留模糊。
/// - [tintBottomScale]：衬底在底边保留的不透明度比例。0 = 衬底同样向下渐隐到
///   全透明，玻璃带与内容之间不出现可见切边；>0 会在带底压出一条底色。
///
/// 默认值 = 接入调参前渲染链路的硬编码常量（σ 15 / extent 1.0 / 底边 0），
/// 保证默认观感逐像素不变；test/models/progressive_blur_tuning_test.dart
/// 有字段级守卫（含与 `kDefaultFrostedSheetBlurSigma` 的一致性），两边漂移会红。
enum ProgressiveBlurPreset {
  /// 清透 — 薄雾 + 渐变更早收干，最接近裸背景。
  clear,

  /// 轻盈 — 比标准薄一档。
  light,

  /// 标准 — 与接入调参前的顶栏渐进模糊逐字段一致。
  standard,

  /// 浓雾 — 更厚的雾面，底边留一点衬底压住衔接处。
  dense,

  /// 用户自定参数（保留最后一次滑杆值）。
  custom,
}

extension ProgressiveBlurPresetX on ProgressiveBlurPreset {
  String get value => switch (this) {
    ProgressiveBlurPreset.clear => 'clear',
    ProgressiveBlurPreset.light => 'light',
    ProgressiveBlurPreset.standard => 'standard',
    ProgressiveBlurPreset.dense => 'dense',
    ProgressiveBlurPreset.custom => 'custom',
  };

  static ProgressiveBlurPreset fromValue(String? value) {
    return ProgressiveBlurPreset.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ProgressiveBlurPreset.standard,
    );
  }

  /// 内置观感（不含 [custom]）。
  static const List<ProgressiveBlurPreset> builtIns = [
    ProgressiveBlurPreset.clear,
    ProgressiveBlurPreset.light,
    ProgressiveBlurPreset.standard,
    ProgressiveBlurPreset.dense,
  ];

  /// 该预设的推荐参数。[custom] 回落 [standard]。
  ProgressiveBlurTuning get recommendedTuning => switch (this) {
    ProgressiveBlurPreset.clear => ProgressiveBlurTuning.presetClear,
    ProgressiveBlurPreset.light => ProgressiveBlurTuning.presetLight,
    ProgressiveBlurPreset.standard => ProgressiveBlurTuning.presetStandard,
    ProgressiveBlurPreset.dense => ProgressiveBlurTuning.presetDense,
    ProgressiveBlurPreset.custom => ProgressiveBlurTuning.presetStandard,
  };
}

/// 渐进模糊参数（设置页滑杆 ↔ 渲染链路 1:1）。
class ProgressiveBlurTuning {
  const ProgressiveBlurTuning({
    this.sigma = defaultSigma,
    this.extent = defaultExtent,
    this.tintBottomScale = defaultTintBottomScale,
  });

  static const defaults = ProgressiveBlurTuning();

  /// 标准（[ProgressiveBlurPreset.standard]）。
  static const presetStandard = defaults;

  /// 清透 — 薄雾 + 渐变更早收干。
  static const presetClear = ProgressiveBlurTuning(
    sigma: 8,
    extent: 0.7,
  );

  /// 轻盈。
  static const presetLight = ProgressiveBlurTuning(
    sigma: 12,
    extent: 0.85,
  );

  /// 浓雾 — 更厚的雾面。
  ///
  /// **档位一律不留底边衬底**（[tintBottomScale] 保持 0）：衬底在带底只要不是
  /// 全透明，就会在「玻璃带 / 下方内容」交界处切出一条横向硬边——浓雾档曾给
  /// 0.18，真机口径「最浓状态下底部出现一条横向」。档位只调浓度与延伸。
  static const presetDense = ProgressiveBlurTuning(sigma: 22);

  /// 按参数反查内置预设，不匹配任意一档即为 [ProgressiveBlurPreset.custom]。
  static ProgressiveBlurPreset matchPreset(ProgressiveBlurTuning tuning) {
    for (final preset in ProgressiveBlurPresetX.builtIns) {
      if (preset.recommendedTuning == tuning) {
        return preset;
      }
    }
    return ProgressiveBlurPreset.custom;
  }

  // --- 默认值（= 渲染链路硬编码常量，漂移会被测试拦下） ---

  /// 模糊强度上限：等于全局高斯 sigma 常量
  /// `kDefaultFrostedSheetBlurSigma`（15）——顶栏渐进档接入调参前用的就是它。
  static const double defaultSigma = 15;

  /// 渐变延伸：1 = 完全清晰正好落在带底。
  static const double defaultExtent = 1;

  /// 下部衬底浓度：0 = 完全不额外加衬底（默认）。
  ///
  /// 注意它与「底边残留」不是一回事：衬底层永远在带底渐隐到全透明（见
  /// `InspireHeaderBlur.tintGradient`），所以任意取值都不会切出横向硬边。
  static const double defaultTintBottomScale = 0;

  // --- 滑杆范围 ---

  /// 0 = 只有衬底没有模糊。
  static const double minSigma = 0;
  static const double maxSigma = 40;
  static const double minExtent = 0.3;

  /// 渐变延伸上限就是 1：模糊必须在带底之前彻底衰减到 0。
  ///
  /// >1 表示到带底仍有残留模糊，而带子外面是清晰内容——两者在交界处硬切，
  /// 又是一条横向边。真机口径「要渐渐消失，自然」，故上限锁死 1。
  static const double maxExtent = 1;
  static const double minTintBottomScale = 0;
  static const double maxTintBottomScale = 0.6;

  /// 模糊强度上限（高斯 sigma，逻辑像素）。
  final double sigma;

  /// 渐变延伸（模糊自顶边衰减到 0 的位置占带宽比例）。
  final double extent;

  /// 下部衬底浓度（0..0.6）：让玻璃带下半段更压得住内容。衬底层始终在带底
  /// 渐隐到全透明，因此它只影响「下半段多压一点」，不会在带底留边。
  final double tintBottomScale;

  ProgressiveBlurTuning copyWith({
    double? sigma,
    double? extent,
    double? tintBottomScale,
  }) {
    return ProgressiveBlurTuning(
      sigma: sigma ?? this.sigma,
      extent: extent ?? this.extent,
      tintBottomScale: tintBottomScale ?? this.tintBottomScale,
    );
  }

  ProgressiveBlurTuning clamped() {
    return ProgressiveBlurTuning(
      sigma: sigma.clamp(minSigma, maxSigma),
      extent: extent.clamp(minExtent, maxExtent),
      tintBottomScale: tintBottomScale.clamp(
        minTintBottomScale,
        maxTintBottomScale,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'sigma': sigma,
    'extent': extent,
    'tintBottomScale': tintBottomScale,
  };

  factory ProgressiveBlurTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }
    return ProgressiveBlurTuning(
      sigma: (json['sigma'] as num?)?.toDouble() ?? defaultSigma,
      extent: (json['extent'] as num?)?.toDouble() ?? defaultExtent,
      tintBottomScale:
          (json['tintBottomScale'] as num?)?.toDouble() ??
          defaultTintBottomScale,
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressiveBlurTuning &&
          sigma == other.sigma &&
          extent == other.extent &&
          tintBottomScale == other.tintBottomScale;

  @override
  int get hashCode => Object.hash(sigma, extent, tintBottomScale);
}
