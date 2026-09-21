// 浅/深成对配置**接线**的验收测试：验的是「设置 → 渲染参数」这一段有没有接通。
//
// 为什么能在这测：`LiquidGlassSurface.resolveStyleFor` 是 `@visibleForTesting` 静态
// 函数，把 `build` 里那套解析原样搬了出来。测试环境没有 shader filter 后端，
// `LiquidGlassSurface` 一律走 fallback、永远不构造玻璃层，所以**只有**通过这个缝
// 才能断言接线；漏传成对开关的症状只是"深色观感不对"，没有任何测试会报错。
//
// 设计见 `.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_shader.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

/// 造一份外观：只改本测试关心的字段，其余取产品默认。
FrostedAppearance _appearance({
  LiquidGlassTuning? tuning,
  LiquidGlassTuning? dark,
  bool link = true,
  bool boost = true,
}) {
  const base = FrostedAppearance.defaults;
  return FrostedAppearance(
    sheetBlurSigma: base.sheetBlurSigma,
    sheetTintAlpha: base.sheetTintAlpha,
    sheetBarrierAlpha: base.sheetBarrierAlpha,
    liquidGlassTuning: tuning,
    liquidGlassTuningDark: dark,
    linkLiquidGlassTuning: link,
    darkGlassBoostEnabled: boost,
  );
}

LiquidGlassStyle _style(
  FrostedAppearance appearance, {
  Brightness brightness = Brightness.dark,
  LiquidGlassRole role = LiquidGlassRole.followsUser,
}) => LiquidGlassSurface.resolveStyleFor(
  appearance: appearance,
  role: role,
  borderRadius: 12,
  brightness: brightness,
);

void main() {
  const tuning = LiquidGlassTuning(tintAlpha: 0.5, blurSigma: 10, rimStrength: 0.5);

  group('followsUser：用户的成对配置真的进到渲染参数里', () {
    test('深色 + 配方开 ⇒ 中性灰 + 三个系数都生效', () {
      final style = _style(_appearance(tuning: tuning));
      expect(style.tint.r, closeTo(0x56 / 255, 1e-6), reason: '目标色没接上');
      expect(style.blurSigma, closeTo(10 * 1.3, 1e-9), reason: '模糊系数没接上');
      expect(style.rimStrength, closeTo(0.5 * 0.6, 1e-9), reason: '边光系数没接上');
      expect(style.tint.a, closeTo(0.5 * 0.85, 1e-9));
    });

    test('深色 + 配方关 ⇒ 退回白底收 15%（回滚开关真的通到底）', () {
      final style = _style(_appearance(tuning: tuning, boost: false));
      expect(style.tint.r, 1.0);
      expect(style.blurSigma, closeTo(10, 1e-9));
      expect(style.rimStrength, closeTo(0.5, 1e-9));
      expect(style.tint.a, closeTo(0.5 * 0.85, 1e-9));
    });

    test('浅色恒不受成对配置影响', () {
      for (final boost in [true, false]) {
        for (final link in [true, false]) {
          final style = _style(
            _appearance(
              tuning: tuning,
              dark: LiquidGlassTuning.presetDense,
              link: link,
              boost: boost,
            ),
            brightness: Brightness.light,
          );
          expect(style.tint, Colors.white.withValues(alpha: 0.5));
          expect(style.blurSigma, closeTo(10, 1e-9));
          expect(style.rimStrength, closeTo(0.5, 1e-9));
        }
      }
    });

    test('深色独立档真的被用上（link=false）', () {
      final style = _style(
        _appearance(
          tuning: tuning,
          dark: const LiquidGlassTuning(tintAlpha: 0.2, blurSigma: 30),
          link: false,
        ),
      );
      expect(style.blurSigma, closeTo(30 * 1.3, 1e-9));
      expect(style.tint.a, closeTo(0.2 * 0.85, 1e-9));
    });

    test('link=true 时深色独立档不参与', () {
      final style = _style(
        _appearance(
          tuning: tuning,
          dark: const LiquidGlassTuning(tintAlpha: 0.2, blurSigma: 30),
        ),
      );
      expect(style.blurSigma, closeTo(10 * 1.3, 1e-9));
      expect(style.tint.a, closeTo(0.5 * 0.85, 1e-9));
    });
  });

  group('pinnedChrome：形状锁标准档，但配方必须照套', () {
    test('用户那套调参与深色档都不参与', () {
      final style = _style(
        _appearance(
          tuning: tuning,
          dark: const LiquidGlassTuning(tintAlpha: 0.2, blurSigma: 30),
          link: false,
        ),
        role: LiquidGlassRole.pinnedChrome,
      );
      expect(style.blurSigma, closeTo(15 * 1.3, 1e-9), reason: '小件该拿标准档 15');
      expect(style.refraction, LiquidGlassPreset.standard.recommendedTuning.refraction);
    });

    test('配方仍然生效 —— 漏给小件就会重现「同一材质两种观感」', () {
      final pinned = _style(
        _appearance(tuning: tuning),
        role: LiquidGlassRole.pinnedChrome,
      );
      final following = _style(_appearance(tuning: tuning));
      expect(
        pinned.tint.r,
        following.tint.r,
        reason: '小件与跟随档的底色目标必须一致（都是配方后的中性灰）',
      );
      expect(pinned.tint.r, closeTo(0x56 / 255, 1e-6));
    });

    test('配方开关关掉时小件也退回白底', () {
      final style = _style(
        _appearance(tuning: tuning, boost: false),
        role: LiquidGlassRole.pinnedChrome,
      );
      expect(style.tint.r, 1.0);
    });
  });
}
