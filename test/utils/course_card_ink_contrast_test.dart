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
      final detail = resolveReadableCourseCardDetailColor(
        preferred: ink,
        cardColor: card,
        surfaceShowsWallpaper: true,
      );
      expect(detail.r, closeTo(ink.r, 0.001));
      expect(detail.g, closeTo(ink.g, 0.001));
      expect(detail.b, closeTo(ink.b, 0.001));
      expect(detail.a, lessThan(1.0));
    });
  });
}

Color parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
