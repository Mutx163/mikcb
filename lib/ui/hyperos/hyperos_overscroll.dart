import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS / Miuix-style edge overscroll: rubber-band blank gap, snap back on release.
///
/// Maps to Miuix [SpringUtils.kt] + RecyclerView overscroll on settings pages.
/// Resistance grows with distance; blank gap is capped at [maxOverscrollFraction]
/// of the viewport. Release always springs back.
/// Use as [ScrollView.physics] or via [HyperosListView] (enabled by default).
class HyperosOverscrollPhysics extends ScrollPhysics {
  const HyperosOverscrollPhysics({
    super.parent,
    this.frictionFactor = 0.52,
    this.maxOverscrollFraction = HyperosMiuixAnim.maxOverscrollFraction,
  });

  /// Finger-to-content ratio while dragging past an edge (Miuix rubber-band feel).
  final double frictionFactor;

  /// Hard cap on blank gap past an edge, as a fraction of viewport height.
  final double maxOverscrollFraction;

  static SpringDescription get _spring {
    final omega = (2 * math.pi) / HyperosMiuixAnim.standardSpringPeriod;
    return SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: omega * omega,
      ratio: HyperosMiuixAnim.criticalDampingRatio,
    );
  }

  @override
  HyperosOverscrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HyperosOverscrollPhysics(
      parent: buildParent(ancestor),
      frictionFactor: frictionFactor,
      maxOverscrollFraction: maxOverscrollFraction,
    );
  }

  double _maxOverscrollDistance(ScrollMetrics position) {
    final viewport = position.viewportDimension;
    final scale = viewport > 0 ? viewport : 400.0;
    return scale * maxOverscrollFraction;
  }

  double _minBound(ScrollMetrics position) =>
      position.minScrollExtent - _maxOverscrollDistance(position);

  double _maxBound(ScrollMetrics position) =>
      position.maxScrollExtent + _maxOverscrollDistance(position);

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final minBound = _minBound(position);
    final maxBound = _maxBound(position);
    if (value < minBound) {
      return value - minBound;
    }
    if (value > maxBound) {
      return value - maxBound;
    }
    return 0;
  }

  double _rubberBandFriction(
    ScrollMetrics position,
    double overscrollPast,
    double offsetMagnitude,
    bool easing,
  ) {
    final viewport = position.viewportDimension;
    final scale = viewport > 0 ? viewport : 400.0;
    final overscrollFraction = overscrollPast / scale;
    final friction = easing
        ? _frictionFactor((overscrollPast - offsetMagnitude) / scale)
        : _frictionFactor(overscrollFraction);
    return friction;
  }

  double _frictionFactor(double overscrollFraction) {
    return math.pow(1 - overscrollFraction, 2).toDouble() * frictionFactor;
  }

  /// Progressive rubber-band resistance before the [maxOverscrollFraction] cap.
  static double _applyFriction(
    double extentOutside,
    double absDelta,
    double gamma,
  ) {
    assert(absDelta > 0);
    var total = 0.0;
    if (extentOutside > 0) {
      final deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) {
        return absDelta * gamma;
      }
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset == 0) {
      return 0;
    }

    final maxOverscroll = _maxOverscrollDistance(position);
    final overscrollPastStart = math.max(
      position.minScrollExtent - position.pixels,
      0,
    );
    final overscrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0,
    );

    // At the hard cap, stop pulling deeper; pull-back still follows the finger.
    if (overscrollPastStart >= maxOverscroll && offset < 0) {
      return 0;
    }
    if (overscrollPastEnd >= maxOverscroll && offset > 0) {
      return 0;
    }

    final wouldOverscrollPastStart =
        offset < 0 && position.pixels + offset < position.minScrollExtent;
    final wouldOverscrollPastEnd =
        offset > 0 && position.pixels + offset > position.maxScrollExtent;

    // Closing rubber-band (pull-back) follows the finger 1:1 so a reverse swipe
    // can collapse the blank gap and keep scrolling into content. Nonlinear
    // resistance applies only when pulling deeper into overscroll.
    if (overscrollPastEnd > 0 && offset < 0) {
      return offset;
    }
    if (overscrollPastStart > 0 && offset > 0) {
      return offset;
    }

    if (!position.outOfRange &&
        !wouldOverscrollPastStart &&
        !wouldOverscrollPastEnd) {
      return offset;
    }

    final overscrollPast = math
        .max(overscrollPastStart, overscrollPastEnd)
        .toDouble();
    final easing =
        (overscrollPastStart > 0 && offset < 0) ||
        (overscrollPastEnd > 0 && offset > 0) ||
        wouldOverscrollPastStart ||
        wouldOverscrollPastEnd;
    final friction = _rubberBandFriction(
      position,
      overscrollPast,
      offset.abs(),
      easing,
    );

    if (!position.outOfRange &&
        (wouldOverscrollPastStart || wouldOverscrollPastEnd)) {
      final boundary = wouldOverscrollPastStart
          ? position.minScrollExtent
          : position.maxScrollExtent;
      final inRange = (boundary - position.pixels).abs();
      final pastEdge = offset.abs() - inRange;
      if (pastEdge <= 0) {
        return offset;
      }
      final inRangeSigned = offset.sign * inRange;
      final overscrollSigned =
          offset.sign * _applyFriction(overscrollPast, pastEdge, friction);
      return inRangeSigned + overscrollSigned;
    }

    return offset.sign * _applyFriction(overscrollPast, offset.abs(), friction);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return BouncingScrollSimulation(
        spring: _spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }
}

/// Default scroll behavior for [HyperosSubpage] / [HyperosRootPage] bodies.
///
/// Child [ListView], [SingleChildScrollView], etc. inherit
/// [HyperosOverscrollPhysics] unless they set [ScrollPhysics] explicitly
/// (e.g. [NeverScrollableScrollPhysics] for nested grids).
class HyperosScrollBehavior extends MaterialScrollBehavior {
  const HyperosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const HyperosOverscrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
