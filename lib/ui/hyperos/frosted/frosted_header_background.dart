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
      blurStyle: HyperosBlurredHeader.headerBlurStyleOf(context),
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
    final resolvedTint =
        tint ??
        HyperosBlurredHeader.nestedSurfaceTintColor(context, withBlur: useBlur);

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
