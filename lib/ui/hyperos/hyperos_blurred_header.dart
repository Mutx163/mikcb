import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/header_blur_style.dart';
import 'frosted/frosted_appearance.dart';
import 'frosted/frosted_header_background.dart';
import 'frosted/flat_backdrop_scope.dart';
import 'frosted/liquid_glass_degradation.dart';
export 'frosted/frosted_appearance.dart';
export 'frosted/frosted_header_background.dart'
    show FrostedHeaderBackground, HyperosFrostedSurface;
export 'frosted/flat_backdrop_scope.dart';
// HyperosFrostedPanelScope is exported via frosted_appearance.dart above.
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Scope for pages that overlay a frosted [FHeader] on scrollable content.
class HyperosBlurredHeaderScope extends InheritedWidget {
  const HyperosBlurredHeaderScope({
    required this.contentTopInset,
    this.blurEnabled = true,
    this.contentUnderHeader = false,
    this.headerBackgroundColor,
    required super.child,
    super.key,
  });

  /// Extra top inset applied to page body so content starts below the header.
  final double contentTopInset;

  /// When false, header shows tint only (no [BackdropFilter]).
  final bool blurEnabled;

  /// When true, list content has scrolled under the header — show frosted blur.
  final bool contentUnderHeader;

  /// Opaque header fill while [contentUnderHeader] is false (matches page bg).
  final Color? headerBackgroundColor;

  static HyperosBlurredHeaderScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosBlurredHeaderScope>();
  }

  static double insetOf(BuildContext context) {
    return maybeOf(context)?.contentTopInset ?? 0;
  }

  /// Reads [contentTopInset] WITHOUT registering an inherited dependency.
  ///
  /// Must be used from [ScrollBehavior.getScrollPhysics]: that runs inside
  /// `Scrollable._updatePosition` with the Scrollable's own context, so a
  /// `dependOnInheritedWidgetOfExactType` there subscribes the Scrollable
  /// element to this scope — every frost flip / inset change then triggers
  /// `didChangeDependencies → _updatePosition`, which tears down and
  /// recreates the ScrollPosition mid-gesture (pixels silently reset to 0,
  /// title flickers). See the collapse/frost regression on short pages.
  static double insetOfUntracked(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<HyperosBlurredHeaderScope>();
    return scope?.contentTopInset ?? 0;
  }

  static bool blurEnabledOf(BuildContext context) {
    return maybeOf(context)?.blurEnabled ?? true;
  }

  static bool contentUnderHeaderOf(BuildContext context) {
    return HyperosHeaderUnderContentScope.of(context);
  }

  static Color? headerBackgroundColorOf(BuildContext context) {
    return maybeOf(context)?.headerBackgroundColor;
  }

  @override
  bool updateShouldNotify(HyperosBlurredHeaderScope oldWidget) {
    // contentUnderHeader is intentionally omitted: it lives in
    // [HyperosHeaderUnderContentScope]. Notifying this scope for frost flips
    // rebuilt every list body that only depends on the top inset
    // ([insetOf]) and read as a hitch when content first tucked under the bar.
    return contentTopInset != oldWidget.contentTopInset ||
        blurEnabled != oldWidget.blurEnabled ||
        headerBackgroundColor != oldWidget.headerBackgroundColor;
  }
}

/// Frost flag only, split out of [HyperosBlurredHeaderScope].
///
/// List bodies depend on the parent scope for [HyperosBlurredHeaderScope.insetOf]
/// and must not rebuild when `contentUnderHeader` flips. Header chrome and
/// scroll-revealed titles subscribe here instead.
class HyperosHeaderUnderContentScope extends InheritedWidget {
  const HyperosHeaderUnderContentScope({
    required this.contentUnderHeader,
    required super.child,
    super.key,
  });

  final bool contentUnderHeader;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              HyperosHeaderUnderContentScope
            >()
            ?.contentUnderHeader ??
        false;
  }

  @override
  bool updateShouldNotify(HyperosHeaderUnderContentScope oldWidget) {
    return contentUnderHeader != oldWidget.contentUnderHeader;
  }
}

