import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/refraction_glass_tuning.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';

void main() {
  group('RefractionGlassPreset 档位语义', () {
    test('value 与 fromValue 往返一致', () {
      for (final preset in RefractionGlassPreset.values) {
        expect(
          RefractionGlassPresetX.fromValue(preset.value),
          preset,
          reason: '${preset.name} 的 value 必须能被 fromValue 读回来',
        );
      }
    });

    test('未知 / 缺失的值归标准档，不会被 custom 抢走', () {
      expect(
        RefractionGlassPresetX.fromValue(null),
        RefractionGlassPreset.standard,
      );
      expect(
        RefractionGlassPresetX.fromValue('liquidGlass'),
        RefractionGlassPreset.standard,
        reason: '历史或别的材质的字符串不能被当成本档',
      );
    });

    test('builtIns 不含 custom', () {
      expect(
        RefractionGlassPresetX.builtIns.contains(RefractionGlassPreset.custom),
        isFalse,
      );
      expect(
        RefractionGlassPresetX.builtIns.length,
        RefractionGlassPreset.values.length - 1,
      );
    });

    test('每个内置档都能被 matchPreset 反推回自己', () {
      for (final preset in RefractionGlassPresetX.builtIns) {
        expect(
          RefractionGlassTuning.matchPreset(preset.recommendedTuning),
          preset,
          reason: '${preset.name} 的推荐参数反推必须回到自己，'
              '否则设置页会显示「自定义」而用户没动过滑杆',
        );
      }
    });

    test('custom 档的推荐参数回落到标准档', () {
      expect(
        RefractionGlassPreset.custom.recommendedTuning,
        RefractionGlassTuning.defaults,
      );
    });

    test('改过一个字段就不再匹配任何内置档', () {
      final tweaked = RefractionGlassTuning.defaults.copyWith(refraction: 9.5);
      expect(
        RefractionGlassTuning.matchPreset(tweaked),
        RefractionGlassPreset.custom,
      );
    });

    test('四档的「厚度感」单调递增', () {
      // 用户选「更厚」时，折射位移、作用带、模糊量都必须跟着涨，不能有的涨有的跌。
      final ladder = RefractionGlassPresetX.builtIns
          .map((preset) => preset.recommendedTuning)
          .toList();
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i].refraction, greaterThan(ladder[i - 1].refraction));
        expect(
          ladder[i].refractionBand,
          greaterThan(ladder[i - 1].refractionBand),
        );
        expect(ladder[i].blurSigma, greaterThan(ladder[i - 1].blurSigma));
        expect(ladder[i].tintAlpha, greaterThan(ladder[i - 1].tintAlpha));
      }
    });
  });

  group('RefractionGlassTuning 默认值', () {
    test('标准档的折射旋钮与课程卡片折射档逐字段一致', () {
      // 「同一个材质只有一种观感」：全局折射与卡片折射是两条独立链路（卡片不受
      // 全局档位约束），但出厂必须长得一样。任何一边改默认值都要同步另一边。
      const card = CourseGlassStyle(borderRadius: 12, tint: Color(0xFF000000));
      const tuning = RefractionGlassTuning.defaults;
      expect(tuning.refraction, card.refraction);
      expect(tuning.refractionBand, card.refractionBand);
      expect(tuning.refractionEdgePow, card.refractionEdgePow);
      expect(tuning.rimStrength, card.rimStrength);
      expect(tuning.rimWidth, card.rimWidth);
    });

    test('默认值落在自己的滑杆区间内', () {
      // 构造默认值落在滑杆区间之外会让「UI 显示」与「内存默认」脱节，
      // 用户把滑杆拖到底也回不到默认值（液态玻璃历史上踩过两次）。
      const t = RefractionGlassTuning.defaults;
      expect(t.refraction, inInclusiveRange(0, RefractionGlassTuning.maxRefraction));
      expect(t.refractionBand, inInclusiveRange(
        RefractionGlassTuning.minRefractionBand,
        RefractionGlassTuning.maxRefractionBand,
      ));
      expect(t.refractionEdgePow, inInclusiveRange(
        RefractionGlassTuning.minRefractionEdgePow,
        RefractionGlassTuning.maxRefractionEdgePow,
      ));
      expect(t.rimStrength, inInclusiveRange(0, 1));
      expect(t.rimWidth, inInclusiveRange(0, RefractionGlassTuning.maxRimWidth));
      expect(t.blurSigma, inInclusiveRange(0, RefractionGlassTuning.maxBlurSigma));
      expect(t.tintAlpha, inInclusiveRange(0, 1));
    });

    test('同值相等，可作为设置页草稿的比较依据', () {
      const a = RefractionGlassTuning(refraction: 9, tintAlpha: 0.4);
      const b = RefractionGlassTuning(refraction: 9, tintAlpha: 0.4);
      const c = RefractionGlassTuning(refraction: 9, tintAlpha: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('RefractionGlassTuning 序列化', () {
    test('toJson / fromJson 往返一致', () {
      const tuning = RefractionGlassTuning(
        refraction: 9.5,
        refractionBand: 8,
        refractionEdgePow: 3,
        rimStrength: 0.3,
        rimWidth: 4,
        blurSigma: 18,
        tintAlpha: 0.6,
      );
      expect(RefractionGlassTuning.fromJson(tuning.toJson()), tuning);
    });

    test('缺键回默认值', () {
      expect(RefractionGlassTuning.fromJson(null), RefractionGlassTuning.defaults);
      expect(
        RefractionGlassTuning.fromJson(const <String, dynamic>{}),
        RefractionGlassTuning.defaults,
      );
    });

    test('越界值被 clamp 回区间内', () {
      final loaded = RefractionGlassTuning.fromJson(const <String, dynamic>{
        'refraction': 999,
        'tintAlpha': -3,
        'blurSigma': 500,
      });
      expect(loaded.refraction, RefractionGlassTuning.maxRefraction);
      expect(loaded.tintAlpha, RefractionGlassTuning.minTintAlpha);
      expect(loaded.blurSigma, RefractionGlassTuning.maxBlurSigma);
      // 未被写坏的键保持默认。
      expect(loaded.refractionBand, RefractionGlassTuning.defaultRefractionBand);
    });

    test('clamped() 对每个旋钮都生效', () {
      final wild = RefractionGlassTuning.defaults.copyWith(
        refraction: -5,
        refractionBand: 100,
        refractionEdgePow: 0,
        rimStrength: 9,
        rimWidth: -1,
        blurSigma: -2,
        tintAlpha: 4,
      ).clamped();
      expect(wild.refraction, RefractionGlassTuning.minRefraction);
      expect(wild.refractionBand, RefractionGlassTuning.maxRefractionBand);
      expect(
        wild.refractionEdgePow,
        RefractionGlassTuning.minRefractionEdgePow,
      );
      expect(wild.rimStrength, RefractionGlassTuning.maxRimStrength);
      expect(wild.rimWidth, RefractionGlassTuning.minRimWidth);
      expect(wild.blurSigma, RefractionGlassTuning.minBlurSigma);
      expect(wild.tintAlpha, RefractionGlassTuning.maxTintAlpha);
    });
  });

  group('RefractionGlassTuning.toStyle', () {
    test('把折射旋钮与圆角原样带进渲染参数', () {
      const tuning = RefractionGlassTuning(
        refraction: 9,
        refractionBand: 8,
        refractionEdgePow: 3,
        rimStrength: 0.3,
        rimWidth: 4,
        blurSigma: 18,
      );
      final style = tuning.toStyle(
        borderRadius: 20,
        brightness: Brightness.light,
      );
      expect(style.borderRadius, 20);
      expect(style.refraction, 9);
      expect(style.refractionBand, 8);
      expect(style.refractionEdgePow, 3);
      expect(style.rimStrength, 0.3);
      expect(style.rimWidth, 4);
      expect(style.blurSigma, 18);
      expect(style.tint, Colors.white.withValues(alpha: 0.70));
    });

    test('深色下底色收 15%，与液态玻璃同口径', () {
      const tuning = RefractionGlassTuning(tintAlpha: 0.4);
      final light = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      final dark = tuning.toStyle(
        borderRadius: 12,
        brightness: Brightness.dark,
      );
      expect((light.tint.a * 1000).round(), 400);
      expect((dark.tint.a * 1000).round(), 340);
    });

    test('底色恒为白色：玻璃的染色由材质定，不由表面定', () {
      // 表面自己带染色就会重演「同一材质两种观感」（历史上被整体删掉过一条
      // 自带纹理的折射通道）。全 app 只有这里产出色。
      final style = RefractionGlassTuning.defaults.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      expect(style.tint.r, 1.0);
      expect(style.tint.g, 1.0);
      expect(style.tint.b, 1.0);
    });
  });
}
