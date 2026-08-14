import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import '../utils/home_page_background.dart';

// Course chrome tests reference the glass mode through this library.
export '../ui/hyperos/frosted/frosted_appearance.dart' show FrostedGlassMode;

/// Reserved clearance between the weekday chrome band and the course grid.
///
/// Also used historically as frosted-band seam overlap between header and
/// weekday glass. Keep this value so glass/cards are not flush.
const homePageFrostedRegionSeamOverlap = 4.0;

/// Extra glass painted around the chrome glass band, outside the visible
/// ClipRect, so the liquid-glass shape boundary never crosses the visible
/// band.
///
/// The package's shaders only refract / edge-light within `thickness` pixels
/// of the shape boundary; at the band's corners that displacement clamps
/// against the backdrop capture and the edge-lighting pass paints a diagonal
/// fringe ("picture frame" / triangle lines) that gets worse as thickness
/// grows (max slider 40) and blur shrinks. Painting the glass far enough off
/// the visible band (>= max thickness + margin) puts every visible pixel in
/// the flat interior of the shape, where displacement and edge lighting are
/// zero — the band renders as clean uniform glass instead.
const homePageChromeGlassEdgeOverdraw = 48.0;

/// Whether any home chrome frosted band should paint over the wallpaper.
///
/// Time column is intentionally excluded: it never uses blur / liquid glass.
bool homePageHasAnyChromeBlur(
  TimetableSettings settings, {
  required bool hasBackdrop,
}) {
  if (!hasBackdrop) {
    return false;
  }
  return settings.homePageHeaderBlurEnabled ||
      settings.homePageWeekdayBarBlurEnabled;
}

/// Number of frames the home chrome glass needs to settle after a wallpaper
/// swap so the backdrop capture is stable before showing the frost.
///
/// Zero when nothing frosted paints (no backdrop, global blur off, or both
/// chrome bands off). Gaussian settles in one frame; liquid glass needs two.
int homePageChromeSettleFrameCount({
  required bool hasBackdrop,
  required bool frostedBlurEnabled,
  required bool headerBlurEnabled,
  required bool weekdayBarBlurEnabled,
  required FrostedGlassMode glassMode,
}) {
  if (!hasBackdrop || !frostedBlurEnabled) {
    return 0;
  }
  if (!headerBlurEnabled && !weekdayBarBlurEnabled) {
    return 0;
  }
  return glassMode == FrostedGlassMode.liquidGlass ? 2 : 1;
}

HomePageBackgroundVisual homePageRegionChromeVisual({
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
  required int region,
  required bool chromeBlurEnabled,
}) {
  if (chromeBlurEnabled && hasHomePageBackdropImage(settings)) {
    return const HomePageBackgroundVisual(color: Colors.transparent);
  }
  return resolveHomePageRegionBackground(
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
    region: region,
  );
}

/// Layout of the chrome glass band (status/title and optional weekday row).
///
/// Exposed for unit tests so the band never extends into the course grid.
({double top, double height}) homePageChromeGlassLayout({
  required double safeAreaTop,
  required bool includeStatusBar,
  required bool headerBlurEnabled,
  required bool weekdayBarBlurEnabled,
  required double weekdayBarHeight,
}) {
  // Title row always occupies this band under the status bar, whether or not
  // header blur is enabled — weekday glass must start after it.
  final titleBandTop = includeStatusBar ? 0.0 : safeAreaTop;
  final titleBandHeight = includeStatusBar
      ? safeAreaTop + homePageHeaderContentHeight
      : homePageHeaderContentHeight;
  final titleBandBottom = titleBandTop + titleBandHeight;

  if (headerBlurEnabled && weekdayBarBlurEnabled) {
    return (
      top: titleBandTop,
      height: titleBandHeight + math.max(0.0, weekdayBarHeight),
    );
  }
  if (headerBlurEnabled) {
    return (top: titleBandTop, height: titleBandHeight);
  }
  // Weekday-only glass: sit on the weekday row. Grid clearance is layout
  // padding under the weekday header, not a shorter glass band.
  return (top: titleBandBottom, height: math.max(0.0, weekdayBarHeight));
}

