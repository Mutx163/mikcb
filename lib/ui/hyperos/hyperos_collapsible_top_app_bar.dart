import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Defaults for [HyperosCollapsibleTopAppBar], aligned with
/// [HyperosMiuixTopAppBar] (Miuix `TopAppBarDefaults`).
abstract final class HyperosCollapsibleTopAppBarDefaults {
  HyperosCollapsibleTopAppBarDefaults._();

  static const double titlePadding = HyperosMiuixTopAppBar.titlePadding;
  static const double navigationIconPadding =
      HyperosMiuixTopAppBar.navigationIconPadding;
  static const double actionIconPadding =
      HyperosMiuixTopAppBar.actionIconPadding;
  static const double collapsedHeight = HyperosMiuixTopAppBar.collapsedHeight;
  static const double largeTitleBottomPadding =
      HyperosMiuixTopAppBar.largeTitleBottomPadding;
  static const double largeTitleContentGap =
      HyperosMiuixTopAppBar.largeTitleContentGap;
  static const double subtitleBottomPadding =
      HyperosMiuixTopAppBar.subtitleBottomPadding;

  /// Large expanded title size (Miuix `title1`).
  static const double largeTitleFontSize = HyperosMiuixTypography.title1;

  /// Collapsed centered title size (Miuix `title3` / nested frosted header).
  static const double smallTitleFontSize = HyperosMiuixTypography.title3;

  /// Subtitle / summary size (Miuix `body2`).
  static const double subtitleFontSize = HyperosMiuixTypography.body2;

  /// Large-title fade slope. Upstream Miuix `TopAppBarLayout`:
  /// `alpha = 1 - (collapsedFraction * 3)` — greying/fading starts on the very
  /// first collapse pixel and the large title is fully gone at 1/3 collapse,
  /// before the small title appears.
  static const double largeTitleFadeRate = 3.0;

  /// Collapse fraction at which the small title toggles visible. Upstream:
  /// `collapsedFraction * 3 >= 1`.
  static const double smallTitleRevealFraction = 1.0 / 3.0;

  /// Rise distance of the small title during its show transition (upstream
  /// moves `translationY` from 20 to 0 with a folme spring).
  static const double smallTitleRisePx = 20.0;

  /// Resolves the small-title opacity from the same collapse progress that
  /// moves the large title.
  ///
  /// Keeping this as a function of collapse progress is important for short
  /// pages: their title follows the list's rubber-band spring after release.
  /// A separate fixed-duration animation would introduce a second, faster
  /// clock and make the title visibly change speed at the midpoint.
  @visibleForTesting
  static double smallTitleOpacityForCollapse(double collapseFraction) {
    final normalizedFraction = collapseFraction.clamp(0.0, 1.0);
    if (normalizedFraction <= smallTitleRevealFraction) {
      return 0.0;
    }
    final revealProgress =
        ((normalizedFraction - smallTitleRevealFraction) /
                (1.0 - smallTitleRevealFraction))
            .clamp(0.0, 1.0);
    return revealProgress;
  }

  /// Extra scroll the collapse snap applies beyond the collapse point so the
  /// first content row parks tight under the small-title band. The content
  /// edge reaches the band at `largeTitleBottomPadding + largeTitleContentGap`
  /// past the collapse point — which is also the frost threshold — so stop
  /// 1px shy of it: visually flush, never overlapping, and the header never
  /// flips to its frosted/blurred state from the snap itself.
  static const double collapseSnapRestTighten =
      HyperosMiuixTopAppBar.largeTitleBottomPadding +
      HyperosMiuixTopAppBar.largeTitleContentGap -
      1.0;
}

/// A curve approximation of the critical spring used by the custom
/// overscroll physics. It is used for in-range endpoint snaps; out-of-range
/// pages follow the actual scroll spring directly.
class _HyperosCriticalSpringCurve extends Curve {
  const _HyperosCriticalSpringCurve();

  static const double _springPeriodSeconds =
      HyperosMiuixAnim.standardSpringPeriod;
  static final double _springOmega = (2 * math.pi) / _springPeriodSeconds;
  static final double _settledProgress = _criticalProgress(
    _springPeriodSeconds,
  );

  static double _criticalProgress(double seconds) {
    final normalizedTime = _springOmega * seconds;
    return 1.0 - (1.0 + normalizedTime) * math.exp(-normalizedTime);
  }

  @override
  double transformInternal(double time) {
    final rawProgress = _criticalProgress(
      time.clamp(0.0, 1.0) * _springPeriodSeconds,
    );
    return (rawProgress / _settledProgress).clamp(0.0, 1.0);
  }
}

/// Mutable collapse state shared by [HyperosExitUntilCollapsedScrollBehavior]
/// and [HyperosCollapsibleTopAppBar].
///
/// Port of Miuix `TopAppBarState`: [heightOffset] is negative while collapsed.
class HyperosCollapsibleTopAppBarState extends ChangeNotifier {
  HyperosCollapsibleTopAppBarState({
    double initialHeightOffsetLimit = double.negativeInfinity,
    double initialHeightOffset = 0,
    double initialContentOffset = 0,
  }) : _heightOffsetLimit = initialHeightOffsetLimit,
       _heightOffset = initialHeightOffset,
       _contentOffset = initialContentOffset;

  double _heightOffsetLimit;
  double _heightOffset;
  double _contentOffset;

  /// Most-negative allowed [heightOffset] (equals `-expansion` once measured).
  double get heightOffsetLimit => _heightOffsetLimit;

  set heightOffsetLimit(double value) {
    // Ignore zero limits when we already have a valid (negative) one. A zero
    // limit can arise transiently when _largeTitleSize is null during a parent
    // rebuild (the Offstage measurer hasn't re-measured yet). Accepting it
    // would force heightOffset → 0, re-expanding the title mid-collapse.
    if (value.abs() < 0.5 &&
        _heightOffsetLimit.isFinite &&
        _heightOffsetLimit < -1.0) {
      return;
    }
    if (_heightOffsetLimit == value) {
      return;
    }
    _heightOffsetLimit = value;
    // Re-clamp current offset into the new range.
    heightOffset = _heightOffset;
    _scheduleNotify();
  }