/// Layout helpers for HyperOS frosted top app bars.
abstract final class HyperosBlurredHeader {
  /// Fallback blur sigma when no [FrostedAppearanceScope] is available.
  static const blurSigma = kDefaultFrostedSheetBlurSigma;

  /// Tint-only scrim while blur is paused (route transition).
  static const lightTintOnlyAlpha = 0.58;

  static const darkTintOnlyAlpha = 0.62;

  /// Live [BackdropFilter] blur on mobile; web uses tint-only.
  ///
  /// [liveBlurSupportedOverride] exists because this reads `dart:io`'s
  /// `Platform`, which is the **host** platform in `flutter test` (Windows on
  /// the dev machine) — a widget test could otherwise never exercise the
  /// "band actually paints an overhang" path.
  @visibleForTesting
  static bool? liveBlurSupportedOverride;

  static bool get liveBlurSupported {
    if (liveBlurSupportedOverride != null) {
      return liveBlurSupportedOverride!;
    }
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Approximate body top inset matching [FHeader] + [SafeArea] on HyperOS pages.
  static double contentTopInset(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    const headerPaddingBottom = 4.0;
    const minHeaderHeight = 44.0;
    return safeTop + minHeaderHeight + headerPaddingBottom;
  }

  /// Approximate body top inset for expanded [HyperosCollapsibleTopAppBar]
  /// before the overlay header is measured (safe top + collapsed row + large title).
  static double contentTopInsetCollapsible(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    // Match expanded layout: action row + large title 1 line + bottom pad,
    // plus the app-side title→content gap (see largeTitleContentGap). The
    // title's height must follow the same system text scale as the real bar;
    // using the unscaled 32sp estimate makes the first list card overlap the
    // title on devices with enlarged system text.
    final scaledLargeTitleHeight = MediaQuery.textScalerOf(context).scale(
      HyperosMiuixTypography.title1 * 1.2,
    );
    final expandedContentHeight =
        HyperosMiuixTopAppBar.collapsedHeight +
        scaledLargeTitleHeight +
        HyperosMiuixTopAppBar.largeTitleBottomPadding +
        HyperosMiuixTopAppBar.largeTitleContentGap;
    return safeTop + expandedContentHeight;
  }

  /// Default vertical size for a single-line [HyperosBlurredHeaderExtension]
  /// row (padding + ~48dp field) before the overlay header is measured.
  static const defaultExtensionHeight = 68.0;

  /// Body inset when a [HyperosBlurredHeaderExtension] is pinned under the bar.
  static double contentTopInsetWithExtension(
    BuildContext context, {
    double extensionHeight = defaultExtensionHeight,
  }) {
    return contentTopInset(context) + extensionHeight;
  }

  /// Miuix collapsed top bar content height (excluding status bar).
  static const contentHeight = HyperosMiuixTopAppBar.collapsedHeight;

  static FrostedAppearance _appearanceOf(BuildContext context) {
    return FrostedAppearanceScope.of(context);
  }

  static double blurSigmaOf(BuildContext context) {
    return _appearanceOf(context).sheetBlurSigma;
  }

  /// 首页顶栏玻璃带材质（独立自由选择）：`progressive` / `gaussian` /
  /// `soft` / `liquid` / `solid`。
  ///
  /// 只驱动首页玻璃带（home_page_region_blur）；子页顶栏外壳读
  /// [subpageHeaderBlurStyleOf]，永不走高级材质。
  static String homeBandGlassMaterialOf(BuildContext context) {
    return _appearanceOf(context).homeBandGlassMaterial;
  }

  /// 子页顶栏（设置等 HyperosSubpage 页）的模糊风格。
  ///
  /// **2026-09-23 起锁死为渐进模糊**（用户口径「子页顶部可以锁定渐变模糊」）：
  /// 设置里不再有这个选项，返回值恒为 [HeaderBlurStyle.inspire]，函数保留只为
  /// 让调用处读起来仍是"取当前风格"。真档位只剩课程卡片自己那一档（另一根轴）。
  static HeaderBlurStyle subpageHeaderBlurStyleOf(BuildContext context) {
    return HeaderBlurStyle.inspire;
  }

  /// 子页顶栏的模糊下沿**最多**能比标题行多画多少（≈ 一个字高）。
  ///
  /// 用户口径 2026-09-23：「让模糊靠下一点，最底下模糊的边界再往下，超过标题
  /// 底部一个字空间」。只加在下沿 —— 标题位置与正文顶部留白都不动。
  ///
  /// ⚠️ 这是**上限**，实际画多少由 [bandBottomOverhang] 按版面空白封顶：外推是
  /// **画在顶栏盒子之外**的（见 [InspireHeaderBlur.bottomOverhang]：只把模糊层与
  /// 衬底层往下撑，布局高度不变），而版面上留给「顶栏底边 → 第一行内容」的空白
  /// 只有 [HyperosMiuixTopAppBar.largeTitleContentGap]。按 20 画就会盖住静止时的
  /// 第一行（小标题只剩下上半截，2026-09-25 桌面小组件页「快速添加到桌面」）。
  static const subpageBandBottomOverhang = 20.0;

  /// 子页顶栏玻璃带此刻是否真的会往下外推那一截。
  ///
  /// 判据必须与 [HyperosFrostedHeaderShell] 里 `bottomOverhang: useBlur ? … : 0`
  /// 的 `useBlur` **同源**：带画了才有下沿可谈；带没画（深色顶栏规范 / 模糊总开关
  /// 关 / 平台不支持 / 无障碍降级）就是页面原样。改这里必须同时看那一处。
  ///
  /// [bandOverhangsOverride] 只给测试用：真机判据里的 [liveBlurSupported] 读的是
  /// `dart:io` 的 `Platform.isAndroid/isIOS`，widget test 跑在宿主平台上（这里是
  /// Windows）恒为 false，没法复现「带真的画出去」那条路。
  @visibleForTesting
  static bool? bandOverhangsOverride;

  static bool bandOverhangs(BuildContext context) =>
      bandOverhangsOverride ??
      (Theme.of(context).brightness != Brightness.dark &&
          backdropBlurEnabledUntracked(context));

  /// [backdropBlurEnabled] but reads [FrostedAppearanceScope] **untracked**.
  ///
  /// The page shell calls this from its own build (see
  /// `HyperosBlurredHeaderShell.bottomOverhang`). A tracked read there would
  /// rebuild the entire open subpage whenever an appearance setting changes —
  /// exactly what [HyperosBlurredHeaderScope.updateShouldNotify] deliberately
  /// avoids. Safe to be stale for a frame: the paint gate
  /// ([HyperosFrostedHeaderShell]) keeps its own tracked read and zeroes the
  /// overhang when blur is off, and the page rebuilds on the same frame the
  /// scope notifies anyway.
  static bool backdropBlurEnabledUntracked(BuildContext context) {
    if (LiquidGlassDegradation.shouldDegrade(context) || !liveBlurSupported) {
      return false;
    }
    final appearance =
        FrostedAppearanceScope.maybeOfUntracked(context)?.appearance ??
        FrostedAppearance.defaults;
    return appearance.blurEnabled;
  }

  /// 玻璃带下沿实际往下多画多少（已按版面空白封顶）。
  ///
  /// 不变式：**带下沿不许越过正文顶边距**（[HyperosBlurredHeaderScope.contentTopInset]
  /// 那一行的顶边），所以能画多少只能看版面上真留出来的那点空白：
  ///
  /// [hasReservedGapBelowHeader] 由页面壳给：只有「大标题折叠页、且顶栏下没有
  /// 工具条」才为真 —— 那正是唯一在顶栏盒子底边之下还留了
  /// [HyperosMiuixTopAppBar.largeTitleContentGap] 设计间距的页型。渐进档的模糊与衬底
  /// 都是**到带底收敛到 0** 的（[InspireHeaderBlur.progressiveExtent] = 1），所以模糊
  /// 尾巴正好铺满那段间距，贴上去没有硬边，**正文一个像素都不动**。
  ///
  /// 其它页型（`collapsibleLargeTitle: false`、顶栏下带工具条）的正文顶边距就是
  /// 顶栏自身高度，**一点空白都没有**，于是不外推 —— 保持 2026-09-23 之前的样子。
  ///
  /// 代价要说明白：这样改完大标题页的模糊尾巴是 8px，而不是当初要的 20px。要拿回
  /// 20px 只能让正文下移 20px（2026-09-25 上一版的做法，用户口径「空隙太大」已否）。
  static double bandBottomOverhang(
    BuildContext context, {
    required bool hasReservedGapBelowHeader,
  }) {
    if (!bandOverhangs(context) || !hasReservedGapBelowHeader) {
      return 0;
    }
    // min() 不是装饰：requested 是 2026-09-23 用户要的「一个字高」，而版面上
    // 真正留出来的空白只有 largeTitleContentGap，超出部分会盖住第一行。
    return math.min(
      subpageBandBottomOverhang,
      HyperosMiuixTopAppBar.largeTitleContentGap,
    );
  }

  static double sheetBarrierAlphaOf(BuildContext context) {
    return _appearanceOf(context).sheetBarrierAlpha;
  }

  /// Soft black dim behind liquid-glass modals (sheets, select popups, dialogs).
  ///
  /// Stronger scrims muddy refraction because the glass samples through the
  /// barrier. Fully transparent barriers make the modal hard to spot as a
  /// modal. Keep this lighter than the gaussian default (~0.20).
  static const liquidGlassModalBarrierAlpha = 0.10;

  /// Modal scrim shared by home menu, sheets, dialogs, and select popups.
  ///
  /// - **Gaussian**: black scrim from [FrostedAppearance.sheetBarrierAlpha]
  ///   (外观与配色), matching the home top-right menu.
  /// - **Liquid glass**: fixed light dim ([liquidGlassModalBarrierAlpha]).
  ///   Just enough hierarchy that every popup reads as the same modal, without
  ///   a heavy grey wash that flattens the refractive glass.
  static Color modalBarrierColor(BuildContext context) {
    final appearance = _appearanceOf(context);
    // Keep the liquid-glass light scrim only while the real refractive glass
    // is in use; once the system degrades glass to a solid (accessibility /
    // reduce-motion / high-contrast), the heavier gaussian scrim gives the
    // now-opaque modal the hierarchy it needs.
    if (appearance.glassMode == FrostedGlassMode.liquidGlass &&
        !LiquidGlassDegradation.shouldDegrade(context)) {
      return Colors.black.withValues(alpha: liquidGlassModalBarrierAlpha);
    }
    return Colors.black.withValues(alpha: sheetBarrierAlphaOf(context));
  }

  /// Whether live [BackdropFilter] blur is allowed (platform + user setting).
  ///
  /// Disabled by [LiquidGlassDegradation] (accessibility / reduce-motion /
  /// high-contrast) so every frosted / gaussian / translucent surface falls
  /// back to its solid material in one place.
  static bool backdropBlurEnabled(BuildContext context) {
    if (LiquidGlassDegradation.shouldDegrade(context)) {
      return false;
    }
    return liveBlurSupported && _appearanceOf(context).blurEnabled;
  }

  static Color tintColor(BuildContext context, {required bool withBlur}) {
    if (!withBlur) {
      final pageBackground = HyperosColors.scaffoldBackground(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return pageBackground.withValues(
        alpha: isDark ? darkTintOnlyAlpha : lightTintOnlyAlpha,
      );
    }
    return _frostedScrimColor(context);
  }

  /// Shared frosted scrim for subpage headers, sheets, and menus.
  ///
  /// ⚠️ **暗色必须是「亮 veil」，不能是暗 veil**（用户口径 2026-09-27：「暗色模式，进入
  /// 设置页面渐变模糊也是显示的透明效果」）。理由：暗 veil 压在暗背景上**一点对比都没有**，
  /// 模糊没有可糊的东西，整条带读起来就是一块透明片 —— 这件事本文件里早就写着：
  /// [homePageRegionTintColor] 的注释「generic tintColor scrim is too dark and low-contrast
  /// on dark wallpapers」说的就是同一件。
  ///
  /// 同族的三个接口早就按「暗色用亮 veil」实现：[homePageRegionTintColor] 0.20 /
  /// [nestedLiquidTileTintColor] 0.12 / [nestedSurfaceTintColor] 0.10 —— **只有这一个共享
  /// 的写成了暗 veil**，而子页顶栏、弹窗面板、菜单全都经过它，于是暗色下这几处一起读成透明。
  ///
  /// 量级与 [homePageRegionTintColor] 的暗色档保持同一档（0.2 上下）：两处不能漂，否则暗色下
  /// 顶栏那条带与首页区域会是两种灰。用户的「材质浓度」（[FrostedAppearance.sheetTintAlpha]）
  /// 仍然起作用，但**留了下限** —— 暗 scrim 落在任何低值上都会读成透明。
  static Color _frostedScrimColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = _appearanceOf(context).sheetTintAlpha;
    if (isDark) {
      return Colors.white.withValues(
        alpha: (alpha * 0.2 + 0.12).clamp(0.16, 0.30),
      );
    }
    return Colors.white.withValues(alpha: alpha);
  }

  /// Frosted bottom sheet / dialog panel tint.
  ///
  /// When [withBlur] is true: milky translucent glass (sigma from settings).
  /// When [withBlur] is false: **fully opaque** surface — never a see-through
  /// panel (Gaussian blur off must not leave transparent sheets).
  static Color sheetTintColor(BuildContext context, {required bool withBlur}) {
    if (!withBlur) {
      return HyperosColors.surfaceContainer(context);
    }
    return _frostedScrimColor(context);
  }

  /// Frosted tint for nested surfaces (menu tiles, chips) over a frosted parent.
  static Color nestedSurfaceTintColor(
    BuildContext context, {
    required bool withBlur,
    Color? base,
  }) {
    if (!withBlur) {
      // Parent may be liquid glass or solid. Prefer a translucent wash so nested
      // icon wells never punch opaque blocks through the panel.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        return Colors.white.withValues(alpha: 0.10);
      }
      return Colors.black.withValues(alpha: 0.05);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      final parentAlpha = _appearanceOf(context).sheetTintAlpha;
      return Colors.white.withValues(
        alpha: (parentAlpha * 0.55 + 0.18).clamp(0.22, 0.72),
      );
    }
    final surface = base ?? HyperosColors.card(context);
    return surface.withValues(alpha: 0.52);
  }

