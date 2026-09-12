import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import '../ui/hyperos/soft_glass/soft_glass_surface.dart';
import '../utils/home_page_background.dart';

// Course chrome tests reference the glass mode through this library.
export '../ui/hyperos/frosted/frosted_appearance.dart' show FrostedGlassMode;

/// Reserved clearance between the weekday chrome band and the course grid.
///
/// Also used historically as frosted-band seam overlap between header and
/// weekday glass. Keep this value so glass/cards are not flush.
const homePageFrostedRegionSeamOverlap = 4.0;

/// Extra glass painted above the chrome glass band's top edge so the liquid
/// glass specular fringe is clipped off-screen instead of showing a 1px
/// hairline seam.
const homePageChromeGlassTopEdgeOverdraw = 4.0;

/// Extra glass painted beyond the band's left/right edges, outside the
/// visible ClipRect, so the liquid-glass shape corners never cross the
/// visible band.
///
/// The package's shaders only refract / edge-light within `thickness` pixels
/// of the shape boundary; at the band's corners that displacement clamps
/// against the backdrop capture and the edge-lighting pass paints a diagonal
/// fringe ("picture frame" / triangle lines) that gets worse as thickness
/// grows (max slider 40) and blur shrinks. Painting the glass far enough
/// beyond the left/right edges (>= max thickness + margin) moves every
/// corner off-screen while the top/bottom edges stay visible, so thickness
/// tuning still changes the band's edge refraction instead of flattening
/// the whole band.
const homePageChromeGlassEdgeOverdraw = 48.0;

/// Extra glass painted BELOW the band's bottom edge, outside the visible
/// ClipRect.
///
/// Kept for API completeness; the preview narrow strip no longer hides the
/// bottom edge — it keeps the edge at the band boundary (like the home page)
/// and caps thickness proportionally so the rim-light stays a thin sheen.
const homePageChromeGlassBottomEdgeOverdraw = 48.0;

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

/// 首页玻璃带应使用的高级材质（柔光 / 液态）；null = 走「顶栏模糊风格」
/// 的基础磨砂（渐进 / 高斯）。
///
/// 主路径：全局材质为高级材质 + 「作用范围 → 首页玻璃带」开 → **跟随全局**，
/// 与弹窗 / 底栏同一份材质，避免「两种玻璃同屏」。
///
/// 旧版本「玻璃材质」独立三档已下线；存量里写死 `liquid` 的用户在
/// `TimetableSettings.fromJson` 里被**上提为全局液态**（观感不变，同时消除第二个轴），
/// 因此这里不再保留任何 legacy 分支。
FrostedGlassMode? homeChromeAdvancedModeOf({
  required FrostedGlassMode glassMode,
  required bool homeChromeScopeEnabled,
}) {
  if (isAdvancedGlassMode(glassMode) && homeChromeScopeEnabled) {
    return glassMode;
  }
  return null;
}

/// [homeChromeAdvancedModeOf] 的 [FrostedAppearance] 便捷入口。
FrostedGlassMode? homeChromeAdvancedGlassMode(FrostedAppearance appearance) =>
    homeChromeAdvancedModeOf(
      glassMode: appearance.glassMode,
      homeChromeScopeEnabled: appearance.liquidGlassHomeChromeEnabled,
    );

/// Number of frames the home chrome glass needs to settle after a wallpaper
/// swap so the backdrop capture is stable before showing the frost.
///
/// Zero when nothing frosted paints (no backdrop, global blur off, or both
/// chrome bands off). Basic frost settles in one frame; advanced material
/// (liquid / soft glass) needs two.
int homePageChromeSettleFrameCount({
  required bool hasBackdrop,
  required bool frostedBlurEnabled,
  required bool headerBlurEnabled,
  required bool weekdayBarBlurEnabled,
  required FrostedGlassMode glassMode,
  bool homeChromeLiquidGlassEnabled = true,
}) {
  if (!hasBackdrop || !frostedBlurEnabled) {
    return 0;
  }
  if (!headerBlurEnabled && !weekdayBarBlurEnabled) {
    return 0;
  }
  // 与 HomePageChromeGlassFill 同判：走高级材质（柔光 / 液态）需两帧稳定，
  // 基础磨砂一帧。
  final chromeUsesAdvanced =
      homeChromeAdvancedModeOf(
        glassMode: glassMode,
        homeChromeScopeEnabled: homeChromeLiquidGlassEnabled,
      ) !=
      null;
  return chromeUsesAdvanced ? 2 : 1;
}