  /// Collapse offset in logical pixels. `0` = fully expanded; more negative =
  /// more collapsed. Always clamped to `[heightOffsetLimit, 0]`.
  double get heightOffset => _heightOffset;

  bool _notifyScheduled = false;

  set heightOffset(double value) {
    final clamped = value.clamp(_heightOffsetLimit, 0.0);
    if (_heightOffset == clamped) {
      return;
    }
    _heightOffset = clamped;
    _scheduleNotify();
  }

  /// Defers [notifyListeners] to after the current frame when called during
  /// layout/paint (e.g. scroll notifications bubbling through performLayout).
  /// Calling [notifyListeners] directly triggers setState inside
  /// [AnimatedBuilder] → "Build scheduled during frame".
  void _scheduleNotify() {
    if (_notifyScheduled) {
      return;
    }

    // Scroll physics ticks run during transient callbacks, before Flutter
    // starts the build/layout phase for that frame. Notify immediately there
    // so the title is painted on the same spring frame as the scroll offset.
    // During layout or paint, defer as before to avoid marking an
    // AnimatedBuilder dirty in the middle of the pipeline.
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.transientCallbacks) {
      notifyListeners();
      return;
    }

    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Cumulative content scroll under the bar (informational / future use).
  double get contentOffset => _contentOffset;

  set contentOffset(double value) {
    if (_contentOffset == value) {
      return;
    }
    _contentOffset = value;
    // Do not notify: contentOffset is bookkeeping only. Notifying here would
    // rebuild listeners on every scroll pixel even when [heightOffset] is
    // already clamped (fully expanded/collapsed), causing title flicker.
  }

  /// `0.0` fully expanded, `1.0` fully collapsed.
  double get collapsedFraction {
    if (_heightOffsetLimit == 0 || _heightOffsetLimit.isInfinite) {
      return 0;
    }
    return (_heightOffset / _heightOffsetLimit).clamp(0.0, 1.0);
  }

  /// Height of the large title text in logical pixels, set by
  /// [_HyperosCollapsibleTopAppBarState] after measurement. Used by the snap
  /// logic to decide the "cut in half" threshold.
  double largeTitleTextHeight = 0;
}

/// Scroll policy that drives [HyperosCollapsibleTopAppBarState].
abstract class HyperosCollapsibleScrollBehavior {
  HyperosCollapsibleTopAppBarState get state;

  /// When true, the bar stays expanded (limit forced to 0 by small bars).
  bool get isPinned;
}

