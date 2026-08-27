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
/// 不越界时玻璃形状的底边恰好压在可见边界上，thickness 档（滑杆最高 40）
/// 宽度的边缘折射/边缘光全部落在带内。首页连续高带（状态栏+标题+星期栏
/// 约 130dp）里这只是细窄的正常玻璃包边；但设置预览里孤立星期栏玻璃条仅
/// 40dp 高，整条都处在边缘区，底边高光会糊成一条贴在星期栏文字正下方的
/// 粗白亮线——该回归已随周边改动（预览去掉模拟标题行、玻璃包升级）复发了
/// 两次。底边与左右一致越界后，可见区内不再出现任何形状边缘，这条视觉规
/// 则不再依赖采样/着色器内部行为。
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
  bool homeChromeLiquidGlassEnabled = true,
}) {
  if (!hasBackdrop || !frostedBlurEnabled) {
    return 0;
  }
  if (!headerBlurEnabled && !weekdayBarBlurEnabled) {
    return 0;
  }
  // 「液态玻璃作用范围 → 首页玻璃带」关闭时按高斯磨砂结算。
  final chromeIsLiquid = glassMode == FrostedGlassMode.liquidGlass &&
      homeChromeLiquidGlassEnabled;
  return chromeIsLiquid ? 2 : 1;
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
      child: IgnorePointer(
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
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
                child: const HomePageChromeGlassFill(),
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
    // 与 [HomePageChromeGlassFill.build] 同判：家族开关关 → 磨砂洗色。
    if (useBlur &&
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassHomeChromeEnabled) {
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
    // 「液态玻璃作用范围 → 首页玻璃带」关闭时回退磨砂材质。
    final useLiquidGlass =
        useBlur &&
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassHomeChromeEnabled;

    const fill = SizedBox.expand();

    if (useLiquidGlass) {
      return HyperosLiquidGlassSurface(
        role: HyperosLiquidGlassRole.header,
        borderRadius: borderRadius,
        instantUnderlay: false,
        useAncestorBackdropGroup: useAncestorBackdropGroup,
        // 与弹窗/菜单等其他液态玻璃表面同材质：不再为可读性叠加 scrim，
        // chrome 文字对比度由墨色极性（homePageChromeForegroundForLuminance）
        // 保证。
        contentLegibilityFill: false,
        child: fill,
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
