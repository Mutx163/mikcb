import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/header_blur_style.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../ui/hyperos/hyperos_theme.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart';
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
/// 与顶边 **[homePageChromeGlassTopEdgeOverdraw] 同因同解**：着色器的受光高光
/// 与折射位移都集中在离形状边界约 1~2px 的一圈里，形状边界一旦正好落在可见区
/// 边界上，那一圈就直接读成一条 1px 的深色发丝边（真机现象：星期栏底边一条黑
/// 边）。顶边靠往上多画 4px 把这条边推到 ClipRect 之外切掉；底边此前是
/// `bottom: 0`（形状边界与裁剪边界重合），所以只有底边没被治住。
///
/// 取 4 而不是更大的值：底边的折射**是有意保留的**（玻璃带与课表的过渡靠它，
/// 见 [homePageChromeGlassEdgeOverdraw] 的说明），4px 只切掉最外圈那点高光，
/// 可见区内的折射深度还剩 `depth=4` 那一档，观感不变。同一个值也是 edge sheet
/// 的既有口径（`hyperos_sheet.dart` 的 `hyperosEdgeSheetBottomOverdraw`）。
///
/// 历史：这里原先是 48.0 且无人使用（当时的注释只把它当「API 完整性」留着）。
/// 48 会把整条底边折射连同圆角一起切出可见区，与「保留底边折射」的设计冲突。
const homePageChromeGlassBottomEdgeOverdraw = 4.0;

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
  // 顶栏材质选「实体」时那条带是**不透明实心条**（本文件 'solid' 分支：页面
  // 底色实心、完全遮住壁纸），它不再提供任何可"同款"的玻璃材质。下游必须按
  // 实底处理，否则会出现「顶栏实心、下面的卡片/覆盖层还透明」的分裂（真机
  // 反馈：全局实体档、课程卡也是实底，日课表顶上的日期卡却还是透的）。
  //
  // 注意与两个旧开关的关系：`homePageHeaderBlurEnabled` /
  // `homePageWeekdayBarBlurEnabled` 只表达「这两块要不要磨砂」，材质档是
  // 2026-09-12 之后独立选择的，两者可以不一致 —— 所以这里必须看材质。
  if (settings.homeBandGlassMaterial == 'solid') {
    return false;
  }
  return settings.homePageHeaderBlurEnabled ||
      settings.homePageWeekdayBarBlurEnabled;
}

