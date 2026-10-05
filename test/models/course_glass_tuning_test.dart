import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course_glass_tuning.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

const _courseColor = Color(0xFF2563EB);

FrostedAppearance _appearance({
  CourseGlassTuning? cardTuning,
  bool darkBoost = true,
}) {
  return FrostedAppearance(
    sheetBlurSigma: kDefaultFrostedSheetBlurSigma,
    sheetTintAlpha: kDefaultFrostedSheetTintAlpha,
    sheetBarrierAlpha: kDefaultFrostedSheetBarrierAlpha,
    courseCardGlassTuning: cardTuning,
    darkGlassBoostEnabled: darkBoost,
  );
}

CourseGlassStyle _resolve({
  CourseGlassTuning? cardTuning,
  bool darkBoost = true,
  Brightness brightness = Brightness.light,
  double opacityScale = 1,
}) {
  return courseGlassStyleFor(
    appearance: _appearance(cardTuning: cardTuning, darkBoost: darkBoost),
    borderRadius: 12,
    courseColor: _courseColor,
    brightness: brightness,
    opacityScale: opacityScale,
  );
}

void main() {
  group('CourseGlassTuning 出厂档', () {
    test('八项就是全局标准档（用户 2026-10-05：「卡片完全跟通用一样」）', () {
      const t = CourseGlassTuning.courseCard;
      expect(t.refraction, 8);
      expect(t.refractionBand, 11);
      expect(t.refractionEdgePow, 2.5);
      expect(t.dispersion, 0.35);
      expect(t.rimStrength, 0.2);
      expect(t.rimWidth, 1.5);
      expect(t.blurSigma, 5);
      expect(t.tintAlpha, 0.70);
    });

    test('出厂值逐字段等于全局标准档，且是**引用**而非抄一份', () {
      // 这条取代了旧的「CourseGlassStyle 默认值必须逐字段等于全局默认值」约束：
      // 那条靠两个文件里的人肉同步维持。2026-10-05 起卡片那份的出厂值直接引用
      // 全局常量、四档预设也直接引用全局那四个，所以这条钉的是**结果**
      // （两个页面必须是同一种玻璃），而「不会漂」由实现保证。
      expect(
        CourseGlassTuning.courseCard.toLiquidGlassTuning(),
        LiquidGlassTuning.defaults,
      );
      // 八个出厂常量本身也都指着全局那几个（改一处即两边同时改）。
      expect(
        CourseGlassTuning.defaultRefraction,
        LiquidGlassTuning.defaultRefraction,
      );
      expect(
        CourseGlassTuning.defaultRefractionBand,
        LiquidGlassTuning.defaultRefractionBand,
      );
      expect(
        CourseGlassTuning.defaultRefractionEdgePow,
        LiquidGlassTuning.defaultRefractionEdgePow,
      );
      expect(
        CourseGlassTuning.defaultDispersion,
        LiquidGlassTuning.defaultDispersion,
      );
      expect(
        CourseGlassTuning.defaultRimStrength,
        LiquidGlassTuning.defaultRimStrength,
      );
      expect(
        CourseGlassTuning.defaultRimWidth,
        LiquidGlassTuning.defaultRimWidth,
      );
      expect(
        CourseGlassTuning.defaultBlurSigma,
        LiquidGlassTuning.defaultBlurSigma,
      );
      expect(
        CourseGlassTuning.defaultTintAlpha,
        LiquidGlassTuning.defaultTintAlpha,
      );
    });

    test('四档预设与全局那四档同值（两个页面的档位表是同一份）', () {
      expect(
        CourseGlassTuning.presetClear.toLiquidGlassTuning(),
        LiquidGlassTuning.presetClear,
      );
      expect(
        CourseGlassTuning.presetLight.toLiquidGlassTuning(),
        LiquidGlassTuning.presetLight,
      );
      expect(CourseGlassTuning.presetStandard, CourseGlassTuning.courseCard);
      expect(
        CourseGlassTuning.presetDense.toLiquidGlassTuning(),
        LiquidGlassTuning.presetDense,
      );
      // 档位 → 卡片参数的映射，两个 getter 必须给出同一份（设置页两页都靠它）。
      for (final preset in LiquidGlassPresetX.builtIns) {
        expect(
          CourseGlassTuning.matchPreset(preset.recommendedCourseTuning),
          preset,
          reason: '${preset.name} 的卡片档必须能被反推回自己',
        );
        expect(
          preset.recommendedCourseTuning.toLiquidGlassTuning(),
          preset.recommendedTuning,
          reason: '${preset.name}：卡片档与全局档必须是同一个数',
        );
      }
      // 自定义不是一组推荐值，回落标准档（与全局同口径）。
      expect(
        LiquidGlassPreset.custom.recommendedCourseTuning,
        CourseGlassTuning.presetStandard,
      );
    });

    test('四档预设也落在卡片页自己的滑杆格点上', () {
      // 卡片那根模糊滑杆的量程与全局不同（上限 = kPreblurMaxSigma，见设置页的
      // `blurSigmaMax`），染色分格数 2026-10-05 起与全局统一为 20（步长 0.05）。
      // 档位值必须同时落在两页的格点上，否则「同一个档在两页拖出来的数不一样」。
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
        final t = preset.recommendedCourseTuning;
        onGrid(
          t.blurSigma,
          LiquidGlassTuning.minBlurSigma,
          kPreblurMaxSigma,
          kPreblurMaxSigma.round(),
        );
        onGrid(t.tintAlpha, 0, 1, 20);
      }
    });

    test('缺键回落的是**卡片**默认，不是全局默认（本类独立存在的头号理由）', () {
      // 复用 LiquidGlassTuning 的话，这里无法区分「卡片的出厂值」，将来两边数值
      // 一旦分家就会静默取错（卡片发浑且不报错）。
      final restored = CourseGlassTuning.fromJson(
        const <String, dynamic>{'refraction': 12},
      );
      expect(restored.refraction, 12);
      expect(restored.tintAlpha, CourseGlassTuning.defaultTintAlpha);
      expect(restored.blurSigma, CourseGlassTuning.defaultBlurSigma);
    });

    test('toJson 往返与 clamped 收口', () {
      const t = CourseGlassTuning(refraction: 14, tintAlpha: 0.6, blurSigma: 22);
      expect(CourseGlassTuning.fromJson(t.toJson()), t);

      const wild = CourseGlassTuning(refraction: 999, tintAlpha: -1);
      final clamped = wild.clamped();
      expect(clamped.refraction, LiquidGlassTuning.maxRefraction);
      expect(clamped.tintAlpha, LiquidGlassTuning.minTintAlpha);
    });

    test('相等性按八项判定', () {
      expect(
        const CourseGlassTuning(),
        const CourseGlassTuning(),
      );
      expect(
        const CourseGlassTuning(),
        isNot(const CourseGlassTuning(dispersion: 0.9)),
      );
    });
  });

  group('courseGlassStyleFor', () {
    test('没有自定义档时 = 出厂档，染色是课程色 × 0.70', () {
      final glass = _resolve();
      expect(glass.borderRadius, 12);
      expect(glass.refraction, CourseGlassTuning.defaultRefraction);
      expect(glass.refractionBand, CourseGlassTuning.defaultRefractionBand);
      expect(
        glass.refractionEdgePow,
        CourseGlassTuning.defaultRefractionEdgePow,
      );
      expect(glass.dispersion, CourseGlassTuning.defaultDispersion);
      expect(glass.rimStrength, CourseGlassTuning.defaultRimStrength);
      expect(glass.rimWidth, CourseGlassTuning.defaultRimWidth);
      expect(glass.tint.r, _courseColor.r);
      expect(glass.tint.g, _courseColor.g);
      expect(glass.tint.b, _courseColor.b);
      expect(glass.tint.a, closeTo(CourseGlassTuning.defaultTintAlpha, 1e-9));
    });

    test('用户调过的那套直接决定形状', () {
      final glass = _resolve(
        cardTuning: const CourseGlassTuning(
          refraction: 14,
          // 11 是出厂作用带（2026-10-05 从 7 改过来），故意写成默认值：
          // 这条用例要证明"出厂那一项照传"，而不是"某个别的值照传"。
          // ignore: avoid_redundant_argument_values
          refractionBand: 11,
          refractionEdgePow: 4,
          dispersion: 0.8,
          rimStrength: 0.5,
          rimWidth: 2.4,
          tintAlpha: 0.55,
        ),
      );
      expect(glass.refraction, 14);
      expect(glass.refractionBand, 11);
      expect(glass.refractionEdgePow, 4);
      expect(glass.dispersion, 0.8);
      expect(glass.rimStrength, 0.5);
      expect(glass.rimWidth, 2.4);
      expect(glass.tint.a, closeTo(0.55, 1e-9));
    });

    test('深色套同一份配方：边光 ×0.6、色散 ×0.7、染色 ×0.85', () {
      final glass = _resolve(brightness: Brightness.dark);
      expect(
        glass.rimStrength,
        closeTo(
          CourseGlassTuning.defaultRimStrength *
              LiquidGlassDarkRecipe.standard.rimStrengthScale,
          1e-9,
        ),
      );
      expect(
        glass.dispersion,
        closeTo(
          CourseGlassTuning.defaultDispersion *
              LiquidGlassDarkRecipe.standard.dispersionScale,
          1e-9,
        ),
      );
      expect(
        glass.tint.a,
        closeTo(
          CourseGlassTuning.defaultTintAlpha *
              LiquidGlassDarkRecipe.standard.tintAlphaScale,
          1e-9,
        ),
      );
      // 透镜几何与光照无关，不参与配方。
      expect(glass.refraction, CourseGlassTuning.defaultRefraction);
      expect(glass.refractionBand, CourseGlassTuning.defaultRefractionBand);
    });

    test('关掉配方即退回旧口径：深色只收染色 15%，其余不动', () {
      final glass = _resolve(brightness: Brightness.dark, darkBoost: false);
      expect(glass.rimStrength, CourseGlassTuning.defaultRimStrength);
      expect(glass.dispersion, CourseGlassTuning.defaultDispersion);
      expect(
        glass.tint.a,
        closeTo(
          CourseGlassTuning.defaultTintAlpha *
              LiquidGlassDarkRecipe.legacy.tintAlphaScale,
          1e-9,
        ),
      );
    });

    test('浅色永远逐字段等于不套配方的值（配方只作用于深色）', () {
      const tuning = CourseGlassTuning(refraction: 15, rimStrength: 0.42);
      final boosted = _resolve(cardTuning: tuning);
      final plain = _resolve(cardTuning: tuning, darkBoost: false);
      expect(boosted, plain);
    });

    test('课程色的压暗系数在 alpha 上再乘一次，且有下限', () {
      // 冲突 / 放假的压暗走 opacityScale；压到 0 也要留 4% 色相兜底。
      final dimmed = _resolve(opacityScale: 0.5);
      expect(
        dimmed.tint.a,
        closeTo(CourseGlassTuning.defaultTintAlpha * 0.5, 1e-9),
      );
      final vanished = _resolve(opacityScale: 0);
      expect(vanished.tint.a, closeTo(minCourseGlassFillAlpha, 1e-9));
    });
  });

  group('courseGlassFillAlpha', () {
    test('是三个档位共用的那一条式子', () {
      expect(courseGlassFillAlpha(0.42, 0.5), closeTo(0.21, 1e-9));
      expect(courseGlassFillAlpha(1, 2), 1);
      expect(courseGlassFillAlpha(0, 1), minCourseGlassFillAlpha);
    });
  });
}