HomePageBackgroundVisual homePageRegionChromeVisual({
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
  required int region,
  required bool chromeBlurEnabled,
}) {
  if (chromeBlurEnabled && hasHomePageBackdrop(settings)) {
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
  return (top: titleBandBottom, height: math.max(0, weekdayBarHeight));
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
    super.key,
  });

  final bool headerBlurEnabled;
  final bool weekdayBarBlurEnabled;
  final bool includeStatusBar;
  final double weekdayBarHeight;

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
      child: const IgnorePointer(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Push the glass beyond the visible band on the left and right
              // so the shape's corners (the source of the diagonal
              // "triangle" fringe / picture-frame streaks at high thickness)
              // stay off-screen and are clipped. The top keeps its small
              // hairline-seam overdraw; the bottom edge stays at the band
              // boundary so thickness tuning keeps its visible edge
              // refraction (see homePageChromeGlassEdgeOverdraw).
              Positioned(
                top: -homePageChromeGlassTopEdgeOverdraw,
                left: -homePageChromeGlassEdgeOverdraw,
                right: -homePageChromeGlassEdgeOverdraw,
                bottom: 0,
                child: HomePageChromeGlassFill(),
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
    this.borderRadius = 0,
    this.useAncestorBackdropGroup = false,
    this.maxThickness,
    super.key,
  });

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

  final double? maxThickness;

  /// Corner radius of the glass shape itself. The chrome band is square (0);
  /// the day-view summary card reuses this material with its card radius —
  /// the liquid-glass shape must be rounded at the source, an outer ClipRRect
  /// alone leaves square refraction / edge lighting.
  final double borderRadius;

  /// Polarity-correct legibility wash colour over raw wallpaper.
  ///
  /// The home chrome band itself no longer paints this scrim: in liquid-glass
  /// mode it is plain glass, the same material as every other surface, and
  /// chrome text contrast is handled by ink polarity
  /// ([homePageChromeForegroundForLuminance]). Kept public for surfaces that
  /// float directly on un-blurred wallpaper and still want a legibility wash —
  /// e.g. the wallpaper picker's header buttons.
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
  /// [HyperosBlurredHeader.homePageRegionTintColor]. The liquid-glass path is
  /// just the header glassColor's milky tint — the band paints no extra
  /// legibility scrim any more, so neither does the stand-in.
  static Color standInWashColor(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);
    // 与 [HomePageChromeGlassFill.build] 同判。
    final advancedMode = useBlur
        ? homeChromeAdvancedGlassMode(appearance)
        : null;
    if (advancedMode == FrostedGlassMode.softGlass) {
      // 底色倍率 = 配方倍率 × 用户调参（与 SoftGlassSurface 的 fill 同口径）。
      return SoftGlassTokens.tint(
        context,
        blurEnabled: useBlur,
        tintAlphaMultiplier:
            SoftGlassRecipe.floatingNavigation.tintAlphaMultiplier *
            appearance.softGlassTuning.tintAlphaMultiplier,
      );
    }
    if (advancedMode == FrostedGlassMode.liquidGlass) {
      return HyperosLiquidGlassSurface.settingsForRole(
        role: HyperosLiquidGlassRole.header,
        brightness: Theme.of(context).brightness,
        tuning: appearance.liquidGlassTuning,
      ).glassColor;
    }
    return HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final appearance = FrostedAppearanceScope.of(context);
    // 仅首页玻璃带走高级材质时走高级面；子页顶栏不经此入口。
    final advancedMode = useBlur
        ? homeChromeAdvancedGlassMode(appearance)
        : null;

    const fill = SizedBox.expand();

    // 柔光：与弹窗 / 底栏同一套雾面材质。玻璃带是窄条，走
    // [SoftGlassSurface] 的默认轻配方 [SoftGlassRecipe.floatingNavigation]
    // （σ ≈ 13.78）；dialog 配方（σ ≈ 53.6）在整条通栏上过重且更贵。
    if (advancedMode == FrostedGlassMode.softGlass) {
      return SoftGlassSurface(
        borderRadius: BorderRadius.circular(borderRadius),
        blurEnabled: useBlur,
        enableShadows: false,
        child: fill,
      );
    }

    if (advancedMode == FrostedGlassMode.liquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.header,
        borderRadius: borderRadius,
        useAncestorBackdropGroup: useAncestorBackdropGroup,
        maxThickness: maxThickness,
        child: fill,
      );
    }

    final frost = FrostedHeaderBackground(
      blurEnabled: useBlur,
      blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
      blurStyle: HyperosBlurredHeader.headerBlurStyleOf(context),
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
