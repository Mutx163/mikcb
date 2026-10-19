// 从 timetable_screen.dart 拆出的日视图翻页物理（2026-10-19，行为零变化）。
// 只依赖 Flutter 手势/物理类型，不读取页面状态。

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show VelocityTracker, kMinFlingVelocity;
import 'package:flutter/material.dart';

/// Per-pointer flick probe for the day pager. One instance per finger, so
/// overlapping touches can't corrupt each other's velocity read. Besides the
/// debug logging, the probe's displacement/duration feeds the rescue velocity
/// consumed by [TimetableDayPagerFlickRescuePhysics] when the framework tracker
/// starves (see that class for the failure mode).
class TimetableDayPagerFlickProbe {
  TimetableDayPagerFlickProbe(this.tracker, this.downTime, this.downPosition)
    : lastTime = downTime;

  final VelocityTracker tracker;
  final Duration downTime;
  final Offset downPosition;
  Duration lastTime;
  int samples = 1;
}

/// Day-pager snap physics with a raw-pointer fallback velocity.
///
/// Failure mode (captured in the `[DayPager]` logs): under frame jank Android
/// delivers batched touch moves once per vsync, so a 50–100ms flick can reach
/// Dart with fewer than the three samples VelocityTracker needs — the drag
/// then ends with zero velocity and the page snaps back even though the
/// finger travelled 100+px. When the incoming velocity is below the fling
/// threshold, this physics re-runs the standard PageScrollPhysics snap with
/// the probe's displacement/duration estimate instead of bouncing back.
///
/// Only effective with `pageSnapping: false`: PageView otherwise wraps its
/// own PageScrollPhysics *outside* whatever physics it is given and this
/// override would never be reached. The snap behaviour itself still comes
/// from the PageScrollPhysics superclass, so nothing else changes.
class TimetableDayPagerFlickRescuePhysics extends PageScrollPhysics {
  const TimetableDayPagerFlickRescuePhysics({
    required this.takeRescueVelocity,
    super.parent,
  });

  /// One-shot supplier of the scroll-space rescue velocity; 0 = none armed.
  final double Function() takeRescueVelocity;

  @override
  TimetableDayPagerFlickRescuePhysics applyTo(ScrollPhysics? ancestor) {
    return TimetableDayPagerFlickRescuePhysics(
      takeRescueVelocity: takeRescueVelocity,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    var effectiveVelocity = velocity;
    if (velocity.abs() < kMinFlingVelocity) {
      final rescue = takeRescueVelocity();
      if (rescue != 0) {
        if (kDebugMode) {
          debugPrint(
            '[DayPager] rescue: vx=${rescue.toStringAsFixed(1)} '
            '(drag reported ${velocity.toStringAsFixed(1)})',
          );
        }
        effectiveVelocity = rescue;
      }
    }
    return super.createBallisticSimulation(position, effectiveVelocity);
  }
}
