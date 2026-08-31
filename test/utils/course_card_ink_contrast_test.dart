import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/course_color_palette.dart';

void main() {
  group('courseCardContrastRatio', () {
    test('identical colors have ratio 1', () {
      expect(
        courseCardContrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
        closeTo(1.0, 0.001),
      );
    });

    test('black on white is the maximum 21:1', () {
      expect(
        courseCardContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF0D47A1);
      const b = Color(0xFF90CAF9);
      expect(
        courseCardContrastRatio(a, b),
        closeTo(courseCardContrastRatio(b, a), 0.0001),
      );
    });
  });

  group('resolveReadableCourseCardTitleColor keeps the user choice', () {
    // Regression: the previous implementation forced pure white whenever the
    // card hue luminance was below 0.62, which threw away the deliberate deep
    // ink of nearly every preset pastel pairing.
    test('preset deep ink survives on its own pastel card, all styles', () {
      for (final pair in kPresetCourseColorPairs) {
        final card = parseHex(pair.cardHex);
        final ink = parseHex(pair.textHex);
        for (final style in CourseCardSurfaceStyle.values) {
          final resolved = resolveReadableCourseCardTitleColor(
            preferred: ink,
            cardColor: card,
            surfaceShowsWallpaper: courseCardSurfaceShowsWallpaper(style),
          );
          expect(
            resolved,
            ink,
            reason:
                'preset ${pair.textHex} on ${pair.cardHex} ($style) must not '
                'be overridden',
          );
        }
      }
    });

    test('solid style keeps a mid-tone ink that clears the contrast bar', () {
      // Dark navy on a pale card: clearly readable, must be preserved.
      const card = Color(0xFFE3F2FD);
      const ink = Color(0xFF0D47A1);
      expect(
        resolveReadableCourseCardTitleColor(
          preferred: ink,
          cardColor: card,
          surfaceShowsWallpaper: false,
        ),
        ink,
      );
    });
  });

  group('resolveReadableCourseCardTitleColor falls back when unreadable', () {
    test('dark ink on a dark card is replaced', () {
      const card = Color(0xFF1B1B1B);
      const ink = Color(0xFF222222);
      final resolved = resolveReadableCourseCardTitleColor(
        preferred: ink,
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(resolved, isNot(ink));
      expect(
        courseCardContrastRatio(resolved, card),
        greaterThanOrEqualTo(courseCardMinContrastRatio),
      );
    });

    test('the override bar is the critical one, not the advisory one', () {
      // #E65100 on #FFCC80 is a shipped preset at ~2.56:1 — under WCAG AA
      // large (3.0) but well above the invisibility bar (2.0). It must be
      // warned about, never silently rewritten.
      const card = Color(0xFFFFCC80);
      const ink = Color(0xFFE65100);
      final ratio = courseCardContrastRatio(ink, card);
      expect(ratio, lessThan(courseCardMinContrastRatio));
      expect(ratio, greaterThan(courseCardCriticalContrastRatio));
      expect(
        resolveReadableCourseCardTitleColor(
          preferred: ink,
          cardColor: card,
          surfaceShowsWallpaper: false,
        ),
        ink,
      );
    });

    test('white ink on a white card falls back to dark, not to white', () {
      const card = Color(0xFFFFFFFF);
      const ink = Color(0xFFFFFFFF);
      final resolved = resolveReadableCourseCardTitleColor(
        preferred: ink,
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(resolved, isNot(const Color(0xFFFFFFFF)));
      expect(resolved.computeLuminance(), lessThan(0.2));
    });

    test('solid style is covered too (it used to be exempt)', () {
      const card = Color(0xFFFAFAFA);
      const ink = Color(0xFFF7F7F7);
      expect(
        resolveReadableCourseCardTitleColor(
          preferred: ink,
          cardColor: card,
          surfaceShowsWallpaper: false,
        ),
        isNot(ink),
      );
    });
  });

  group('courseCardUnreadablePresetCardHexes', () {
    test('a readable ink reports no failures', () {
      expect(
        courseCardUnreadablePresetCardHexes(
          ink: const Color(0xFF000000),
          surfaceStyle: CourseCardSurfaceStyle.solid,
        ),
        isEmpty,
      );
    });

    test('a near-card-tone ink reports failures so the user is warned', () {
      final failing = courseCardUnreadablePresetCardHexes(
        // Same family/lightness as the pastel cards themselves.
        ink: const Color(0xFFA5D6A7),
        surfaceStyle: CourseCardSurfaceStyle.solid,
      );
      expect(failing, isNotEmpty);
    });
  });

  group('detail color', () {
    test('is derived from the resolved title ink, softened', () {
      const card = Color(0xFF90CAF9);
      const ink = Color(0xFF0D47A1);
      final title = resolveReadableCourseCardTitleColor(
        preferred: ink,
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      final detail = resolveReadableCourseCardDetailColor(
        preferred: ink,
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      expect(detail.r, closeTo(ink.r, 0.001));
      expect(detail.g, closeTo(ink.g, 0.001));
      expect(detail.b, closeTo(ink.b, 0.001));
      expect(detail.a, lessThan(1.0));
    });
  });

  group('detail color polarity (solid surfaces)', () {
    // 回归：白标题（#FF9800 上对比度 2.16 ≥ 2.0 被保留）曾与同样达标的
    // 黑简介（9.7:1）同卡混色——详情墨必须跟随标题墨的明暗极性。
    test('opposite-polarity detail follows the kept white title', () {
      const card = Color(0xFFFF9800);
      final title = resolveReadableCourseCardTitleColor(
        preferred: const Color(0xFFFFFFFF),
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(title, const Color(0xFFFFFFFF)); // advisory 区间内保留用户白墨
      final detail = resolveReadableCourseCardDetailColor(
        preferred: const Color(0xFF000000),
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(detail.r, closeTo(1.0, 0.001));
      expect(detail.g, closeTo(1.0, 0.001));
      expect(detail.b, closeTo(1.0, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });

    test('reverse divergence also snaps to the title ink', () {
      const card = Color(0xFFFF9800);
      final title = resolveReadableCourseCardTitleColor(
        preferred: const Color(0xFF000000),
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(title, const Color(0xFF000000)); // 9.7:1 保留
      final detail = resolveReadableCourseCardDetailColor(
        preferred: const Color(0xFFFFFFFF),
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(detail.r, closeTo(0.0, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });

    test('same-polarity detail keeps its guarded ink (pastel flips both)', () {
      const card = Color(0xFF90CAF9); // 白字 1.75 < 2.0 → 标题翻近黑
      final title = resolveReadableCourseCardTitleColor(
        preferred: const Color(0xFFFFFFFF),
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      expect(title.computeLuminance(), lessThan(0.5));
      final detail = resolveReadableCourseCardDetailColor(
        preferred: const Color(0xFF000000),
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: false,
      );
      // 黑墨本就达标（12:1）且与标题同极性 → 保留纯黑，不并入标题墨。
      expect(detail.r, closeTo(0.0, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });

    test('wallpaper surfaces keep the divergent user choice', () {
      const card = Color(0xFFFF9800);
      final detail = resolveReadableCourseCardDetailColor(
        preferred: const Color(0xFF000000),
        resolvedTitleInk: const Color(0xFFFFFFFF),
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      expect(detail.r, closeTo(0.0, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });
  });

  group('courseCardInkIsNeutral', () {
    test('white / black / greys and near-black deep inks are neutral', () {
      for (final hex in [
        '#FFFFFF', '#000000', '#1F1F1F', '#1A1A1A', '#808080', '#0D0D14',
      ]) {
        expect(courseCardInkIsNeutral(parseHex(hex)), isTrue, reason: hex);
      }
    });

    test('hue-bearing inks are not neutral', () {
      for (final hex in [
        '#FF9800', '#B34700', '#0D47A1', '#F48FB1', '#90CAF9',
      ]) {
        expect(courseCardInkIsNeutral(parseHex(hex)), isFalse, reason: hex);
      }
    });
  });

  group('glass ink rule (gaussian over wallpaper)', () {
    const card = Color(0xFFFF9800); // 课程橙，tint 亮度约 0.437

    test('hue ink drops to auto black on a bright wallpaper', () {
      // effective = 0.437*0.5 + 0.8*0.5 ≈ 0.62 → chrome 墨取近黑
      final ink = resolveReadableCourseCardGlassInk(
        preferred: parseHex('#B34700'),
        cardColor: card,
        wallpaperLuminance: 0.8,
      );
      expect(ink, const Color(0xFF1A1A1A));
    });

    test('hue ink drops to auto white on a dark wallpaper', () {
      // effective ≈ 0.27 < 0.45 → 白墨
      final ink = resolveReadableCourseCardGlassInk(
        preferred: parseHex('#0D47A1'),
        cardColor: card,
        wallpaperLuminance: 0.1,
      );
      expect(ink, const Color(0xFFFFFFFF));
    });

    test('readable neutral ink keeps the user choice on bright wallpaper', () {
      final ink = resolveReadableCourseCardGlassInk(
        preferred: parseHex('#1F1F1F'),
        cardColor: card,
        wallpaperLuminance: 0.8,
      );
      expect(ink, parseHex('#1F1F1F'));
    });

    test('neutral ink that would wash out flips (white on bright glass)', () {
      final ink = resolveReadableCourseCardGlassInk(
        preferred: const Color(0xFFFFFFFF),
        cardColor: card,
        wallpaperLuminance: 0.8,
      );
      expect(ink, const Color(0xFF1A1A1A));
    });

    test('resolver routes glass with luminance through the glass rule', () {
      final title = resolveReadableCourseCardTitleColor(
        preferred: const Color(0xFFFFFFFF),
        cardColor: card,
        surfaceShowsWallpaper: true,
        wallpaperLuminance: 0.8,
      );
      expect(title, const Color(0xFF1A1A1A));
    });

    test('glass without luminance keeps legacy behavior (user choice)', () {
      final title = resolveReadableCourseCardTitleColor(
        preferred: parseHex('#B34700'),
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      expect(title, parseHex('#B34700'));
      final detail = resolveReadableCourseCardDetailColor(
        preferred: const Color(0xFF000000),
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      expect(detail.r, closeTo(0.0, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });

    test('detail ink follows the resolved title ink on glass', () {
      final title = resolveReadableCourseCardTitleColor(
        preferred: const Color(0xFFFFFFFF),
        cardColor: card,
        surfaceShowsWallpaper: true,
        wallpaperLuminance: 0.8,
      );
      expect(title, const Color(0xFF1A1A1A));
      final detail = resolveReadableCourseCardDetailColor(
        preferred: parseHex('#B34700'),
        resolvedTitleInk: title,
        cardColor: card,
        surfaceShowsWallpaper: true,
        wallpaperLuminance: 0.8,
      );
      expect(detail.r, closeTo(title.r, 0.001));
      expect(detail.a, closeTo(0.7, 0.01));
    });
  });
}

Color parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