  /// Nested tile wash when the parent sheet already uses liquid glass.
  ///
  /// Must stay translucent — solid secondaryVariant reads as dead blocks.
  ///
  /// **背后是平色底时改走中性水洗**（[nestedSurfaceTintColor] 的 `withBlur: false`
  /// 分支），与「面板被技术 / 系统门禁摘成实底」同一个出口、同一份数值：
  /// 白色水洗的分层**靠玻璃采到有颜色的背景**成立，采不到就是白叠白
  /// （算术与取舍见 [HyperosFlatBackdropScope] 的类注释）。
  ///
  /// 这是两条消费路径（[HyperosFrostedSurface] 与 `HyperosAdaptiveCard`）共用的
  /// 唯一出口 —— **不要**在调用方各自加判据，两处一漂又是「同一材质两种观感」。
  static Color nestedLiquidTileTintColor(BuildContext context) {
    if (HyperosFlatBackdropScope.isFlatOf(context)) {
      return nestedSurfaceTintColor(context, withBlur: false);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withValues(alpha: 0.12);
    }
    return Colors.white.withValues(alpha: 0.28);
  }

  /// Frosted tint for home timetable regions over a full-screen backdrop.
  ///
  /// Uses a milky scrim so blur reads on both light and dark photos; the generic
  /// [tintColor] scrim is too dark and low-contrast on dark wallpapers.
  static Color homePageRegionTintColor(
    BuildContext context, {
    required bool withBlur,
  }) {
    if (!withBlur) {
      return tintColor(context, withBlur: false);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withValues(alpha: 0.20);
    }
    final alpha = (_appearanceOf(context).sheetTintAlpha * 0.85 + 0.14).clamp(
      0.30,
      0.68,
    );
    return Colors.white.withValues(alpha: alpha);
  }

