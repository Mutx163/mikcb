// 液态玻璃「浅/深成对配方」的验收测试（纯 Dart，不需要真机）。
//
// 设计见 `.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`。
// 这里钉住四类不变量：
//   ① **浅色逐位不变**（恒等配方 + 特征化），这是整个改动的前置承诺；
//   ② 未迁移调用点零回归（`darkBoost = false` 时深色 == 今天的行为）；
//   ③ **0 安全**：系数一律用乘 ⇒ 用户关掉的通道永远保持关闭；
//   ④ 几何通道不参与深浅配方（透镜形状与光照无关）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_shader.dart';

void main() {
  group('恒等配方：浅色列必须是恒等', () {
    test('系数全为 1、目标底色为纯白', () {
      const identity = LiquidGlassDarkRecipe.identity;
      expect(identity.tintAlphaScale, 1);
      expect(identity.blurSigmaScale, 1);
      expect(identity.rimStrengthScale, 1);
      expect(identity.dispersionScale, 1);
      expect(identity.tintTarget, const Color(0xFFFFFFFF));
    });

    test('浅色输出与「直接拿旋钮值」逐字段相同', () {
      // 特征化的替代形式：浅色不套任何配方，所以 style 必须逐个字段等于原值。
      const tuning = LiquidGlassTuning(
        refraction: 9,
        refractionBand: 8,
        refractionEdgePow: 3,
        dispersion: 0.4,
        rimStrength: 0.3,
        rimWidth: 2.5,
        blurSigma: 18,
        tintAlpha: 0.6,
      );

      final style = tuning.toStyle(
        borderRadius: 20,
        brightness: Brightness.light,
      );

      expect(style.borderRadius, 20);
      expect(style.refraction, 9);
      expect(style.refractionBand, 8);
      expect(style.refractionEdgePow, 3);
      expect(style.dispersion, 0.4);
      expect(style.rimStrength, 0.3);
      expect(style.rimWidth, 2.5);
      expect(style.blurSigma, 18);
      expect(style.tint, Colors.white.withValues(alpha: 0.6));
    });

    test('浅色恒为白底，且深浅开关都不影响它', () {
      const tuning = LiquidGlassTuning();
      const dark = LiquidGlassTuning(tintAlpha: 0.2);

      final plain = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      // 传了深色档 + 两个开关，浅色输出仍必须逐字段相同。
      final wired = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
        dark: dark,
        link: false,
        darkBoost: true,
      );

      expect(wired, plain, reason: '浅色不该被成对配置撼动');
      expect(plain.tint.r, 1.0);
      expect(plain.tint.g, 1.0);
      expect(plain.tint.b, 1.0);
    });
  });

  group('未迁移调用点零回归：darkBoost = false 就是今天的行为', () {
    test('深色只收 15%，底色仍是白', () {
      const tuning = LiquidGlassTuning(tintAlpha: 0.4);
      final dark = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
      );
      expect((dark.tint.a * 1000).round(), 340);
      expect(dark.tint.r, 1.0);
      expect(dark.tint.g, 1.0);
      expect(dark.tint.b, 1.0);
    });

    test('tintForMode 不传成对配置 = 旧口径，且与 toStyle 逐字段一致', () {
      // 静态替身走 tintForMode、实体玻璃走 toStyle，两者必须同口径，
      // 否则深色下替身停在白底、玻璃已经是中性灰。
      const tuning = LiquidGlassTuning(tintAlpha: 0.4);
      expect(
        tuning.tintForMode(brightness: Brightness.light),
        tuning
            .toStyle(borderRadius: 0, brightness: Brightness.light)
            .tint,
      );
      expect(
        tuning.tintForMode(brightness: Brightness.dark),
        tuning.toStyle(borderRadius: 0, brightness: Brightness.dark).tint,
      );
      // 旧口径：浅色不缩、深色收 15%。
      expect(
        tuning.tintForMode(brightness: Brightness.light).a,
        closeTo(0.4, 1e-9),
      );
      expect(
        tuning.tintForMode(brightness: Brightness.dark).a,
        closeTo(0.34, 1e-9),
      );
    });

    test('tintForMode 传成对配置时与 toStyle 同口径（含目标灰）', () {
      const tuning = LiquidGlassTuning(tintAlpha: 0.4);
      const dark = LiquidGlassTuning(tintAlpha: 0.9);
      for (final link in [true, false]) {
        for (final boost in [true, false]) {
          expect(
            tuning.tintForMode(
              brightness: Brightness.dark,
              dark: dark,
              link: link,
              darkBoost: boost,
            ),
            tuning
                .toStyle(
                  borderRadius: 0,
                  brightness: Brightness.dark,
                  dark: dark,
                  link: link,
                  darkBoost: boost,
                )
                .tint,
            reason: 'link=$link darkBoost=$boost 时替身与实体漂了',
          );
        }
      }
      // 开了配方 ⇒ 目标色变成中性灰（rgb 也变，不只是 alpha）。
      final boosted = tuning.tintForMode(
        brightness: Brightness.dark,
        darkBoost: true,
      );
      expect(boosted.r, closeTo(0x56 / 255, 1e-6));
    });
  });

  group('深色配方：换中性灰 + 逐通道系数', () {
    test('目标底色是中性灰，不是黑', () {
      const tuning = LiquidGlassTuning(tintAlpha: 1);
      final style = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        darkBoost: true,
      );
      // alpha 是 1 × tintAlphaScale(0.85)，本测试只关心 rgb。
      expect(style.tint.a, closeTo(0.85, 1e-9));
      // 0x56 / 255 —— 关键点是"远大于 0"，即暗而不黑。
      expect(style.tint.r, closeTo(0x56 / 255, 1e-6));
      expect(style.tint.g, closeTo(0x56 / 255, 1e-6));
      expect(style.tint.b, closeTo(0x56 / 255, 1e-6));
    });

    test('四个系数各自生效', () {
      const tuning = LiquidGlassTuning(
        blurSigma: 10,
        tintAlpha: 0.4,
        rimStrength: 0.5,
        dispersion: 0.5,
      );
      final light = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      final dark = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        darkBoost: true,
      );

      expect(dark.blurSigma, closeTo(light.blurSigma * 1.3, 1e-9));
      expect(dark.tint.a, closeTo(light.tint.a * 0.85, 1e-9));
      expect(dark.rimStrength, closeTo(light.rimStrength * 0.6, 1e-9));
      expect(dark.dispersion, closeTo(light.dispersion * 0.7, 1e-9));
    });

    test('系数不会把值顶出滑杆区间', () {
      const maxed = LiquidGlassTuning(
        blurSigma: LiquidGlassTuning.maxBlurSigma,
        rimStrength: LiquidGlassTuning.maxRimStrength,
        dispersion: LiquidGlassTuning.maxDispersion,
      );
      final style = maxed.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        darkBoost: true,
      );
      // 模糊 40 × 1.3 = 52 会被收回到上限；收边光的两个系数只会往下走。
      expect(style.blurSigma, LiquidGlassTuning.maxBlurSigma);
      expect(
        style.rimStrength,
        closeTo(LiquidGlassTuning.maxRimStrength * 0.6, 1e-9),
      );
      expect(
        style.dispersion,
        closeTo(LiquidGlassTuning.maxDispersion * 0.7, 1e-9),
      );
      expect(style.blurSigma, lessThanOrEqualTo(LiquidGlassTuning.maxBlurSigma));
      expect(
        style.rimStrength,
        lessThanOrEqualTo(LiquidGlassTuning.maxRimStrength),
      );
      expect(
        style.dispersion,
        lessThanOrEqualTo(LiquidGlassTuning.maxDispersion),
      );
    });
  });

  group('0 安全：用户关掉的通道永远保持关闭', () {
    test('四个受系数影响的通道在 0 处输出恒为 0', () {
      const zeroed = LiquidGlassTuning(
        blurSigma: 0,
        tintAlpha: 0,
        rimStrength: 0,
        dispersion: 0,
      );
      final style = zeroed.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        darkBoost: true,
      );
      expect(style.tint.a, 0);
      expect(style.blurSigma, 0);
      expect(style.rimStrength, 0);
      expect(style.dispersion, 0);
    });

    test('底色为 0 时换目标色不改变画面（着色器 mix 的 α = 0 分支）', () {
      // `Color` 的 `==` 会连 rgb 一起比，所以这里**不能**直接断言两个 tint 相等。
      // 断言的是"渲染等价的前提"：两者 alpha 都是 0，而
      // `shaders/glass_surface_refraction.frag:262` 的
      // `mix(base, u_tint.rgb, clamp(u_tint.a, 0, 1))` 在 α = 0 时恒等于 base。
      const zeroed = LiquidGlassTuning(tintAlpha: 0);
      final legacy = zeroed.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
      );
      final boosted = zeroed.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        darkBoost: true,
      );
      expect(legacy.tint.a, 0);
      expect(boosted.tint.a, 0);
      expect(
        boosted.tint.r,
        isNot(legacy.tint.r),
        reason: 'rgb 确实换了，只是被 α = 0 乘掉 —— 记住这条，别写"两者相等"的断言',
      );
    });

    test('系数是乘性的：输出 == 浅色值 × 系数（逐通道）', () {
      // 抽查若干非 0 非满的值，确认"乘"而不是"加"或"插值"。
      for (final alpha in [0.1, 0.35, 0.7, 1.0]) {
        for (final rim in [0.05, 0.2, 0.9]) {
          final tuning = LiquidGlassTuning(tintAlpha: alpha, rimStrength: rim);
          final light = tuning.toStyle(
            borderRadius: 0,
            brightness: Brightness.light,
          );
          final dark = tuning.toStyle(
            borderRadius: 0,
            brightness: Brightness.dark,
            darkBoost: true,
          );
          expect(dark.tint.a, closeTo(light.tint.a * 0.85, 1e-9));
          expect(dark.rimStrength, closeTo(light.rimStrength * 0.6, 1e-9));
        }
      }
    });
  });

  group('成对与开关', () {
    // 折射取默认 8（显式写出会撞 avoid_redundant_argument_values）；重点是深色档是 20。
    const lightTuning = LiquidGlassTuning(rimStrength: 0.4);
    const darkTuning = LiquidGlassTuning(refraction: 20, rimStrength: 0.9);

    test('link = true 时深色仍以浅色档为形状', () {
      final style = lightTuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        dark: darkTuning,
      );
      // 折射 20 是深色档的，不该出现；边光走浅色档 0.4（未开 boost 不缩放）。
      expect(style.refraction, 8);
      expect(style.rimStrength, closeTo(0.4, 1e-9));
    });

    test('link = false 时用深色档本身', () {
      final style = lightTuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        dark: darkTuning,
        link: false,
      );
      expect(style.refraction, 20);
      expect(style.rimStrength, closeTo(0.9, 1e-9));
    });

    test('link = false 但没给深色档 ⇒ 回落浅色档，不是崩或空', () {
      final style = lightTuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        link: false,
      );
      expect(style.refraction, 8);
    });

    test('forMode 与 toStyle 的选档口径一致', () {
      expect(
        lightTuning.forMode(
          brightness: Brightness.dark,
          dark: darkTuning,
          link: false,
        ),
        darkTuning,
      );
      expect(
        lightTuning.forMode(
          brightness: Brightness.light,
          dark: darkTuning,
          link: false,
        ),
        lightTuning,
        reason: '浅色不该被深色档影响',
      );
    });

    test('深色档预填浅色档值 ⇒ 与跟随态逐字段相同（编辑器「不跳」的依据）', () {
      // 外观编辑器打开「独立设置深色档」时会把 liquidGlassTuningDark 预填成
      // 浅色档，承诺"这一按不改变画面"。这条就是那个承诺的契约：配方套在
      // 「选中的那一档」上，两档相同时输出必须逐字段一致。
      const tuning = LiquidGlassTuning(
        refraction: 11,
        blurSigma: 14,
        tintAlpha: 0.55,
        rimStrength: 0.35,
        dispersion: 0.4,
      );
      final followed = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
      );
      final independent = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
        dark: tuning,
        link: false,
      );
      expect(
        independent,
        followed,
        reason: '预填浅色档后画面跳了 —— 编辑器的预填逻辑或 toStyle 的选档错了',
      );
      // 开配方也成立：配方对两态一视同仁。
      expect(
        tuning.toStyle(
          borderRadius: 12,
          brightness: Brightness.dark,
          dark: tuning,
          link: false,
          darkBoost: true,
        ),
        tuning.toStyle(
          borderRadius: 12,
          brightness: Brightness.dark,
          darkBoost: true,
        ),
      );
    });
  });

  group('几何通道不参与深浅配方', () {
    test('折射 / 作用带 / 陡缓 / 高光带宽在四种组合下都原样透传', () {
      const tuning = LiquidGlassTuning(
        refraction: 11,
        refractionBand: 9,
        refractionEdgePow: 2.2,
        rimWidth: 2,
      );
      // 第四组是"深色档独立"：它的几何是另一套值，本测试要验的是**配方不动几何**，
      // 所以给深色档同一套几何，只让配方那一层去缩放强度类通道。
      const darkWithSameGeometry = LiquidGlassTuning(
        refraction: 11,
        refractionBand: 9,
        refractionEdgePow: 2.2,
        rimWidth: 2,
        rimStrength: 0.8,
      );
      final combos = <LiquidGlassStyle>[
        tuning.toStyle(borderRadius: 12, brightness: Brightness.light),
        tuning.toStyle(borderRadius: 12, brightness: Brightness.dark),
        tuning.toStyle(
          borderRadius: 12,
          brightness: Brightness.dark,
          darkBoost: true,
        ),
        tuning.toStyle(
          borderRadius: 12,
          brightness: Brightness.dark,
          dark: darkWithSameGeometry,
          link: false,
          darkBoost: true,
        ),
      ];
      for (final style in combos) {
        expect(style.refraction, 11);
        expect(style.refractionBand, 9);
        expect(style.refractionEdgePow, 2.2);
        expect(style.rimWidth, 2);
      }
    });
  });
}
