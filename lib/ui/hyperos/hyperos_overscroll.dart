import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';

/// HyperOS / Miuix-style edge overscroll: rubber-band blank gap, snap back on release.
///
/// Drag resistance: first [HyperosMiuixAnim.overscrollDragFreeZonePx] follow the
/// finger 1:1, then transfer ratio falls off steeply toward the half-screen cap.
/// Use as [ScrollView.physics] or via [HyperosListView] (enabled by default).
///
/// Pair with [hyperosBlockStretchOverscroll] / [HyperosScrollBehavior] so Android
/// Material 3 stretch does not bypass this physics.
class HyperosOverscrollPhysics extends ScrollPhysics {
  const HyperosOverscrollPhysics({
    super.parent,
    this.maxOverscrollFraction = HyperosMiuixAnim.maxOverscrollFraction,
    this.topInset = 0,
  });

  /// Hard cap on blank gap past an edge, as a fraction of viewport height.
  final double maxOverscrollFraction;

  /// Overlay header height excluded from the overscroll budget on HyperOS pages.
  final double topInset;

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
      maxOverscrollFraction: maxOverscrollFraction,
      topInset: topInset,
    );
  }

  double _contentViewport(ScrollMetrics position) {
    final viewport = position.viewportDimension;
    final scale = viewport > 0 ? viewport : 400.0;
    final inset = topInset.clamp(0.0, scale);
    return math.max(scale - inset, 0.0);
  }

  double _maxOverscrollDistance(ScrollMetrics position) {
    return _contentViewport(position) * maxOverscrollFraction;
  }

  double _minOverscrollBound(ScrollMetrics position) =>
      position.minScrollExtent - _maxOverscrollDistance(position);

  double _maxOverscrollBound(ScrollMetrics position) =>
      position.maxScrollExtent + _maxOverscrollDistance(position);

  double _limitDragDelta(ScrollMetrics position, double delta) {
    if (delta == 0) {
      return 0;
    }
    final minBound = _minOverscrollBound(position);
    final maxBound = _maxOverscrollBound(position);
    // ScrollPosition applies `pixels -= return`.
    final target = position.pixels - delta;
    if (target < minBound) {
      return position.pixels - minBound;
    }
    if (target > maxBound) {
      return position.pixels - maxBound;
    }
    return delta;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final minBound = _minOverscrollBound(position);
    final maxBound = _maxOverscrollBound(position);
    if (value < minBound) {
      return value - minBound;
    }
    if (value > maxBound) {
      return value - maxBound;
    }
    return 0;
  }

  /// Finger-to-content ratio for deepening overscroll (1.0 = fully follow finger).
  @visibleForTesting
  static double dragTransferRatio(double overscrollPast, double maxOverscroll) {
    if (maxOverscroll <= 0) {
      return 1.0;
    }
    final freeZone = HyperosMiuixAnim.overscrollDragFreeZonePx;
    if (overscrollPast <= freeZone) {
      return 1.0;
    }
    final range = math.max(maxOverscroll - freeZone, 1.0);
    final depth = ((overscrollPast - freeZone) / range).clamp(0.0, 1.0);
    final falloff = math
        .pow(1 - depth, HyperosMiuixAnim.overscrollDragFalloffExponent)
        .toDouble();
    final minTransfer = HyperosMiuixAnim.overscrollDragMinTransfer;
    return minTransfer + (1.0 - minTransfer) * falloff;
  }

  double _deepeningApplied(
    ScrollMetrics position,
    double overscrollPast,
    double deltaMagnitude,
  ) {
    if (deltaMagnitude <= 0) {
      return 0;
    }

    final maxOverscroll = _maxOverscrollDistance(position);
    final startRatio = dragTransferRatio(overscrollPast, maxOverscroll);
    final roughApplied = deltaMagnitude * startRatio;
    final endRatio = dragTransferRatio(
      overscrollPast + roughApplied,
      maxOverscroll,
    );
    return deltaMagnitude * (startRatio + endRatio) / 2;
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

    double finish(String _phase, double applied, {double? overscrollPast}) {
      final _ = overscrollPast;
      return applied;
    }

    // ScrollPosition applies `pixels -= return`; deepening top uses offset > 0.
    if (overscrollPastStart >= maxOverscroll && offset > 0) {
      return finish('cap-top', 0, overscrollPast: overscrollPastStart.toDouble());
    }
    if (overscrollPastEnd >= maxOverscroll && offset < 0) {
      return finish('cap-bottom', 0, overscrollPast: overscrollPastEnd.toDouble());
    }

    final wouldOverscrollPastStart =
        offset > 0 && position.pixels - offset < position.minScrollExtent;
    final wouldOverscrollPastEnd =
        offset < 0 && position.pixels - offset > position.maxScrollExtent;

    // Closing rubber-band (pull-back) follows the finger 1:1 — same easing
    // directions as BouncingScrollPhysics (pixels -= return).
    if (overscrollPastStart > 0 && offset < 0) {
      return finish(
        'unwind-top',
        _limitDragDelta(position, offset),
        overscrollPast: overscrollPastStart.toDouble(),
      );
    }
    if (overscrollPastEnd > 0 && offset > 0) {
      return finish(
        'unwind-bottom',
        _limitDragDelta(position, offset),
        overscrollPast: overscrollPastEnd.toDouble(),
      );
    }

    if (!position.outOfRange &&
        !wouldOverscrollPastStart &&
        !wouldOverscrollPastEnd) {
      return finish('in-range', offset);
    }

    final overscrollPast = math
        .max(overscrollPastStart, overscrollPastEnd)
        .toDouble();

    if (!position.outOfRange &&
        (wouldOverscrollPastStart || wouldOverscrollPastEnd)) {
      final boundary = wouldOverscrollPastStart
          ? position.minScrollExtent
          : position.maxScrollExtent;
      final inRange = (boundary - position.pixels).abs();
      final pastEdge = offset.abs() - inRange;
      if (pastEdge <= 0) {
        return finish(
          'edge-in-range',
          _limitDragDelta(position, offset),
          overscrollPast: overscrollPast,
        );
      }
      final inRangeSigned = offset.sign * inRange;
      final overscrollSigned =
          offset.sign * _deepeningApplied(position, overscrollPast, pastEdge);
      return finish(
        'cross-edge',
        _limitDragDelta(position, inRangeSigned + overscrollSigned),
        overscrollPast: overscrollPast,
      );
    }

    return finish(
      'deepen',
      _limitDragDelta(
        position,
        offset.sign * _deepeningApplied(position, overscrollPast, offset.abs()),
      ),
      overscrollPast: overscrollPast,
    );
  }

  double _clampReleaseVelocity(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    final overscrollPastStart = math.max(
      position.minScrollExtent - position.pixels,
      0,
    );
    final overscrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0,
    );
    if (overscrollPastStart > tolerance.distance && velocity < 0) {
      return 0;
    }
    if (overscrollPastEnd > tolerance.distance && velocity > 0) {
      return 0;
    }
    return velocity;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final overscrollPastStart = math.max(
      position.minScrollExtent - position.pixels,
      0,
    );
    final overscrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0,
    );
    final clampedVelocity = _clampReleaseVelocity(position, velocity);

    if (overscrollPastStart > tolerance.distance) {
      return ScrollSpringSimulation(
        _spring,
        position.pixels,
        position.minScrollExtent,
        clampedVelocity,
        tolerance: tolerance,
      );
    }
    if (overscrollPastEnd > tolerance.distance) {
      return ScrollSpringSimulation(
        _spring,
        position.pixels,
        position.maxScrollExtent,
        clampedVelocity,
        tolerance: tolerance,
      );
    }

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

