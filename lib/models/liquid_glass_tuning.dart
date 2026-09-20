import 'package:flutter/material.dart';

import '../ui/hyperos/liquid/liquid_glass_shader.dart';

/// 全局「液态玻璃」的观感档位。
///
/// 与 `SoftGlassPreset` / `ProgressiveBlurPreset` 同构：前四档是内置观感，
/// [custom] 保留用户自己拖出来的参数。档位名沿用同一套「清透 → 轻盈 → 标准 →
/// 厚重」阶梯，用户在三套高级材质之间迁移时不用重新学。
enum LiquidGlassPreset {
  /// 最薄：折射浅、作用带窄、几乎不染色。
  clear,

  /// 偏薄：仍明显透出背景。
  light,

  /// 标准档 —— **必须逐字段等于课程卡片液态玻璃档的默认值**，见
  /// [LiquidGlassTuning.defaults] 的说明。
  standard,

  /// 最厚：折射深、作用带宽、底色更实。
  dense,

  /// 用户自己拖出来的参数。
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

  /// 内置观感（不含 [custom]）。
  static const List<LiquidGlassPreset> builtIns = [
    LiquidGlassPreset.clear,
    LiquidGlassPreset.light,
    LiquidGlassPreset.standard,
    LiquidGlassPreset.dense,
  ];

  /// 本档推荐的参数。[custom] 回落到 [LiquidGlassTuning.defaults]。
  LiquidGlassTuning get recommendedTuning => switch (this) {
    LiquidGlassPreset.clear => LiquidGlassTuning.presetClear,
    LiquidGlassPreset.light => LiquidGlassTuning.presetLight,
    LiquidGlassPreset.standard => LiquidGlassTuning.defaults,
    LiquidGlassPreset.dense => LiquidGlassTuning.presetDense,
    LiquidGlassPreset.custom => LiquidGlassTuning.defaults,
  };
}

/// 用户可调的液态玻璃参数（逻辑像素口径）。
///
/// 只有 [LiquidGlassTuning.defaults] 这一档的折射旋钮**逐字段等于**
/// `CourseGlassStyle` 的默认值（折射 8 / 作用带 7 / 陡缓 2.5 / 高光 0.2 /
/// 高光带 1.5）：全局液态玻璃与课程卡片液态玻璃是两条独立链路（卡片不受全局档位
/// 约束），但出厂观感必须一样，否则用户会在两个页面看到两种玻璃。
///
/// 模糊量与底色深浅没有卡片对应项（卡片吃的是预先糊好的位图、染的是课程色），
/// 因此取的是**现有磨砂面板**已经调好的那两个值（sigma 15 / alpha 0.70）：
/// 从「高斯模糊」切到「液态玻璃」时，只该多出边缘折射与受光高光，不该顺带
/// 把整块面板的奶白程度也换掉。
///
/// 这些参数由 `TimetableSettings` 持久化，并在渲染期经 [toStyle] 合成
/// [LiquidGlassStyle]。**表面自己不得再传折射参数**：全 app 只此一套，历史上
/// 「同一材质两种观感」正是被自带的参数通道搞出来的。
@immutable
class LiquidGlassTuning {
  const LiquidGlassTuning({
    this.refraction = defaultRefraction,
    this.refractionBand = defaultRefractionBand,
    this.refractionEdgePow = defaultRefractionEdgePow,
    this.dispersion = defaultDispersion,
    this.rimStrength = defaultRimStrength,
    this.rimWidth = defaultRimWidth,
    this.blurSigma = defaultBlurSigma,
    this.tintAlpha = defaultTintAlpha,
  });

  static const defaults = LiquidGlassTuning();

  /// 标准档（同 [defaults]）。
  static const presetStandard = defaults;

