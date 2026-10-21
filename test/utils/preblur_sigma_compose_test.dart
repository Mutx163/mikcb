import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

/// 壁纸那层模糊必须折进玻璃的烤图量 —— 否则玻璃里透出的仍是原图
/// （2026-10-21 用户报「壁纸糊了，可课程卡 / 玻璃带底下还是原来那张」）。
///
/// 期望值全部是**手推**的，不从实现里抄：
/// 高斯核方差可加，先 σ₁ 再 σ₂ 等价于单次 `sqrt(σ₁² + σ₂²)`。
void main() {
  group('composePreblurSigmas', () {
    test('两层都为正：按平方和开根号合成', () {
      // 3 与 4 → 5（勾股数，最好核对）。
      expect(composePreblurSigmas(glassSigma: 3, wallSigma: 4), closeTo(5, 1e-9));
      // 15 与 20 → 25。
      expect(
        composePreblurSigmas(glassSigma: 15, wallSigma: 20),
        closeTo(25, 1e-9),
      );
      // 同值两层：sqrt(2)·σ ≈ 1.4142σ —— 不是 2σ（那会把"糊一点点"放大成大糊）。
      final same = composePreblurSigmas(glassSigma: 10, wallSigma: 10);
      expect(same, closeTo(10 * math.sqrt2, 1e-9));
      expect(same, lessThan(20));
    });

    test('壁纸没糊（0）：原样返回玻璃那层', () {
      expect(composePreblurSigmas(glassSigma: 12, wallSigma: 0), 12);
      expect(composePreblurSigmas(glassSigma: 0, wallSigma: 0), 0);
    });

    test('玻璃是 0 的清档：只剩壁纸那层（不能把 0 当成"没有"就丢掉壁纸）', () {
      // 卡片的 0 是**有效清档**（用户 2026-09-22 口径「让 0 真的清」）。
      // 但壁纸糊了之后，卡片背后本来就是糊壁纸，所以此时应当是 wallSigma 本身。
      expect(composePreblurSigmas(glassSigma: 0, wallSigma: 9), 9);
    });

    test('负值按 0 处理（不该出现，但不许算出 NaN）', () {
      expect(composePreblurSigmas(glassSigma: -1, wallSigma: 8), 8);
      expect(composePreblurSigmas(glassSigma: 8, wallSigma: -1), 8);
      expect(composePreblurSigmas(glassSigma: -3, wallSigma: -4), 0);
    });
  });

  group('resolveHomePreblurSigma 折入壁纸那层', () {
    test('壁纸糊了之后，玻璃带的烤图量变大（否则玻璃底仍是原图）', () {
      final plain = resolveHomePreblurSigma(
        gaussianCardsDrive: false,
        liquidGlassChrome: false,
        sheetBlurSigma: 15,
        liquidGlassTunedBlur: null,
        wallSigma: 0,
      );
      final blurred = resolveHomePreblurSigma(
        gaussianCardsDrive: false,
        liquidGlassChrome: false,
        sheetBlurSigma: 15,
        liquidGlassTunedBlur: null,
        wallSigma: 8,
      );
      expect(plain, 15);
      // sqrt(15² + 8²) = 17
      expect(blurred, closeTo(17, 1e-9));
      expect(blurred, greaterThan(plain));
    });

    test('液态档同样折入，且仍夹在 0~24 之间', () {
      final v = resolveHomePreblurSigma(
        gaussianCardsDrive: false,
        liquidGlassChrome: true,
        sheetBlurSigma: 15,
        liquidGlassTunedBlur: 20,
        wallSigma: 20,
      );
      // sqrt(400+400) ≈ 28.28，被上限 24 夹住
      expect(v, closeTo(24, 1e-9));
    });

    test('2026-10-19 那条口径不破：液态 chrome 仍优先于 gaussianCardsDrive', () {
      // 这条防回归：改成"折入壁纸"时不许把判定顺序又搞乱。
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: true,
          liquidGlassChrome: true,
          sheetBlurSigma: 15,
          liquidGlassTunedBlur: 8,
          wallSigma: 0,
        ),
        8,
      );
    });
  });

  group('resolveCourseCardPreblurSigma 折入壁纸那层', () {
    const liquid = CourseCardSurfaceStyle.liquidGlass;

    test('非液态档仍然不烤（返回 null），壁纸糊了也不烤', () {
      expect(
        resolveCourseCardPreblurSigma(
          cardStyle: CourseCardSurfaceStyle.gaussian,
          cardTuning: null,
          wallSigma: 10,
        ),
        isNull,
      );
      expect(
        resolveCourseCardPreblurSigma(
          cardStyle: CourseCardSurfaceStyle.solid,
          cardTuning: null,
          wallSigma: 10,
        ),
        isNull,
      );
    });

    test('卡片 0 清档 + 壁纸没糊：仍是 0（出原图、不跑高斯）', () {
      const tuning = CourseGlassTuning(
        refraction: 0,
        refractionBand: 0,
        refractionEdgePow: 1,
        dispersion: 0,
        rimStrength: 0,
        rimWidth: 0,
        blurSigma: 0,
        tintAlpha: 0,
      );
      expect(
        resolveCourseCardPreblurSigma(
          cardStyle: liquid,
          cardTuning: tuning,
          wallSigma: 0,
        ),
        0,
      );
    });

    test('卡片 0 清档 + 壁纸糊了：变成壁纸那层（卡片背后本来就是糊壁纸）', () {
      const tuning = CourseGlassTuning(
        refraction: 0,
        refractionBand: 0,
        refractionEdgePow: 1,
        dispersion: 0,
        rimStrength: 0,
        rimWidth: 0,
        blurSigma: 0,
        tintAlpha: 0,
      );
      expect(
        resolveCourseCardPreblurSigma(
          cardStyle: liquid,
          cardTuning: tuning,
          wallSigma: 9,
        ),
        9,
      );
    });

    test('卡片自己的磨砂量与壁纸那层合成后仍不超过 24', () {
      const tuning = CourseGlassTuning(
        refraction: 0,
        refractionBand: 0,
        refractionEdgePow: 1,
        dispersion: 0,
        rimStrength: 0,
        rimWidth: 0,
        blurSigma: 24,
        tintAlpha: 0,
      );
      final v = resolveCourseCardPreblurSigma(
        cardStyle: liquid,
        cardTuning: tuning,
        wallSigma: 24,
      );
      expect(v, closeTo(24, 1e-9));
    });
  });
}
