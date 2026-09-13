import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

void main() {
  group('SoftGlassTuning defaults', () {
    test('blur/tint multipliers default to identity (1.0)', () {
      // 倍率 1 = 配方半径与底色不缩放，直接落到上游 OS4 材质。
      expect(SoftGlassTuning.defaults.blurRadiusMultiplier, 1);
      expect(SoftGlassTuning.defaults.tintAlphaMultiplier, 1);
    });

    test('edge highlight default is identity (menu parity)', () {
      // 1.0 = 不缩放上游描边 = 首页菜单 / 选择弹层原样。
      //
      // 曾经是 0.95（自研链路 SoftGlassTokens.edgeHighlightAlpha 的数值）。
      // 迁到上游后那个值变成了「给菜单同款描边再乘 0.95」，于是标准档其实
      // 比菜单暗一档，与「标准档 = 菜单原样」的承诺矛盾。
      expect(SoftGlassTuning.defaultEdgeHighlight, 1);
      expect(SoftGlassTuning.presetStandard.edgeHighlight, 1);
    });

    test('recipe baseline is sourced from the render token', () {
      // 「标准档 = 菜单同款」的半径承诺：配方基准必须等于 token 常量。
      expect(
        SoftGlassRecipe.standard.blurRadiusDp,
        SoftGlassTokens.baseBlurRadius,
      );
    });
  });

  group('SoftGlassPreset', () {
    test('built-in presets round-trip through matchPreset', () {
      for (final preset in SoftGlassPresetX.builtIns) {
        expect(
          SoftGlassTuning.matchPreset(preset.recommendedTuning),
          preset,
          reason: '$preset.recommendedTuning 应反查回自身',
        );
      }
    });

    test('unknown tuning resolves to custom', () {
      expect(
        SoftGlassTuning.matchPreset(
          SoftGlassTuning.defaults.copyWith(blurRadiusMultiplier: 1.23),
        ),
        SoftGlassPreset.custom,
      );
    });

    test('fromValue falls back to standard on unknown value', () {
      expect(SoftGlassPresetX.fromValue('nope'), SoftGlassPreset.standard);
      expect(SoftGlassPreset.custom.value, 'custom');
    });

    test('custom preset falls back to standard tuning', () {
      expect(
        SoftGlassPreset.custom.recommendedTuning,
        SoftGlassTuning.presetStandard,
      );
    });
  });

  group('SoftGlassTuning json / copyWith / clamp', () {
    test('json round trip preserves every field', () {
      const tuning = SoftGlassTuning.presetDense;
      final restored = SoftGlassTuning.fromJson(tuning.toJson());
      expect(restored, tuning);
    });

    test('null json falls back to defaults', () {
      expect(SoftGlassTuning.fromJson(null), SoftGlassTuning.defaults);
      expect(SoftGlassTuning.fromJson(const {}), SoftGlassTuning.defaults);
    });

    test('legacy refraction-era fields are ignored, not fatal', () {
      // 自研折射链路删除后，旧备份/旧设置里仍可能带着 refraction /
      // depthEffect / chromaticAberration，解析必须继续可用。
      final legacy = SoftGlassTuning.fromJson(const {
        'blurRadiusMultiplier': 1.5,
        'refraction': 999,
        'depthEffect': 7,
        'chromaticAberration': -1,
      });
      expect(legacy.blurRadiusMultiplier, 1.5);
      expect(legacy.tintAlphaMultiplier, 1);
      expect(legacy.edgeHighlight, SoftGlassTuning.defaultEdgeHighlight);
    });

    test('out-of-range json values are clamped', () {
      final clamped = SoftGlassTuning.fromJson(const {
        'blurRadiusMultiplier': 99,
        'tintAlphaMultiplier': -3,
        'edgeHighlight': 2,
      });
      expect(
        clamped.blurRadiusMultiplier,
        SoftGlassTuning.maxBlurRadiusMultiplier,
      );
      expect(clamped.tintAlphaMultiplier, SoftGlassTuning.minTintAlphaMultiplier);
      expect(clamped.edgeHighlight, SoftGlassTuning.maxEdgeHighlight);
    });

    test('copyWith only overrides given fields', () {
      final tuning = SoftGlassTuning.defaults.copyWith(edgeHighlight: 0.5);
      expect(tuning.edgeHighlight, 0.5);
      expect(tuning.blurRadiusMultiplier, 1);
    });
  });
}
