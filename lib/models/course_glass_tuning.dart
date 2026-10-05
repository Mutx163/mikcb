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
/// * **出厂值与四档预设跟全局完全一样**（2026-10-05 用户拍板：「卡片完全跟通用一样」）。
///   实现上不是抄一份数，而是**直接引用** [LiquidGlassTuning] 的那些常量与预设 ——
///   两边同改一处就够，不可能漂。真正属于卡片自己的只剩**语义**：这里 [tintAlpha]
///   染的是**课程色**（全局那份染玻璃底色白）。
///
/// 为什么不把卡片也塞进 [LiquidGlassTuning] 加一个 `courseCard` 常量：`fromJson`
/// 缺键回落时无法区分"卡片的出厂值"，且卡片要有自己的**档位胶囊 + 自己的存档键**。
/// 保留独立类型换来的是这两件事（渲染口径仍统一走 `toStyle`）。
///
/// ⚠️ 改 [LiquidGlassTuning] 的出厂值会**连带**改卡片出厂档，这是有意的（见上面）。
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

  // --- 出厂档 ---
  //
  // 八项**全部**引用全局标准档：卡片与全局的玻璃出厂观感必须一样，否则用户会在两个
  // 页面看到两种玻璃。2026-10-05 之前这里只有前五项引用，模糊与染色是卡片自己的
  // （15 / 0.32）；那次一并改成引用，理由与新的阶梯见 `LiquidGlassTuning` 的类注释。
  static const double defaultRefraction = LiquidGlassTuning.defaultRefraction;
  static const double defaultRefractionBand =
      LiquidGlassTuning.defaultRefractionBand;
  static const double defaultRefractionEdgePow =
      LiquidGlassTuning.defaultRefractionEdgePow;
  static const double defaultDispersion = LiquidGlassTuning.defaultDispersion;
  static const double defaultRimStrength = LiquidGlassTuning.defaultRimStrength;
  static const double defaultRimWidth = LiquidGlassTuning.defaultRimWidth;

  /// 卡片位图的磨砂量。等于全局那份（出厂 5）—— 卡片吃的也是同一份观感。
  ///
  /// 注意量程与去处都与全局那份不同：上限由出图侧的 `kPreblurMaxSigma` 兜着，
  /// 且**不吃深色配方**（机制见下面 [blurSigma] 那条）。
  static const double defaultBlurSigma = LiquidGlassTuning.defaultBlurSigma;

  /// 课程色的不透明度（出厂 0.20，与全局同数）。
  ///
  /// ⚠️ 注意这里比「高斯档」的 0.42 低一大截：这一档的卖点是「能看见背景在边缘被掰弯」，
  /// 染色压太实会把折射和高光一起盖掉。课程颜色仍然可辨 —— 冲突/放假压暗那一道 4%
  /// 兜底（`minCourseGlassFillAlpha`）与 `contentCardInkOverWallpaper` 的字色判据
  /// 都按这个值算过。
  static const double defaultTintAlpha = LiquidGlassTuning.defaultTintAlpha;

  // --- 四档预设（与全局同一批常量，见 [LiquidGlassPreset]）---
  //
  // `static final` 而不是 `const`：[fromLiquidGlassTuning] 是工厂（八行构造），
  // const 表达式里调不了。读取时机是首次访问，对象不可变，语义上没有差别。

  /// 标准档（= [courseCard]）。
  static const presetStandard = courseCard;

  /// 清澈档。染色与模糊都归零 —— 见 [LiquidGlassTuning.presetClear]。
  static final presetClear = CourseGlassTuning.fromLiquidGlassTuning(
    LiquidGlassTuning.presetClear,
  );

  /// 轻雾档。见 [LiquidGlassTuning.presetLight]。
  static final presetLight = CourseGlassTuning.fromLiquidGlassTuning(
    LiquidGlassTuning.presetLight,
  );

  /// 浓密档。见 [LiquidGlassTuning.presetDense]。
  static final presetDense = CourseGlassTuning.fromLiquidGlassTuning(
    LiquidGlassTuning.presetDense,
  );

  /// 反推 [tuning] 属于哪一档；都不匹配时返回 [LiquidGlassPreset.custom]。
  ///
  /// 与 [LiquidGlassTuning.matchPreset] 同构，但比的是**卡片这套**的值：档位胶囊
  /// 要靠它把"用户拖到刚好等于某一档"的状态认回来（设置页的滑杆回调直接把档位
  /// 打成 custom，这里反推才能在重新打开面板时还原成内置档）。
  static LiquidGlassPreset matchPreset(CourseGlassTuning tuning) {
    for (final preset in LiquidGlassPresetX.builtIns) {
      if (preset.recommendedCourseTuning == tuning) {
        return preset;
      }
    }
    return LiquidGlassPreset.custom;
  }

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

/// 档位 → **卡片那套**的推荐参数。与 [LiquidGlassPresetX.recommendedTuning] 同构，
/// 是「课程卡片」页那排胶囊唯一的取值入口（设置页两页都用它，两页因此不可能给出
/// 不一样的档）。
///
/// 扩展放在本文件而不是 [liquid_glass_tuning.dart]：那边被本文件 import，反过来
/// import 会成环，而且「卡片那套」的知识本来就属于卡片这个文件。
extension CourseGlassPresetTuningX on LiquidGlassPreset {
  CourseGlassTuning get recommendedCourseTuning => switch (this) {
    LiquidGlassPreset.clear => CourseGlassTuning.presetClear,
    LiquidGlassPreset.light => CourseGlassTuning.presetLight,
    LiquidGlassPreset.standard => CourseGlassTuning.presetStandard,
    LiquidGlassPreset.dense => CourseGlassTuning.presetDense,
    // 自定义不是一组推荐值，回落到标准档（与全局那份同口径）。
    LiquidGlassPreset.custom => CourseGlassTuning.presetStandard,
  };
}
