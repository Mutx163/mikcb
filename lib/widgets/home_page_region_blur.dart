import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/header_blur_style.dart';
import '../models/liquid_glass_tuning.dart';
import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos_blurred_header.dart';
import '../ui/hyperos/hyperos_theme.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart';
import '../utils/home_page_background.dart';

// Course chrome tests reference the glass mode through this library.
export '../ui/hyperos/frosted/frosted_appearance.dart' show FrostedGlassMode;

/// Reserved clearance between the weekday chrome band and the course grid.
///
/// Also used historically as frosted-band seam overlap between header and
/// weekday glass. Keep this value so glass/cards are not flush.
const homePageFrostedRegionSeamOverlap = 4.0;

/// 液态玻璃带**上边**的最小外溢量（逻辑 px）。
///
/// ⚠️ 只管上边。下边是 [homePageChromeGlassBottomEdgeOverdraw]（**0**：与底栏药丸
/// 同口径，让折射曲线走完）；两条边为什么要分开算见
/// [homePageChromeGlassVerticalOverhang]。
///
/// 取值 8 的依据：`2026-09-18-liquid-glass-surface.md` 里底部弹窗那次真机测量 ——
/// 「折射作用带 7 逻辑 px，外溢取 8（≥ 7）后可见区的第一条像素已经在深度 ≥ 8 处，
/// 折射与高光都为 0，边缘只剩干净的玻璃本体」。默认档的折射作用带正好是 7。
const homePageChromeGlassTopEdgeOverdraw = 8.0;

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
/// corner off-screen while the **bottom** edge stays visible, so thickness
/// tuning still changes the band's edge refraction instead of flattening
/// the whole band. (The top edge is pushed out too, but for a different
/// reason — see [homePageChromeGlassVerticalOverhang].)
const homePageChromeGlassEdgeOverdraw = 48.0;

/// 液态玻璃带**下边**的外溢量：**0**（逻辑 px）—— 与底栏药丸同口径。
///
/// 历史：48.0（无人使用）→ 4.0 → 8.0 → `max(8, max(作用带, 高光带宽) + 1)`（跟滑杆长到
/// 25.5）→ 0 → 4 → **0（本版，2026-09-20 晚）**。来回改了六次，根因是**判据一直搞错了**。
///
/// ## 为什么是 0：位移曲线被「截断」才读成线，走完才是玻璃
///
/// 着色器的位移是 `push = refract × profile(1 − 深度 / 作用带)`：贴边满位移，往里
/// 19.5px（用户档作用带）平滑衰减到 0 —— **整条曲线是一个环，读起来是透镜**。
///
/// 下边外溢 = N 的意思是"形状边界推到可见区下面 N px"，于是**可见区里能看到的只剩曲线
/// 从深度 N 往里的后半截**：
///
/// * **N > 0（4 / 8 / 15.5）⇒ 曲线被截断在可见区边缘上**：最外那一像素的位移只有
///   `profile(N)` 那一档（用户档 N=4 → 6.7px，满位移是 17px），紧挨着它外侧就是**没有
///   玻璃的课表**（位移 0）。曲线在边界上从 6.7px 直接掉到 0 —— 这一刀读出来就是
///   **一条线**。而且 N 越小截得越晚、位移越大，线越明显；N 越大线越靠上、越淡，到
///   N ≥ 作用带时整圈被推出可见区（`push ≡ 0`）—— 那时连玻璃本体都没了（用户口径
///   「完全透明、没有折射功能」）。**这就是"怎么调都是线"的原因：这一族值全都在截断。**
/// * **N = 0 ⇒ 曲线走完**：可见区最外那一像素正好是满位移（17px），往里平滑归零，
///   和底栏药丸逐像素同构（药丸就是 0 外溢、贴边 12.6px）。
///
/// ## 底栏药丸是这条口径的活证据
///
/// 药丸（`timetable_screen.dart` 的 `_dockPillSurface`）与这条带**同一份材质、同一份
/// 参数**，唯一差别是几何：药丸零外溢 ⇒ 那一圈整圈在可见区里 ⇒ 用户口径「折射效果特别
/// 好看」。所以"同材质不同观感"不是材质的锅，是**外溢把环截断了**。
///
/// 旧版 4px 的注释写的是"形状边界落在可见区边界上会读成发丝边"—— 那条是给**旧版边光**
/// 写的：旧边光「贴边最亮、往里二次衰减」，峰值正好压在边界上，所以在直边上描出一条硬
/// 线。09-20 边光截面已改成「峰在带内」（峰值在离边 0.35×带宽处，边界上亮度本来就是
/// 0），药丸零外溢也不见硬线 ⇒ 那条依据已经过期。
///
/// 注：这条带下边自 2026-09-20 起走「细长条 ⇒ 整圈均匀」那一档（见
/// `liquidGlassRimCornerOnlyForSize`），所以零外溢时**边光也在可见区里**（这是要的：
/// 它和折射一起构成那圈边缘观感，且边光不依赖背景，平坦壁纸上是唯一看得见的玻璃感）。
const homePageChromeGlassBottomEdgeOverdraw = 0.0;

