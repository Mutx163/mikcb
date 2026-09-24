import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overlay_header.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

/// Hue in degrees; the accents used here sit in the blue/green range so a
/// plain difference is enough (no 0/360 wrap).
double _hueOf(Color color) => HSLColor.fromColor(color).hue;

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
          homeBandGlassMaterial: 'progressive',
        ),
        0,
      );
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: false,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: true,
          homeBandGlassMaterial: 'progressive',
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
          homeBandGlassMaterial: 'progressive',
        ),
        0,
      );
    });

    test('实体档需一帧稳定；非实体档（含存量中间档）需两帧', () {
      expect(
        homePageChromeSettleFrameCount(
          hasBackdrop: true,
          frostedBlurEnabled: true,
          headerBlurEnabled: true,
          weekdayBarBlurEnabled: false,
          homeBandGlassMaterial: 'solid',
        ),
        1,
      );
      // 判据是「液态」：只有液态玻璃带需要等预模糊落地再出图（两帧）。
      // 磨砂带（'frost'，跟随默认 + 默认档高斯）走渐进模糊链路，没有折射
      // 位移，与实体一样一帧就稳。
      for (final material in ['liquid', 'frost', 'solid']) {
        expect(
          homePageChromeSettleFrameCount(
            hasBackdrop: true,
            frostedBlurEnabled: true,
            headerBlurEnabled: false,
            weekdayBarBlurEnabled: true,
            homeBandGlassMaterial: material,
          ),
          material == 'liquid' ? 2 : 1,
          reason: material,
        );
      }
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

    test('zoom 缩小取景窗口、且保住对齐点', () {
      const viewport = Size(400, 800);
      const image = Size(1600, 800);
      // 基准：可见宽度 0.25、居中起点 0.375。放大 2 倍 ⇒ 0.125、起点 0.4375。
      final zoomed = homePageWallpaperVisibleSourceRect(
        viewportSize: viewport,
        imageSize: image,
        zoom: 2,
      );
      expect(zoomed.width, closeTo(0.125, 0.0001));
      expect(zoomed.left, closeTo(0.4375, 0.0001));

      // -1 / +1 两个端点与不放大时一致：贴哪条边还是贴哪条边（放大只是把窗口收窄）。
      expect(
        homePageWallpaperVisibleSourceRect(
          viewportSize: viewport,
          imageSize: image,
          alignX: -1,
          zoom: 2,
        ).left,
        closeTo(0, 0.0001),
      );
      final rightEdge = homePageWallpaperVisibleSourceRect(
        viewportSize: viewport,
        imageSize: image,
        alignX: 1,
        zoom: 2,
      );
      expect(rightEdge.left + rightEdge.width, closeTo(1, 0.0001));

      // 越界倍数被钳到渲染侧同一份上下限。
      expect(
        homePageWallpaperVisibleSourceRect(
          viewportSize: viewport,
          imageSize: image,
          zoom: 99,
        ).width,
        closeTo(0.25 / kWallpaperMaxScale, 0.0001),
      );
      expect(
        homePageWallpaperVisibleSourceRect(
          viewportSize: viewport,
          imageSize: image,
          zoom: 0.1,
        ).width,
        closeTo(0.25, 0.0001),
      );
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

    test('user custom colour keeps its hue when unreadable over the wallpaper', () {
      const customBlue = Color(0xFF2563EB);
      // Dark band (0.05): the blue keeps only ~1.2:1 → lightened until it
      // clears 3:1, and it stays blue (never swapped for pure white).
      final onDarkBand = homePageOverWallpaperInk(
        configuredHex: '#2563EB',
        defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
        themeFallback: const Color(0xFF111111),
        hasBackdrop: true,
        wallpaperLuminance: 0.05,
      );
      expect(homePageInkHasSufficientContrast(onDarkBand, 0.05), isTrue);
      expect(onDarkBand, isNot(homePageChromeForegroundOnDark));
      expect((_hueOf(onDarkBand) - _hueOf(customBlue)).abs(), lessThan(5));
      // A near-white custom ink on a light band has no hue to keep: it goes to
      // the black pole outright, not to a "just 3:1" mid grey. That is the
      // same outcome the old flip gave, and it is what a grey pick deserves.
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
      // Same for a hand-picked dark grey on a dark band (black wallpaper) →
      // the white pole.
      expect(
        homePageOverWallpaperInk(
          configuredHex: '#3C3C3C',
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0,
        ),
        homePageChromeForegroundOnDark,
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

    test('default ink still flips black/white with the wallpaper', () {
      // Nothing was picked here, so the auto flip stays: that IS the default's
      // behaviour (and the ink keeps ~10:1 instead of stopping at 3:1).
      expect(
        homePageOverWallpaperInk(
          configuredHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          defaultHex: TimetableSettings.defaultWeekdayBarFontColorLight,
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
          wallpaperLuminance: 0.6,
        ),
        homePageChromeForegroundOnLight,
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

    test('unreadable accent keeps its hue and only moves in lightness', () {
      // No backdrop → the accent always stays.
      expect(
        homePageOverWallpaperAccent(
          configuredHex: '#2563EB',
          themeFallback: const Color(0xFF111111),
          hasBackdrop: true,
        ),
        const Color(0xFF2563EB),
      );
      const accent = Color(0xFF2563EB);
      // Dark band: the default blue sits at ~1.2:1 → lightened toward white
      // (pale blue), NOT replaced by pure white.
      final onDarkBand = homePageOverWallpaperAccent(
        configuredHex: '#2563EB',
        themeFallback: const Color(0xFF111111),
        hasBackdrop: true,
        wallpaperLuminance: 0.05,
      );
      expect(homePageInkHasSufficientContrast(onDarkBand, 0.05), isTrue);
      expect(onDarkBand, isNot(homePageChromeForegroundOnDark));
      expect(
        onDarkBand.computeLuminance(),
        greaterThan(accent.computeLuminance()),
      );
      expect((_hueOf(onDarkBand) - _hueOf(accent)).abs(), lessThan(5));
      // Mid band (~0.5): used to flip to pure black; now a darker blue.
      final onMidBand = homePageOverWallpaperAccent(
        configuredHex: '#2563EB',
        themeFallback: const Color(0xFF111111),
        hasBackdrop: true,
        wallpaperLuminance: 0.5,
      );
      expect(homePageInkHasSufficientContrast(onMidBand, 0.5), isTrue);
      expect(onMidBand, isNot(Colors.black));
      expect(
        onMidBand.computeLuminance(),
        lessThan(accent.computeLuminance()),
      );
      expect((_hueOf(onMidBand) - _hueOf(accent)).abs(), lessThan(5));
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

    test('readableColorOnLuminance keeps the configured hue on both sides', () {
      const accent = Color(0xFF4CAF50);
      final onDarkBand = readableColorOnLuminance(accent, 0.05);
      final onMidBand = readableColorOnLuminance(accent, 0.5);
      expect(homePageInkHasSufficientContrast(onDarkBand, 0.05), isTrue);
      expect(homePageInkHasSufficientContrast(onMidBand, 0.5), isTrue);
      expect((_hueOf(onDarkBand) - _hueOf(accent)).abs(), lessThan(5));
      expect((_hueOf(onMidBand) - _hueOf(accent)).abs(), lessThan(5));
      // 0.4 is a band the "toward white" side cannot serve — pure white tops
      // out at 2.3:1 there — while the dark side needs only a few steps. The
      // smaller move wins, so the accent stays blue (never pure white).
      final onStuckBand = readableColorOnLuminance(accent, 0.4);
      expect(homePageInkHasSufficientContrast(onStuckBand, 0.4), isTrue);
      expect(onStuckBand, isNot(Colors.white));
      expect((_hueOf(onStuckBand) - _hueOf(accent)).abs(), lessThan(5));
      // 0.3 is the boundary case that separates "fewest steps" from "same
      // polarity as the neighbouring labels": lightening needs the full walk
      // to pure white, darkening needs a handful of steps → the hue stays.
      final onBoundaryBand = readableColorOnLuminance(accent, 0.3);
      expect(homePageInkHasSufficientContrast(onBoundaryBand, 0.3), isTrue);
      expect(onBoundaryBand, isNot(Colors.white));
      expect((_hueOf(onBoundaryBand) - _hueOf(accent)).abs(), lessThan(5));
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
    test('header+weekday band covers the chrome-grid clearance too', () {
      // 页面在星期行与课表之间留了 `homePageFrostedRegionSeamOverlap` 的间隙；
      // 带子必须把它一起盖住，否则那一小条完全没有玻璃（磨砂一开读成一条暗线）。
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
      expect(
        layout.height,
        safeTop +
            homePageHeaderContentHeight +
            weekday +
            homePageFrostedRegionSeamOverlap,
      );
    });

    test('带底正好落在课表第一行的上沿', () {
      // 页面自己怎么排的（`_buildWeekPage`）：星期行 → 间隙 → 课表。所以课表上沿 =
      // 标题行底 + 星期行高 + 间隙。带底比它高一点，那一小条就没玻璃、磨砂一开
      // 读成一条横贯屏幕的暗线；比它低就是压进课表。
      const safeTop = 48.0;
      const weekday = 40.0;
      final layout = homePageChromeGlassLayout(
        safeAreaTop: safeTop,
        includeStatusBar: true,
        headerBlurEnabled: true,
        weekdayBarBlurEnabled: true,
        weekdayBarHeight: weekday,
      );
      const gridTop =
          safeTop +
          homePageHeaderContentHeight +
          weekday +
          homePageFrostedRegionSeamOverlap;
      expect(layout.top + layout.height, gridTop);
    });

    test('标题行常量必须等于根标题栏的最小高度', () {
      // 上一条几何断言的**前提**：带子把标题行当成 `homePageHeaderContentHeight`
      // 高，而页面真正排出来的是根标题栏自己的高度。两者一旦不一致，带底就不再
      // 落在课表上沿（2026-09-20 的真因就是 46 vs 44 —— 差出来的 2px 正好是那条
      // 没有玻璃的横条）。这里只钉最小高度；标题内容比它高时两者仍会分叉，属已知
      // 边界（首页标题行固定是一行 24px 文字 + 动作钮，不到 44）。
      const header = HyperosRootHeader(title: SizedBox.shrink());
      expect(homePageHeaderContentHeight, header.minHeight);
    });

    test('weekday-only band starts below title bar and covers the clearance', () {
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
      expect(
        layout.height,
        weekday + homePageFrostedRegionSeamOverlap,
        reason: '只有星期行时同样要盖住它下面那段间隙',
      );
    });

    test('标题行单独成带时不带那段间隙', () {
      // 没有星期行 ⇒ 页面也不留那段间隙，带子到标题行底为止。
      const safeTop = 48.0;
      final layout = homePageChromeGlassLayout(
        safeAreaTop: safeTop,
        includeStatusBar: true,
        headerBlurEnabled: true,
        weekdayBarBlurEnabled: false,
        weekdayBarHeight: 40,
      );
      expect(layout.height, safeTop + homePageHeaderContentHeight);
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
        // streaks) stay outside the visible band at any thickness. Only the
        // left/right edges are pushed this far: the bottom edge deliberately
        // stays on the band (overhang 0) so its refraction + highlight ring
        // stays inside the visible region, and the top edge only needs to
        // clear the refraction band (see homePageChromeGlassVerticalOverhang).
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

  group('controllerPageOrNull', () {
    const pagerChildren = [Text('a'), Text('b'), Text('c')];

    testWidgets('reads the live page with a single attached PageView', (
      tester,
    ) async {
      final controller = PageController(initialPage: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 200,
            child: PageView(controller: controller, children: pagerChildren),
          ),
        ),
      );
      expect(controllerPageOrNull(controller), 1.0);
      controller.dispose();
    });

    test('returns null before any PageView attached', () {
      final controller = PageController(initialPage: 3);
      expect(controllerPageOrNull(controller), isNull);
    });

    testWidgets(
      'returns null in the subtree-replacement double-attach frame instead of asserting',
      (tester) async {
        // Setting a wallpaper flips hasBackdrop / useHomePreblur gates, which
        // wrap or rebuild the home stack around the week pager. The outgoing
        // PageView element deactivates immediately but its scroll position
        // only detaches at end-of-frame unmount (ScrollableState.dispose),
        // so the fresh PageView attaches while the stale one is still
        // attached: positions.length == 2 for that whole frame. This mirrors
        // that window by swapping in a two-pager tree and probing mid-build.
        final controller = PageController(initialPage: 1);
        Widget singlePager() => SizedBox(
          height: 200,
          child: PageView(controller: controller, children: pagerChildren),
        );

        await tester.pumpWidget(MaterialApp(home: singlePager()));
        expect(controllerPageOrNull(controller), 1.0);

        Object? directPageError;
        double? pageViaHelper;
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PageView(
                    controller: controller,
                    children: pagerChildren,
                  ),
                ),
                // Built after the fresh PageView attached, so this reads in
                // the same double-attach frame the wallpaper layers hit.
                Builder(
                  builder: (context) {
                    try {
                      controller.page;
                    } catch (error) {
                      directPageError = error;
                    }
                    pageViaHelper = controllerPageOrNull(controller);
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        );

        // The legacy read asserts in this frame — the reported wallpaper
        // crash. The tolerant read returns null so callers can fall back to
        // the controller's initialPage for the one transitional frame.
        expect(directPageError, isA<AssertionError>());
        expect(pageViaHelper, isNull);

        // After the frame finalizes, the outgoing position detaches and the
        // surviving pager's page reads normally again.
        expect(controllerPageOrNull(controller), 1.0);
        controller.dispose();
      },
    );
  });
}
