import 'package:flutter/material.dart';

import '../ui/hyperos/liquid/liquid_glass_shader.dart';

/// 「液态玻璃」的观感档位 —— **一条 10 格的厚度阶梯**，全局与课程卡片共用
/// （2026-10-05：卡片那页也摆这条滑杆，两边推荐值引的是同一批常量）。
///
/// [custom] 不在这条阶梯上：它是"用户动过旋钮"的状态，由设置页在用户碰旋钮的那一刻
/// 打上去，不占格位。
///
/// ## 存档值为什么长得不齐
///
/// 2026-10-05 之前只有四档（clear / light / standard / dense），老存档里就是这四个
/// `value`。现在扩到 10 档，**仍然沿用这四个旧值**（分别落在第 1 / 6 / 7 / 10 格），
/// 其余六格用 `levelN`。这样老用户升级后档位名不会被静默改成"标准"，也不会
/// 掉进 `custom`（值还能被 [LiquidGlassPresetX.fromValue] 原样读回）。
enum LiquidGlassPreset {
  /// 第 1 格（最薄）：折射浅、作用带窄，**染色与模糊都归零** —— 背景一块都不挡。
  clear,

  /// 第 2 格。
  level2,

  /// 第 3 格。
  level3,

  /// 第 4 格。
  level4,

  /// 第 5 格。
  level5,

  /// 第 6 格。存档值沿用旧的 `light`（2026-10-05 前它是四档里的第 2 档，位置上
  /// 对应这条 10 格阶梯的偏薄一侧）。
  light,

  /// 第 7 格 —— **全 app 的玻璃基准**。存档值沿用旧的 `standard`（缺键也回落这一格）。
  standard,

  /// 第 8 格。
  level8,

  /// 第 9 格。
  level9,

  /// 第 10 格（最厚）：折射深、作用带宽、底色更实。存档值沿用旧的 `dense`。
  dense,

  /// 用户自己拖出来的参数（不在 10 格阶梯上）。
  custom,
}

extension LiquidGlassPresetX on LiquidGlassPreset {
  /// 存档值。**四个老值原样沿用**（见枚举注释），其余用 `levelN`。
  String get value => switch (this) {
    LiquidGlassPreset.clear => 'clear',
    LiquidGlassPreset.level2 => 'level2',
    LiquidGlassPreset.level3 => 'level3',
    LiquidGlassPreset.level4 => 'level4',
    LiquidGlassPreset.level5 => 'level5',
    LiquidGlassPreset.light => 'light',
    LiquidGlassPreset.standard => 'standard',
    LiquidGlassPreset.level8 => 'level8',
    LiquidGlassPreset.level9 => 'level9',
    LiquidGlassPreset.dense => 'dense',
    LiquidGlassPreset.custom => 'custom',
  };

  static LiquidGlassPreset fromValue(String? value) {
    return LiquidGlassPreset.values.firstWhere(
      (item) => item.value == value,
      // 缺键与不认识的值都归第 7 格（标准），**不能是 custom** —— 否则"从没调过"
      // 的老用户会被显示成自定义，参数区莫名其妙展开一屏。
      //
      // 但这只在「参数侧也是标准档」时才对，见 [reconcileStoredPreset]：老存档
      // 里档位键与参数键的生命周期不同，只看档位键会让面板显示的格号与实际
      // 渲染的参数对不上。
      orElse: () => LiquidGlassPreset.standard,
    );
  }

