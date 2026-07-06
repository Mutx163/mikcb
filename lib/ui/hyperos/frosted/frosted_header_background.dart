import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../hyperos_blurred_header.dart';

/// Frosted top bar: Flutter [BackdropFilter] blur + tint scrim.
class FrostedHeaderBackground extends StatelessWidget {
  const FrostedHeaderBackground({
    required this.tint,
    required this.child,
    this.blurEnabled = true,
    this.blurSigma = HyperosBlurredHeader.blurSigma,
    super.key,
  });

  final Color tint;
  final Widget child;
  final bool blurEnabled;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: blurEnabled
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                          tileMode: TileMode.clamp,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      ColoredBox(color: tint),
                    ],
                  )
                : ColoredBox(color: tint),
          ),
          child,
        ],
      ),
    );
  }
}

/// Shell matching [HyperosBlurredHeaderShell] API with live backdrop blur.
class HyperosFrostedHeaderShell extends StatelessWidget {
  const HyperosFrostedHeaderShell({
    required this.child,
    this.blurEnabled = true,
    super.key,
  });

  final Widget child;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final scopeBlur = HyperosBlurredHeaderScope.blurEnabledOf(context);
    final useBlur =
        blurEnabled &&
        scopeBlur &&
        HyperosBlurredHeader.backdropBlurEnabled(context);
    final tint = HyperosBlurredHeader.tintColor(context, withBlur: useBlur);

    return FrostedHeaderBackground(
      blurEnabled: useBlur,
      blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
      tint: tint,
      child: child,
    );
  }
}

/// Rounded frosted surface for cards, menu tiles, and icon wells.
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
    final useBlur =
        HyperosBlurredHeader.backdropBlurEnabled(context) &&
        (blurEnabled ?? true);
    final resolvedTint =
        tint ??
        HyperosBlurredHeader.nestedSurfaceTintColor(context, withBlur: useBlur);

    var content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: child);
    }

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