/// Collapse tracks content scroll position 1:1 (Miuix
/// `ExitUntilCollapsedScrollBehavior`).
///
/// `heightOffset = -(pixels - minScrollExtent)`, then clamped. No delta
/// accumulation while dragging. On [ScrollEndNotification], when the bar is
/// mid-collapse, the list is animated to fully expanded or fully collapsed
/// (whichever end is nearer) — matches Miuix `snapAnimationSpec`.
class HyperosExitUntilCollapsedScrollBehavior
    implements HyperosCollapsibleScrollBehavior {
  HyperosExitUntilCollapsedScrollBehavior({
    HyperosCollapsibleTopAppBarState? state,
    this.canScroll,
    this.requireOuterScrollable = true,
    this.snapOnRelease = true,
    // Match the 400ms critical spring used by HyperosOverscrollPhysics. A
    // shorter endpoint snap makes the title visibly accelerate after the
    // slower rubber-band has already started returning.
    this.snapDuration = const Duration(milliseconds: 400),
    this.snapCurve = const _HyperosCriticalSpringCurve(),
    this.onSnapCompleted,
  }) : state = state ?? HyperosCollapsibleTopAppBarState();

  @override
  final HyperosCollapsibleTopAppBarState state;

  /// Optional gate; when it returns false, scroll is ignored.
  final bool Function()? canScroll;

  /// When true, only accept [ScrollNotification.depth] == 0 (listener wraps the
  /// scroll view). Page shells that listen above nested listeners should set
  /// false so depth > 0 notifications still drive collapse.
  final bool requireOuterScrollable;

  /// Snap the list to expanded or collapsed after the finger lifts mid-range.
  final bool snapOnRelease;

  final Duration snapDuration;
  final Curve snapCurve;

  /// Called after an endpoint snap settles so visual collaborators such as
  /// the frosted header can resync from the final scroll position.
  final VoidCallback? onSnapCompleted;

  bool _snapInProgress = false;
  DateTime? _snapCompletedAt;

  /// Tracks a short-page title snap against the list's own rubber-band.
  ///
  /// A short page cannot keep the large title collapsed through its normal
  /// scroll range, so the list briefly moves out of range and then springs
  /// back. The title must follow that same spring progress instead of jumping
  /// directly to the half-cut decision's endpoint on [ScrollEndNotification].
  double? _shortPageSpringReleasePixels;
  double? _shortPageSpringTargetPixels;
  double _shortPageReleaseTitleOffset = 0;
  double _shortPageTargetTitleOffset = 0;
  double? _shortPageLastUserDragPixels;

  /// True while a snap-to-endpoint animation is running. Listeners should avoid
  /// toggling visual state (e.g. frost) during the snap to prevent flicker.
  bool get isSnapInProgress => _snapInProgress;

  /// True briefly after a snap animation completes. Pixels can oscillate around
  /// the endpoint threshold during this window, so listeners should keep
  /// suppressing frost toggles to avoid a one-shot flash.
  bool get isSnapCooldown =>
      _snapCompletedAt != null &&
      DateTime.now().difference(_snapCompletedAt!) <
          const Duration(milliseconds: 800);

  /// Pixel position captured when the current short-page spring began.
  ///
  /// The page shell uses this same anchor when it computes the paint-only body
  /// translation. Keeping the value here prevents the title and the body from
  /// normalizing the same physical spring against different release frames.
  double? get shortPageSpringReleasePixels => _shortPageSpringReleasePixels;

  /// In-range pixel position reached when the current short-page spring ends.
  double? get shortPageSpringTargetPixels => _shortPageSpringTargetPixels;

  /// Title offset at the end of the current short-page transition.
  double? get shortPageSpringTargetTitleOffset => _shortPageTargetTitleOffset;

  /// Returns progress through the current short-page transition for [pixels].
  ///
  /// The page shell uses this exact calculation for its paint-only body
  /// translation, so the title and body share one release anchor and one
  /// physical scroll sample instead of maintaining separate spring clocks.
  /// [pixels] uses the same absolute scroll coordinate as
  /// [ScrollMetrics.pixels].
  double? shortPageSpringProgressForPixels(double pixels) {
    final releasePixels = _shortPageSpringReleasePixels;
    final targetPixels = _shortPageSpringTargetPixels;
    if (releasePixels == null || targetPixels == null) {
      return null;
    }
    final totalDistance = releasePixels - targetPixels;
    if (totalDistance.abs() <= 0.01) {
      return 1.0;
    }
    final remainingFraction = ((pixels - targetPixels) / totalDistance).clamp(
      0.0,
      1.0,
    );
    return 1.0 - remainingFraction;
  }

  @override
  bool get isPinned => false;

  /// Feed from [NotificationListener] / [HyperosCollapsibleScrollListener].
  bool handleScroll(ScrollNotification notification) {
    final pixels = notification.metrics.pixels;
    final minExtent = notification.metrics.minScrollExtent;
    final maxExtent = notification.metrics.maxScrollExtent;

    // Non-scrollable lists still respond to overscroll (pull-down) so the
    // title can collapse. Handled in _syncOffsetToPosition / snap.

    if (canScroll != null && !canScroll!()) {
      return false;
    }
    // Only the outermost vertical scrollable drives the bar.
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (requireOuterScrollable && notification.depth != 0) {
      return false;
    }

    // Short pages (a handful of rows) cannot scroll far enough to hold the
    // title collapsed via scroll position: the title can only be collapsed by
    // rubber-band overscroll, which springs back to the top on release. On
    // those pages the generic scroll-position sync would re-expand the title
    // during spring-back (the "回弹 + 闪烁" bug). Route them to a dedicated path
    // that freezes the collapsed title on release instead.
    final limit = state.heightOffsetLimit;
    final expansion = limit.isFinite ? -limit : 0.0;
    final canParkViaScroll =
        expansion <= 0 || (maxExtent - minExtent) >= expansion - 1.0;
    if (!canParkViaScroll) {
      return _handleShortPageScroll(notification);
    }

    if (_snapInProgress && notification is! ScrollEndNotification) {
      // Keep heightOffset in sync while the snap animation runs.
      _syncOffsetToPosition(notification.metrics);
      return false;
    }
    // When the user releases while in overscroll, freeze the title during
    // the subsequent spring-back animation so it doesn't re-expand.
    if (notification is ScrollEndNotification &&
        pixels > maxExtent + 0.5 &&
        state.heightOffset < 0) {
      _frozenDuringOverscrollSpringBack = true;
    }
    // New drag starts → clear freeze.
    if (notification is ScrollStartNotification) {
      _frozenDuringOverscrollSpringBack = false;
    }
    if (_frozenDuringOverscrollSpringBack) {
      state.contentOffset = pixels;
      if (pixels <= maxExtent + 0.5) {
        // Spring-back finished; re-sync once and clear the flag.
        _frozenDuringOverscrollSpringBack = false;
        _syncOffsetToPosition(notification.metrics);
        // Fall through: the ScrollEnd that accompanies spring-back settle
        // must reach the snap logic below, otherwise the title can park
        // at a half-collapsed position when overscroll rebound ends.
      } else {
        return false;
      }
    }

    _syncOffsetToPosition(notification.metrics);

    // Snap on release — must run BEFORE the small-title lock check, otherwise
    // a mid-scroll release that falls into the lock path will never snap and
    // the title stays frozen at a half-collapsed position forever.
    if (snapOnRelease && notification is ScrollEndNotification) {
      _snapToNearestEndpoint(notification);
      _smallTitleLocked = false;
      state.contentOffset = pixels;
      return false;
    }

    // Small-title lock: once the title is collapsed, keep it collapsed until
    // the user scrolls all the way back to the top (pixels ≈ 0). Fling
    // animations that happen to reach the top must NOT unlock — only a
    // deliberate user drag should re-expand the title.
    if (state.heightOffset < -5.0 && pixels > 0.5) {
      _smallTitleLocked = true;
    }
    if (_smallTitleLocked) {
      if (notification is ScrollStartNotification) {
        // New gesture: clear lock so the user can freely interact.
        _smallTitleLocked = false;
      } else {
        // During the current gesture (drag or fling), keep the title frozen.
        state.contentOffset = pixels;
        return false;
      }
    }

    return false;
  }

  /// Collapse handling for pages too short to hold the title collapsed via
  /// scroll position (see [handleScroll]).
  ///
  /// The title tracks rubber-band overscroll while the finger is down. During
  /// the spring-back it follows the same physical scroll progress to the
  /// endpoint chosen from the visual half-cut threshold, so the title never
  /// switches to a separate, faster animation clock.
  bool _handleShortPageScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    final limit = state.heightOffsetLimit;
    if (!limit.isFinite || limit >= 0) {
      _syncOffsetToPosition(metrics);
      return false;
    }

    final isActiveUserDrag =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;
    final isUserDragStart =
        notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final isBallisticUpdate =
        notification is ScrollUpdateNotification &&
        notification.dragDetails == null;

    // A new finger gesture takes ownership from an in-progress rubber-band
    // synchronization. Ballistic ScrollStartNotification has no drag details,
    // so it does not accidentally cancel the title's spring-following state.
    if (isUserDragStart) {
      _clearShortPageSpringBack();
      _shortPageLastUserDragPixels = null;
    }

    if (isActiveUserDrag) {
      // The first ballistic notification may already have advanced one or
      // more frames beyond the finger's release position. Capture the last
      // user-controlled sample so the title and body start their transition
      // from the same physical point.
      _shortPageLastUserDragPixels = metrics.pixels;
    }

    // The framework only sends the final ScrollEndNotification after a
    // ballistic overscroll spring has finished. Capture the release state on
    // the first ballistic update instead of waiting for that final event;
    // otherwise the title remains frozen during the spring and jumps to its
    // endpoint on the last frame.
    if (isBallisticUpdate &&
        _shortPageSpringReleasePixels == null &&
        (metrics.pixels < metrics.minScrollExtent - 0.5 ||
            metrics.pixels > metrics.maxScrollExtent + 0.5)) {
      final releaseTitleOffset = state.heightOffset;
      final textHeight = state.largeTitleTextHeight;
      final snapThreshold = textHeight > 0 ? textHeight * 0.5 : -limit * 0.5;
      final targetTitleOffset = -releaseTitleOffset >= snapThreshold
          ? limit
          : 0.0;
      final targetPixels = metrics.pixels > metrics.maxScrollExtent
          ? metrics.maxScrollExtent
          : metrics.minScrollExtent;
      _beginShortPageSpringBack(
        releasePixels: _shortPageLastUserDragPixels ?? metrics.pixels,
        targetPixels: targetPixels,
        releaseTitleOffset: releaseTitleOffset,
        targetTitleOffset: targetTitleOffset,
      );
    }

    // During the list's ballistic return, advance the title using the actual
    // scroll position. This makes the large-title endpoint land in the same
    // frame as the rubber-band instead of completing in a separate, faster
    // jump.
    if (!isActiveUserDrag &&
        _shortPageSpringReleasePixels != null &&
        _shortPageSpringTargetPixels != null) {
      _syncShortPageTitleToSpring(metrics);
      return false;
    }

    if (notification is ScrollEndNotification) {
      // If no ballistic frame was emitted (for example, a synthetic
      // notification in a test), use the current offset to choose the nearer
      // endpoint based on the large title text's visual cut position.
      final scrolled = -state.heightOffset;
      final textHeight = state.largeTitleTextHeight;
      final snapThreshold = textHeight > 0 ? textHeight * 0.5 : -limit * 0.5;
      final targetTitleOffset = scrolled >= snapThreshold ? limit : 0.0;
      final isOutOfRange =
          metrics.pixels < metrics.minScrollExtent - 0.5 ||
          metrics.pixels > metrics.maxScrollExtent + 0.5;

      if (isOutOfRange &&
          (targetTitleOffset - state.heightOffset).abs() > 0.5) {
        final targetPixels = metrics.pixels > metrics.maxScrollExtent
            ? metrics.maxScrollExtent
            : metrics.minScrollExtent;
        final springDistance = metrics.pixels - targetPixels;
        if (springDistance.abs() > 0.5) {
          _beginShortPageSpringBack(
            releasePixels: metrics.pixels,
            targetPixels: targetPixels,
            releaseTitleOffset: state.heightOffset,
            targetTitleOffset: targetTitleOffset,
          );
          state.contentOffset = metrics.pixels;
          return false;
        }
      }

      final position = _positionFromNotification(notification);
      if (position != null &&
          position.hasPixels &&
          (position.pixels - metrics.minScrollExtent).abs() > 0.5 &&
          (targetTitleOffset - state.heightOffset).abs() > 0.5) {
        // A short page can finish a gesture inside its normal scroll range,
        // without producing an overscroll spring. Drive that return through
        // the same scroll-position-based transition instead of changing the
        // title to its endpoint in one notification.
        _beginShortPageSpringBack(
          releasePixels: position.pixels,
          targetPixels: metrics.minScrollExtent,
          releaseTitleOffset: state.heightOffset,
          targetTitleOffset: targetTitleOffset,
        );
        _animateShortPageToEndpoint(position, metrics.minScrollExtent);
        state.contentOffset = metrics.pixels;
        return false;
      }

      state.heightOffset = targetTitleOffset;
      _clearShortPageSpringBack();
      state.contentOffset = metrics.pixels;
      return false;
    }

    final scrolled = metrics.pixels - metrics.minScrollExtent;
    final desired = scrolled <= 0 ? 0.0 : -scrolled;
    final wouldExpand = desired > state.heightOffset + 0.01;

    if (wouldExpand && !isActiveUserDrag) {
      // Spring-back / fling: keep the collapsed title frozen (no rebound).
      state.contentOffset = metrics.pixels;
      return false;
    }

    state.heightOffset = desired;
    state.contentOffset = metrics.pixels;
    return false;
  }

  void _beginShortPageSpringBack({
    required double releasePixels,
    required double targetPixels,
    required double releaseTitleOffset,
    required double targetTitleOffset,
  }) {
    if (_shortPageSpringReleasePixels != null ||
        _shortPageSpringTargetPixels != null ||
        (releasePixels - targetPixels).abs() <= 0.5) {
      return;
    }
    _shortPageSpringReleasePixels = releasePixels;
    _shortPageSpringTargetPixels = targetPixels;
    _shortPageReleaseTitleOffset = releaseTitleOffset;
    _shortPageTargetTitleOffset = targetTitleOffset;
  }

  void _clearShortPageSpringBack() {
    _shortPageSpringReleasePixels = null;
    _shortPageSpringTargetPixels = null;
    _shortPageReleaseTitleOffset = 0;
    _shortPageTargetTitleOffset = 0;
    _shortPageLastUserDragPixels = null;
  }

  void _animateShortPageToEndpoint(
    ScrollPosition position,
    double targetPixels,
  ) {
    final clampedTarget = targetPixels.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    scheduleMicrotask(() {
      if (!position.hasPixels) {
        _clearShortPageSpringBack();
        return;
      }
      position
          .animateTo(clampedTarget, duration: snapDuration, curve: snapCurve)
          .whenComplete(() {
            if (position.hasPixels &&
                _shortPageSpringReleasePixels != null &&
                _shortPageSpringTargetPixels != null) {
              _syncShortPageTitleToSpring(position);
            }
          });
    });
  }

  void _syncShortPageTitleToSpring(ScrollMetrics metrics) {
    final releasePixels = _shortPageSpringReleasePixels;
    final targetPixels = _shortPageSpringTargetPixels;
    if (releasePixels == null || targetPixels == null) {
      return;
    }

    final totalDistance = releasePixels - targetPixels;
    if (totalDistance.abs() <= 0.01) {
      state.heightOffset = _shortPageTargetTitleOffset;
      state.contentOffset = metrics.pixels;
      _clearShortPageSpringBack();
      return;
    }

    // `remainingFraction` follows the physical spring from release (1) to
    // the in-range edge (0). Both top and bottom overscroll use the same
    // signed ratio, so no direction-specific timing curve is needed.
    final springProgress = shortPageSpringProgressForPixels(metrics.pixels)!;
    final titleOffset =
        _shortPageReleaseTitleOffset +
        (_shortPageTargetTitleOffset - _shortPageReleaseTitleOffset) *
            springProgress;
    state.heightOffset = titleOffset;
    state.contentOffset = metrics.pixels;

    final remainingFraction = 1.0 - springProgress;
    if (remainingFraction <= 0.001 ||
        (metrics.pixels - targetPixels).abs() <= 0.5) {
      state.heightOffset = _shortPageTargetTitleOffset;
      _clearShortPageSpringBack();
    }
  }

  ScrollPosition? _positionFromNotification(ScrollNotification notification) {
    if (notification.metrics is ScrollPosition) {
      return notification.metrics as ScrollPosition;
    }
    final notificationContext = notification.context;
    return notificationContext == null
        ? null
        : Scrollable.maybeOf(notificationContext)?.position;
  }

  /// When true, the user released their finger while the list was in
  /// overscroll (pixels > maxScrollExtent). During the subsequent spring-back
  /// animation the title must stay frozen — otherwise _syncOffsetToPosition
  /// would gradually re-expand it as pixels decrease back toward
  /// maxScrollExtent, which the user perceives as "title snaps back to big
  /// after release".
  bool _frozenDuringOverscrollSpringBack = false;

  /// When true, the title is in small (collapsed) state and must stay that way
  /// until the user scrolls all the way back to the top. This prevents the
  /// title from flickering between big/small while reading mid-page content.
  bool _smallTitleLocked = false;

  void _syncOffsetToPosition(ScrollMetrics metrics) {
    final limit = state.heightOffsetLimit;
    if (!limit.isFinite) {
      return;
    }
    if (limit == 0) {
      state.heightOffset = 0;
      return;
    }
    // Scroll up (pixels > min) → offset < 0 (collapse).
    // Scroll down / overscroll (pixels <= min) → offset = 0 (expand).
    // Setter clamps to [heightOffsetLimit, 0].
    final scrolled = metrics.pixels - metrics.minScrollExtent;
    final newOffset = scrolled <= 0 ? 0.0 : -scrolled;
    state.heightOffset = newOffset;
    state.contentOffset = metrics.pixels;
  }

  /// On release, snap to nearest endpoint. The decision is based on the large
  /// title text's visual cut position (not the scroll fraction), so releasing
  /// with the text cut in half always snaps to the side that leaves the
  /// majority of the text visible — matching the feel of a physical "cut in
  /// half" gesture.
  ///
  /// - Upper half of the text visible → snap to expanded (scroll back to top).
  /// - Lower half of the text visible → snap to collapsed (park under the bar).
  void _snapToNearestEndpoint(ScrollEndNotification notification) {
    final limit = state.heightOffsetLimit;
    if (!limit.isFinite || limit >= 0) {
      return;
    }
    final scrolled = -state.heightOffset; // pixels the title has been pushed up
    final textHeight = state.largeTitleTextHeight;
    final snapThreshold = textHeight > 0 ? textHeight * 0.5 : -limit * 0.5;
    // Already parked at an end — nothing to do.
    if (scrolled <= 0.5 || scrolled >= -limit - 0.5) {
      return;
    }

    final metrics = notification.metrics;
    final expansion = -limit;
    final minExtent = metrics.minScrollExtent;
    // Text is less than half cut → snap back to expanded (top).
    // Text is more than half cut → snap to collapsed AND tighten: keep
    // scrolling until the first content row sits flush under the small-title
    // band (1px shy of the frost threshold — see collapseSnapRestTighten).
    final collapseTarget =
        minExtent +
        expansion +
        HyperosCollapsibleTopAppBarDefaults.collapseSnapRestTighten;
    final targetPixels = scrolled < snapThreshold ? minExtent : collapseTarget;

    // notification.metrics is almost always a ScrollPosition for real scroll
    // notifications — use it directly instead of Scrollable.maybeOf(context),
    // which fails because the notification's context IS the Scrollable itself,
    // and maybeOf only searches ancestors (never the widget itself).
    final ScrollPosition? position;
    if (notification.metrics is ScrollPosition) {
      position = notification.metrics as ScrollPosition;
    } else {
      final notificationContext = notification.context;
      position = notificationContext == null
          ? null
          : Scrollable.maybeOf(notificationContext)?.position;
    }
    if (position == null || !position.hasPixels) {
      return;
    }
    if ((position.pixels - targetPixels).abs() < 0.5) {
      return;
    }

    _snapInProgress = true;
    final pos = position; // local non-null capture for the closure
    // Do NOT call animateTo synchronously here: ScrollEndNotification is
    // dispatched from inside ScrollPosition.beginActivity() *before* the new
    // idle activity is assigned and the old one disposed. An activity started
    // reentrantly at this point is immediately disposed by the outer
    // beginActivity, so the snap animation dies before its first frame (the
    // "release mid-collapse parks anywhere" bug). Defer to a microtask so the
    // notification dispatch and activity swap fully unwind first.
    scheduleMicrotask(() {
      if (!pos.hasPixels) {
        _snapInProgress = false;
        onSnapCompleted?.call();
        return;
      }
      pos
          .animateTo(
            targetPixels.clamp(pos.minScrollExtent, pos.maxScrollExtent),
            duration: snapDuration,
            curve: snapCurve,
          )
          .whenComplete(() {
            _snapInProgress = false;
            _snapCompletedAt = DateTime.now();
            if (pos.hasPixels) {
              _syncOffsetToPosition(pos);
            }
            onSnapCompleted?.call();
          });
    });
  }
}

