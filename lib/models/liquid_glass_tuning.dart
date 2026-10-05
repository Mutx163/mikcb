import 'package:flutter/material.dart';

import '../ui/hyperos/liquid/liquid_glass_shader.dart';

/// 「液态玻璃」的观感档位。**全局与课程卡片共用同一套**（2026-10-05：卡片那页也
/// 摆出这排胶囊，两边推荐值引的是同一批常量，所以不可能漂）。
///
/// 与旧的渐进模糊预设体系同构（那一套 2026-09-23 已随子页顶栏锁定删除）：前四档是内置观感，
/// [custom] 保留用户自己拖出来的参数。档位名沿用同一套「清透 → 轻盈 → 标准 →
/// 厚重」阶梯，用户在三套高级材质之间迁移时不用重新学。
enum LiquidGlassPreset {
  /// 最薄（清澈）：折射浅、作用带窄，**染色与模糊都归零** —— 背景一块都不挡。
  clear,

  /// 偏薄（轻雾）：清透与标准之间那一格。
  light,

  /// 标准档 —— **必须逐字段等于课程卡片标准档的默认值**，见
  /// [LiquidGlassTuning.defaults] 的说明。
  standard,

  /// 最厚（浓密）：折射深、作用带宽、底色更实。
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
/// 本类的 [defaults] 就是**标准档**，课程卡片那份出厂档**逐字段等于**它
/// （折射 8 / 作用带 11 / 陡缓 2.5 / 高光 0.2 / 高光带 1.5 / 模糊 5 / 染色 20%）。
/// 两者是两条独立链路（卡片不跟随全局档位，见 `CourseGlassTuning`），但**出厂观感
/// 必须一样**，否则用户会在两个页面看到两种玻璃 —— 2026-10-05 起这条不再靠两处
/// 人肉同步维持：卡片那份的出厂值直接引用本类的常量，四档预设也直接引用下面这四个。
///
/// 模糊量与底色深浅的**语义**两边不同（全局染「玻璃底色白」、卡片染「课程色」），
/// 但取值口径已统一（2026-10-05 用户拍板：「卡片完全跟通用一样」）。注意卡片那份
/// 的模糊只喂它那张预糊位图、逐帧的光照配方对它不生效（见 `CourseGlassTuning`）。
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

  // ── 四档阶梯怎么排的（2026-10-05）──────────────────────────────────────────
  //
  // 用户只钉了**两端**：清澈的染色与模糊都归 0，标准是折射 8 / 作用带 11 /
  // 模糊 5 / 染色 20%。剩下两格按「同一个旋钮上取两端的中点」补齐，而不是各写
  // 一个看起来好看的数：
  //
  //   presetClear  = 标准 **减去**一整格（折射 8→6、作用带 11→8……）
  //   presetLight  = 清澈与标准之间各让一半
  //   presetDense  = 标准 **加上**一整格（作用带 11→15、模糊 5→12……）
  //
  // 这样排的结果是「厚度感」那几个旋钮全部单调递增（测试
  // `test/models/liquid_glass_tuning_test.dart` 的「四档的厚度感单调递增」钉的就是
  // 它）：用户一路往右点，玻璃只会**越来越厚**，不会出现某一项反而变薄。
  //
  // 陡缓 refractionEdgePow 反着走（越薄越陡）—— 位移集中在最外圈，薄的玻璃若还
  // 铺满整条作用带就看不出"边"了。
  //
  // 每一项都落在**自己那根滑杆的格点**上（区间见本类下方，分格数见
  // `settings_appearance_editor.dart` 的 `_glassSliderTiles`）：预设值必须是用户拖得
  // 到、也看得见的数，否则会出现「档位写着模糊 5，切到自定义却停在 4」这种对不上
  // 的半失效状态。
  //
  // ⚠️ 课程卡片那四档**不是**另抄一份数，而是直接引用下面这四个（见
  // `course_glass_tuning.dart` 的 `presetClear` 等），所以两边不可能漂。

