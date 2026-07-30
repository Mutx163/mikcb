import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
      final double overscroll = value - minBound;
      final double delta = value - position.pixels;
      // Guard against floating-point drift where pixels is already slightly
      // beyond the boundary.  The framework asserts |overscroll| <= |delta|;
      // clamp to delta so the assertion is never violated.
      return overscroll.abs() > delta.abs() ? delta : overscroll;
    }
    if (value > maxBound) {
      final double overscroll = value - maxBound;
      final double delta = value - position.pixels;
      return overscroll.abs() > delta.abs() ? delta : overscroll;
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

    final beforePixels = position.pixels;
    final maxOverscroll = _maxOverscrollDistance(position);
    final overscrollPastStart = math.max(
      position.minScrollExtent - position.pixels,
      0,
    );
    final overscrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0,
    );

    double finish(String phase, double applied, {double? overscrollPast}) {
      final _ = (phase, overscrollPast);
      // ScrollPosition applies `pixels -= applied`. Observe the post-drag
      // pixels so edge arrival is detected even when no NotificationListener
      // is mounted above the scrollable.
      hyperosObserveScrollEdgeHaptic(
        position: position,
        pixels: beforePixels - applied,
        source: 'physics phase=$phase',
      );
      return applied;
    }

    // ScrollPosition applies `pixels -= return`; deepening top uses offset > 0.
    if (overscrollPastStart >= maxOverscroll && offset > 0) {
      return finish(
        'cap-top',
        0,
        overscrollPast: overscrollPastStart.toDouble(),
      );
    }
    if (overscrollPastEnd >= maxOverscroll && offset < 0) {
      return finish(
        'cap-bottom',
        0,
        overscrollPast: overscrollPastEnd.toDouble(),
      );
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

/// Edge-arrival haptic latch (one state per scroll [Axis]).
///
/// Fires only when content *arrives* at the top/bottom edge from the interior,
/// not when the user is already parked at that edge and deepens rubber-band
/// overscroll (blank gap).
///
/// After an edge has fired (or was seeded as already-at-edge), the same edge
/// re-arms only after the user scrolls about **half a viewport** into content.
///
/// State is keyed by [Axis] (not [ScrollPosition] identity). HyperOS pages
/// often rebuild scrollables mid-gesture; a new ScrollPosition would otherwise
/// reset latches and re-fire on every near-edge jiggle.
///
/// Detection runs from two places so every page is covered:
/// 1. [HyperosOverscrollPhysics.applyPhysicsToUserOffset] (finger drag)
/// 2. [ScrollUpdateNotification] via [HyperosScrollBehavior] / page hosts
///    (ballistic fling settle)
class _OverscrollEdgeHapticState {
  double? lastPixels;
  bool topConsumed = false;
  bool bottomConsumed = false;
  Duration lastFireTimestamp = Duration.zero;
}

/// One latch per scroll axis (vertical list / horizontal pager).
final Map<Axis, _OverscrollEdgeHapticState> _overscrollEdgeHapticStates = {};

/// Global gate for edge-arrival haptics (mirrors [TimetableSettings.enableHaptics]).
/// Defaults to true; call [hyperosSetEdgeHapticsEnabled] when settings load/change.
bool _hyperosEdgeHapticsEnabled = true;

/// Enables or disables list edge-arrival haptic feedback app-wide.
void hyperosSetEdgeHapticsEnabled(bool enabled) {
  _hyperosEdgeHapticsEnabled = enabled;
}

/// Fraction of [ScrollMetrics.viewportDimension] that must be traveled into
/// content before the same edge can fire again (~half screen).
@visibleForTesting
const hyperosOverscrollEdgeHapticRearmViewportFraction = 0.5;

/// Treat positions within this distance of min/max as "at the edge".
@visibleForTesting
const hyperosOverscrollEdgeHapticEdgeEpsilonPx = 0.5;

/// Ignore a second fire within this window (ballistic settle / dual listeners).
@visibleForTesting
const hyperosOverscrollEdgeHapticCooldown = Duration(milliseconds: 120);

/// Clears edge-haptic latches (tests only).
@visibleForTesting
void hyperosResetOverscrollEdgeHaptics() {
  _overscrollEdgeHapticStates.clear();
}

/// Distance from an edge into content required to re-arm that edge's haptic.
@visibleForTesting
double hyperosOverscrollEdgeHapticRearmDistance(ScrollMetrics position) {
  final viewport = position.viewportDimension;
  if (viewport <= 0) {
    return 200.0;
  }
  // Half viewport, never below 160px.
  return math.max(
    viewport * hyperosOverscrollEdgeHapticRearmViewportFraction,
    160.0,
  );
}

Duration _overscrollEdgeHapticNow() {
  try {
    return SchedulerBinding.instance.currentSystemFrameTimeStamp;
  } catch (_) {
    return Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
  }
}

bool _isAtTopEdge(double pixels, double minExtent) =>
    pixels <= minExtent + hyperosOverscrollEdgeHapticEdgeEpsilonPx;

bool _isAtBottomEdge(double pixels, double maxExtent) =>
    pixels >= maxExtent - hyperosOverscrollEdgeHapticEdgeEpsilonPx;

bool _isInteriorForTopRearm({
  required double pixels,
  required double minExtent,
  required double maxExtent,
  required double rearmDistance,
}) {
  return pixels > minExtent + rearmDistance &&
      pixels <= maxExtent + hyperosOverscrollEdgeHapticEdgeEpsilonPx;
}

bool _isInteriorForBottomRearm({
  required double pixels,
  required double minExtent,
  required double maxExtent,
  required double rearmDistance,
}) {
  return pixels < maxExtent - rearmDistance &&
      pixels >= minExtent - hyperosOverscrollEdgeHapticEdgeEpsilonPx;
}

Future<void> _fireEdgeHaptic() async {
  try {
    await HapticFeedback.selectionClick();
  } catch (_) {
    // Best-effort platform channel.
  }
}

/// Core edge-arrival observer. Used by physics (drag) and notifications (fling).
bool hyperosObserveScrollEdgeHaptic({
  required ScrollMetrics position,
  required double pixels,
  Object? key,
  String source = 'unknown',
}) {
  if (!_hyperosEdgeHapticsEnabled) {
    return false;
  }
  // Axis is the stable latch key (see class doc). Optional [key]/[source]
  // retained for call-site readability.
  final _ = (key, source);
  final axis = position.axis;
  final minExtent = position.minScrollExtent;
  final maxExtent = position.maxScrollExtent;
  final rearmDistance = hyperosOverscrollEdgeHapticRearmDistance(position);

  final atTop = _isAtTopEdge(pixels, minExtent);
  final atBottom = _isAtBottomEdge(pixels, maxExtent);

  final state = _overscrollEdgeHapticStates.putIfAbsent(
    axis,
    _OverscrollEdgeHapticState.new,
  );

  final scrollableRange = maxExtent - minExtent;

  // Non-scrollable / near-zero range: never fire.
  if (scrollableRange <= hyperosOverscrollEdgeHapticEdgeEpsilonPx) {
    state.topConsumed = true;
    state.bottomConsumed = true;
    state.lastPixels = pixels;
    return false;
  }

  final canRearm = scrollableRange >= rearmDistance;
  if (canRearm) {
    if (_isInteriorForTopRearm(
      pixels: pixels,
      minExtent: minExtent,
      maxExtent: maxExtent,
      rearmDistance: rearmDistance,
    )) {
      state.topConsumed = false;
    }
    if (_isInteriorForBottomRearm(
      pixels: pixels,
      minExtent: minExtent,
      maxExtent: maxExtent,
      rearmDistance: rearmDistance,
    )) {
      state.bottomConsumed = false;
    }
  }

  var fired = false;
  final lastPixels = state.lastPixels;

  if (lastPixels == null) {
    if (atTop) {
      state.topConsumed = true;
    }
    if (atBottom) {
      state.bottomConsumed = true;
    }
  } else {
    final now = _overscrollEdgeHapticNow();
    final cooldownOk =
        now - state.lastFireTimestamp >= hyperosOverscrollEdgeHapticCooldown;

    final wasAtTop = _isAtTopEdge(lastPixels, minExtent);
    final wasAtBottom = _isAtBottomEdge(lastPixels, maxExtent);

    final arrivedAtTop = atTop && !wasAtTop && !state.topConsumed;
    final arrivedAtBottom = atBottom && !wasAtBottom && !state.bottomConsumed;

    if (arrivedAtTop && cooldownOk) {
      state.topConsumed = true;
      state.lastFireTimestamp = now;
      _fireEdgeHaptic();
      fired = true;
    }
    if (arrivedAtBottom && cooldownOk) {
      state.bottomConsumed = true;
      state.lastFireTimestamp = now;
      _fireEdgeHaptic();
      fired = true;
    }
  }

  state.lastPixels = pixels;
  return fired;
}

/// Notification entry used by [HyperosScrollBehavior] and list hosts.
///
/// Also covers ballistic (fling) frames that never go through
/// [HyperosOverscrollPhysics.applyPhysicsToUserOffset].
bool hyperosHandleOverscrollEdgeHaptic(ScrollNotification notification) {
  if (notification is! ScrollUpdateNotification) {
    return false;
  }

  final metrics = notification.metrics;
  // Vertical lists + horizontal carousels (e.g. home week pager).
  if (metrics.axis != Axis.vertical && metrics.axis != Axis.horizontal) {
    return false;
  }

  return hyperosObserveScrollEdgeHaptic(
    position: metrics,
    pixels: metrics.pixels,
    source: 'notification depth=${notification.depth}',
  );
}

/// Ensures rubber-band overscroll snaps back after drag ends.
///
/// Also dispatches edge haptics via [hyperosHandleOverscrollEdgeHaptic] so
/// existing NotificationListener call sites pick up both behaviors.
bool hyperosHandleOverscrollSnapBack(ScrollNotification notification) {
  hyperosHandleOverscrollEdgeHaptic(notification);

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
      : () {
          final notificationContext = notification.context;
          if (notificationContext == null) {
            return null;
          }
          return Scrollable.maybeOf(notificationContext)?.position ??
              notificationContext
                  .findAncestorStateOfType<ScrollableState>()
                  ?.position;
        }();
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
///
/// Wraps every scrollable so edge haptics + snap-back work on **all** pages
/// that inherit this behavior (settings, subpages, raw ListViews, etc.).
class HyperosScrollBehavior extends MaterialScrollBehavior {
  const HyperosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Called from Scrollable._updatePosition with the Scrollable's OWN
    // context. Reading the header scope here must NOT register a dependency:
    // otherwise every scope change (frost flip, collapse inset) triggers
    // didChangeDependencies → _updatePosition → ScrollPosition recreation
    // mid-gesture, silently resetting pixels to 0 (title flicker on short
    // collapsible pages). Untracked read: topInset only shapes the
    // rubber-band cap, staleness until the next natural rebuild is fine.
    final inset = HyperosBlurredHeaderScope.insetOfUntracked(context);
    return HyperosOverscrollPhysics(
      parent: const AlwaysScrollableScrollPhysics(),
      topInset: inset,
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Material would insert StretchingOverscrollIndicator here; we replace it
    // with a global scroll notification hook instead.
    return NotificationListener<ScrollNotification>(
      onNotification: hyperosHandleOverscrollSnapBack,
      child: child,
    );
  }
}