/// One continuous frosted / liquid-glass chrome mask for the home timetable.
///
/// Covers status bar + title and/or the weekday bar only. The glass layer is
/// physically bounded to that band (not a full-screen ClipPath), so liquid
/// glass / BackdropFilter cannot bleed into the course grid.
class HomePageContinuousChromeFrostedOverlay extends StatelessWidget {
  const HomePageContinuousChromeFrostedOverlay({
    required this.headerBlurEnabled,
    required this.weekdayBarBlurEnabled,
    required this.includeStatusBar,
    required this.weekdayBarHeight,
    this.wallpaperTopLuminance,
    super.key,
  });

  final bool headerBlurEnabled;
  final bool weekdayBarBlurEnabled;
  final bool includeStatusBar;
  final double weekdayBarHeight;

  /// Sampled luminance of the wallpaper behind this band, when known.
  ///
  /// Drives the legibility scrim's polarity so it never fights the ink colour
  /// picked by [homePageChromeForegroundForLuminance]: a dark wallpaper gets a
  /// dark scrim under light ink, not a white wash that flattens contrast.
  final double? wallpaperTopLuminance;

  bool get _hasAnyBand => headerBlurEnabled || weekdayBarBlurEnabled;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyBand) {
      return const SizedBox.shrink();
    }

    final layout = homePageChromeGlassLayout(
      safeAreaTop: MediaQuery.paddingOf(context).top,
      includeStatusBar: includeStatusBar,
      headerBlurEnabled: headerBlurEnabled,
      weekdayBarBlurEnabled: weekdayBarBlurEnabled,
      weekdayBarHeight: weekdayBarHeight,
    );
    if (layout.height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: layout.top,
      left: 0,
      right: 0,
      height: layout.height,
      child: IgnorePointer(
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Paint the glass beyond the visible band on all four sides so
              // the liquid-glass shape boundary (refraction lens + specular
              // fringe) stays off-screen and the whole visible band renders as
              // flat glass — no corner "triangle" lines / picture-frame
              // streaks at high thickness, no 1px hairline seams (see
              // homePageChromeGlassEdgeOverdraw).
              Positioned(
                top: -homePageChromeGlassEdgeOverdraw,
                left: -homePageChromeGlassEdgeOverdraw,
                right: -homePageChromeGlassEdgeOverdraw,
                bottom: -homePageChromeGlassEdgeOverdraw,
                child: HomePageChromeGlassFill(
                  wallpaperTopLuminance: wallpaperTopLuminance,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chrome glass *material* — liquid glass or gaussian frost, per settings.
///
/// Public so the settings previews can paint the same material as the home
/// page while positioning the band themselves:
/// [HomePageContinuousChromeFrostedOverlay] derives its geometry from the real
/// status-bar inset and home-page constants, neither of which applies inside a
/// scaled-down preview box.
class HomePageChromeGlassFill extends StatelessWidget {
  const HomePageChromeGlassFill({
    this.wallpaperTopLuminance,
    this.borderRadius = 0,
    this.useAncestorBackdropGroup = false,
    super.key,
  });

  final double? wallpaperTopLuminance;

  /// Sample the nearest [BackdropGroup]'s full-size backdrop instead of the
  /// band's own clipped bounds.
  ///
  /// The home page's band sits on the physical screen edges, so its own-bounds
  /// backdrop capture never clamps visibly. Inside a settings preview the band
  /// is a small interior rectangle: refraction displacement past its bounds
  /// then clamps against the band's own edges and streaks all four into a
  /// "picture frame". Setting this to true makes the band sample a full-size
  /// grouped capture (wallpaper layer + [UndimmedBackdropCapture] inside the
  /// group) so the displacement range stays inside the captured backdrop.
  final bool useAncestorBackdropGroup;

  /// Corner radius of the glass shape itself. The chrome band is square (0);
  /// the day-view summary card reuses this material with its card radius —
  /// the liquid-glass shape must be rounded at the source, an outer ClipRRect
  /// alone leaves square refraction / edge lighting.
  final double borderRadius;

  /// Polarity-correct legibility scrim colour for this band.
  ///
  /// Public so Opacity-safe stand-ins (day-view summary during the overlay
  /// open/close ramp) can paint the exact same wash over a pre-blurred
  /// wallpaper sample and read as the same glass.
  static Color scrimColor(
    BuildContext context, {
    double? wallpaperTopLuminance,
  }) {
    final luminance = wallpaperTopLuminance;
    final bool wantsDarkScrim = luminance != null
        ? luminance < 0.45
        : Theme.of(context).brightness == Brightness.dark;
    return wantsDarkScrim
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
  }

  /// Wash colour a pre-blur stand-in must paint to read as this material.
  ///
  /// Mirrors [build] exactly. The gaussian-frost path tints with
  /// [HyperosBlurredHeader.homePageRegionTintColor] and paints **no** scrim.
  /// The liquid-glass path is the header glassColor's milky wash **plus**
  /// [scrimColor] over it — the scrim alone reads clearly darker than the
  /// band, so the two layers are composited into one equivalent colour.
  static Color standInWashColor(
    BuildContext context, {
    double? wallpaperTopLuminance,
  }) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);
    if (useBlur && appearance.glassMode == FrostedGlassMode.liquidGlass) {
      final glass = HyperosLiquidGlassSurface.settingsForRole(
        role: HyperosLiquidGlassRole.header,
        brightness: Theme.of(context).brightness,
        tuning: appearance.liquidGlassTuning,
      ).glassColor;
      return _stackedWash(
        glass,
        scrimColor(context, wallpaperTopLuminance: wallpaperTopLuminance),
      );
    }
    return HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
  }

  /// Composites two translucent washes into the one equivalent translucent
  /// colour of painting [over] on top of [under], over any backdrop.
  static Color _stackedWash(Color under, Color over) {
    final overA = over.a;
    final underA = under.a * (1 - overA);
    final outA = overA + underA;
    if (outA <= 0) {
      return const Color(0x00000000);
    }
    double channel(double u, double o) => (o * overA + u * underA) / outA;
    return Color.from(
      alpha: outA,
      red: channel(under.r, over.r),
      green: channel(under.g, over.g),
      blue: channel(under.b, over.b),
    );
  }

  /// Polarity-correct legibility scrim for this band.
  ///
  /// The generic sheet/header fill in [HyperosLiquidGlassSurface] keys off the
  /// *theme* brightness, which is wrong here: with a light theme over a dark
  /// wallpaper it washes the band white while the ink is already white. Follow
  /// the sampled wallpaper luminance instead, and fall back to the theme when
  /// no sample is available.
  Widget _scrim(BuildContext context) {
    final color = scrimColor(
      context,
      wallpaperTopLuminance: wallpaperTopLuminance,
    );
    return Positioned.fill(
      child: IgnorePointer(child: ColoredBox(color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final glassMode = FrostedAppearanceScope.of(context).glassMode;
    final useLiquidGlass = useBlur && glassMode == FrostedGlassMode.liquidGlass;

    const fill = SizedBox.expand();

    if (useLiquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.header,
        borderRadius: borderRadius,
        instantUnderlay: false,
        useAncestorBackdropGroup: useAncestorBackdropGroup,
        // This band paints its own wallpaper-aware scrim below.
        contentLegibilityFill: false,
        child: Stack(
          fit: StackFit.passthrough,
          children: [_scrim(context), fill],
        ),
      );
    }

    final frost = FrostedHeaderBackground(
      blurEnabled: useBlur,
      blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
      tint: HyperosBlurredHeader.homePageRegionTintColor(
        context,
        withBlur: useBlur,
      ),
      child: fill,
    );
    if (borderRadius <= 0) {
      return frost;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: frost,
    );
  }
}

/// Solid mask over the status bar when backdrop scope excludes it.
class HomePageStatusBarBackdropMask extends StatelessWidget {
  const HomePageStatusBarBackdropMask({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.paddingOf(context).top;
    if (height <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: ColoredBox(color: color),
    );
  }
}
