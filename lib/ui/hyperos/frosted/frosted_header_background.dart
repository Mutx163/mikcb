import 'package:flutter/material.dart';

import '../../../models/header_blur_style.dart';
import '../hyperos_blurred_header.dart';
import '../hyperos_sheet.dart';
import '../inspire/inspire_header_blur.dart';
// HyperosFlatBackdropScope is exported via hyperos_blurred_header.dart above
// (与 HyperosFrostedPanelScope 同一条路子：单一入口，不在这里二次 import)。
import 'liquid_glass_degradation.dart';

/// 本格是否浮在一块**液态玻璃**弹窗面板上。
///
/// 弹窗家族锁标准档之后不再有开关可看：面板出图恒为液态玻璃，唯一能让它改成
/// 实底的是技术 / 系统门禁（[LiquidGlassDegradation.shouldDegrade]）。
///
/// 2026-09-30 高斯模糊档退场后，这里原本还并列着一个「全局档位是不是液态」的
/// 判据 —— 那让「面板是液态玻璃、内里小格却按磨砂上水洗」成为可能（同一块面板
/// 两种观感）。液态档成为唯一玻璃档之后判据只剩门禁这一条。
bool _isLiquidSheetPanel(BuildContext context) {
  return !LiquidGlassDegradation.shouldDegrade(context);
}

/// Frosted top bar: progressive blur + tint scrim (via [InspireHeaderBlur]).
///
/// [blurStyle] 只切换过渡形态，两档都走 `inspire_blur`：
/// - [HeaderBlurStyle.gaussian]：整带均匀强度 + 底边渐隐收边
/// - [HeaderBlurStyle.inspire]：自顶边向下连续衰减
///
/// 首页玻璃带与子页顶栏外壳共用此入口，统一跟随用户设置。
class FrostedHeaderBackground extends StatelessWidget {
  const FrostedHeaderBackground({
    required this.tint,
    required this.child,
    this.blurEnabled = true,
    this.blurSigma = HyperosBlurredHeader.blurSigma,
    this.blurStyle = HeaderBlurStyle.gaussian,
    this.opaqueAtRest = false,
    this.bottomOverhang = 0,
    this.cornerRampIn = 0,
    this.shapeTopInset = 0,
    this.tintBottomScale = 0,
    super.key,
  });

  final Color tint;
  final Widget child;
  final bool blurEnabled;
  final double blurSigma;
  final HeaderBlurStyle blurStyle;

  /// See [InspireHeaderBlur.opaqueAtRest]. Only the subpage top-bar shell
  /// turns this on — sheets and cards are not under the collapsible band and
  /// keep their progressive bottom fade.
  final bool opaqueAtRest;

  /// See [InspireHeaderBlur.bottomOverhang]. Only the subpage top-bar shell
  /// passes a non-zero value.
  final double bottomOverhang;

  /// See [InspireHeaderBlur.cornerRampIn]. Only the bottom-sheet top band turns
  /// this on (= the panel's corner radius) — it is the one band whose top edge
  /// **is** the panel's own outline. Defaults to 0 so the subpage top bar and
  /// home glass band stay byte-identical to the settings-page look the user
  /// asked to keep.
  final double cornerRampIn;

  /// See [InspireHeaderBlur.shapeTopInset]. Only the bottom-sheet top band
  /// passes a non-zero value (= the drag-handle strip the band shifted above
  /// the panel's top edge).
  final double shapeTopInset;

  /// See [InspireHeaderBlur.tintBottomScale]. Only the bottom-sheet top band
  /// passes a non-zero value.
  final double tintBottomScale;

  @override
  Widget build(BuildContext context) {
    return InspireHeaderBlur(
      tint: tint,
      blurEnabled: blurEnabled,
      blurSigma: blurSigma,
      style: blurStyle,
      opaqueAtRest: opaqueAtRest,
      bottomOverhang: bottomOverhang,
      cornerRampIn: cornerRampIn,
      shapeTopInset: shapeTopInset,
      tintBottomScale: tintBottomScale,
      child: child,
    );
  }
}

/// Shell matching [HyperosBlurredHeaderShell] API with live backdrop blur.
class HyperosFrostedHeaderShell extends StatelessWidget {
  const HyperosFrostedHeaderShell({
    required this.child,
    this.blurEnabled = true,
    this.tint,
    this.opaqueAtRest = false,
    this.bottomOverhang = 0,
    super.key,
  });