  /// 偏薄档：只把三个「厚度感」旋钮往薄里调，高光与染色同步收一点。
  static const presetClear = LiquidGlassTuning(
    refraction: 6,
    refractionBand: 6,
    refractionEdgePow: 3,
    dispersion: 0.25,
    rimStrength: 0.14,
    rimWidth: 1.1,
    blurSigma: 8,
    tintAlpha: 0.35,
  );

  /// 轻盈档。
  static const presetLight = LiquidGlassTuning(
    refraction: 7,
    refractionBand: 6.5,
    refractionEdgePow: 2.7,
    dispersion: 0.3,
    rimStrength: 0.17,
    rimWidth: 1.3,
    blurSigma: 12,
    tintAlpha: 0.55,
  );

  /// 厚重档。
  static const presetDense = LiquidGlassTuning(
    refraction: 11,
    refractionBand: 9,
    refractionEdgePow: 2.2,
    dispersion: 0.5,
    rimStrength: 0.26,
    rimWidth: 2,
    blurSigma: 22,
    tintAlpha: 0.85,
  );

  /// 反推 [tuning] 属于哪一档；都不匹配时返回 [LiquidGlassPreset.custom]。
  static LiquidGlassPreset matchPreset(LiquidGlassTuning tuning) {
    for (final preset in LiquidGlassPresetX.builtIns) {
      if (preset.recommendedTuning == tuning) {
        return preset;
      }
    }
    return LiquidGlassPreset.custom;
  }

  // --- 默认值 ---
  // 前五项必须与 CourseGlassStyle 的默认值一致（有测试断言）。
  static const double defaultRefraction = 8;
  static const double defaultRefractionBand = 7;
  static const double defaultRefractionEdgePow = 2.5;
  // 边缘高光：宽度 1.5 逻辑 px（≈ 4.5 物理 px）、强度 0.2。
  //
  // 这一对数字的来路（2026-09-20 一天内走了三步，别再走回去）：
  //   ① 原值 3 / 0.2 —— 宽度 3 逻辑 px（9 物理 px）在**横贯屏幕的长直边**上读成一条
  //      浅条纹（用户口径「上面和左右两边浅条纹」）；
  //   ② 收到 0.8 / 0.28 —— 0.8 不到一个逻辑像素，真机上是一根发丝，圆角上直接读出
  //      **锯齿**，而且浅边并没消失（发丝比宽带更像"描边"，用户口径「圆角有锯齿，
  //      三边浅边还在」）；
  //   ③ 现在这版 —— 宽度回到**一个逻辑像素以上**，同时把截面从「贴边最亮」改成
  //      「峰在带内」（见两个 .frag 里的说明）。锯齿的成因是峰值压在抗锯齿的半像素
  //      过渡带里，跟宽度是两个问题：宽度决定"是不是一根发丝"，截面决定"峰值落不落
  //      在抗锯齿那一圈"。强度随宽度回调（0.28 → 0.2），峰值亮度降下来。
  static const double defaultRimStrength = 0.2;
  static const double defaultRimWidth = 1.5;
  // 后两项对齐现有磨砂面板的默认值（kDefaultFrostedSheetBlurSigma /
  // kDefaultFrostedSheetTintAlpha），理由见类注释。
  static const double defaultBlurSigma = 15;
  static const double defaultTintAlpha = 0.70;
  // 色散是 2026-09-19 借 Kyant0 Backdrop 加的第八个旋钮：标准档取克制的
  // 0.35（边缘 1~2px 的彩虹镶边），课程卡那份没有这个旋钮（卡片是独立链路）。
  static const double defaultDispersion = 0.35;

