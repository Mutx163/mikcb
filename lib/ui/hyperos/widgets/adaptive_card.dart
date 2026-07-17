import 'package:flutter/material.dart';

import '../hyperos_radius.dart';
import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';

/// Publishes the corner radius actually applied by [HyperosAdaptiveCard].
///
/// Row press highlights must clip to this value — not a fixed
/// [HyperosTokens.cardRadius] — or short cards look mismatched under the finger.
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
    return maybeOf(context)?.radius ?? fallback ?? HyperosTokens.cardRadius;
  }

  @override
  bool updateShouldNotify(HyperosSurfaceRadiusScope oldWidget) {
    return (radius - oldWidget.radius).abs() > 0.01;
  }
}

/// Settings-style card whose corner radius follows measured height.
///
/// Short content (single row, collapsed accordion, one action button) uses
/// [HyperosTokens.controlRadius]; tall multi-row groups keep
/// [HyperosTokens.cardRadius]. See [HyperosRadius].
class HyperosAdaptiveCard extends StatefulWidget {
  const HyperosAdaptiveCard({
    super.key,
    required this.child,
    this.color,
    this.preferredRadius,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final Color? color;

  /// Preferred radius for tall surfaces. Defaults to [HyperosTokens.cardRadius].
  final double? preferredRadius;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  State<HyperosAdaptiveCard> createState() => _HyperosAdaptiveCardState();
}

class _HyperosAdaptiveCardState extends State<HyperosAdaptiveCard> {
  /// Seed with a single-row height so the first frame already uses control radius.
  double _height = HyperosTokens.listRowMinHeight;

  void _handleSize(Size size) {
    if (!mounted) {
      return;
    }
    final nextHeight = size.height;
    if ((nextHeight - _height).abs() < 0.5) {
      return;
    }
    final previousRadius = HyperosRadius.surfaceRadiusForHeight(
      _height,
      preferred: widget.preferredRadius,
    );
    final nextRadius = HyperosRadius.surfaceRadiusForHeight(
      nextHeight,
      preferred: widget.preferredRadius,
    );
    // Skip rebuild when only height noise changes and radius stays the same.
    if ((nextRadius - previousRadius).abs() < 0.01) {
      _height = nextHeight;
      return;
    }
    setState(() => _height = nextHeight);
  }

  @override
  Widget build(BuildContext context) {
    final radius = HyperosRadius.surfaceRadiusForHeight(
      _height,
      preferred: widget.preferredRadius,
    );
    Widget content = widget.child;
    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }
    return Material(
      color: widget.color ?? HyperosColors.card(context),
      shape: HyperosTheme.roundedShape(radius),
      clipBehavior: widget.clipBehavior,
      child: HyperosSurfaceRadiusScope(
        radius: radius,
        child: HyperosSizeReporter(onSize: _handleSize, child: content),
      ),
    );
  }
}
