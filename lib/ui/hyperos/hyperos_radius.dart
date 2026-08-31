import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'hyperos_tokens.dart';

/// Corner-radius helpers for HyperOS / Miuix chips, popups, and controls.
///
/// **Note** Card surfaces ([HyperosAdaptiveCard] and everything built on it)
/// now use the upstream flutter_miuix strategy — fixed 16dp squircle — and no
/// longer consult [surfaceRadiusForHeight]. The helpers below remain for
/// proportional chip radii and for popups/controls that clamp a preferred
/// radius against a measured height.
abstract final class HyperosRadius {
  /// Minimum flat side wall (dp) kept after clamping, so arcs never merge.
  static const minStraightEdge = 6.0;

  /// Surfaces shorter than this use [HyperosTokens.controlRadius] as the
  /// preferred radius (single list row / collapsed accordion header).
  static const shortSurfaceThreshold =
      HyperosTokens.listRowMinHeight * 1.35; // ~75.6

  /// Clamps [preferred] so `radius < height/2 - minStraightEdge`.
  ///
  /// When [height] is unknown or non-positive, returns [preferred] unchanged.
  static double clampCornerRadius(double preferred, double height) {
    if (height <= 0 || !height.isFinite) {
      return preferred;
    }
    final maxRadius = (height / 2) - minStraightEdge;
    if (maxRadius <= 0) {
      // Pathologically short: half-height is the geometric limit.
      return height / 2;
    }
    if (preferred <= maxRadius) {
      return preferred;
    }
    return maxRadius;
  }

  /// Picks the preferred radius for a measured surface height, then clamps.
  ///
  /// Short surfaces prefer [HyperosTokens.controlRadius]; tall ones prefer
  /// [preferred] (defaults to [HyperosTokens.cardRadius]).
  static double surfaceRadiusForHeight(double height, {double? preferred}) {
    final tallPreferred = preferred ?? HyperosTokens.cardRadius;
    const shortPreferred = HyperosTokens.controlRadius;
    final chosen = height > 0 && height < shortSurfaceThreshold
        ? shortPreferred
        : tallPreferred;
    return clampCornerRadius(chosen, height);
  }

  /// Minimum height that can host [radius] without collapsing into a capsule.
  static double minHeightForRadius(double radius) {
    return radius * 2 + minStraightEdge * 2;
  }

  /// Corner radius for a square/chip of [size] using the icon-badge proportion.
  static double chipRadius(double size) {
    if (size <= 0) {
      return 0;
    }
    final proportional =
        size * HyperosTokens.iconBadgeRadius / HyperosTokens.iconBadgeSize;
    return clampCornerRadius(proportional, size);
  }

  static BorderRadius borderRadiusForHeight(
    double height, {
    double? preferred,
  }) {
    return BorderRadius.circular(
      surfaceRadiusForHeight(height, preferred: preferred),
    );
  }
}

/// Reports the laid-out size of [child] after each layout pass.
class HyperosSizeReporter extends SingleChildRenderObjectWidget {
  const HyperosSizeReporter({super.key, required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderHyperosSizeReporter(onSize: onSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderHyperosSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

/// Layout proxy that reports size changes to [onSize].
class RenderHyperosSizeReporter extends RenderProxyBox {
  RenderHyperosSizeReporter({required this.onSize});

  ValueChanged<Size> onSize;
  Size? _lastReported;

  @override
  void performLayout() {
    super.performLayout();
    final laidOut = size;
    if (_lastReported == laidOut) {
      return;
    }
    _lastReported = laidOut;
    // Defer so setState from the listener is not during layout.
    final callback = onSize;
    final reported = laidOut;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback(reported);
    });
  }
}
