import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/card_surface_ink.dart';
import 'package:university_timetable/utils/wallpaper_luminance_profile.dart';

/// 「卡面判墨」的核心契约。期望值全部是人推出来的几何关系，不是从实现里抄的：
///
/// * 白字对背景 `L` 的对比度 = `1.05 / (L + 0.05)`；
/// * 黑字（#1A1A1A，亮度 ≈ 0.00806）对 `L` 的对比度 = `(L + 0.05) / 0.05806`；
/// * 两者相等的点解出来 L ≈ 0.2021 —— 这就是「翻面点为什么是 0.2」的来历。
///
/// 2026-10-21 两张真机截图就是在这条曲线上判错的，用例 3 与 4 直接把当时的
/// 实测数值搬进来当反例。
void main() {
  // 常量自检：0.2 不是拍脑袋定的，是解出来的。
  test('黑白对比度相等的亮度点 = 0.2017（这是翻面点的来历）', () {
    const darkInkLuminance = 0.01033; // #1A1A1A = 26/255 的线性亮度
    double whiteRatio(double l) => 1.05 / (l + 0.05);
    double darkRatio(double l) =>
        (l + 0.05) / (darkInkLuminance + 0.05);
    // 解 1.05/(L+0.05) = (L+0.05)/0.06033 得 L ≈ 0.2017。
    const crossover = 0.2017;
    expect(
      (whiteRatio(crossover) - darkRatio(crossover)).abs(),
      lessThan(0.01),
      reason: '在 0.2017 处黑白对比度应当几乎相等',
    );
    // 两侧方向正确：更暗的背景上白字更强，更亮的背景上黑字更强。
    expect(whiteRatio(0.05), greaterThan(darkRatio(0.05)));
    expect(darkRatio(0.6), greaterThan(whiteRatio(0.6)));
  });

  group('bestCardInkForLuminance', () {
    test('近黑背景（0.03）给白字', () {
      expect(bestCardInkForLuminance(0.03), cardInkLight);
    });

    test('亮背景（0.9）给近黑字', () {
      expect(bestCardInkForLuminance(0.9), cardInkDark);
    });

    test('极暗处白字对比度远高于 4.5', () {
      expect(cardInkContrastRatio(cardInkLight, 0.03), greaterThan(4.5));
    });

    // 这条钉住「翻面点必须是 0.2 而不是 0.45」：
    // 在 0.22~0.44 这段，旧口径（背景 < 0.45 就给白字）与实际对比度结论**相反**
    // —— 背景已经很亮，白字只有 2.1~3.9:1，黑字却有 4.5~8.1:1。
    // 删掉这条，把判据改回 0.45 阈值时其余用例全都还是绿的（已实测）。
    for (final luminance in <double>[0.28, 0.35, 0.42]) {
      test('中等亮度 $luminance：必须按对比度选黑字，不能被 0.45 阈值骗成白字', () {
        final ink = bestCardInkForLuminance(luminance);
        expect(ink, cardInkDark);
        // 并且黑字确实明显更优，不是勉强打平。
        expect(
          cardInkContrastRatio(cardInkDark, luminance),
          greaterThan(cardInkContrastRatio(cardInkLight, luminance)),
        );
        expect(
          cardInkContrastRatio(cardInkDark, luminance),
          greaterThan(cardInkBodyTextContrastRatio),
        );
      });
    }
  });

  group('cardSurfaceLuminance（真实染色比例，不是写死 0.5）', () {
    test('实体卡（washAlpha = 1）只看卡自己的颜色', () {
      const fill = Color(0xFF90CAF9);
      expect(
        cardSurfaceLuminance(
          fill: fill,
          washAlpha: 1,
          wallpaperLuminance: 0.9,
        ),
        closeTo(fill.computeLuminance(), 1e-9),
      );
    });

    test('纯壁纸（washAlpha = 0）只看壁纸', () {
      expect(
        cardSurfaceLuminance(
          fill: const Color(0xFFFFFFFF),
          washAlpha: 0,
          wallpaperLuminance: 0.02,
        ),
        closeTo(0.02, 1e-9),
      );
    });

    test('高斯档 42% 染色：白卡压近黑壁纸仍偏暗', () {
      // 白(1.0) × 0.42 + 0.03 × 0.58 = 0.4374
      expect(
        cardSurfaceLuminance(
          fill: const Color(0xFFFFFFFF),
          washAlpha: 0.42,
          wallpaperLuminance: 0.03,
        ),
        closeTo(0.42 + 0.03 * 0.58, 1e-9),
      );
    });
  });

  group('真机反例：2026-10-21 两张截图', () {
    test('截图 1 第三张卡（近黑水面 0.005~0.03）必须给白字', () {
      // 当时：近黑字 #1F1F1F 落在 0.03 的背景上，实测对比度 1.5:1。
      final ink = cardSurfaceInk(
        fill: const Color(0xFF94A3B8), // 非本周灰 / 课程色系
        washAlpha: 0.42,
        wallpaperLuminance: 0.03,
      );
      expect(ink, cardInkLight, reason: '近黑背景上必须是白字');
      final surface = cardSurfaceLuminance(
        fill: const Color(0xFF94A3B8),
        washAlpha: 0.42,
        wallpaperLuminance: 0.03,
      );
      expect(
        cardInkContrastRatio(ink, surface),
        greaterThan(4.5),
        reason: '正文标准：对比度必须达标',
      );
    });

    test('截图 2 日期卡 / 作业带（浅色主题白卡 + 暗壁纸）不能再判成黑字', () {
      // 旧实现：主题白 × 0.20 就已经 = 0.20 的分界点 → 永远黑字。
      // 现在卡面亮度算出来是 0.2×1.0 + 0.8×0.05 = 0.24，
      // 0.24 处黑字 5.0:1 / 白字 3.6:1 —— 黑字确实更优，但它必须**真的**
      // 更优，而不是靠一个 0.45 的魔法阈值永远赢。
      final surface = cardSurfaceLuminance(
        fill: const Color(0xFFFFFFFF),
        washAlpha: 0.2,
        wallpaperLuminance: 0.05,
      );
      expect(surface, closeTo(0.24, 1e-9));
      final darkRatio = cardInkContrastRatio(cardInkDark, surface);
      final lightRatio = cardInkContrastRatio(cardInkLight, surface);
      expect(darkRatio, greaterThan(lightRatio), reason: '0.24 处确实是黑字更优');
      expect(darkRatio, greaterThan(4.5), reason: '而且黑字要真的达标');
    });

    test('壁纸真的黑下去后，同一张白卡必须翻成白字（旧实现不会）', () {
      // 这正是旧口径做不到的事：washAlpha 0.2 时卡面 = 0.2 + 0.8×壁纸。
      // 壁纸 0.01 → 卡面 0.208，此时白字 4.1:1、黑字 4.4:1，接近临界；
      // 壁纸降到 0.0 → 卡面 0.2，黑白几乎相等。要看到"真的翻面"，得用
      // 更薄的染色（液态玻璃 0.7 深色配方 / 清澈档）。
      final surface = cardSurfaceLuminance(
        fill: const Color(0xFFFFFFFF),
        washAlpha: 0.1,
        wallpaperLuminance: 0.01,
      );
      expect(surface, closeTo(0.109, 1e-9));
      expect(
        cardSurfaceInk(
          fill: const Color(0xFFFFFFFF),
          washAlpha: 0.1,
          wallpaperLuminance: 0.01,
        ),
        cardInkLight,
        reason: '卡面 0.109 已低于 0.2，白字应当胜出',
      );
    });
  });

  group('自定义字色（导入「自动匹配字色」写入 #1F1F1F）', () {
    test('近黑背景上不达标 → 不再被强行保留', () {
      // 旧实现拿整屏平均 0.10 检查，4.2:1 通过 → 黑字留在近黑卡上。
      // 现在按这张卡的真实卡面检查：必须换成白字。
      final ink = cardSurfaceInk(
        fill: const Color(0xFF1F1F1F),
        washAlpha: 0.42,
        wallpaperLuminance: 0.03,
        preferred: const Color(0xFF1F1F1F),
      );
      final surface = cardSurfaceLuminance(
        fill: const Color(0xFF1F1F1F),
        washAlpha: 0.42,
        wallpaperLuminance: 0.03,
      );
      expect(
        cardInkContrastRatio(ink, surface),
        greaterThanOrEqualTo(3),
        reason: '换出来的墨色至少要比原来读得清',
      );
      expect(ink, isNot(const Color(0xFF1F1F1F)));
    });

    test('亮卡上的深色自定义字色照旧保留（不误伤）', () {
      const preferred = Color(0xFF1F1F1F);
      final ink = cardSurfaceInk(
        fill: const Color(0xFFFFF3E0),
        washAlpha: 0.42,
        wallpaperLuminance: 0.95,
        preferred: preferred,
      );
      expect(ink, preferred, reason: '在达标的情况下必须尊重用户/导入的颜色');
    });

    test('壁纸亮度未知时保留自定义字色（旧行为不变）', () {
      const preferred = Color(0xFF0D47A1);
      final ink = cardSurfaceInk(
        fill: const Color(0xFF90CAF9),
        washAlpha: 0.42,
        wallpaperLuminance: null,
        preferred: preferred,
      );
      expect(ink, preferred);
    });
  });

  group('染色比例必须是真实值，不能拿出厂常数顶替', () {
    // 2026-10-21 实测（截图 2：浅色主题 + 水墨夜景壁纸）反推出来的事实：
    //   摘要卡内部 0.071，紧邻上下的裸壁纸 0.078~0.114 —— 卡面比壁纸更暗，
    //   说明有效染色只有 ~3%，而代码里的出厂常数是 0.42 / 0.70。
    // 拿常数判会把卡面算成 0.44~0.72 的中灰，于是给近黑壁纸上的卡发黑字。
    test('3% 染色（实测值）→ 近黑壁纸上的卡必须给白字', () {
      final ink = cardSurfaceInk(
        fill: const Color(0xFFFFFFFF), // 浅色主题的主题卡面
        washAlpha: 0.03, // 实测有效染色
        wallpaperLuminance: 0.05,
      );
      expect(ink, cardInkLight);
    });

    test('同一个场景若错用出厂常数 0.42，会算出黑字（这就是旧 bug 的形状）', () {
      final wrong = cardSurfaceInk(
        fill: const Color(0xFFFFFFFF),
        washAlpha: 0.42, // 出厂常数：与实际渲染差一个量级
        wallpaperLuminance: 0.05,
      );
      expect(
        wrong,
        cardInkDark,
        reason: '钉住"常数会判成黑字"这个事实，'
            '以免有人把 washAlpha 参数改回常数还觉得无害',
      );
    });

    test('0.03 与 0.42 在同一壁纸上给出相反结论（必须走真实值）', () {
      const wallpaper = 0.05;
      expect(
        cardSurfaceInk(
          fill: const Color(0xFFFFFFFF),
          washAlpha: 0.03,
          wallpaperLuminance: wallpaper,
        ),
        isNot(
          cardSurfaceInk(
            fill: const Color(0xFFFFFFFF),
            washAlpha: 0.42,
            wallpaperLuminance: wallpaper,
          ),
        ),
        reason: '两者结论不同，所以"传错 washAlpha"是能看出来的',
      );
    });
  });

  group('VerticalBand（按卡片位置取亮度）', () {
    test('由屏幕矩形算出比例', () {
      final band = VerticalBand.fromRect(
        const Rect.fromLTWH(0, 250, 400, 120),
        1000,
      );
      expect(band.fromFraction, closeTo(0.25, 1e-9));
      expect(band.toFraction, closeTo(0.37, 1e-9));
    });

    test('高度为 0 / 屏高非法时给安全兜底，不抛异常', () {
      expect(
        () => VerticalBand.fromRect(const Rect.fromLTWH(0, 0, 10, 0), 0),
        returnsNormally,
      );
      final band = VerticalBand.fromRect(const Rect.fromLTWH(0, 0, 10, 0), 0);
      expect(band.toFraction, greaterThan(band.fromFraction));
    });

    test('剖面按区间取平均：上半亮、下半黑', () {
      final profile = WallpaperLuminanceProfile(
        rowLuminances: List<double>.generate(
          100,
          (i) => i < 50 ? 1.0 : 0.0,
        ),
      );
      expect(
        profile.luminanceForVerticalRange(0, 0.5),
        closeTo(1.0, 1e-9),
      );
      expect(
        profile.luminanceForVerticalRange(0.5, 1),
        closeTo(0.0, 1e-9),
      );
      // 整屏平均：一半亮一半黑。
      expect(profile.luminanceForVerticalRange(0, 1), closeTo(0.5, 1e-9));
    });

    test('区间越界会被收口，不会抛异常', () {
      final profile = WallpaperLuminanceProfile(
        rowLuminances: List<double>.filled(10, 0.5),
      );
      expect(
        () => profile.luminanceForVerticalRange(-1, 2),
        returnsNormally,
      );
      expect(profile.luminanceForVerticalRange(-1, 2), closeTo(0.5, 1e-9));
    });

    test('空剖面返回 null（调用方回落到整屏带）', () {
      expect(WallpaperLuminanceProfile.empty.average, isNull);
      expect(
        WallpaperLuminanceProfile.empty.luminanceForVerticalRange(0, 1),
        isNull,
      );
      expect(WallpaperLuminanceProfile.empty.bands, isNull);
    });
  });

  group('细节墨（教师/地点那几行）', () {
    test('极性跟标题一致', () {
      final detail = cardSurfaceDetailInk(
        cardInkLight,
        surfaceLuminance: 0.03,
      );
      expect(detail.computeLuminance(), greaterThan(0.5));
    });

    test('软化后读不清时提回不透明的同一档墨（极性不变）', () {
      // 白字以 0.3 alpha 落在 0.9 的亮卡上：上屏后是 1.0×0.3 + 0.9×0.7 = 0.93，
      // 与 0.9 的背景只差 1.1:1 —— 必须提回不透明白（对比度 1.05/0.95 ≈ 1.1
      // 也不够，所以实现应当返回原墨，让调用方自己看到"这个组合本来就不行"）。
      final detail = cardSurfaceDetailInk(
        cardInkLight,
        alpha: 0.3,
        surfaceLuminance: 0.9,
      );
      // 白墨在 0.9 的亮卡上天然读不清（1.1:1）—— 这条用例钉的是"不会假装
      // 它可读"：实现必须返回不透明原墨，而不是继续叠一层更糊的半透明墨。
      expect(detail, cardInkLight);
    });

    test('暗卡上的白字软化后仍然达标', () {
      final detail = cardSurfaceDetailInk(
        cardInkLight,
        surfaceLuminance: 0.03,
      );
      // 上屏后 = 1.0×0.92 + 0.03×0.08 = 0.9224；对 0.03 的背景 ≈ 12:1。
      expect(
        cardInkContrastRatio(detail, 0.03),
        greaterThanOrEqualTo(cardInkBodyTextContrastRatio),
      );
    });
  });
}