  /// 标准档（同 [defaults]）：**整条阶梯的基准**。
  static const presetStandard = defaults;

  /// 清澈档（最薄）：染色与模糊都归零，只剩边缘折射、色散与边光。
  static const presetClear = LiquidGlassTuning(
    refraction: 6,
    refractionBand: 8,
    refractionEdgePow: 3.25,
    dispersion: 0.15,
    rimStrength: 0.1,
    rimWidth: 1.2,
    // 0 是**有效**取值，不是"没配"：背景一块都不挡，整块玻璃只剩边缘在动。
    blurSigma: 0,
    tintAlpha: 0,
  );

  /// 轻雾档：清透与标准之间那一格。
  static const presetLight = LiquidGlassTuning(
    refraction: 7,
    refractionBand: 9.5,
    refractionEdgePow: 2.75,
    dispersion: 0.25,
    rimStrength: 0.15,
    rimWidth: 1.3,
    blurSigma: 2,
    tintAlpha: 0.1,
  );

  /// 浓密档：标准之上那一格。
  static const presetDense = LiquidGlassTuning(
    refraction: 11,
    refractionBand: 15,
    refractionEdgePow: 2.25,
    dispersion: 0.5,
    rimStrength: 0.25,
    rimWidth: 2,
    blurSigma: 12,
    tintAlpha: 0.4,
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

  // --- 默认值（即标准档）---
  // 前五项必须与 CourseGlassStyle 的默认值一致（有测试断言）。
  static const double defaultRefraction = 8;
  // 作用带 7 → 11（2026-10-05 用户拍板，与折射 8 一起给的两项）。
  //
  // 作用带是**绝对值**（逻辑 px），不随表面大小缩放，所以它同时是"边有多宽"的
  // 观感参数和"要外溢多少才采得到背景"的布局参数：首页顶栏玻璃带上边按
  // `max(作用带, 边光带) + 1` 外溢（`homePageChromeGlassVerticalOverhang`），
  // 窄件另有一道按短边封顶折射位移的适配（`narrowSurfaceMaxRefraction`）。
  // 7 → 11 之后前者自动跟着涨，不用在这里额外改任何布局常量。
  static const double defaultRefractionBand = 11;
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
  // 模糊 15 → 5、染色 0.70 → 0.20（2026-10-05 用户拍板，与折射/作用带一起给的）。
  //
  // 这两个数原来是**对齐旧磨砂面板**的取值（kDefaultFrostedSheetBlurSigma /
  // kDefaultFrostedSheetTintAlpha），理由是「从高斯模糊切到液态玻璃时只该多出边缘
  // 折射与受光高光」。现在口径反过来了：液态玻璃要的是**看得见背景在边缘被掰弯**，
  // 15 的模糊 + 70% 的白底正好把折射和高光一起盖掉（所以那档的卖点一直读不出来），
  // 于是往「清澈」那一头收。清澈档的 0 / 0 是这条线的另一端 —— 见上面的阶梯说明。
  //
  // ⚠️ 改这两个数会**同时**改课程卡片的出厂档（那边直接引用本类的默认值，见
  // `CourseGlassTuning.defaultBlurSigma` / `defaultTintAlpha`）。这是有意的：
  // 用户要的是两个页面同一种玻璃。
  static const double defaultBlurSigma = 5;
  static const double defaultTintAlpha = 0.2;
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

  /// 该明暗 + 成对开关下，这块玻璃的底色。
  ///
  /// 与 [toStyle] 走**同一套**选档（[forMode]）与配方（[LiquidGlassDarkRecipe]），
  /// 所以静态替身与实体玻璃不会漂。只在需要底色、不想构造整个 style 时用它
  /// （静态替身：没有采样源时顶栏玻璃带画的近似底色）。
  ///
  /// 不传成对配置时就是旧口径：底色恒白、深色收 15% —— 深色背景本身暗，
  /// 同样的白底会显得更糊。
  Color tintForMode({
    required Brightness brightness,
    LiquidGlassTuning? dark,
    bool link = true,
    bool darkBoost = false,
  }) {
    final recipe = _recipeFor(brightness, darkBoost: darkBoost);
    final base = forMode(brightness: brightness, dark: dark, link: link);
    return recipe.tintFor(base.tintAlpha);
  }

  /// 该明暗 + 开关下要套的配方。浅色恒为恒等配方 ⇒ 浅色逐位不变。
  static LiquidGlassDarkRecipe _recipeFor(
    Brightness brightness, {
    required bool darkBoost,
  }) => switch (brightness) {
    Brightness.dark => darkBoost
        ? LiquidGlassDarkRecipe.standard
        : LiquidGlassDarkRecipe.legacy,
    Brightness.light => LiquidGlassDarkRecipe.identity,
  };

  /// 按明暗挑出该用哪一档配置。
  ///
  /// 浅色恒为 [this]；深色不独立（`link = true`）时也是 [this]（再套深色配方），
  /// 独立时才用 [dark]；[dark] 为 null 视为跟随。
  LiquidGlassTuning forMode({
    required Brightness brightness,
    LiquidGlassTuning? dark,
    bool link = true,
  }) {
    if (brightness != Brightness.dark) {
      return this;
    }
    if (link) {
      return this;
    }
    return dark ?? this;
  }

  /// 合成一块液态玻璃表面的渲染参数。
  ///
  /// 这是**全 app 唯一的**参数入口：各表面只提供自己的圆角与当前明暗，折射旋钮、
  /// 底色、光来向一律从这里出，所以不存在「这个表面折射 8、那个表面折射 12」。
  ///
  /// 浅/深成对（2026-09-21）：
  /// * [dark] 是深色档（null = 跟随浅色档 [this]）；
  /// * [link] = false 时才真的用 [dark]；true 时深色也以 [this] 为形状；
  /// * [darkBoost] = true 才把 [LiquidGlassDarkRecipe.standard] 套到深色上。
  ///
  /// **默认 `darkBoost = false` 是刻意的**：那是今天的行为（白底 + 深色收 15%），
  /// 所以未迁移的调用点零回归。由设置驱动的调用点显式传产品默认值。
  LiquidGlassStyle toStyle({
    required double borderRadius,
    required Brightness brightness,
    LiquidGlassTuning? dark,
    bool link = true,
    bool darkBoost = false,
  }) {
    final base = forMode(brightness: brightness, dark: dark, link: link);
    final recipe = _recipeFor(brightness, darkBoost: darkBoost);
    return LiquidGlassStyle(
      borderRadius: borderRadius,
      tint: recipe.tintFor(base.tintAlpha),
      blurSigma: recipe.blurFor(base.blurSigma),
      refraction: base.refraction,
      refractionBand: base.refractionBand,
      refractionEdgePow: base.refractionEdgePow,
      dispersion: recipe.dispersionFor(base.dispersion),
      rimStrength: recipe.rimFor(base.rimStrength),
      rimWidth: base.rimWidth,
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

/// 深色模式对浅色档施加的**配方**：目标底色 + 逐通道系数。
///
/// 为什么是「成对配方」而不是「同一套底色缩放」：这是业内的共同做法，四家都是两套配方，
/// 不是一套乘系数 ——
/// * Apple：`UIBlurEffect.Style` 有成对的 `systemMaterialLight` / `systemMaterialDark`
///   （文档逐字 "is always light" / "is always dark"），另有 `dark` / `extraDark` 定义为
///   "The area of the view is darker than the underlying view"；
/// * Microsoft Fluent：Mica / Acrylic 明确 "mode aware"，而 Smoke "is not mode aware;
///   it is always translucent black"（遮罩层**故意不随深浅变**）；
/// * Material 3：深浅靠两套 `surfaceContainer*` 色阶（早先的 elevation overlay 在深色下
///   把表面**提亮**，α 5%→12%）；
/// * miuix（本仓上游）：每个材质都是 `isDark ? Dark : Light` 的成对常量，且暗色**换混合模式**
///   —— 第二层 `0x66565656` 中灰 @ `luminosity`、第三层 `0x993F3F3F` @ `overlay`，
///   `actionBarMask` 暗色 blur 40→60。
///
/// 两条硬规则（都是"材质完全可自定义"这个定位逼出来的）：
/// 1. **系数一律用乘，不用加**：`effective = value × coef`。于是 0 恒为 0
///    （用户关掉的通道永远保持关闭，`0 × 0.6 = 0`），单调、也不会把值顶出滑杆范围。
/// 2. **目标底色用中性灰，不用黑**：暗底上再叠一层暗膜，面板与背景会糊在一起，
///    既没边界也没玻璃感（miuix 从不用黑做染色层，黑色只以 5~10% 的 `plusDarker` 做压暗）。
///
/// 几何通道（折射 / 作用带 / 陡缓 / 穹顶）**不参与**：透镜形状与光照无关，
/// 四家都没有按模式改透镜几何的先例。
@immutable
class LiquidGlassDarkRecipe {
  const LiquidGlassDarkRecipe({
    required this.tintTarget,
    required this.tintAlphaScale,
    required this.blurSigmaScale,
    required this.rimStrengthScale,
    required this.dispersionScale,
  });

  /// 浅色用的恒等配方：目标白、系数全 1。乘 1.0 在 IEEE754 下是恒等，
  /// 所以浅色渲染逐位不变。
  static const identity = LiquidGlassDarkRecipe(
    tintTarget: Color(0xFFFFFFFF),
    tintAlphaScale: 1,
    blurSigmaScale: 1,
    rimStrengthScale: 1,
    dispersionScale: 1,
  );

  /// **今天的行为**：底色仍是白、深色只收 15%，其余不动。
  /// [LiquidGlassTuning.toStyle] 在 `darkBoost = false` 时走它 ⇒ 未迁移调用点零回归。
  static const legacy = LiquidGlassDarkRecipe(
    tintTarget: Color(0xFFFFFFFF),
    tintAlphaScale: 0.85,
    blurSigmaScale: 1,
    rimStrengthScale: 1,
    dispersionScale: 1,
  );

  /// 产品默认的深色配方（起步值，待真机校准）。
  ///
  /// 模糊上浮对齐 miuix 的 `actionBarMask` 暗色 40→60；边光下收是因为
  /// `lit = tinted + rimColor × rim` 是**恒定加色项**，底色一变暗它的相对亮度就升高。
  static const standard = LiquidGlassDarkRecipe(
    tintTarget: Color(0xFF565656),
    tintAlphaScale: 0.85,
    blurSigmaScale: 1.3,
    rimStrengthScale: 0.6,
    dispersionScale: 0.7,
  );

  /// 深色档的目标底色（中性灰量级，不是黑）。
  final Color tintTarget;

  /// 底色不透明度系数。
  final double tintAlphaScale;

  /// 模糊量系数。
  final double blurSigmaScale;

  /// 边缘高光强度系数。
  final double rimStrengthScale;

  /// 色散强度系数。
  final double dispersionScale;

  /// 目标底色 + 收缩后的 alpha。与 [LiquidGlassTuning.tintColor] 同口径。
  Color tintFor(double tintAlpha) =>
      tintTarget.withValues(alpha: (tintAlpha * tintAlphaScale).clamp(0.0, 1.0));

  /// 模糊量，按滑杆区间收口（系数不得把值顶出区间）。
  double blurFor(double blurSigma) => (blurSigma * blurSigmaScale).clamp(
    LiquidGlassTuning.minBlurSigma,
    LiquidGlassTuning.maxBlurSigma,
  );

  /// 边光强度，收在 0–1。
  double rimFor(double rimStrength) =>
      (rimStrength * rimStrengthScale).clamp(0.0, 1.0);

  /// 色散强度，收在 0–1。
  double dispersionFor(double dispersion) =>
      (dispersion * dispersionScale).clamp(0.0, 1.0);
}
