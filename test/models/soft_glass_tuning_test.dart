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

    test('edge highlight default matches render token', () {
      expect(
        SoftGlassTuning.defaultEdgeHighlight,
        SoftGlassTokens.edgeHighlightAlpha,
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