/// No-op listenable used when a collapsible bar has no scroll behavior.
class _HyperosNoopListenable implements Listenable {
  const _HyperosNoopListenable._();

  static const instance = _HyperosNoopListenable._();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Bridges scroll notifications to [HyperosExitUntilCollapsedScrollBehavior].
class HyperosCollapsibleScrollListener extends StatelessWidget {
  const HyperosCollapsibleScrollListener({
    super.key,
    required this.behavior,
    required this.child,
  });

  final HyperosExitUntilCollapsedScrollBehavior behavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: behavior.handleScroll,
      child: child,
    );
  }
}

/// Convenience factory matching Miuix `miuixScrollBehavior()`.
HyperosExitUntilCollapsedScrollBehavior hyperosCollapsibleScrollBehavior({
  HyperosCollapsibleTopAppBarState? state,
  bool Function()? canScroll,
  bool requireOuterScrollable = true,
}) {
  return HyperosExitUntilCollapsedScrollBehavior(
    state: state,
    canScroll: canScroll,
    requireOuterScrollable: requireOuterScrollable,
  );
}

/// Pulls plain text out of a page [title] widget for collapsible bars.
///
/// Returns null for complex titles (e.g. custom profile switchers) so the
/// page shell can fall back to the nested frosted header.
String? hyperosExtractPageTitleText(Widget title) {
  if (title is Text) {
    return title.data;
  }
  return null;
}