/// 首页顶栏材质是否为高级材质（柔光 / 液态）——两者自带模糊，壁纸预模糊
/// 需要按折射/雾面参数预热，玻璃带渲染也需要额外一帧稳定。
bool homeBandUsesAdvancedGlass(String material) =>
    material == 'soft' || material == 'liquid';

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
  required String homeBandGlassMaterial,
}) {
  if (!hasBackdrop || !frostedBlurEnabled) {
    return 0;
  }
  if (!headerBlurEnabled && !weekdayBarBlurEnabled) {
    return 0;
  }
  // 与 HomePageChromeGlassFill 同判：走高级材质（柔光 / 液态）需两帧稳定，
  // 基础磨砂一帧。
  return homeBandUsesAdvancedGlass(homeBandGlassMaterial) ? 2 : 1;
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
              // stay off-screen and are clipped. Top and bottom each keep a
              // small overdraw so the straight-side specular fringe is cut
              // instead of showing as a 1px hairline seam; the bottom one is
              // only 4px, so the visible edge keeps its refraction (see
              // homePageChromeGlassBottomEdgeOverdraw).
              Positioned(
                top: -homePageChromeGlassTopEdgeOverdraw,
                left: -homePageChromeGlassEdgeOverdraw,
                right: -homePageChromeGlassEdgeOverdraw,
                bottom: -homePageChromeGlassBottomEdgeOverdraw,
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
    this.maxRefraction,
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

  /// 折射位移上限（逻辑 px），见 [LiquidGlassSurface.maxRefraction]。
  ///
  /// 窄带（设置页预览里那条 ~40dp 的星期条）上必须压小，否则上下两条边缘
  /// 折射带会占满整条带。null = 不压。
  final double? maxRefraction;

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
    // 与 [HomePageChromeGlassFill.build] 同判：柔光/液态仅在模糊可用时上带。
    final material = HyperosBlurredHeader.homeBandGlassMaterialOf(context);
    final appearance = FrostedAppearanceScope.of(context);
    if (material == 'soft' && useBlur) {
      // 与 `SoftGlassSurface.fill` **同源同口径**：两边都走 `SoftGlassTokens.tint`
      // （配方倍率 0.90 已在函数内部计入，这里只补用户档位倍率）。
      //
      // 注意这只是**静态替身的近似等效底色**：真实玻璃（有 backdrop 时）的底色
      // 来自上游 `popupViewGlass` 的三层颜色层 + blend shader，与单个 Color
      // 不可能严格等价，替身与真玻璃之间允许有细微差异。
      return SoftGlassTokens.tint(
        context,
        blurEnabled: useBlur,
        tintAlphaMultiplier: appearance.softGlassTuning.tintAlphaMultiplier,
      );
    }
    if (material == 'liquid' && useBlur) {
      return (appearance.liquidGlassTuning ?? LiquidGlassTuning.defaults)
          .tintColor(Theme.of(context).brightness);
    }
    return HyperosBlurredHeader.homePageRegionTintColor(
      context,
      withBlur: useBlur,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    // 首页顶栏材质独立自由选择（2026-09-12）：渐进磨砂 / 高斯磨砂 / 柔光 /
    // 液态 / 实体，与全局玻璃模式及「作用范围」开关无关。柔光/液态自带模
    // 糊，但沿用 useBlur 门：模糊总开关关闭或系统降级时回落实底衬底，与旧
    // 高级材质路径的降级口径一致。
    final material = HyperosBlurredHeader.homeBandGlassMaterialOf(context);
    const fill = SizedBox.expand();

    // 高斯 / 渐进磨砂带：既是这两个材质档本身，也是液态玻璃在引擎没有
    // shader filter 后端 / 着色器未就绪时的回落（仍是玻璃观感）。
    Widget frostBand() {
      final frost = FrostedHeaderBackground(
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        blurStyle: material == 'gaussian'
            ? HeaderBlurStyle.gaussian
            : HeaderBlurStyle.inspire,
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

    switch (material) {
      case 'liquid' when useBlur:
        return LiquidGlassSurface(
          borderRadius: borderRadius,
          // 首页带上自己那块 bounds 就够宽；设置页预览里它是小矩形，
          // 必须共享组捕获，否则折射位移被钳在带边界上糊成「相框」。
          grouped: useAncestorBackdropGroup,
          maxRefraction: maxRefraction,
          fallbackBuilder: (_) => frostBand(),
          child: fill,
        );
      case 'soft' when useBlur:
        // 柔光：与弹窗 / 底栏 / 顶栏全是同一套配方（全 app 一个常量）。
        return SoftGlassSurface(
          borderRadius: BorderRadius.circular(borderRadius),
          enableShadows: false,
          child: fill,
        );
      case 'gaussian':
      case 'progressive':
        return frostBand();
      case 'solid':
        // 实体档：用户显式选择的不透明顶栏——页面底色实心条，完全遮住
        // 壁纸。与 default 分支的「淡色衬底」是两回事：那是不模糊时的降
        // 级态水洗（半透明），这不是。
        final solid = ColoredBox(
          color: HyperosColors.scaffoldBackground(context),
          child: fill,
        );
        if (borderRadius <= 0) {
          return solid;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: solid,
        );
      default:
        // 柔光/液态在模糊总开关关闭（或系统降级）时的回落：保留既有口径
        // 的淡色半透明衬底（「模糊关=只剩纯色衬底」）。
        return FrostedHeaderBackground(
          blurEnabled: false,
          blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          tint: HyperosBlurredHeader.homePageRegionTintColor(
            context,
            withBlur: false,
          ),
          child: fill,
        );
    }
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
