import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

void main() {
  group('homePageHasAnyChromeBlur', () {
    test('false without backdrop even if blur switches on', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageHeaderBlurEnabled: true,
        homePageWeekdayBarBlurEnabled: true,
      );
      expect(homePageHasAnyChromeBlur(settings, hasBackdrop: false), isFalse);
    });

    test('true when header or weekday blur enabled with backdrop', () {
      final headerOnly = TimetableSettings.defaults().copyWith(
        homePageHeaderBlurEnabled: true,
      );
      final weekdayOnly = TimetableSettings.defaults().copyWith(
        homePageWeekdayBarBlurEnabled: true,
      );
      final neither = TimetableSettings.defaults().copyWith(
        homePageHeaderBlurEnabled: false,
        homePageWeekdayBarBlurEnabled: false,
      );
      expect(homePageHasAnyChromeBlur(headerOnly, hasBackdrop: true), isTrue);
      expect(homePageHasAnyChromeBlur(weekdayOnly, hasBackdrop: true), isTrue);
      // The time column never gets chrome blur; with both chrome toggles off
      // there is no band to paint even when a wallpaper is set.
      expect(homePageHasAnyChromeBlur(neither, hasBackdrop: true), isFalse);
    });
  });

  group('homePageChromeSettleFrameCount', () {
    test('zero without backdrop or global blur', () {
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: false,
          frostedBlurEnabled: true,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: false,
          glassMode: FrostedGlassMode.gaussian,
        ),
        0,
      );
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: false,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: true,
          glassMode: FrostedGlassMode.liquidGlass,
        ),
        0,
      );
    });

    test('zero when chrome bands are both off', () {
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: true,
          headerBlurEnabled: false,
          weekdayBarBlurEnabled: false,
          glassMode: FrostedGlassMode.gaussian,
        ),
        0,
      );
    });

    test('gaussian needs one settle frame; liquid needs two', () {
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: true,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: false,
          glassMode: FrostedGlassMode.gaussian,
        ),
        1,
      );
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: true,
          headerBlurEnabled: false,
          weekdayBarBlurEnabled: true,
          glassMode: FrostedGlassMode.liquidGlass,
        ),
        2,
      );
    });
  });

  group('prepareHomePageVisualReadiness', () {
    test('missing path returns empty regardless of theme', () async {
      final readiness = await prepareHomePageVisualReadiness(
        TimetableSettings.defaults(),
      );
      expect(readiness, HomePageVisualReadiness.empty);
    });

    test('missing file still returns empty via hasBackdrop gate', () async {
      final settings = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: r'C:\does\not\exist\wallpaper.jpg',
        homePageHeaderBlurEnabled: true,
        frostedBlurEnabled: true,
        frostedGlassMode: FrostedGlassMode.liquidGlass,
      );
      final readiness = await prepareHomePageVisualReadiness(settings);
      // hasHomePageBackdropImage uses existsSync; missing file → empty.
      expect(readiness, HomePageVisualReadiness.empty);
    });
  });

  group('homePageWallpaperVisibleSourceRect', () {
    test('wide image crops horizontally and follows alignment', () {
      final centered = homePageWallpaperVisibleSourceRect(
        viewportSize: const Size(400, 800),
        imageSize: const Size(1600, 800),
      );
      expect(centered.left, closeTo(0.375, 0.0001));
      expect(centered.top, 0);
      expect(centered.width, closeTo(0.25, 0.0001));
      expect(centered.height, 1);

      final right = homePageWallpaperVisibleSourceRect(
        viewportSize: const Size(400, 800),
        imageSize: const Size(1600, 800),
        alignX: 1,
      );
      expect(right.left, closeTo(0.75, 0.0001));
      expect(right.width, closeTo(0.25, 0.0001));
    });

    test('tall image crops vertically and clamps alignment', () {
      final top = homePageWallpaperVisibleSourceRect(
        viewportSize: const Size(800, 400),
        imageSize: const Size(800, 1600),
        alignY: -2,
      );
      expect(top.left, 0);
      expect(top.top, 0);
      expect(top.width, 1);
      expect(top.height, closeTo(0.25, 0.0001));

      final bottom = homePageWallpaperVisibleSourceRect(
        viewportSize: const Size(800, 400),
        imageSize: const Size(800, 1600),
        alignY: 2,
      );
      expect(bottom.top, closeTo(0.75, 0.0001));
    });
  });

  group('homePageChromeForegroundForLuminance', () {
    test('dark wallpaper yields light ink', () {
      expect(
        homePageChromeForegroundForLuminance(0.1),
        homePageChromeForegroundOnDark,
      );
    });

    test('light wallpaper yields dark ink', () {
      expect(
        homePageChromeForegroundForLuminance(0.8),
        homePageChromeForegroundOnLight,
      );
    });

    test('null falls back', () {
      expect(
        homePageChromeForegroundForLuminance(
          null,
          fallback: const Color(0xFF112233),
        ),
        const Color(0xFF112233),
      );
    });
  });

  group('homePageOverWallpaperInk', () {
    test('default light ink flips to white on dark wallpaper', () {
      expect(
        homePageOverWallpaperInk(
          configuredHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.1,
        ),
        homePageChromeForegroundOnDark,
      );
    });

    test('user custom color is kept while readable over the wallpaper', () {
      const customBlue = Color(0xFF2563EB);
      // Light band (0.6): contrast ≈ 3.2:1 → the custom colour stays.
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#2563EB',
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.6,
        ),
        customBlue,
      );
    });

    test('user custom color falls back to auto black/white when unreadable '
        'over the wallpaper', () {
      // Dark band (0.05): #2563EB keeps only ~2:1 → auto-flips to white so
      // the chrome never renders invisible ink over the photo.
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#2563EB',
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.05,
        ),
        homePageChromeForegroundOnDark,
      );
      // A light custom ink on a light band is equally unreadable → black.
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#F2F2F2',
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.9,
        ),
        homePageChromeForegroundOnLight,
      );
      // Without a luminance sample (sampling pending) the colour is kept.
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#2563EB',
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: null,
        ),
        const Color(0xFF2563EB),
      );
    });

    test('without wallpaper uses configured or theme fallback', () {
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#123456',
          defaultHex: TimetableSettings.defaultTimeAxisFontColorLight,
          themeFallback: const Color(0xFFAAAAAA),
          hasBackdrop: false,
          wallpaperLuminance: null,
        ),
        const Color(0xFF123456),
      );
      expect(
        homePageOverWallpaperInk(
          configuredHex: null,
          defaultHex: TimetableSettings.defaultTimeAxisFontColorLight,
          themeFallback: const Color(0xFFAAAAAA),
          hasBackdrop: false,
          wallpaperLuminance: 0.1,
        ),
        const Color(0xFFAAAAAA),
      );
    });
  });

  group('homePageOverWallpaperAccent', () {
    test('keeps configured accent and falls back to theme', () {
      expect(
        homePageOverWallpaperAccent(
          configuredHex: '#2563EB',
          themeFallback: const Color(0xFF111111),
        ),
        const Color(0xFF2563EB),
      );
      expect(
        homePageOverWallpaperAccent(
          configuredHex: null,
          themeFallback: const Color(0xFF111111),
        ),
        const Color(0xFF111111),
      );
    });

    test('accent falls back to auto black/white when unreadable', () {
      // No backdrop → the accent always stays.
      expect(
        homePageOverWallpaperAccent(
          configuredHex: '#2563EB',
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
        ),
        const Color(0xFF2563EB),
      );
      // Dark band: the default blue keeps only ~2:1 → auto-flips white so the
      // "today" column never vanishes into the photo.
      expect(
        homePageOverWallpaperAccent(
          configuredHex: '#2563EB',
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.05,
        ),
        homePageChromeForegroundOnDark,
      );
      // Light band: contrast is sufficient → the custom blue stays.
      expect(
        homePageOverWallpaperAccent(
          configuredHex: '#2563EB',
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.6,
        ),
        const Color(0xFF2563EB),
      );
    });
  });

  group('homePageInkHasSufficientContrast', () {
    test('black/white inks are readable on the opposite band', () {
      expect(homePageInkHasSufficientContrast(Colors.black, 1), isTrue);
      expect(homePageInkHasSufficientContrast(Colors.white, 0), isTrue);
    });

    test('same-polarity inks are unreadable', () {
      expect(homePageInkHasSufficientContrast(Colors.black, 0.05), isFalse);
      expect(homePageInkHasSufficientContrast(Colors.white, 0.9), isFalse);
    });

    test('honours the custom ratio threshold', () {
      // Black on 0.35 ≈ 8:1 — passes at 3:1, fails at 9:1.
      expect(homePageInkHasSufficientContrast(Colors.black, 0.35), isTrue);
      expect(
        homePageInkHasSufficientContrast(
          Colors.black,
          0.35,
          minContrastRatio: 9,
        ),
        isFalse,
      );
    });
  });

  group('homePageHeaderBlurBandRect', () {
    test('includes status bar from top when scope enabled', () {
      const safeTop = 48.0;
      const extend = homePageFrostedRegionSeamOverlap;

      final layout = homePageHeaderBlurBandRect(
        safeAreaTop: safeTop,
        includeStatusBar: true,
        extendBottom: extend,
      );

      expect(layout.top, 0);
      expect(layout.height, safeTop + homePageHeaderContentHeight + extend);
    });

    test('starts below status bar when scope disabled', () {
      const safeTop = 48.0;
      const extend = homePageFrostedRegionSeamOverlap;

      final layout = homePageHeaderBlurBandRect(
        safeAreaTop: safeTop,
        includeStatusBar: false,
        extendBottom: extend,
      );

      expect(layout.top, safeTop);
      expect(layout.height, homePageHeaderContentHeight + extend);
    });
  });

  group('homePageChromeGlassLayout', () {
    test(
      'header+weekday band matches chrome height (gap is layout padding)',
      () {
        const safeTop = 48.0;
        const weekday = 40.0;
        final layout = homePageChromeGlassLayout(
          safeAreaTop: safeTop,
          includeStatusBar: true,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: true,
          weekdayBarHeight: weekday,
        );
        expect(layout.top, 0);
        expect(layout.height, safeTop + homePageHeaderContentHeight + weekday);
      },
    );

    test('weekday-only band starts below title bar', () {
      const safeTop = 48.0;
      const weekday = 40.0;
      final layout = homePageChromeGlassLayout(
        safeAreaTop: safeTop,
        includeStatusBar: true,
        headerBlurEnabled: false,
        weekdayBarBlurEnabled: true,
        weekdayBarHeight: weekday,
      );
      expect(layout.top, safeTop + homePageHeaderContentHeight);
      expect(layout.height, weekday);
    });

    test(
      'reserved chrome-grid clearance token is the original seam overlap',
      () {
        expect(homePageFrostedRegionSeamOverlap, 4.0);
      },
    );

    test(
      'side overdraw pushes glass corners off-screen at any thickness',
      () {
        // Must exceed the maximum user-tunable thickness (40) so the shape
        // corners (the source of diagonal "triangle" fringe / picture-frame
        // streaks) stay outside the visible band at any thickness. The
        // top/bottom edges intentionally stay at the band so thickness
        // tuning keeps its visible edge refraction.
        expect(homePageChromeGlassEdgeOverdraw, greaterThanOrEqualTo(40.0));
      },
    );

    test(
      'top overdraw hides liquid specular hairline seam',
      () {
        expect(homePageChromeGlassTopEdgeOverdraw, greaterThanOrEqualTo(2.0));
      },
    );
  });
}