  /// Light accent wash for icon wells on an already-frosted tile.
  ///
  /// Do not stack another [BackdropFilter] here — nested blur on a tinted
  /// parent reads muddy/dark. Pair with [HyperosFrostedSurface.blurEnabled:
  /// false].
  static Color accentSurfaceTintColor(Color accent) {
    return accent.withValues(alpha: 0.12);
  }
}

/// Frosted header chrome: [BackdropFilter] blur + tint + title row.
class HyperosBlurredHeaderShell extends StatelessWidget {
  const HyperosBlurredHeaderShell({
    required this.child,
    this.bottomOverhang = 0,
    super.key,
  });

  final Widget child;

  /// How far the band's blur/tint may paint **below this box** (see
  /// [HyperosBlurredHeader.bandBottomOverhang] for the cap and why it is not
  /// the full [HyperosBlurredHeader.subpageBandBottomOverhang]).
  ///
  /// Defaults to 0 so a bare usage (showcase) never grows into the body.
  final double bottomOverhang;

  @override
  Widget build(BuildContext context) {
    final scope = HyperosBlurredHeaderScope.maybeOf(context);
    final routeBlur = scope?.blurEnabled ?? true;
    // Prefer the frost-only nested scope; fall back to the parent field, then
    // true so bare showcase usages without a page scope keep the old default.
    final underHeader =
        context
                .dependOnInheritedWidgetOfExactType<
                  HyperosHeaderUnderContentScope
                >()
                ?.contentUnderHeader ??
            scope?.contentUnderHeader ??
            true;
    // Keep the GPU blur layer mounted whenever the platform can frost — not
    // only after content tucks under the band. Mounting Inspire.backdropBlur
    // on the first under-header frame hitched the small-title join. Frost and
    // route-blur only swap the tint (opaque page color ↔ frosted scrim);
    // route transitions still hide the frost visually via [routeBlur].
    // 模糊层与下沿外推是同一个开关（[bandOverhangs]）：带不画，下沿也不画。
    final blurCapable = HyperosBlurredHeader.bandOverhangs(context);
    final atRestColor =
        scope?.headerBackgroundColor ??
        HyperosColors.scaffoldBackground(context);
    final tint = (blurCapable && routeBlur && underHeader)
        ? HyperosBlurredHeader.tintColor(context, withBlur: true)
        : atRestColor;

    // 顶栏统一走高斯模糊路径：即使全局开启液态玻璃，顶栏也不用折射 shader，
    // 避免标题文字下方的液态观感与正文/弹窗不一致。
    return HyperosFrostedHeaderShell(
      blurEnabled: blurCapable,
      tint: tint,
      // 无内容压在带下时衬底必须铺满整条带。折叠顶栏的模糊层常驻，而
      // inspire 档衬底底边渐隐到全透明，会留出一条透明窗口——内容还没
      // 真正压到带底时就被糊进这条窗口，随后衬底整条切进来，读作
      // 「内容快插到标题栏时顿一下」。见 [InspireHeaderBlur.opaqueAtRest]。
      opaqueAtRest: !underHeader,
      // 模糊下沿往下推多少由调用方按版面空白封顶（2026-09-23 用户口径要的是
      // 「超过标题底部一个字空间」，但空白只有 largeTitleContentGap那么多；
      // 硬画 20 会盖住静止时的第一行，见 [bandBottomOverhang]）。
      bottomOverhang: bottomOverhang,
      child: child,
    );
  }
}

/// Pads widgets pinned directly under the frosted title row inside the same
/// [HyperosBlurredHeaderShell] (search bars, segmented filters, etc.).
class HyperosBlurredHeaderExtension extends StatelessWidget {
  const HyperosBlurredHeaderExtension({
    super.key,
    required this.child,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(16, 8, 16, 12);

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: child);
  }
}

/// Pads non-scroll page bodies below a frosted header overlay.
class HyperosBlurredBodyInset extends StatelessWidget {
  const HyperosBlurredBodyInset({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = HyperosBlurredHeaderScope.insetOf(context);
    if (inset == 0) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.only(top: inset),
      child: child,
    );
  }
}