/// Large-title collapsible top app bar for the HyperOS kit.
///
/// Port of Compose Miuix `TopAppBar` (`TopAppBarLayout`):
/// - Expanded: large left-aligned title (`title1` 32sp) only
/// - Collapsed: smaller centered title (`title3` 20sp) only
/// - Two independent layers: the large title lives in a lower ClipRect that
///   starts at the band's bottom edge, rides up with the collapse offset and
///   is clipped at that edge — it never enters the band, regardless of band
///   color. It greys/fades from the first collapse pixel
///   (`alpha = 1 - fraction * 3`, upstream formula) and is gone before the
///   small title shows.
/// - Small title starts revealing at 1/3 collapse; its opacity and 20px rise
///   are derived from the same collapse progress as the large title, so it
///   never introduces a second animation clock during a spring-back.
/// - Release mid-range: list snaps to expanded or collapsed (see scroll behavior)
///
/// Without [scrollBehavior] the bar stays fully expanded (static large title).
/// Pair with [HyperosCollapsibleScrollListener] on the body scroll view.
///
/// [HyperosSubpage] / [HyperosRootPage] use this automatically when
/// `overlayHeader` is true and the page title is plain [Text].
class HyperosCollapsibleTopAppBar extends StatefulWidget {
  const HyperosCollapsibleTopAppBar({
    super.key,
    required this.title,
    this.color,
    this.titleColor,
    this.largeTitle,
    this.largeTitleColor,
    this.subtitle = '',
    this.subtitleColor,
    this.navigationIcon,
    this.actions,
    this.scrollBehavior,
    this.defaultWindowInsetsPadding = true,
    this.titlePadding = HyperosCollapsibleTopAppBarDefaults.titlePadding,
    this.navigationIconPadding =
        HyperosCollapsibleTopAppBarDefaults.navigationIconPadding,
    this.actionIconPadding =
        HyperosCollapsibleTopAppBarDefaults.actionIconPadding,
    this.bottomContent,
    this.blurred = false,
    this.blurRadius = 24,
    this.blurTintAlpha = 0.55,
  });