/// 这条玻璃带**上下两条直边**各要往外多画多少（逻辑 px）。
///
/// 两条边**分开算**，因为它们在屏幕上扮演的角色完全不同：
///
/// * **上边**：压在屏幕顶边上（`includeStatusBar` 为真时带顶 = 0），着色器在作用带内
///   是**朝形状外**采样的，朝上就落到屏幕外 —— 引擎给的那圈空内容经
///   `mix(base, tint, α)` 读成近黑（真机现象：一条发丝线）。状态栏不吃背景时上边落在
///   状态栏下面，但上面那层是不透明的状态栏遮罩（[HomePageStatusBarBackdropMask]），
///   朝外采样会把遮罩色拉进来。⇒ 上边必须推出 ≥ 作用带宽度，让可见区里 `push ≡ 0`。
/// * **下边**：**0**（与底栏药丸同口径）—— 外溢一旦 > 0，可见区里看到的就只是折射
///   曲线被截断的后半截，边界上位移从 `profile(N)` 直接掉到 0，读成一条线；0 让曲线
///   走完，整圈是个透镜。与滑杆无关（固定 0），理由见
///   [homePageChromeGlassBottomEdgeOverdraw]。
///
/// **实体**：不透明实心条，既没有形状边界那套折射，也没有任何需要外溢的形状 —— 盒子
/// 就是可见带，**上下都是 0**。
///
/// ⚠️ 判据是"非实体"（[homeBandUsesAdvancedGlass]），**不是** `material == 'liquid'`：
/// 2026-09-20 口径收成「液态 / 实体」两档后，存量的 `progressive` / `gaussian` / `soft`
/// 也渲染液态玻璃（见 [HomePageChromeGlassFill.build]）。若这里仍按字面 `'liquid'` 判，
/// 存量档会拿到 `(0, 0)` —— 上边不再推出可见区，真机那条发丝线立刻回来（旧注释里
/// "渐进 / 高斯上下都是 0" 的那套理由随该分支一起作废：这两种材质已经没有自己的
/// 渲染分支了）。
({double top, double bottom}) homePageChromeGlassVerticalOverhang({
  required String material,
  required double refractionBand,
  required double rimWidth,
}) {
  if (!homeBandUsesAdvancedGlass(material)) {
    return (top: 0, bottom: 0);
  }
  return (
    top: math.max(
      homePageChromeGlassTopEdgeOverdraw,
      math.max(refractionBand, rimWidth) + 1,
    ),
    bottom: homePageChromeGlassBottomEdgeOverdraw,
  );
}

/// [homePageChromeGlassVerticalOverhang] 的取参入口：首页玻璃带与设置页预览带
/// **共用同一口径**，两边都从这里取，别各自算。
({double top, double bottom}) homePageChromeGlassVerticalOverhangOf(
  BuildContext context,
) {
  final tuning =
      FrostedAppearanceScope.of(context).liquidGlassTuning ??
      LiquidGlassTuning.defaults;
  return homePageChromeGlassVerticalOverhang(
    material: HyperosBlurredHeader.homeBandGlassMaterialOf(context),
    refractionBand: tuning.refractionBand,
    rimWidth: tuning.rimWidth,
  );
}

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

/// 首页顶栏材质是否为高级材质（液态）——自带模糊，壁纸预模糊需要按折射/雾面
/// 参数预热，玻璃带渲染也需要额外一帧稳定。
///
/// 2026-09-20 起口径只有「液态 / 实体」两档，所以判据就是「非实体」：任何非
/// `solid` 的取值（含历史中间档）都按液态处理，与 [HomePageChromeGlassFill]
/// 的渲染分支逐字一致。
bool homeBandUsesAdvancedGlass(String material) => material != 'solid';

