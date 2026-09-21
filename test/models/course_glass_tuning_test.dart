import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course_glass_tuning.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';

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
    test('八项就是改动前卡片的行为（默认状态观感逐位不变）', () {
      const t = CourseGlassTuning.courseCard;
      expect(t.refraction, 8);
      expect(t.refractionBand, 7);
      expect(t.refractionEdgePow, 2.5);
      expect(t.dispersion, 0.35);
      expect(t.rimStrength, 0.2);
      expect(t.rimWidth, 1.5);
      expect(t.blurSigma, 15);
      // 卡片染的是**课程色**，所以是 0.32（改动前 CourseSurface 里那个值），
      // 不是全局那份的「底色白」0.70。
      expect(t.tintAlpha, 0.32);
    });

    test('与全局标准档只差「染色」一项 —— 出厂观感必须一样', () {
      // 这条取代了旧的「CourseGlassStyle 默认值必须逐字段等于 LiquidGlassTuning」
      // 约束：那条靠两个文件里的人肉同步维持，现在卡片有自己的档，数值一致
      // 本身就是出厂档的定义。这里钉的是**结果**，不是实现。
      const card = CourseGlassTuning.courseCard;
      const global = LiquidGlassTuning.defaults;
      expect(card.refraction, global.refraction);
      expect(card.refractionBand, global.refractionBand);
      expect(card.refractionEdgePow, global.refractionEdgePow);
      expect(card.dispersion, global.dispersion);
      expect(card.rimStrength, global.rimStrength);
      expect(card.rimWidth, global.rimWidth);
      expect(card.blurSigma, global.blurSigma);
      expect(card.tintAlpha, isNot(global.tintAlpha));
    });

    test('缺键回落的是**卡片**默认，不是全局默认（本类独立存在的头号理由）', () {
      // 复用 LiquidGlassTuning 的话，这里会静默变成 0.70（卡片发浑且不报错）。
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
    test('没有自定义档时 = 出厂档，染色是课程色 × 0.32', () {
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