  final Widget child;
  final bool blurEnabled;
  final Color? tint;

  /// See [InspireHeaderBlur.opaqueAtRest].
  final bool opaqueAtRest;

  /// 模糊下沿往下多画多少（见 [InspireHeaderBlur.bottomOverhang]）。
  ///
  /// **只在真的画模糊时生效**：模糊关掉（系统无障碍降级、平台不支持、用户关掉
  /// 模糊总开关）时衬底是**不透明的页面底色**，把它往下延 20dp 会盖住正文顶部
  /// 那一条 —— 那就不是"模糊靠下"，而是"内容被切"。所以按 [useBlur] 门控。
  /// （深色模式 2026-10-10 起与浅色同构，不再是关模糊的情形之一，见
  /// [HyperosBlurredHeader.bandOverhangs]。）
  final double bottomOverhang;

  @override
  Widget build(BuildContext context) {
    final platformBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    final useBlur = blurEnabled && platformBlur;
    final resolvedTint =
        tint ?? HyperosBlurredHeader.tintColor(context, withBlur: useBlur);

    return FrostedHeaderBackground(
      blurEnabled: useBlur,
      blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
      blurStyle: HyperosBlurredHeader.subpageHeaderBlurStyleOf(context),
      tint: resolvedTint,
      // 常驻模糊 + 无内容压带时必须整条不透明，否则衬底底边渐隐会露出
      // 一截已经糊进来的内容（见 [InspireHeaderBlur.opaqueAtRest]）。
      opaqueAtRest: opaqueAtRest,
      bottomOverhang: useBlur ? bottomOverhang : 0,
      child: child,
    );
  }
}

/// Rounded frosted surface for cards, menu tiles, and icon wells.
///
/// 嵌套在液体玻璃 Sheet 内时不再叠加 BackdropFilter，避免双重模糊/发黑。
class HyperosFrostedSurface extends StatelessWidget {
  const HyperosFrostedSurface({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.padding,
    this.tint,
    this.blurEnabled,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool? blurEnabled;

  @override
  Widget build(BuildContext context) {
    var content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: child);
    }

    final inLiquidPanel =
        _isLiquidSheetPanel(context) && HyperosFrostedPanelScope.of(context);
    if (inLiquidPanel) {
      final resolvedTint =
          tint ?? HyperosBlurredHeader.nestedLiquidTileTintColor(context);
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(color: resolvedTint, child: content),
      );
    }

    final useBlur =
        HyperosBlurredHeader.backdropBlurEnabled(context) &&
        (blurEnabled ?? true);
    // 「面板读作不透明浅色卡片」有**两种**成因，都得换掉白色水洗：
    // 1. 面板被**技术 / 系统门禁**（平台视图、无障碍降级）摘成实体卡片；
    // 2. 背后是**平色底**（没壁纸）—— 玻璃采不到任何东西，出图与实底无异，
    //    白 0.28 叠在近白面板上只差 1~2 个色阶（课程弹窗的「时间 / 老师 / 地点」
    //    几行整块隐形，用户口径 2026-09-29）。
    // 两者都走 withBlur:false 的中性水洗（亮色黑 5% / 暗色白 10%），同一份数值。
    //
    // 只作用于 sheet 面板内（PanelScope 标记）；面板外的菜单/井保持原判。
    // ⚠️ 液态面板那条不走这里 —— 它在上面的 `inLiquidPanel` 分支里已经经
    // `nestedLiquidTileTintColor` 判过同一件事，两处判据是同一个作用域。
    final sheetPanelFellBackSolid =
        HyperosFrostedPanelScope.of(context) &&
        (LiquidGlassDegradation.shouldDegrade(context) ||
            HyperosFlatBackdropScope.isFlatOf(context));
    final resolvedTint =
        tint ??
        HyperosBlurredHeader.nestedSurfaceTintColor(
          context,
          withBlur: useBlur && !sheetPanelFellBackSolid,
        );

    return ClipRRect(
      borderRadius: borderRadius,
      child: FrostedHeaderBackground(
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        tint: resolvedTint,
        child: content,
      ),
    );
  }
}
