import 'package:flutter/foundation.dart';

import 'liquid_glass_tuning.dart';

/// 课程卡片这一档液态玻璃的**自有**参数（逻辑像素口径）。
///
/// 与全局液态玻璃（[LiquidGlassTuning]）的关系：
///
/// * **形状与光照同一套数学** —— 取值仍走 `LiquidGlassTuning.toStyle()` 这个唯一入口，
///   深浅配方（`darkBoost`）也照吃，所以两个页面看到的玻璃不会因为"另一套参数"而分叉；
/// * **值各存各的** —— 卡片不跟随用户在全局那 8 根滑杆上调出来的档位，反之亦然。
///   用户 2026-09-21 的原话是「这个玻璃跟全局的玻璃还是不同的，所以单独给他一套自定义配置」。
/// * **染色语义不同** —— 全局那份染的是「玻璃底色白」，卡片染的是**课程色**；所以这里的
///   [tintAlpha] 是课程色叠在玻璃上的不透明度（出厂 0.32），而全局那份是底色白的不透明度
///   （出厂 0.70）。
///
/// 为什么不复用 [LiquidGlassTuning] 加一个 `courseCard` 常量：它的 `fromJson` 缺键回落到
/// **全局**默认，坏档 / 部分 JSON 会把卡片染色从 0.32 静默改成 0.70（卡片发浑且不报错）；
/// 而且它带着 `LiquidGlassPreset` 那套预设语义，卡片这边明确不要档位胶囊。
///
/// 出厂档 [courseCard] 的八项**逐字段等于改动前写死在 `CourseGlassStyle` 里的行为**
/// （前五项是当时的硬编码默认值，[blurSigma] 15 等于当时取到的面板磨砂），所以默认状态
/// 观感逐位不变。
@immutable
class CourseGlassTuning {
  const CourseGlassTuning({
    this.refraction = defaultRefraction,
    this.refractionBand = defaultRefractionBand,
    this.refractionEdgePow = defaultRefractionEdgePow,
    this.dispersion = defaultDispersion,
    this.rimStrength = defaultRimStrength,
    this.rimWidth = defaultRimWidth,
    this.blurSigma = defaultBlurSigma,
    this.tintAlpha = defaultTintAlpha,
  });

  /// 出厂卡片档。滑杆上的「建议点位」取的就是这一档的对应值。
  static const courseCard = CourseGlassTuning();

  // --- 出厂值 ---
  //
  // 前五项沿用全局标准档的数字：卡片与全局的玻璃出厂观感必须一样，否则用户会在两个页面
  // 看到两种玻璃。它们曾经靠「`CourseGlassStyle` 默认值必须逐字段等于全局默认值」这条
  // 人肉同步维持；卡片有自己的配置之后这条约束不再需要，数值一致本身就是出厂档的定义。
  static const double defaultRefraction = LiquidGlassTuning.defaultRefraction;
  static const double defaultRefractionBand =
      LiquidGlassTuning.defaultRefractionBand;
  static const double defaultRefractionEdgePow =
      LiquidGlassTuning.defaultRefractionEdgePow;
  static const double defaultDispersion = LiquidGlassTuning.defaultDispersion;
  static const double defaultRimStrength = LiquidGlassTuning.defaultRimStrength;
  static const double defaultRimWidth = LiquidGlassTuning.defaultRimWidth;

  /// 卡片位图的磨砂量。15 = 改动前卡片实际吃到的那个值（面板磨砂的出厂值），
  /// 所以换上这张自有位图之后观感不变。
  static const double defaultBlurSigma = 15;

  /// 课程色的不透明度。0.32 = 改动前 `CourseSurface.refractionFillAlpha`，
  /// 比高斯档的 0.42 低一截：这一档的卖点是「能看见背景在边缘被掰弯」，染色压太实
  /// 会把折射和高光一起盖掉；但也留足色相，让课程颜色仍然可辨。
  static const double defaultTintAlpha = 0.32;

  /// 边缘处的最大折射位移（逻辑 px）。
  final double refraction;

  /// 折射作用带宽度（逻辑 px）。
  final double refractionBand;

  /// 位移沿边缘上升的陡缓，越大越集中在最外圈。
  final double refractionEdgePow;

  /// 色散强度（0–1）：折射带内红/蓝采样点错开的比例，0 = 关。
  final double dispersion;

  /// 边缘高光强度（0–1）。
  final double rimStrength;

  /// 边缘高光带宽（逻辑 px）。
  final double rimWidth;

  /// 卡片预糊位图的磨砂量（逻辑 px）。
  ///
  /// **注意它不受深色配方影响**：位图按一个 sigma 烤一次，而配方里的 ×1.3 是逐帧的
  /// 光照适配。深色只作用于几何与边光（见 [toLiquidGlassTuning] 的调用方），
  /// 别把 `toStyle` 算出来的 blurSigma 拿去烤图 —— 那样深色那次 ×1.3 会永远不生效。
  final double blurSigma;

  /// 课程色的不透明度（0–1）。
  final double tintAlpha;

  CourseGlassTuning copyWith({
    double? refraction,
    double? refractionBand,
    double? refractionEdgePow,
    double? dispersion,
    double? rimStrength,
    double? rimWidth,
    double? blurSigma,
    double? tintAlpha,
  }) {
    return CourseGlassTuning(
      refraction: refraction ?? this.refraction,
      refractionBand: refractionBand ?? this.refractionBand,
      refractionEdgePow: refractionEdgePow ?? this.refractionEdgePow,
      dispersion: dispersion ?? this.dispersion,
      rimStrength: rimStrength ?? this.rimStrength,
      rimWidth: rimWidth ?? this.rimWidth,
      blurSigma: blurSigma ?? this.blurSigma,
      tintAlpha: tintAlpha ?? this.tintAlpha,
    );
  }