/// Number of frames the home chrome glass needs to settle after a wallpaper
/// swap so the backdrop capture is stable before showing the frost.
///
/// Zero when nothing frosted paints (no backdrop, global blur off, or both
/// chrome bands off). 实体档 settles in one frame; 非实体（液态玻璃，含存量
/// progressive / gaussian / soft —— 它们也渲染液态玻璃）needs two.
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
  // 与 HomePageChromeGlassFill 同判：非实体档（液态玻璃）需两帧稳定，实体一帧。
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
/// **带底必须落在课表第一行的上沿**：首页在星期行与课表之间留了一段
/// [homePageFrostedRegionSeamOverlap] 的间隙，带子如果停在这段间隙之上，那一小条
/// 就**完全没有玻璃**（它既不在玻璃形状里，也不属于课表）。磨砂一开，玻璃与那条
/// 原样内容之间就切出一条横贯屏幕的暗线 —— 真机 2026-09-20「星期栏底边一条黑线」
/// 的真因，与模糊强度相关、与上下外溢无关（那 2px 根本不归外溢管）。所以这段间隙
/// **算进带高**。
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
      height:
          titleBandHeight +
          math.max(0.0, weekdayBarHeight) +
          homePageFrostedRegionSeamOverlap,
    );
  }
  if (headerBlurEnabled) {
    // 没有星期行 ⇒ 页面也不留那段间隙，带子到标题行底为止。
    return (top: titleBandTop, height: titleBandHeight);
  }
  // Weekday-only glass: sit on the weekday row, and cover the clearance the
  // page reserves below it (same reason as the combined band above).
  return (
    top: titleBandBottom,
    height: math.max(0, weekdayBarHeight) + homePageFrostedRegionSeamOverlap,
  );
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

    // 上下外溢按材质 + 边分别算（见 [homePageChromeGlassVerticalOverhang]）：
    // 非实体档（液态玻璃，含存量中间档）上边要盖过用户的「作用带宽度」、下边与底栏
    // 药丸同为 0；实体档两条边都是 0。
    final overhang = homePageChromeGlassVerticalOverhangOf(context);

    return Positioned(
      top: layout.top,
      left: 0,
      right: 0,
      height: layout.height,
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 左、右推 48px 是为了把形状**圆角**推离可见区（高厚度下的对角
              // "相框"条纹就是那里来的）；上边推 `overhang.top`（那条边压在屏幕顶边
              // 上）；**下边只推 `overhang.bottom`（液态 0）** —— 下边是这条带唯一
              // 可见的形状边界，推出去就等于把折射 / 高光 / 色散整圈删掉
              // （见 [homePageChromeGlassBottomEdgeOverdraw]）。
              Positioned(
                top: -overhang.top,
                left: -homePageChromeGlassEdgeOverdraw,
                right: -homePageChromeGlassEdgeOverdraw,
                bottom: -overhang.bottom,
                child: const HomePageChromeGlassFill(
                  // ⚠️ 必须采**祖先组的整屏背景**（2026-09-20 修）。
                  //
                  // 带级采样下，折射位移一旦越过带自己的边界就"钳在带自己的边上"
                  // （见 [HomePageChromeGlassFill.useAncestorBackdropGroup] 的说明），
                  // 于是从条带边缘读出来。首页为此**早就搭好了组捕获结构**
                  // （`timetable_screen.dart` 的 `BackdropGroup` + 全尺寸
                  // `UndimmedBackdropCapture`），只是这里的开关一直没接上。
                  // 组捕获与"上边外溢推到裁剪线外"是**两条并行的手段**：前者管位移
                  // 出界，后者管上边那圈边缘带本身落在可见区里。
                  useAncestorBackdropGroup: true,
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
    this.borderRadius = 0,
    this.useAncestorBackdropGroup = false,
    this.maxRefraction,
    super.key,
  });

  /// Sample the nearest [BackdropGroup]'s full-size backdrop instead of the
  /// band's own clipped bounds.
  ///
  /// ⚠️ **首页这条带必须打开它**（2026-09-20 修）：带级采样下折射位移越过带边界就
  /// 会"钳在带自己的边上"（下面那段原文写的就是这件事，但它的结论对**下边**不成立：
  /// 这条带的左右被 48px overdraw 推到屏幕外、上边被推出可见区，**只有下边是真正可见
  /// 的形状边界**）。位移被钳在下边 ⇒ 真机读成一条黑线（用户实测：打开磨砂强度后
  /// 星期栏底边一条黑线）。首页为此**早就搭好了组捕获结构**（`timetable_screen.dart`
  /// 的 `BackdropGroup` + 全尺寸 `UndimmedBackdropCapture`），只是这里的开关一直没接上。
  ///
  /// **设置页预览那条带同样打开**（`timetable_week_preview.dart`）：它上下两条横边
  /// 都在可见区附近（首页那条的上边被状态栏埋掉），所以它是"上下各一条线"，同一味药。
  /// 这条带与首页那条的差别不在采样源，而在**几何适配**：预览带会压折射位移
  /// （[maxRefraction]，按带高折算 —— 那是"窄带别被整圈描边糊满"，与采样源无关）。
  ///
  /// 原文（保留，作为"当年为什么没想到"的记录）：Inside a settings preview the band
  /// is a small interior rectangle: refraction displacement past its bounds then clamps
  /// against the band's own edges and streaks all four into a "picture frame". Setting
  /// this to true makes the band sample a full-size grouped capture (wallpaper layer +
  /// [UndimmedBackdropCapture] inside the group) so the displacement range stays inside
  /// the captured backdrop.
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
    // 与 [HomePageChromeGlassFill.build] 同判：非实体即液态，液态仅在模糊可用时上带。
    final material = HyperosBlurredHeader.homeBandGlassMaterialOf(context);
    final appearance = FrostedAppearanceScope.of(context);
    if (material != 'solid' && useBlur) {
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
    // 首页顶栏材质：**只有「液态玻璃 / 实体」两档**（2026-09-20 起，与外观编辑器里
    // 那两个选项逐字一致）。存量 progressive / gaussian / soft 在设置层就归到了液态
    // （`TimetableSettings.sanitizeHomeBandGlassMaterial`），这里再按「非实体即液态」
    // 兜一层：任何非 'solid' 的取值都渲染液态玻璃，绝不会再出现「界面显示液态、
    // 实际渲染渐进磨砂」的错位 —— 用户 2026-09-20 报的「顶栏没有玻璃效果」正是它
    // （渐进档没有折射、也没有边光那一圈，怎么调参数都不会有玻璃感）。
    final material = HyperosBlurredHeader.homeBandGlassMaterialOf(context);
    const fill = SizedBox.expand();

    // 液态玻璃在引擎没有 shader filter 后端 / 着色器未就绪时的回落：仍是磨砂玻璃
    // 观感（就是这条带 2026-09-20 之前一直画的那条渐进模糊链路）。
    Widget frostBand() {
      final frost = FrostedHeaderBackground(
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        blurStyle: HeaderBlurStyle.inspire,
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

    if (material != 'solid') {
      // 液态玻璃。模糊总开关关闭（或系统降级）时回落实底衬底：保留既有口径的
      // 淡色半透明衬底（「模糊关 = 只剩纯色衬底」），与旧高级材质路径一致。
      if (!useBlur) {
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
      return LiquidGlassSurface(
        borderRadius: borderRadius,
        // 首页带上自己那块 bounds 就够宽；设置页预览里它是小矩形，
        // 必须共享组捕获，否则折射位移被钳在带边界上糊成「相框」。
        grouped: useAncestorBackdropGroup,
        maxRefraction: maxRefraction,
        fallbackBuilder: (_) => frostBand(),
        child: fill,
      );
    }

    // 实体档：用户显式选择的不透明顶栏——页面底色实心条，完全遮住
    // 壁纸。与上面那个「淡色衬底」是两回事：那是不模糊时的降级态水洗
    // （半透明），这不是。
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
  }
}

/// 转场期间让「按屏幕坐标取值」的玻璃带**逐帧重画**。
///
/// 存在的理由（2026-09-20 实测：进「课表页面」设置页时，预览的顶栏 / 星期栏里会扫出一根
/// 细竖线，位置每次还不太一样）：
///
/// * 液态玻璃着色器的几何按**屏幕物理像素**算，其中 `u_area_origin` 是 Dart 侧在
///   **paint 期**用 `localToGlobal` 读的 —— 契约写在 `glass_surface_refraction.frag`
///   文件头：**形状要正，这一帧就得重画一次**。
/// * 但 `HyperosPageRoute` 的转场外壳把整页包进了 `RepaintBoundary`
///   （`hyperos_navigation.dart` 的 `_HyperosTransitionPageShell`，为的是滑入时整页像素
///   复用、不逐帧重栅格化）。框架对「没被标脏的重绘边界」只做一件事：换掉图层偏移
///   （`PaintingContext._compositeChild`：`childOffsetLayer.offset = offset`），
///   **不重画**。实测：同一次滑动里，包了重绘边界的子树画 1 次，没包的兄弟画 4 次。
/// * 于是滑入期间玻璃带的 `u_area_origin` 停在"上一次重画时"的屏幕位置，偏差量正好等于
///   这段时间页面滑过的距离。带左右各有 [homePageChromeGlassEdgeOverdraw]（48px）藏在
///   可见区外，偏差扫进 48 ~ 48+带宽 这个区间时，形状那条直边就落进可见区 —— 真机上读作
///   一根细线，位置随"上一次重画发生在哪一帧"而变，滑到位偏差归零就消失。
/// * 本节点订阅宿主路由的主 / 副动画，转场每推进一帧就 `markNeedsPaint`，把形状重新钉在
///   带上；自己又是重绘边界，所以这次重画只覆盖这条带，不牵连整页（保住外壳那笔优化）。
///   动画停住就不再 tick ⇒ 静止时零额外重画。
///
/// 只有液态档需要它，已按材质门控（实体档驱动为 null，一点额外重画都不加）：实体档不按
/// 屏幕坐标算形状，位置由图层合成负责，不重画也是对的。门控判据是"非实体"
/// （[homeBandUsesAdvancedGlass]）—— 存量 progressive / gaussian / soft 同样渲染液态玻璃，
/// 不能漏掉（漏掉就是它们转场时扫出细竖线）。
///
/// ⚠️ 转场期间**不要**改成"先不画这条玻璃带"：那会让带在落定瞬间才出现，用户明确
/// 不要进场时的任何闪动（2026-09-20 拍板）。
class HomePageChromeGlassTransitionRepaint extends StatefulWidget {
  const HomePageChromeGlassTransitionRepaint({required this.child, super.key});

  final Widget child;

  @override
  State<HomePageChromeGlassTransitionRepaint> createState() =>
      _HomePageChromeGlassTransitionRepaintState();
}

class _HomePageChromeGlassTransitionRepaintState
    extends State<HomePageChromeGlassTransitionRepaint> {
  Animation<double>? _primary;
  Animation<double>? _secondary;
  Listenable? _driver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只有液态档需要它（实体档不按屏幕坐标算形状，见类注释）—— 实体档在转场期间
    // 白花这笔重画没有意义。判据是"非实体"（与 [HomePageChromeGlassFill.build] 的渲染
    // 分支逐字一致）：存量 progressive / gaussian / soft 也渲染液态玻璃，同样要驱动。
    final needsDriver =
        homeBandUsesAdvancedGlass(
          HyperosBlurredHeader.homeBandGlassMaterialOf(context),
        );
    // 宿主路由（没有路由就退化成"不驱动"，行为与不加本节点一致）。
    final route = needsDriver ? ModalRoute.of(context) : null;
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (identical(primary, _primary) && identical(secondary, _secondary)) {
      return;
    }
    _primary = primary;
    _secondary = secondary;
    // 副动画也要听：本页被后一页盖住时，页面是被视差推着走的（同一件事）。
    _driver = Listenable.merge(<Listenable?>[primary, secondary]);
  }

  @override
  Widget build(BuildContext context) => _ChromeGlassTransitionRepaint(
    driver: _driver,
    child: widget.child,
  );
}

class _ChromeGlassTransitionRepaint extends SingleChildRenderObjectWidget {
  const _ChromeGlassTransitionRepaint({required this.driver, required super.child});

  /// 转场动画；每 tick 一次就把子树标脏一次。null = 不驱动。
  final Listenable? driver;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChromeGlassTransitionRepaint(driver);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    if (renderObject is! _RenderChromeGlassTransitionRepaint) return;
    renderObject.driver = driver;
  }
}

class _RenderChromeGlassTransitionRepaint extends RenderProxyBox {
  _RenderChromeGlassTransitionRepaint(Listenable? driver) : _driver = driver {
    _driver?.addListener(markNeedsPaint);
  }

  Listenable? _driver;

  set driver(Listenable? value) {
    if (identical(_driver, value)) return;
    _driver?.removeListener(markNeedsPaint);
    _driver = value;
    _driver?.addListener(markNeedsPaint);
  }

  /// 独立重绘边界：标脏只让这条带重画，不动宿主页面的缓存像素。
  @override
  bool get isRepaintBoundary => true;

  @override
  void dispose() {
    // 必须摘干净：dispose 之后 markNeedsPaint 会在 debug 下抛异常。
    _driver?.removeListener(markNeedsPaint);
    _driver = null;
    super.dispose();
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
