import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart'
    show MiuixCardDefaults, MiuixSquircleBorder;

import '../frosted/liquid_glass_degradation.dart';
import '../hyperos_blurred_header.dart';
import '../hyperos_sheet.dart';
import '../hyperos_theme.dart';

/// Publishes the corner radius actually applied by [HyperosAdaptiveCard].
///
/// Row press highlights must clip to this value so first/last rows follow
/// the card arc exactly.
class HyperosSurfaceRadiusScope extends InheritedWidget {
  const HyperosSurfaceRadiusScope({
    super.key,
    required this.radius,
    required super.child,
  });

  final double radius;

  static HyperosSurfaceRadiusScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosSurfaceRadiusScope>();
  }

  static double of(BuildContext context, {double? fallback}) {
    return maybeOf(context)?.radius ??
        fallback ??
        MiuixCardDefaults.cornerRadius;
  }

  @override
  bool updateShouldNotify(HyperosSurfaceRadiusScope oldWidget) {
    return (radius - oldWidget.radius).abs() > 0.01;
  }
}

/// Settings card using the upstream flutter_miuix radius strategy: fixed
/// [MiuixCardDefaults.cornerRadius] (16) squircle on every surface,
/// regardless of content height.
///
/// Replaces the former height-adaptive policy (short card 16 / tall group
/// 24) after the upstream strategy was adopted app-wide. The squircle path
/// itself clamps geometrically to half the shorter side, so pathologically
/// short content still cannot overflow into a capsule beyond that limit.
///
/// On a plain settings page the card is the opaque white surface. Inside a
/// frosted / liquid-glass panel ([HyperosFrostedPanelScope]) it degrades to a
/// translucent nested-glass wash so the panel's blur and refraction stay
/// visible through the group — same rule as the other in-glass surfaces
/// (select popups, menu tiles).
class HyperosAdaptiveCard extends StatelessWidget {
  const HyperosAdaptiveCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Material(
      color: color ?? _resolvedCardColor(context),
      shape: const MiuixSquircleBorder(
        cornerRadius: MiuixCardDefaults.cornerRadius,
      ),
      clipBehavior: clipBehavior,
      child: HyperosSurfaceRadiusScope(
        radius: MiuixCardDefaults.cornerRadius,
        child: content,
      ),
    );
  }

  /// Card fill for the surface this card sits on.
  ///
  /// Opaque white on settings pages; translucent glass wash on a frosted /
  /// liquid-glass panel (see [HyperosBlurredHeader.nestedSurfaceTintColor] and
  /// [HyperosBlurredHeader.nestedLiquidTileTintColor]).
  Color _resolvedCardColor(BuildContext context) {
    if (!HyperosFrostedPanelScope.of(context)) {
      return HyperosColors.card(context);
    }
    final appearance = FrostedAppearanceScope.of(context);
    if (appearance.glassMode == FrostedGlassMode.liquidGlass &&
        !LiquidGlassDegradation.shouldDegrade(context)) {
      return HyperosBlurredHeader.nestedLiquidTileTintColor(context);
    }
    return HyperosBlurredHeader.nestedSurfaceTintColor(
      context,
      withBlur: HyperosBlurredHeader.backdropBlurEnabled(context),
    );
  }
}
