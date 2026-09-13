import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/progressive_blur_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('ProgressiveBlurTuning defaults stay in sync with render constants', () {
    test('default sigma equals the global frosted blur sigma', () {
      // 模型默认值是渲染链路硬编码常量的「用户可调镜像」：顶栏渐进档接入
      // 调参前用的就是全局高斯 sigma 常量。两边漂移会让「标准」预设与
      // 接入前的默认观感不一致。
      expect(ProgressiveBlurTuning.defaultSigma,
          kDefaultFrostedSheetBlurSigma);
    });

    test('default extent/tint keep the pre-tuning look', () {
      // extent 1 = 完全清晰正好落在带底；底边衬底 0 = 与内容之间无切边。
      expect(ProgressiveBlurTuning.defaults.extent, 1);
      expect(ProgressiveBlurTuning.defaults.tintBottomScale, 0);
    });

    test('scope default is the standard tuning', () {
      expect(
        FrostedAppearance.defaults.progressiveBlurTuning,
        ProgressiveBlurTuning.presetStandard,
      );
    });
  });

  group('ProgressiveBlurPreset', () {
    test('built-in presets round-trip through matchPreset', () {
      for (final preset in ProgressiveBlurPresetX.builtIns) {
        expect(
          ProgressiveBlurTuning.matchPreset(preset.recommendedTuning),
          preset,
          reason: '$preset.recommendedTuning 应反查回自身',
        );
      }
    });

    test('unknown tuning resolves to custom', () {
      expect(
        ProgressiveBlurTuning.matchPreset(
          ProgressiveBlurTuning.defaults.copyWith(sigma: 31),
        ),
        ProgressiveBlurPreset.custom,
      );
    });

    test('fromValue falls back to standard on unknown value', () {
      expect(ProgressiveBlurPresetX.fromValue('nope'),
          ProgressiveBlurPreset.standard);
      expect(ProgressiveBlurPreset.custom.value, 'custom');
    });

    test('custom preset falls back to standard tuning', () {
      expect(
        ProgressiveBlurPreset.custom.recommendedTuning,
        ProgressiveBlurTuning.presetStandard,
      );
    });

    test('no preset leaves a tint at the band bottom', () {
      // 回归钉：衬底在带底只要不是全透明，就会切出一条横向硬边——浓雾档
      // 曾给 0.18，真机口径「最浓状态下底部出现一条横向」。
      for (final preset in ProgressiveBlurPresetX.builtIns) {
        expect(
          preset.recommendedTuning.tintBottomScale,
          0,
          reason: '$preset 不得在带底留残余衬底',
        );
      }
      // 自定义档同样不允许越过「带底全透明」这条线（渲染侧另有兜底）。
      expect(ProgressiveBlurTuning.maxTintBottomScale, greaterThan(0));
    });

    test('extent can never leave blur at the band bottom', () {
      // >1 表示到带底仍有残留模糊，而带外是清晰内容——交界处硬切又是横向边。
      expect(ProgressiveBlurTuning.maxExtent, 1);
      for (final preset in ProgressiveBlurPresetX.builtIns) {
        expect(
          preset.recommendedTuning.extent,
          lessThanOrEqualTo(ProgressiveBlurTuning.maxExtent),
        );
      }
    });

    test('preset ladder is ordered clear < light < standard < dense', () {
      double sigmaOf(ProgressiveBlurPreset preset) =>
          preset.recommendedTuning.sigma;
      expect(sigmaOf(ProgressiveBlurPreset.clear),
          lessThan(sigmaOf(ProgressiveBlurPreset.light)));
      expect(sigmaOf(ProgressiveBlurPreset.light),
          lessThan(sigmaOf(ProgressiveBlurPreset.standard)));
      expect(sigmaOf(ProgressiveBlurPreset.standard),
          lessThan(sigmaOf(ProgressiveBlurPreset.dense)));
      // 渐变更薄的档位必须收得更早。
      expect(
        ProgressiveBlurPreset.clear.recommendedTuning.extent,
        lessThanOrEqualTo(ProgressiveBlurPreset.standard.recommendedTuning.extent),
      );
    });
  });

  group('ProgressiveBlurTuning json / copyWith / clamp', () {
    test('json round trip preserves every field', () {
      const tuning = ProgressiveBlurTuning.presetDense;
      expect(ProgressiveBlurTuning.fromJson(tuning.toJson()), tuning);
    });

    test('null json falls back to defaults', () {
      expect(ProgressiveBlurTuning.fromJson(null), ProgressiveBlurTuning.defaults);
      expect(
        ProgressiveBlurTuning.fromJson(const {}),
        ProgressiveBlurTuning.defaults,
      );
    });

    test('out-of-range json values are clamped', () {
      final clamped = ProgressiveBlurTuning.fromJson(const {
        'sigma': 999,
        'extent': -5,
        'tintBottomScale': 9,
      });
      expect(clamped.sigma, ProgressiveBlurTuning.maxSigma);
      expect(clamped.extent, ProgressiveBlurTuning.minExtent);
      expect(clamped.tintBottomScale,
          ProgressiveBlurTuning.maxTintBottomScale);
    });

    test('copyWith only overrides given fields', () {
      final tuning = ProgressiveBlurTuning.defaults.copyWith(sigma: 30);
      expect(tuning.sigma, 30);
      expect(tuning.extent, ProgressiveBlurTuning.defaultExtent);
      expect(tuning.tintBottomScale,
          ProgressiveBlurTuning.defaultTintBottomScale);
    });

    test('equality is field-wise', () {
      expect(
        const ProgressiveBlurTuning(sigma: 20),
        ProgressiveBlurTuning.defaults.copyWith(sigma: 20),
      );
      expect(
        const ProgressiveBlurTuning(sigma: 20),
        isNot(const ProgressiveBlurTuning(sigma: 21)),
      );
    });
  });
}
