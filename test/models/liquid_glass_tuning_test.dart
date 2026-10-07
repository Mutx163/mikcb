import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';

void main() {
  group('LiquidGlassPreset 档位语义', () {
    test('value 与 fromValue 往返一致', () {
      for (final preset in LiquidGlassPreset.values) {
        expect(
          LiquidGlassPresetX.fromValue(preset.value),
          preset,
          reason: '${preset.name} 的 value 必须能被 fromValue 读回来',
        );
      }
    });

    test('未知 / 缺失的值归标准档，不会被 custom 抢走', () {
      expect(
        LiquidGlassPresetX.fromValue(null),
        LiquidGlassPreset.standard,
      );
      expect(
        LiquidGlassPresetX.fromValue('refractionGlass'),
        LiquidGlassPreset.standard,
        reason: '旧档位名（已并入液态玻璃）不能被当成本档的预设值',
      );
    });

    test('builtIns 不含 custom', () {
      expect(
        LiquidGlassPresetX.builtIns.contains(LiquidGlassPreset.custom),
        isFalse,
      );
      expect(
        LiquidGlassPresetX.builtIns.length,
        LiquidGlassPreset.values.length - 1,
      );
    });

    test('每个内置档都能被 matchPreset 反推回自己', () {
      for (final preset in LiquidGlassPresetX.builtIns) {
        expect(
          LiquidGlassTuning.matchPreset(preset.recommendedTuning),
          preset,
          reason: '${preset.name} 的推荐参数反推必须回到自己，'
              '否则设置页会显示「自定义」而用户没动过滑杆',
        );
      }
    });

    test('custom 档的推荐参数回落到标准档', () {
      expect(
        LiquidGlassPreset.custom.recommendedTuning,
        LiquidGlassTuning.defaults,
      );
    });

    test('改过一个字段就不再匹配任何内置档', () {
      final tweaked = LiquidGlassTuning.defaults.copyWith(refraction: 9.5);
      expect(
        LiquidGlassTuning.matchPreset(tweaked),
        LiquidGlassPreset.custom,
      );
    });

    test('四档的「厚度感」单调递增', () {
      // 用户选「更厚」时，折射位移、作用带、模糊量都必须跟着涨，不能有的涨有的跌。
      final ladder = LiquidGlassPresetX.builtIns
          .map((preset) => preset.recommendedTuning)
          .toList();
      for (var i = 1; i < ladder.length; i++) {
        // 折射与边光是**非严格**递增：清澈（第 1 格）到标准（第 7 格）之间折射只有
        // 6 → 8 两个逻辑 px 的余地，10 格塞不下 7 个互不相同的值（滑杆步长 0.5）。
        // 厚薄差主要由模糊与染色拉出来 —— 那两项是严格递增，下面单独钉。
        expect(
          ladder[i].refraction,
          greaterThanOrEqualTo(ladder[i - 1].refraction),
        );
        expect(
          ladder[i].refractionBand,
          greaterThanOrEqualTo(ladder[i - 1].refractionBand),
        );
        expect(
          ladder[i].dispersion,
          greaterThanOrEqualTo(ladder[i - 1].dispersion),
        );
        expect(ladder[i].blurSigma, greaterThan(ladder[i - 1].blurSigma));
        expect(ladder[i].tintAlpha, greaterThan(ladder[i - 1].tintAlpha));
      }
    });

    test('2026-10-05 用户钉的那几个值不许被顺手改掉', () {
      // 这条钉的是**产品口径**本身：
      //   第 7 格（标准）= 折射 8 / 作用带 11 / 模糊 **15** / 染色 **70%**
      //   第 1 格（清澈）= 染色与模糊**都归零**，且自始至终**一个数都没动过**
      //
      // 模糊与染色当天都被降过一次（15→5、0.70→0.20）又都退了回来，理由同一个：
      // 本类的 [defaults] 同时是**全 app 的基准**（弹窗家族恒锁标准档且用户没有开关
      // 可调，顶栏带、玻璃坞都跟它走），动它等于把软件全局的玻璃底色与磨砂程度一起
      // 换掉（用户原话：「标准档位改了导致软件全局的标准变了」）。这条就是防止又一次
      // "看着不顺眼就改一改"——要更清透只能往下选那 10 格阶梯里更薄的几格。
      const std = LiquidGlassTuning.presetStandard;
      expect(std.refraction, 8);
      expect(std.refractionBand, 11);
      expect(std.blurSigma, 15);
      expect(std.tintAlpha, 0.70);

      const clear = LiquidGlassTuning.presetClear;
      expect(clear.refraction, 6);
      expect(clear.refractionBand, 8);
      expect(clear.blurSigma, 0);
      expect(clear.tintAlpha, 0);

      // 最厚那一格的模糊封在 24：卡片那根滑杆的上限就是 `kPreblurMaxSigma` = 24，
      // 再高卡片会显示一个拖不到的数。
      expect(LiquidGlassTuning.presetDense.blurSigma, 24);

      // 「清澈」那两个 0 是**有效取值**不是"没配"：反推仍要认得出它就是清澈档。
      expect(LiquidGlassTuning.matchPreset(clear), LiquidGlassPreset.clear);
    });

    test('10 格阶梯：清澈是第 1 格、标准是第 7 格', () {
      // 用户 2026-10-05 原话：「标准档位在第七档，一共十个档位」。滑杆的读数就是
      // 这个数字，所以「第几格 ↔ 哪一档」必须双向钉死。
      expect(LiquidGlassPresetX.builtIns.length, 10);
      expect(LiquidGlassPreset.clear.step, 1);
      expect(LiquidGlassPreset.standard.step, 7);
      expect(LiquidGlassPreset.dense.step, 10);

      for (final preset in LiquidGlassPresetX.builtIns) {
        expect(preset.step, isNotNull);
        expect(
          LiquidGlassPresetX.fromStep(preset.step!),
          preset,
          reason: '${preset.name} 的第几格必须能反查回自己',
        );
      }
      // 滑杆只可能给 1~10；越界与坏值回落到标准，别把渲染层带崩。
      expect(LiquidGlassPresetX.fromStep(0), LiquidGlassPreset.standard);
      expect(LiquidGlassPresetX.fromStep(11), LiquidGlassPreset.standard);
      expect(LiquidGlassPreset.custom.step, isNull, reason: '自定义不在阶梯上');
    });

    test('四个老存档值仍落在老位置上（升级不能改档名）', () {
      // 2026-10-05 之前只有四档，老存档里就是这四个 value。扩到 10 格之后**仍然
      // 沿用**：老用户升级后档位名不会被静默改成「标准」，参数也不会掉进 custom。
      expect(
        LiquidGlassPresetX.fromValue('clear'),
        LiquidGlassPreset.clear,
      );
      expect(LiquidGlassPresetX.fromValue('light'), LiquidGlassPreset.light);
      expect(
        LiquidGlassPresetX.fromValue('standard'),
        LiquidGlassPreset.standard,
      );
      expect(LiquidGlassPresetX.fromValue('dense'), LiquidGlassPreset.dense);
      // 老的 `light`（四档里的第 2 档）在新阶梯上落在偏薄一侧。
      expect(LiquidGlassPreset.light.step, 6);
    });

    test('nearestPreset：动过旋钮之后滑杆停在最近的那一格', () {
      // 参数精确等于某一格时，最近的那格必然是它自己 —— 滑杆读数不会说谎。
      for (final preset in LiquidGlassPresetX.builtIns) {
        expect(
          LiquidGlassTuning.nearestPreset(preset.recommendedTuning),
          preset,
        );
      }
      // 它存在的理由：用户动过旋钮之后，滑杆要能反映**当前参数的真实厚薄**，
      // 而不是停在"上一次选的那一格"。
      const std = LiquidGlassTuning.presetStandard;
      expect(
        LiquidGlassTuning.nearestPreset(std.copyWith(blurSigma: 26)).step,
        greaterThan(LiquidGlassPreset.standard.step!),
        reason: '模糊拖大之后滑杆必须往右',
      );
      expect(
        LiquidGlassTuning.nearestPreset(std.copyWith(blurSigma: 2)).step,
        lessThan(LiquidGlassPreset.standard.step!),
        reason: '模糊拖小之后滑杆必须往左',
      );
      // 就近的一格自己胜出（模糊挪一格、其余不动）。
      expect(
        LiquidGlassTuning.nearestPreset(
          LiquidGlassTuning.presetLevel3.copyWith(blurSigma: 4),
        ),
        LiquidGlassPreset.level3,
      );
    });

    test('每档每一项都落在自己那根滑杆的格点上', () {
      // 预设值必须是用户拖得到、也看得见的数，否则会出现「档位写着模糊 5，切到
      // 自定义却停在 4」这种对不上的半失效状态。格点数见设置页 `_glassSliderTiles`
      // 的 `divisions`（折射 40 / 作用带 46 / 陡缓 20 / 色散 20 / 边光 20 /
      // 边光带 30 / 模糊 整数 / 染色 20）。
      void onGrid(double value, double min, double max, int divisions) {
        final step = (max - min) / divisions;
        final steps = (value - min) / step;
        expect(
          (steps - steps.round()).abs(),
          lessThan(1e-9),
          reason: '$value 不是 $min~$max 分 $divisions 格上的点',
        );
      }

      for (final preset in LiquidGlassPresetX.builtIns) {
        final t = preset.recommendedTuning;
        onGrid(t.refraction, 0, LiquidGlassTuning.maxRefraction, 40);
        onGrid(
          t.refractionBand,
          LiquidGlassTuning.minRefractionBand,
          LiquidGlassTuning.maxRefractionBand,
          46,
        );
        onGrid(
          t.refractionEdgePow,
          LiquidGlassTuning.minRefractionEdgePow,
          LiquidGlassTuning.maxRefractionEdgePow,
          20,
        );
        onGrid(t.dispersion, 0, 1, 20);
        onGrid(t.rimStrength, 0, 1, 20);
        onGrid(t.rimWidth, 0, LiquidGlassTuning.maxRimWidth, 30);
        onGrid(t.blurSigma, 0, LiquidGlassTuning.maxBlurSigma, 40);
        onGrid(t.tintAlpha, 0, 1, 20);
      }
    });
  });

  group('LiquidGlassTuning 默认值', () {
    test('默认值落在自己的滑杆区间内', () {
      // 构造默认值落在滑杆区间之外会让「UI 显示」与「内存默认」脱节，
      // 用户把滑杆拖到底也回不到默认值（液态玻璃历史上踩过两次）。
      const t = LiquidGlassTuning.defaults;
      expect(t.refraction, inInclusiveRange(0, LiquidGlassTuning.maxRefraction));
      expect(t.refractionBand, inInclusiveRange(
        LiquidGlassTuning.minRefractionBand,
        LiquidGlassTuning.maxRefractionBand,
      ));
      expect(t.refractionEdgePow, inInclusiveRange(
        LiquidGlassTuning.minRefractionEdgePow,
        LiquidGlassTuning.maxRefractionEdgePow,
      ));
      expect(t.dispersion, inInclusiveRange(
        LiquidGlassTuning.minDispersion,
        LiquidGlassTuning.maxDispersion,
      ));
      expect(t.rimStrength, inInclusiveRange(0, 1));
      expect(t.rimWidth, inInclusiveRange(0, LiquidGlassTuning.maxRimWidth));
      expect(t.blurSigma, inInclusiveRange(0, LiquidGlassTuning.maxBlurSigma));
      expect(t.tintAlpha, inInclusiveRange(0, 1));
    });

    test('同值相等，可作为设置页草稿的比较依据', () {
      const a = LiquidGlassTuning(refraction: 9, tintAlpha: 0.4);
      const b = LiquidGlassTuning(refraction: 9, tintAlpha: 0.4);
      const c = LiquidGlassTuning(refraction: 9, tintAlpha: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('LiquidGlassTuning 序列化', () {
    test('toJson / fromJson 往返一致', () {
      const tuning = LiquidGlassTuning(
        refraction: 9.5,
        refractionBand: 8,
        refractionEdgePow: 3,
        rimStrength: 0.3,
        rimWidth: 2.5,
        blurSigma: 18,
        tintAlpha: 0.6,
      );
      expect(LiquidGlassTuning.fromJson(tuning.toJson()), tuning);
    });

    test('缺键回默认值', () {
      expect(LiquidGlassTuning.fromJson(null), LiquidGlassTuning.defaults);
      expect(
        LiquidGlassTuning.fromJson(const <String, dynamic>{}),
        LiquidGlassTuning.defaults,
      );
    });

    test('老存档没有 dispersion 键时回落默认（升级路径）', () {
      final loaded = LiquidGlassTuning.fromJson(const <String, dynamic>{
        'refraction': 9.5,
        'refractionBand': 8,
      });
      expect(loaded.refraction, 9.5);
      expect(loaded.refractionBand, 8);
      expect(loaded.dispersion, LiquidGlassTuning.defaultDispersion);
    });

    test('越界值被 clamp 回区间内', () {
      final loaded = LiquidGlassTuning.fromJson(const <String, dynamic>{
        'refraction': 999,
        'tintAlpha': -3,
        'blurSigma': 500,
      });
      expect(loaded.refraction, LiquidGlassTuning.maxRefraction);
      expect(loaded.tintAlpha, LiquidGlassTuning.minTintAlpha);
      expect(loaded.blurSigma, LiquidGlassTuning.maxBlurSigma);
      // 未被写坏的键保持默认。
      expect(loaded.refractionBand, LiquidGlassTuning.defaultRefractionBand);
    });

    test('clamped() 对每个旋钮都生效', () {
      final wild = LiquidGlassTuning.defaults.copyWith(
        refraction: -5,
        refractionBand: 100,
        refractionEdgePow: 0,
        rimStrength: 9,
        rimWidth: -1,
        blurSigma: -2,
        tintAlpha: 4,
      ).clamped();
      expect(wild.refraction, LiquidGlassTuning.minRefraction);
      expect(wild.refractionBand, LiquidGlassTuning.maxRefractionBand);
      expect(
        wild.refractionEdgePow,
        LiquidGlassTuning.minRefractionEdgePow,
      );
      expect(wild.rimStrength, LiquidGlassTuning.maxRimStrength);
      expect(wild.rimWidth, LiquidGlassTuning.minRimWidth);
      expect(wild.blurSigma, LiquidGlassTuning.minBlurSigma);
      expect(wild.tintAlpha, LiquidGlassTuning.maxTintAlpha);
    });
  });

  group('LiquidGlassTuning.toStyle', () {
    test('把折射旋钮与圆角原样带进渲染参数', () {
      const tuning = LiquidGlassTuning(
        refraction: 9,
        refractionBand: 8,
        refractionEdgePow: 3,
        rimStrength: 0.3,
        rimWidth: 2.5,
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
      expect(style.dispersion, tuning.dispersion);
      expect(style.rimStrength, 0.3);
      expect(style.rimWidth, 2.5);
      expect(style.blurSigma, 18);
      expect(style.tint, Colors.white.withValues(alpha: 0.70));
    });

    test('深色下底色收 15%，与液态玻璃同口径', () {
      const tuning = LiquidGlassTuning(tintAlpha: 0.4);
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
      final style = LiquidGlassTuning.defaults.toStyle(
        borderRadius: 12,
        brightness: Brightness.light,
      );
      expect(style.tint.r, 1.0);
      expect(style.tint.g, 1.0);
      expect(style.tint.b, 1.0);
    });
  });
}