  /// 存档里「档位」与「参数」对不上时，以谁为准。
  ///
  /// 这两个字段是**分别**存下来的，来源与生命周期都不同：
  ///
  /// - 参数键（`liquidGlassTuning` / `courseCardGlassTuning`）从液态玻璃落地那天
  ///   就在，用户拖旋钮会写它；
  /// - 档位键（`liquidGlassPreset` / `courseCardGlassPreset`）是 2026-10-05 把
  ///   阶梯扩成 10 格时才加的。
  ///
  /// 于是两种「对不上」都会真实存在，且都必须在读取时收敛，否则**面板在说谎**
  /// （渲染只吃参数键，`liquid_glass_surface.dart` / `frosted_appearance.dart`
  /// 都只读 `liquidGlassTuning`）：
  ///
  /// 1. **档位键缺失、参数键有值。** 老存档在档位键存在之前用户拖过旋钮。裸
  ///    [fromValue] 会按「缺键回标准」显示第 7 格，而旋钮显示的是那份自定义参数
  ///    —— 档位滑杆与下面 8 根旋钮读数对不上。
  /// 2. **档位键有值、参数键与之不符。** 2026-10-05 扩格时 `clear` / `light` /
  ///    `dense` 三档的推荐参数被改过（`clear` 的模糊 8→0、染色 0.35→0；
  ///    `dense` 的模糊 22→24、染色 0.85→0.9；`light` 改的是折射 7→7.5 与作用带
  ///    6.5→10.5，模糊与染色没变）。用户在那之前选的就是档位键写着、参数键存着
  ///    **老推荐值**。这时滑杆显示的格号对应的推荐值已经不是他手上那份参数，
  ///    而渲染仍按老参数走 —— 同样是面板说谎。
  ///
  /// 规则（参数侧永远是真源）：
  ///
  /// - 没有参数键 ⇒ 没有任何东西与档位键矛盾，返回 [fromValue] 的结果（缺键 → 标准）。
  /// - 参数键逐字段等于某一格 ⇒ 返回那一格。缺键的情况在这里也就落到标准档
  ///   （"从没调过"的用户参数键同样是出厂值），[fromValue] 那条注释里的顾虑不受影响。
  /// - 否则 ⇒ [matchPreset] 的结果，即 `custom`（老参数不精确等于任何一格时）
  ///   或恰好等于的那一格。
  ///
  /// [stored] 已经是 [fromValue] 归一过的值；[rawStored] 是存档里的原始字符串，
  /// 只用于区分「缺键」与「真的写了某一档」。卡片那套用
  /// [CourseGlassTuning.matchPreset] 反推自己那份参数，等价做法是本函数在
  /// `TimetableSettings.fromJson` 里对两种类型分别调用。
  static LiquidGlassPreset reconcileStoredPreset({
    required String? rawStored,
    required LiquidGlassPreset stored,
    required LiquidGlassTuning? tuning,
  }) {
    if (tuning == null) {
      return stored;
    }
    if (rawStored != null &&
        stored != LiquidGlassPreset.custom &&
        stored.recommendedTuning == tuning) {
      return stored;
    }
    return LiquidGlassTuning.matchPreset(tuning);
  }

  /// 内置观感（不含 [custom]），**顺序就是厚度从薄到厚**，也就是滑杆从左到右。
  ///
  /// 滑杆与档位表的唯一真源：设置页的节点滑杆按下标取档、反推时按下标回填，
  /// 都只走这一份列表（见 [step] / [fromStep]）。
  static const List<LiquidGlassPreset> builtIns = [
    LiquidGlassPreset.clear,
    LiquidGlassPreset.level2,
    LiquidGlassPreset.level3,
    LiquidGlassPreset.level4,
    LiquidGlassPreset.level5,
    LiquidGlassPreset.light,
    LiquidGlassPreset.standard,
    LiquidGlassPreset.level8,
    LiquidGlassPreset.level9,
    LiquidGlassPreset.dense,
  ];

  /// 本档在 10 格阶梯上的**第几格**（1 起，最薄 = 1，最厚 = 10）。
  ///
  /// [custom] 不在阶梯上，返回 `null`。
  int? get step {
    final index = LiquidGlassPresetX.builtIns.indexOf(this);
    return index < 0 ? null : index + 1;
  }

  /// 第几格 → 那一格的档位。[step] 的逆向，供滑杆回调用。
  ///
  /// 越界（0 / 11 / 非整数）回落到 [standard]：滑杆给的值只可能是 1~10，这里只是
  /// 别让一个坏值把渲染层带崩。
  static LiquidGlassPreset fromStep(int step) {
    if (step < 1 || step > builtIns.length) {
      return LiquidGlassPreset.standard;
    }
    return builtIns[step - 1];
  }

