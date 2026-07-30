import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart'
    show MiuixCardDefaults, MiuixSquircleBorder;

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

/// White settings card using the upstream flutter_miuix radius strategy:
/// fixed [MiuixCardDefaults.cornerRadius] (16) squircle on every surface,
/// regardless of content height.
///
/// Replaces the former height-adaptive policy (short card 16 / tall group
/// 24) after the upstream strategy was adopted app-wide. The squircle path
/// itself clamps geometrically to half the shorter side, so pathologically
/// short content still cannot overflow into a capsule beyond that limit.
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
      color: color ?? HyperosColors.card(context),
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
}