  /// 区间收口。**区间常量复用全局那套**（`LiquidGlassTuning.minXxx/maxXxx`）：
  /// 两边都是同一族旋钮，各写一份迟早会漂。
  CourseGlassTuning clamped() {
    return CourseGlassTuning(
      refraction: refraction.clamp(
        LiquidGlassTuning.minRefraction,
        LiquidGlassTuning.maxRefraction,
      ),
      refractionBand: refractionBand.clamp(
        LiquidGlassTuning.minRefractionBand,
        LiquidGlassTuning.maxRefractionBand,
      ),
      refractionEdgePow: refractionEdgePow.clamp(
        LiquidGlassTuning.minRefractionEdgePow,
        LiquidGlassTuning.maxRefractionEdgePow,
      ),
      dispersion: dispersion.clamp(
        LiquidGlassTuning.minDispersion,
        LiquidGlassTuning.maxDispersion,
      ),
      rimStrength: rimStrength.clamp(
        LiquidGlassTuning.minRimStrength,
        LiquidGlassTuning.maxRimStrength,
      ),
      rimWidth: rimWidth.clamp(
        LiquidGlassTuning.minRimWidth,
        LiquidGlassTuning.maxRimWidth,
      ),
      blurSigma: blurSigma.clamp(
        LiquidGlassTuning.minBlurSigma,
        LiquidGlassTuning.maxBlurSigma,
      ),
      tintAlpha: tintAlpha.clamp(
        LiquidGlassTuning.minTintAlpha,
        LiquidGlassTuning.maxTintAlpha,
      ),
    );
  }

  /// 合成给 [LiquidGlassTuning.toStyle] 用的等价全局档。
  ///
  /// 存在的意义就是**把解析交回唯一入口**：形状、深浅配方、区间收口都只有那一处实现，
  /// 卡片不再自己算一遍（历史教训：同一材质两种观感正是被自带的参数通道搞出来的）。
  LiquidGlassTuning toLiquidGlassTuning() => LiquidGlassTuning(
    refraction: refraction,
    refractionBand: refractionBand,
    refractionEdgePow: refractionEdgePow,
    dispersion: dispersion,
    rimStrength: rimStrength,
    rimWidth: rimWidth,
    blurSigma: blurSigma,
    tintAlpha: tintAlpha,
  );

  /// [toLiquidGlassTuning] 的**逆向**：把「按滑杆改过的」等价全局档抄回卡片这一套。
  ///
  /// 存在的理由：材质面板里三套滑杆共用同一份行构造（编辑页的 `_glassSliderTiles`），
  /// 而滑杆回调拿到的类型是 [LiquidGlassTuning] —— 走这一趟抄写比再写一遍八行构造稳。
  /// **只抄这八个字段**：预设档、深浅独立这些语义卡片本来就没有，别在这里长出第二套口径。
  factory CourseGlassTuning.fromLiquidGlassTuning(LiquidGlassTuning tuning) {
    return CourseGlassTuning(
      refraction: tuning.refraction,
      refractionBand: tuning.refractionBand,
      refractionEdgePow: tuning.refractionEdgePow,
      dispersion: tuning.dispersion,
      rimStrength: tuning.rimStrength,
      rimWidth: tuning.rimWidth,
      blurSigma: tuning.blurSigma,
      tintAlpha: tuning.tintAlpha,
    );
  }

  Map<String, dynamic> toJson() => {
    'refraction': refraction,
    'refractionBand': refractionBand,
    'refractionEdgePow': refractionEdgePow,
    'dispersion': dispersion,
    'rimStrength': rimStrength,
    'rimWidth': rimWidth,
    'blurSigma': blurSigma,
    'tintAlpha': tintAlpha,
  };

  /// 缺键回落到**卡片**出厂档（不是全局那份）—— 这正是本类独立存在的头号理由。
  factory CourseGlassTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return courseCard;
    }
    return CourseGlassTuning(
      refraction: (json['refraction'] as num?)?.toDouble() ?? defaultRefraction,
      refractionBand:
          (json['refractionBand'] as num?)?.toDouble() ?? defaultRefractionBand,
      refractionEdgePow:
          (json['refractionEdgePow'] as num?)?.toDouble() ??
          defaultRefractionEdgePow,
      dispersion:
          (json['dispersion'] as num?)?.toDouble() ?? defaultDispersion,
      rimStrength:
          (json['rimStrength'] as num?)?.toDouble() ?? defaultRimStrength,
      rimWidth: (json['rimWidth'] as num?)?.toDouble() ?? defaultRimWidth,
      blurSigma: (json['blurSigma'] as num?)?.toDouble() ?? defaultBlurSigma,
      tintAlpha: (json['tintAlpha'] as num?)?.toDouble() ?? defaultTintAlpha,
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseGlassTuning &&
          refraction == other.refraction &&
          refractionBand == other.refractionBand &&
          refractionEdgePow == other.refractionEdgePow &&
          dispersion == other.dispersion &&
          rimStrength == other.rimStrength &&
          rimWidth == other.rimWidth &&
          blurSigma == other.blurSigma &&
          tintAlpha == other.tintAlpha;

  @override
  int get hashCode => Object.hash(
    refraction,
    refractionBand,
    refractionEdgePow,
    dispersion,
    rimStrength,
    rimWidth,
    blurSigma,
    tintAlpha,
  );
}