  /// 本档推荐的参数。[custom] 回落到 [LiquidGlassTuning.defaults]（第 7 格）。
  LiquidGlassTuning get recommendedTuning => switch (this) {
    LiquidGlassPreset.clear => LiquidGlassTuning.presetClear,
    LiquidGlassPreset.level2 => LiquidGlassTuning.presetLevel2,
    LiquidGlassPreset.level3 => LiquidGlassTuning.presetLevel3,
    LiquidGlassPreset.level4 => LiquidGlassTuning.presetLevel4,
    LiquidGlassPreset.level5 => LiquidGlassTuning.presetLevel5,
    LiquidGlassPreset.light => LiquidGlassTuning.presetLight,
    LiquidGlassPreset.standard => LiquidGlassTuning.defaults,
    LiquidGlassPreset.level8 => LiquidGlassTuning.presetLevel8,
    LiquidGlassPreset.level9 => LiquidGlassTuning.presetLevel9,
    LiquidGlassPreset.dense => LiquidGlassTuning.presetDense,
    LiquidGlassPreset.custom => LiquidGlassTuning.defaults,
  };
}

/// 用户可调的液态玻璃参数（逻辑像素口径）。
///
/// 本类的 [defaults] 就是**第 7 格（标准）**，课程卡片那份出厂档**逐字段等于**它
/// （折射 8 / 作用带 11 / 陡缓 2.5 / 高光 0.2 / 高光带 1.5 / 模糊 15 / 染色 70%）。
/// 两者是两条独立链路（卡片不跟随全局档位，见 `CourseGlassTuning`），但**出厂观感
/// 必须一样**，否则用户会在两个页面看到两种玻璃 —— 2026-10-05 起这条不再靠两处
/// 人肉同步维持：卡片那份的出厂值直接引用本类的常量，那 10 格预设也直接引用下面这十个。
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

  // ── 10 格厚度阶梯怎么排的（2026-10-05）────────────────────────────────────
  //
  // 用户当天分三步钉下来的，顺序很重要，因为**每一次都是往回退**：
  //
  //   ① 先要「标准档 染色 20% / 模糊 5 / 折射 8 / 作用带 11，清澈的染色与模糊都归 0，
  //      其余档以标准为基准自己排」；
  //   ② 回头把**标准档染色退回 70%**：「标准档位改了导致软件全局的标准变了」——
  //      本类的 [defaults] 同时是全 app 的基准（弹窗家族恒锁标准档、顶栏带、玻璃坞
  //      都跟它走），动它不是"改一个档"，是**把软件全局的玻璃底色一起换掉**；
  //   ③ 又把**标准档模糊退回 15**、**清澈档的数值一字不动**，并把四档扩成 **10 格**，
  //      标准落在**第 7 格**（用户原话：「标准档位在第七档，一共十个档位」）。
  //
  // 于是现在的形状：**清澈（第 1 格，数值自 ① 起没动过）是这条阶梯的基准**，
  // 往右单调加厚；标准在第 7 格，往右还有 3 格。
  //
  // 每一格都是「同一个旋钮上取两端的中点」插出来的，不是各写一个看起来好看的数；
  // 实测上**厚薄差主要由模糊与染色拉出来**——折射从清澈的 6 到标准的 8 之间只有 2
  // 的余地，10 格塞不下 7 个互不相同的值（所以下面几格里折射会重复，那不是笔误），
  // 折射要到浓密那三格才继续往上走。
  //
  // 陡缓 refractionEdgePow 反着走（越薄越陡）——位移集中在最外圈，薄的玻璃若还铺满
  // 整条作用带就读不出"边"了。
  //
  // 每一项都落在**自己那根滑杆的格点**上（区间见本类下方，分格数见
  // `settings_appearance_editor.dart` 的 `_glassSliderTiles`）：预设值必须是用户拖得
  // 到、也看得见的数，否则会出现「第 3 格写着模糊 3，切到自定义却停在 4」这种对不上的
  // 半失效状态。由 `liquid_glass_tuning_test.dart` 的「每档每一项都落在格点上」逐项核。
  //
  // ⚠️ 最厚那格的模糊封在 **24**，不是更高：卡片那根模糊滑杆的上限就是
  // `kPreblurMaxSigma` = 24（预糊位图的出图上限），再高卡片会显示一个拖不到的数。
  //
  // ⚠️ 课程卡片那 10 格**不是**另抄一份数，而是直接引用下面这十个（见
  // `course_glass_tuning.dart` 的 `presetClear` 等），所以两边不可能漂。

  /// 第 7 格（标准，同 [defaults]）：**整条阶梯的基准**，也是全 app 的玻璃基准。
  static const presetStandard = defaults;

  /// 第 1 格（最薄）：**染色与模糊都归零**，折射浅、作用带窄 —— 背景一块都不挡，
  /// 整块玻璃只剩边缘折射、色散与边光在动。
  static const presetClear = LiquidGlassTuning(
    refraction: 6,
    refractionBand: 8,
    refractionEdgePow: 3.25,
    dispersion: 0.15,
    rimStrength: 0.1,
    rimWidth: 1.2,
    // 两个 0 都是**有效**取值，不是"没配"：着色器那条 mix 在 α=0 时逐像素恒等、
    // 背景原样透出。深色配方是乘性的（×0.85），0 × 0.85 仍是 0，所以深色下也照旧
    // 全透 —— 由 `liquid_glass_dark_recipe_test.dart` 的「0 安全」钉着。
    blurSigma: 0,
    tintAlpha: 0,
  );

  /// 第 2 格。
  static const presetLevel2 = LiquidGlassTuning(
    refraction: 6,
    refractionBand: 8.5,
    refractionEdgePow: 3.25,
    dispersion: 0.2,
    rimStrength: 0.1,
    rimWidth: 1.2,
    blurSigma: 1,
    tintAlpha: 0.1,
  );

  /// 第 3 格。
  static const presetLevel3 = LiquidGlassTuning(
    refraction: 6.5,
    refractionBand: 9,
    refractionEdgePow: 3,
    dispersion: 0.2,
    rimStrength: 0.15,
    rimWidth: 1.3,
    blurSigma: 3,
    tintAlpha: 0.2,
  );

  /// 第 4 格。
  static const presetLevel4 = LiquidGlassTuning(
    refraction: 7,
    refractionBand: 9.5,
    refractionEdgePow: 3,
    dispersion: 0.25,
    rimStrength: 0.15,
    rimWidth: 1.3,
    blurSigma: 5,
    tintAlpha: 0.3,
  );

  /// 第 5 格。
  static const presetLevel5 = LiquidGlassTuning(
    refraction: 7,
    refractionBand: 10,
    refractionEdgePow: 2.75,
    dispersion: 0.25,
    // 这几格刻意把八项**全列出来**（哪怕等于出厂值）：它们是一张要能一眼比出
    // 高低的表，少列一项看着像漏写。
    // ignore: avoid_redundant_argument_values
    rimStrength: 0.2,
    rimWidth: 1.4,
    blurSigma: 8,
    tintAlpha: 0.4,
  );

  /// 第 6 格（存档值沿用旧的 `light`）。
  static const presetLight = LiquidGlassTuning(
    refraction: 7.5,
    refractionBand: 10.5,
    refractionEdgePow: 2.75,
    dispersion: 0.3,
    // ignore: avoid_redundant_argument_values -- 同上：阶梯表要能一眼比。
    rimStrength: 0.2,
    rimWidth: 1.4,
    blurSigma: 12,
    tintAlpha: 0.55,
  );

  /// 第 8 格。
  static const presetLevel8 = LiquidGlassTuning(
    refraction: 9,
    refractionBand: 13,
    refractionEdgePow: 2.25,
    dispersion: 0.4,
    rimStrength: 0.25,
    rimWidth: 1.7,
    blurSigma: 18,
    tintAlpha: 0.75,
  );

  /// 第 9 格。
  static const presetLevel9 = LiquidGlassTuning(
    refraction: 10,
    refractionBand: 14,
    refractionEdgePow: 2.25,
    dispersion: 0.45,
    rimStrength: 0.3,
    rimWidth: 1.9,
    blurSigma: 21,
    tintAlpha: 0.8,
  );

  /// 第 10 格（最厚，存档值沿用旧的 `dense`）。
  static const presetDense = LiquidGlassTuning(
    refraction: 11,
    refractionBand: 15,
    refractionEdgePow: 2,
    dispersion: 0.5,
    rimStrength: 0.3,
    rimWidth: 2.1,
    blurSigma: 24,
    // 刻意不到 1：全不透明就不是玻璃了，折射与高光会被彻底盖掉。这一格的卖点
    // 是"厚"，不是"实"。
    tintAlpha: 0.9,
  );

  /// 反推 [tuning] 属于哪一格；都不匹配时返回 [LiquidGlassPreset.custom]。
  static LiquidGlassPreset matchPreset(LiquidGlassTuning tuning) {
    for (final preset in LiquidGlassPresetX.builtIns) {
      if (preset.recommendedTuning == tuning) {
        return preset;
      }
    }
    return LiquidGlassPreset.custom;
  }

  /// [tuning] 最接近哪一格 —— **给"用户动过旋钮"之后滑杆停在哪一格用**。
  ///
  /// 为什么不用 [matchPreset]：动过旋钮之后参数一般不精确等于任何一格，而滑杆总得给
  /// 一个位置。取「最近」而不是「上一次选的那格」，是为了滑杆读数能反映当前参数的真实
  /// 厚薄（用户把模糊拖大了，滑杆就该往右走）。
  ///
  /// 距离只看**模糊**与**染色**两项，各自按整条阶梯的跨度归一化 —— 这两项才是厚薄的
  /// 主要来源（折射那几格本来就重复，摊进距离里只会添噪声）。两项等权。
  static LiquidGlassPreset nearestPreset(LiquidGlassTuning tuning) {
    const spanBlur =
        LiquidGlassTuning.maxBlurSigma - LiquidGlassTuning.minBlurSigma;
    const spanTint =
        LiquidGlassTuning.maxTintAlpha - LiquidGlassTuning.minTintAlpha;
    var best = LiquidGlassPreset.clear;
    var bestDistance = double.infinity;
    for (final preset in LiquidGlassPresetX.builtIns) {
      final other = preset.recommendedTuning;
      final dBlur = (other.blurSigma - tuning.blurSigma).abs() / spanBlur;
      final dTint = (other.tintAlpha - tuning.tintAlpha).abs() / spanTint;
      final distance = dBlur * dBlur + dTint * dTint;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = preset;
      }
    }
    return best;
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
  // 模糊与底色白**都照旧**（15 / 0.70），2026-10-05 降过又当天退了回来。
  //
  // 两者原来都**对齐旧磨砂面板的默认值**（kDefaultFrostedSheetBlurSigma /
  // kDefaultFrostedSheetTintAlpha），理由是「从高斯模糊切到液态玻璃时只该多出边缘折射
  // 与受光高光，不该顺带把整块面板的奶白程度也换掉」。
  //
  // ⚠️ 这一天里两项都被降过一次（模糊 15→5、染色 0.70→0.20），又都被退回来，理由是
  // 同一个：本类的 [defaults] 同时是**全 app 的基准** —— 弹窗家族（小件恒锁标准档、
  // 用户没有开关可调）、首页顶栏带、玻璃坞全都跟它走。动它不是"改一个档"，是**把软件
  // 全局的玻璃底色与磨砂程度一起换掉**（用户原话：「标准档位改了导致软件全局的标准变了」）。
  // 也就是说"看得见折射"这件事**不能靠改基准档来实现** —— 要更清透只能往下选那 10 格
  // 阶梯里更薄的几格。
  //
  // ⚠️ 改这两个数会**同时**改课程卡片的出厂档（那边直接引用本类的默认值，见
  // `CourseGlassTuning.defaultBlurSigma` / `defaultTintAlpha`）。这是有意的：
  // 用户要的是两个页面同一种玻璃。
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
