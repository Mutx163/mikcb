import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS / Miuix-style edge overscroll: rubber-band blank gap, snap back on release.
///
/// Maps to Miuix [SpringUtils.kt] + RecyclerView overscroll on settings pages.
/// Resistance grows with distance but does not hard-stop; release always springs back.
/// Use as [ScrollView.physics] or via [HyperosListView] (enabled by default).
class HyperosOverscrollPhysics extends ScrollPhysics {
  const HyperosOverscrollPhysics({super.parent, this.frictionFactor = 0.52});

  /// Finger-to-content ratio while dragging past an edge (Miuix rubber-band feel).
  final double frictionFactor;

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
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Allow unlimited rubber-band overscroll; resistance is applied in
    // [applyPhysicsToUserOffset], snap-back in [createBallisticSimulation].
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

  /// Same progressive rubber-band as [BouncingScrollPhysics]: no hard distance cap.
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

    final overscrollPastStart = math.max(
      position.minScrollExtent - position.pixels,
      0,
    );
    final overscrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0,
    );
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