  final String title;
  final Color? color;
  final Color? titleColor;

  /// Expanded large title text; defaults to [title].
  final String? largeTitle;
  final Color? largeTitleColor;

  final String subtitle;
  final Color? subtitleColor;

  final Widget? navigationIcon;
  final List<Widget>? actions;
  final HyperosCollapsibleScrollBehavior? scrollBehavior;

  /// Apply horizontal [MediaQuery] padding (display cutout / system bars).
  final bool defaultWindowInsetsPadding;

  final double titlePadding;
  final double navigationIconPadding;
  final double actionIconPadding;
  final Widget? bottomContent;

  /// Live [BackdropFilter] frosted background (optional enhancement).
  final bool blurred;
  final double blurRadius;
  final double blurTintAlpha;

  @override
  State<HyperosCollapsibleTopAppBar> createState() =>
      _HyperosCollapsibleTopAppBarState();
}

class _HyperosCollapsibleTopAppBarState
    extends State<HyperosCollapsibleTopAppBar> {
  final GlobalKey _largeTitleKey = GlobalKey();
  final GlobalKey _navigationIconKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();
  final GlobalKey _subtitleKey = GlobalKey();
  final GlobalKey _bottomContentKey = GlobalKey();

  Size? _largeTitleSize;
  Size? _navigationIconSize;
  Size? _actionsSize;
  Size? _subtitleSize;
  Size? _bottomContentSize;
  bool _measured = false;

  String? _measuredTitle;
  double _largeTitleTextHeight = 0;
  double _smallTitleTextHeight = 0;
  double _smallTitleTextWidth = 0;

  @override
  void didUpdateWidget(covariant HyperosCollapsibleTopAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.subtitle != widget.subtitle ||
        oldWidget.largeTitle != widget.largeTitle ||
        oldWidget.navigationIcon != widget.navigationIcon ||
        oldWidget.actions != widget.actions ||
        oldWidget.bottomContent != widget.bottomContent) {
      _measured = false;
    }
  }

  void _scheduleMeasure() {
    if (_measured) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      var didMeasure = false;
      void measure(GlobalKey key, Size? current, ValueSetter<Size> setter) {
        final context = key.currentContext;
        if (context == null) {
          return;
        }
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.size != current) {
          setter(box.size);
          didMeasure = true;
        }
      }

      measure(
        _largeTitleKey,
        _largeTitleSize,
        (size) => _largeTitleSize = size,
      );
      measure(
        _navigationIconKey,
        _navigationIconSize,
        (size) => _navigationIconSize = size,
      );
      measure(_actionsKey, _actionsSize, (size) => _actionsSize = size);
      measure(_subtitleKey, _subtitleSize, (size) => _subtitleSize = size);
      measure(
        _bottomContentKey,
        _bottomContentSize,
        (size) => _bottomContentSize = size,
      );
      if (mounted && didMeasure) {
        _measured = true;
        setState(() {});
      }
    });
  }

  /// Compensates for [MiuixFontWeightScope]'s font weight adjustment.
  /// When the system has a non-zero fontWeightAdjustment, hardcoded w400/w500
  /// raw [TextStyle]s get the system delta applied on top and appear bold,
  /// while MiuixTheme-based text styles are already compensated.  Reading the
  /// adjustment from [MiuixTheme] and subtracting it keeps the titles visually
  /// consistent with the rest of the page.
  int get _fontWeightDelta =>
      MiuixTheme.maybeOf(context)?.fontWeightAdjustment ?? 0;

  TextStyle _largeTitleStyle(Color color) {
    return TextStyle(
      fontSize: HyperosCollapsibleTopAppBarDefaults.largeTitleFontSize,
      fontWeight: FontWeight((400 - _fontWeightDelta).clamp(100, 900)),
      color: color,
      height: 1.2,
    );
  }

  TextStyle _smallTitleStyle(Color color) {
    return TextStyle(
      fontSize: HyperosCollapsibleTopAppBarDefaults.smallTitleFontSize,
      fontWeight: FontWeight((500 - _fontWeightDelta).clamp(100, 900)),
      color: color,
      height: 1.2,
    );
  }

  TextStyle _subtitleStyle(Color color) {
    return TextStyle(
      fontSize: HyperosCollapsibleTopAppBarDefaults.subtitleFontSize,
      fontWeight: FontWeight((400 - _fontWeightDelta).clamp(100, 900)),
      color: color,
      height: 1.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.color ?? HyperosColors.scaffoldBackground(context);
    final titleColor = widget.titleColor ?? HyperosColors.primaryText(context);
    final largeTitleColor =
        widget.largeTitleColor ?? HyperosColors.primaryText(context);
    final subtitleColor =
        widget.subtitleColor ?? HyperosColors.secondaryText(context);

    final behavior = widget.scrollBehavior;
    final largeTitleText = widget.largeTitle ?? widget.title;
    final hasSubtitle = widget.subtitle.isNotEmpty;
    const collapsedHeight = HyperosCollapsibleTopAppBarDefaults.collapsedHeight;

    final largeTitleHeight = _largeTitleSize?.height ?? 0;
    final expansion = largeTitleHeight.clamp(0.0, double.infinity);

    final largeTitleStyle = _largeTitleStyle(largeTitleColor);
    final smallTitleStyle = _smallTitleStyle(titleColor);

    if (_measuredTitle != widget.title) {
      _measuredTitle = widget.title;
      final largePainter = TextPainter(
        text: TextSpan(text: widget.title, style: largeTitleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);
      _largeTitleTextHeight = largePainter.height;
      largePainter.dispose();

      final smallPainter = TextPainter(
        text: TextSpan(text: widget.title, style: smallTitleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);
      _smallTitleTextHeight = smallPainter.height;
      _smallTitleTextWidth = smallPainter.width;
      smallPainter.dispose();
    }

    final verticalCenter = collapsedHeight / 2;
    final smallSubtitleHeight = hasSubtitle
        ? (_subtitleSize?.height ?? 0.0)
        : 0.0;
    final expandedBottomPadding = hasSubtitle
        ? HyperosCollapsibleTopAppBarDefaults.subtitleBottomPadding
        : HyperosCollapsibleTopAppBarDefaults.largeTitleBottomPadding;
    final bottomContentHeight = _bottomContentSize?.height ?? 0.0;

    _scheduleMeasure();

    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = widget.defaultWindowInsetsPadding
        ? mediaQuery.padding.horizontal
        : 0.0;

    final navigationWidth = _navigationIconSize?.width ?? 0.0;
    final navigationHeight = _navigationIconSize?.height ?? 0.0;
    final actionsWidth = _actionsSize?.width ?? 0.0;
    final actionsHeight = _actionsSize?.height ?? 0.0;
    final contentWidth = mediaQuery.size.width - horizontalPadding * 2;

    Widget animatedBody = AnimatedBuilder(
      animation: behavior?.state ?? _HyperosNoopListenable.instance,
      builder: (context, _) {
        final collapseFraction = behavior?.state.collapsedFraction ?? 0.0;
        final heightOffset = behavior?.state.heightOffset ?? 0.0;
        final effectiveOffset = heightOffset.isFinite ? heightOffset : 0.0;

        final currentExpansion = largeTitleHeight.clamp(0.0, double.infinity);
        final barCollapseFraction = currentExpansion > 0
            ? (effectiveOffset.abs() / currentExpansion).clamp(0.0, 1.0)
            : 0.0;
        final barHeight = currentExpansion > 0
            ? collapsedHeight + currentExpansion * (1 - barCollapseFraction)
            : collapsedHeight;

        final largeLeft = widget.titlePadding;
        final smallAvailableWidth = math.max(
          0.0,
          contentWidth - navigationWidth - actionsWidth,
        );
        final smallTitleWidth = math.min(
          _smallTitleTextWidth,
          smallAvailableWidth,
        );
        var smallLeft = (contentWidth - smallTitleWidth) / 2;
        if (smallLeft < navigationWidth) {
          smallLeft = navigationWidth;
        } else if (smallLeft + smallTitleWidth > contentWidth - actionsWidth) {
          smallLeft = contentWidth - actionsWidth - smallTitleWidth;
        }
        smallLeft = smallLeft.clamp(
          0.0,
          math.max(0.0, contentWidth - smallTitleWidth),
        );
        final smallCenterY = verticalCenter;
        // Large title rides up with the collapse offset. Its layer starts at
        // the band's bottom edge (top = collapsedHeight), so moving up clips
        // the glyph at that edge: it is occluded by the band boundary itself
        // and can never render inside the band, regardless of band color.
        final largeTitleTop = effectiveOffset;
        final smallTitleTop = smallCenterY - _smallTitleTextHeight / 2;
        // Upstream Miuix: `alpha = 1 - (collapsedFraction * 3)` — the large
        // title starts greying/fading on the very first collapse pixel and is
        // fully gone at 1/3 collapse (about half covered), before the small
        // title shows.
        final largeFadeT =
            (collapseFraction *
                    HyperosCollapsibleTopAppBarDefaults.largeTitleFadeRate)
                .clamp(0.0, 1.0);
        final largeOpacity = 1.0 - largeFadeT;
        final smallOpacity =
            HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(
              collapseFraction,
            );
        final smallTitleRise =
            HyperosCollapsibleTopAppBarDefaults.smallTitleRisePx *
            (1.0 - smallOpacity);
        // Greying starts immediately with the first collapse movement.
        final largeInk = Color.lerp(
          largeTitleColor,
          HyperosColors.secondaryText(context),
          largeFadeT,
        )!;
        final largeTitleMaxWidth = math.max(
          0.0,
          contentWidth - largeLeft - widget.titlePadding,
        );
        final smallTitleMaxWidth = math.max(
          0.0,
          contentWidth - smallLeft - actionsWidth,
        );

        // Subtitle rides with the large title (same layer, same clipping).
        final currentSubtitleTop = hasSubtitle
            ? _largeTitleTextHeight + 2.0 + effectiveOffset
            : 0.0;
        final currentSubtitleLeft = largeLeft;
        final currentSubtitleMaxWidth = math.max(
          0.0,
          contentWidth - currentSubtitleLeft - widget.titlePadding,
        );

        final smallTitleBottomForLayout =
            verticalCenter + _smallTitleTextHeight / 2;
        final contentTop = math.max(
          barHeight + expandedBottomPadding,
          smallTitleBottomForLayout +
              (hasSubtitle ? smallSubtitleHeight + 2.0 : 0.0) +
              expandedBottomPadding,
        );
        final layoutHeight = contentTop + bottomContentHeight;

        return SizedBox(
          width: contentWidth,
          height: layoutHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // === Lower layer: large title, strictly below the band ===
              // Starts at the band's bottom edge so the rising glyph is
              // clipped there — two independent layers; the large title can
              // never enter the band (works with transparent band colors).
              Positioned(
                top: collapsedHeight,
                left: 0,
                right: 0,
                height:
                    _largeTitleTextHeight +
                    (hasSubtitle ? smallSubtitleHeight + 2.0 : 0.0),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        left: largeLeft,
                        top: largeTitleTop,
                        child: Opacity(
                          opacity: largeOpacity,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: largeTitleMaxWidth,
                            ),
                            child: Text(
                              largeTitleText,
                              style: largeTitleStyle.copyWith(color: largeInk),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (hasSubtitle)
                        Positioned(
                          left: currentSubtitleLeft,
                          top: currentSubtitleTop,
                          child: Opacity(
                            opacity: largeOpacity,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: currentSubtitleMaxWidth,
                              ),
                              child: Text(
                                widget.subtitle,
                                style: _subtitleStyle(subtitleColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // === Upper layer: opaque band with small title + chrome ===
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: collapsedHeight,
                child: ColoredBox(
                  color: backgroundColor,
                  child: Stack(
                    children: [
                      if (smallOpacity > 0.001)
                        Positioned(
                          left: smallLeft,
                          top: smallTitleTop + smallTitleRise,
                          child: Opacity(
                            opacity: smallOpacity,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: smallTitleMaxWidth,
                              ),
                              child: Text(
                                widget.title,
                                style: smallTitleStyle.copyWith(
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      if (widget.navigationIcon != null)
                        Positioned(
                          left: widget.navigationIconPadding,
                          top: verticalCenter - navigationHeight / 2,
                          child: KeyedSubtree(
                            key: _navigationIconKey,
                            child: widget.navigationIcon!,
                          ),
                        ),
                      if (widget.actions?.isNotEmpty ?? false)
                        Positioned(
                          right: widget.actionIconPadding,
                          top: verticalCenter - actionsHeight / 2,
                          child: Row(
                            key: _actionsKey,
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.bottomContent != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: contentTop,
                  child: widget.bottomContent!,
                ),
            ],
          ),
        );
      },
    );

    // Offstage measurer for expansion / leading / trailing sizes.
    final measurer = Offstage(
      offstage: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
            ),
            child: Padding(
              key: _largeTitleKey,
              padding: EdgeInsets.symmetric(horizontal: widget.titlePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    largeTitleText,
                    style: largeTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasSubtitle)
                    Text(widget.subtitle, style: _subtitleStyle(subtitleColor)),
                ],
              ),
            ),
          ),
          // Navigation icon and actions are measured from their live instances
          // (see [_navigationIconKey] / [_actionsKey] above): remounting the
          // caller's widgets offstage would duplicate any GlobalKey they carry.
          Padding(
            key: _subtitleKey,
            padding: EdgeInsets.zero,
            child: Text(widget.subtitle, style: _subtitleStyle(subtitleColor)),
          ),
          if (widget.bottomContent != null)
            KeyedSubtree(key: _bottomContentKey, child: widget.bottomContent!),
        ],
      ),
    );

    // Publish expansion as heightOffsetLimit for the scroll behavior.
    if (behavior != null) {
      final limit = -expansion;
      if (behavior.state.heightOffsetLimit != limit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            behavior.state.heightOffsetLimit = limit;
          }
        });
      }
      // Sync the large-title text height so the snap threshold can detect
      // "cut in half" by the visual text position, not the total widget height.
      if (behavior.state.largeTitleTextHeight != _largeTitleTextHeight) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            behavior.state.largeTitleTextHeight = _largeTitleTextHeight;
          }
        });
      }
    }

    final foreground = AnnotatedRegion<SystemUiOverlayStyle>(
      value: HyperosColors.systemOverlayForBackground(backgroundColor),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Stack(
            children: [
              ClipRect(child: animatedBody),
              measurer,
            ],
          ),
        ),
      ),
    );

    if (!widget.blurred) {
      return Material(color: backgroundColor, child: foreground);
    }

    final sigma = widget.blurRadius.clamp(0.0, 150.0) * 0.45;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: ColoredBox(
                  color: backgroundColor.withValues(
                    alpha: widget.blurTintAlpha,
                  ),
                ),
              ),
            ),
          ),
          foreground,
        ],
      ),
    );
  }
}
