import 'package:flutter/material.dart';

import '../../../models/liquid_glass_tuning.dart';
import 'liquid_glass_shader.dart';

/// [LiquidGlassTuning] → ui 层 [LiquidGlassStyle] 的**唯一**装配出口。
///
/// 2026-10-20 从 `lib/models/liquid_glass_tuning.dart` 迁出（risk-register A5：
/// 拆掉 models→ui 的反向依赖边——模型不该认识 ui 层的样式类）。模型只留纯数据
/// 与选档（[LiquidGlassTuning.forMode] / [LiquidGlassTuning.recipeFor] /
/// [LiquidGlassTuning.tintForMode]），面向 ui 的装配住这里。
///
/// 守卫：`test/architecture/liquid_glass_single_entry_guard_test.dart` 把
/// 「lib/ 下唯一允许构造 [LiquidGlassStyle] 的文件」钉在本文件上——本扩展是
/// 浅/深成对配方与「全 app 一套观感」的唯一落点，表面自己 `LiquidGlassStyle(...)`
/// 一个出来会绕过成对逻辑，而且绕过之后不会有任何测试报错。
extension LiquidGlassTuningStyleX on LiquidGlassTuning {
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
    final recipe = LiquidGlassTuning.recipeFor(
      brightness,
      darkBoost: darkBoost,
    );
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
}
