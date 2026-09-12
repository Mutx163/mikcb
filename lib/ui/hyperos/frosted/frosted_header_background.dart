import 'package:flutter/material.dart';

import '../../../models/header_blur_style.dart';
import '../hyperos_blurred_header.dart';
import '../hyperos_sheet.dart';
import '../inspire/inspire_header_blur.dart';
import 'liquid_glass_degradation.dart';

bool _isLiquidSheetPanel(BuildContext context) {
  if (LiquidGlassDegradation.shouldDegrade(context)) return false;
  final scope = FrostedAppearanceScope.maybeOf(context);
  if (scope == null) return false;
  final a = scope.appearance;
  return a.glassMode == FrostedGlassMode.liquidGlass &&
      a.liquidGlassSheetDialogEnabled;
}

/// 柔光面板内的嵌套 tile：与 [_isLiquidSheetPanel] 同口径（同为高级材质，
/// 受同一组「作用范围 → 弹窗与对话框」开关与系统降级约束）。
bool _isSoftSheetPanel(BuildContext context) {
  if (LiquidGlassDegradation.shouldDegrade(context)) return false;
  final scope = FrostedAppearanceScope.maybeOf(context);
  if (scope == null) return false;
  final a = scope.appearance;
  return a.glassMode == FrostedGlassMode.softGlass &&
      a.liquidGlassSheetDialogEnabled;
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

  @override
  Widget build(BuildContext context) {
    return InspireHeaderBlur(
      tint: tint,
      blurEnabled: blurEnabled,
      blurSigma: blurSigma,
      style: blurStyle,
      opaqueAtRest: opaqueAtRest,
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
    super.key,
  });

  final Widget child;
  final bool blurEnabled;
  final Color? tint;

  /// See [InspireHeaderBlur.opaqueAtRest].
  final bool opaqueAtRest;

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

    // Soft glass panel: parent already owns blur — nested tiles only wash.
    final inSoftPanel =
        _isSoftSheetPanel(context) && HyperosFrostedPanelScope.of(context);
    if (inSoftPanel) {
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
    // 与面板材质同步：高级材质（柔光/液态）+「作用范围→弹窗」关（或系统
    // 降级）时，父面板已按 HyperosSheetFrame 的 solid 分支回退**纯白实体
    // 卡片**；白色水洗叠白底会让嵌套 tile 整个隐形（只剩文字）。改走
    // withBlur:false 的中性水洗（亮色黑 5% / 暗色白 10%），与实体面板同框。
    // 只作用于 sheet 面板内（PanelScope 标记）；面板外的菜单/井保持原判。
    final scope = FrostedAppearanceScope.maybeOf(context);
    final sheetPanelFellBackSolid =
        scope != null &&
        HyperosFrostedPanelScope.of(context) &&
        LiquidGlassDegradation.familyFallsBackToSolid(
          context,
          advancedFamilyEnabled:
              scope.appearance.liquidGlassSheetDialogEnabled,
        );
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