  // --- 滑杆区间 ---
  static const double minRefraction = 0;
  static const double maxRefraction = 20;
  static const double minRefractionBand = 1;
  static const double maxRefractionBand = 24;
  static const double minRefractionEdgePow = 1;
  static const double maxRefractionEdgePow = 6;
  static const double minDispersion = 0;
  static const double maxDispersion = 1;
  static const double minRimStrength = 0;
  static const double maxRimStrength = 1;
  static const double minRimWidth = 0;
  // 上限从 12 收到 3：12（= 36 物理 px）已经是一整条宽带了，留着等于把「条纹」这条
  // 路重新开放给滑杆。3 仍比任何预设（最大 2）宽松。
  static const double maxRimWidth = 3;
  static const double minBlurSigma = 0;
  static const double maxBlurSigma = 40;
  static const double minTintAlpha = 0;
  static const double maxTintAlpha = 1;

  /// 边缘处的最大折射位移（逻辑 px）。
  final double refraction;

  /// 折射作用带宽度（逻辑 px）。
  final double refractionBand;

  /// 位移沿边缘上升的陡缓，越大越集中在最外圈（圆弧截面之上的陡缓指数）。
  final double refractionEdgePow;

  /// 色散强度（0–1）：折射带内红/蓝采样错开的比例，0 = 关。
  final double dispersion;

  /// 边缘高光强度（0–1）。
  final double rimStrength;

  /// 边缘高光带宽（逻辑 px）。
  final double rimWidth;

  /// 实时背景的模糊量（逻辑 px）。
  final double blurSigma;

  /// 底色（白）不透明度（0–1）。
  final double tintAlpha;

  LiquidGlassTuning copyWith({
    double? refraction,
    double? refractionBand,
    double? refractionEdgePow,
    double? dispersion,
    double? rimStrength,
    double? rimWidth,
    double? blurSigma,
    double? tintAlpha,
  }) {
    return LiquidGlassTuning(
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

  LiquidGlassTuning clamped() {
    return LiquidGlassTuning(
      refraction: refraction.clamp(minRefraction, maxRefraction),
      refractionBand: refractionBand.clamp(
        minRefractionBand,
        maxRefractionBand,
      ),
      refractionEdgePow: refractionEdgePow.clamp(
        minRefractionEdgePow,
        maxRefractionEdgePow,
      ),
      dispersion: dispersion.clamp(minDispersion, maxDispersion),
      rimStrength: rimStrength.clamp(minRimStrength, maxRimStrength),
      rimWidth: rimWidth.clamp(minRimWidth, maxRimWidth),
      blurSigma: blurSigma.clamp(minBlurSigma, maxBlurSigma),
      tintAlpha: tintAlpha.clamp(minTintAlpha, maxTintAlpha),
    );
  }

  /// 底色（白）在给定明暗下的实际颜色。
  ///
  /// 深色下收 15%：深色背景本身暗，同样的白底会显得更糊。抽成方法是因为
  /// 除了渲染，**静态替身**（没有采样源时顶栏玻璃带画的近似底色）也要用同一个
  /// 口径，两处各写一遍迟早会漂。
  Color tintColor(Brightness brightness) {
    final alpha = brightness == Brightness.dark
        ? (tintAlpha * 0.85).clamp(0.0, 1.0)
        : tintAlpha.clamp(0.0, 1.0);
    return Colors.white.withValues(alpha: alpha);
  }

  /// 合成一块液态玻璃表面的渲染参数。
  ///
  /// 这是**全 app 唯一的**参数入口：各表面只提供自己的圆角与当前明暗，折射旋钮、
  /// 底色、光来向一律从这里出，所以不存在「这个表面折射 8、那个表面折射 12」。
  LiquidGlassStyle toStyle({
    required double borderRadius,
    required Brightness brightness,
  }) {
    return LiquidGlassStyle(
      borderRadius: borderRadius,
      tint: tintColor(brightness),
      blurSigma: blurSigma,
      refraction: refraction,
      refractionBand: refractionBand,
      refractionEdgePow: refractionEdgePow,
      dispersion: dispersion,
      rimStrength: rimStrength,
      rimWidth: rimWidth,
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

  factory LiquidGlassTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaults;
    }
    return LiquidGlassTuning(
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
      other is LiquidGlassTuning &&
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