/// Blocks Material 3 [StretchingOverscrollIndicator] so [HyperosOverscrollPhysics]
/// drives overscroll. Wrap every HyperOS scrollable that needs rubber-band drag.
Widget hyperosBlockStretchOverscroll({required Widget child}) {
  return NotificationListener<OverscrollIndicatorNotification>(
    onNotification: (notification) {
      notification.disallowIndicator();
      return true;
    },
    child: child,
  );
}

/// Ensures rubber-band overscroll snaps back after drag ends.
bool hyperosHandleOverscrollSnapBack(ScrollNotification notification) {
  if (notification is! ScrollEndNotification) {
    return false;
  }

  final metrics = notification.metrics;
  if (metrics.pixels >= metrics.minScrollExtent &&
      metrics.pixels <= metrics.maxScrollExtent) {
    return false;
  }

  final ScrollPosition? position = metrics is ScrollPosition
      ? metrics
      : notification.context
          ?.findAncestorStateOfType<ScrollableState>()
          ?.position;
  if (position == null || !position.hasPixels) {
    return false;
  }

  final target = metrics.pixels.clamp(
    metrics.minScrollExtent,
    metrics.maxScrollExtent,
  );
  final tolerance = position.physics.toleranceFor(position).distance;
  if ((metrics.pixels - target).abs() < tolerance) {
    return false;
  }

  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!position.hasPixels) {
      return;
    }
    if (position.pixels >= position.minScrollExtent &&
        position.pixels <= position.maxScrollExtent) {
      return;
    }
    if (position.physics.createBallisticSimulation(position, 0) != null) {
      return;
    }
    final snapTarget = position.pixels.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - snapTarget).abs() < tolerance) {
      return;
    }
    position.animateTo(
      snapTarget,
      duration: Duration(
        milliseconds: (HyperosMiuixAnim.standardSpringPeriod * 1000).round(),
      ),
      curve: Curves.easeOutCubic,
    );
  });
  return false;
}

/// Default scroll behavior for [HyperosSubpage] / [HyperosRootPage] bodies.
class HyperosScrollBehavior extends MaterialScrollBehavior {
  const HyperosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return HyperosOverscrollPhysics(
      parent: const AlwaysScrollableScrollPhysics(),
      topInset: HyperosBlurredHeaderScope.insetOf(context),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
