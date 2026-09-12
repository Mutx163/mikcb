import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_refraction.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

void main() {
  group('SoftGlassTuning defaults stay in sync with render tokens', () {
    test('optical defaults match SoftGlassRefraction constants', () {
      // 模型默认值是渲染链路硬编码常量的「用户可调镜像」，两边漂移会让
      // 「标准」预设与接入调参前的默认观感不一致。
      expect(SoftGlassTuning.defaultRefraction,
          SoftGlassRefraction.refractionHeightDp);
      expect(SoftGlassTuning.defaultRefraction,
          SoftGlassRefraction.refractionAmountDp);
      expect(
        SoftGlassTuning.defaultChromaticAberration,
        SoftGlassRefraction.chromaticAberrationDp,
      );
      expect(SoftGlassTuning.defaultDepthEffect, SoftGlassRefraction.depthEffect);
      expect(
        SoftGlassTuning.defaultEdgeHighlight,
        SoftGlassTokens.edgeHighlightAlpha,
      );
    });

    test('blur/tint multipliers default to identity (1.0)', () {
      // 倍率 1 = 接入调参前的行为（配方半径与底色不缩放）。
      expect(SoftGlassTuning.defaults.blurRadiusMultiplier, 1);
      expect(SoftGlassTuning.defaults.tintAlphaMultiplier, 1);
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
          SoftGlassTuning.defaults.copyWith(refraction: 3),
        ),
        SoftGlassPreset.custom,
      );
    });

    test('fromValue falls back to standard on unknown value', () {
      expect(
        SoftGlassPresetX.fromValue('nope'),
        SoftGlassPreset.standard,
      );
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
      expect(
        SoftGlassTuning.fromJson(const {}),
        SoftGlassTuning.defaults,
      );
    });

    test('out-of-range json values are clamped', () {
      final clamped = SoftGlassTuning.fromJson(const {
        'blurRadiusMultiplier': 99,
        'tintAlphaMultiplier': -3,
        'refraction': 500,
        'depthEffect': 7,
        'chromaticAberration': -1,
        'edgeHighlight': 2,
      });
      expect(clamped.blurRadiusMultiplier,
          SoftGlassTuning.maxBlurRadiusMultiplier);
      expect(clamped.tintAlphaMultiplier,
          SoftGlassTuning.minTintAlphaMultiplier);
      expect(clamped.refraction, SoftGlassTuning.maxRefraction);
      expect(clamped.depthEffect, SoftGlassTuning.maxDepthEffect);
      expect(clamped.chromaticAberration,
          SoftGlassTuning.minChromaticAberration);
      expect(clamped.edgeHighlight, SoftGlassTuning.maxEdgeHighlight);
    });

    test('copyWith only overrides given fields', () {
      final tuning = SoftGlassTuning.defaults.copyWith(edgeHighlight: 0.5);
      expect(tuning.edgeHighlight, 0.5);
      expect(tuning.refraction, SoftGlassTuning.defaultRefraction);
    });
  });
}
