// 从 timetable_screen.dart 拆出的首页滚动/下拉物理与手势探测（2026-10-19，行为零变化）。

import 'package:flutter/material.dart';

/// 首页纵向滚动体的 physics：下拉开着时把用户位移整个吃掉。
///
/// 「回拉取消」的手感要求：下拉还没收回时手指上移应该是**把下拉收回去**，
/// 而不是让列表跟着滚——两者同时发生，读起来就是"我想取消，页面却被滚上去
/// 了"。所以下拉开着期间 `applyPhysicsToUserOffset` 返回 0（列表冻住），等
/// 下拉收到 0 再恢复 1:1，同一次手势接着滚是自然的。
///
/// 必须**常驻安装**：`Scrollable._shouldUpdatePosition` 按 physics 的
/// runtimeType 判断要不要重建 ScrollPosition，运行中换类型会重建 position
/// 并当场终结手势。这里只让闭包读状态，类型的 runtimeType 恒定不变。
class TimetableHomePullFreezeScrollPhysics extends ClampingScrollPhysics {
  const TimetableHomePullFreezeScrollPhysics({required this.isFrozen, super.parent});

  /// 下拉是否还开着（开着就冻结纵向滚动）。
  final bool Function() isFrozen;

  @override
  TimetableHomePullFreezeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TimetableHomePullFreezeScrollPhysics(
      isFrozen: isFrozen,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isFrozen()) {
      return 0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}
/// Home timetable only: clamping scroll, no HyperOS rubber-band overscroll.
class TimetableHomeScrollBehavior extends ScrollBehavior {
  const TimetableHomeScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No Material stretch / glow — keep the grid hard-edged.
    return child;
  }
}

/// Vertical pull detector that yields to horizontal week paging.
///
/// Claims the gesture arena only after the drag is clearly more vertical than
/// horizontal, so left/right week swipes stay smooth.
class TimetableHomePullVerticalDragDetector extends StatefulWidget {
  const TimetableHomePullVerticalDragDetector({
    super.key,
    required this.child,
    required this.enabled,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<double> onPullUpdate;
  final VoidCallback onPullEnd;
  final VoidCallback onPullCancel;

  @override
  State<TimetableHomePullVerticalDragDetector> createState() =>
      _TimetableHomePullVerticalDragDetectorState();
}

class _TimetableHomePullVerticalDragDetectorState
    extends State<TimetableHomePullVerticalDragDetector> {
  double _accumulatedDx = 0;
  double _accumulatedDy = 0;
  bool _isTrackingVerticalPull = false;

  static const double _axisDecisionDistance = 10;

  void _resetTracking() {
    _accumulatedDx = 0;
    _accumulatedDy = 0;
    _isTrackingVerticalPull = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _resetTracking();
      },
      onPointerMove: (event) {
        final delta = event.delta;
        _accumulatedDx += delta.dx;
        _accumulatedDy += delta.dy;

        if (!_isTrackingVerticalPull) {
          final absDx = _accumulatedDx.abs();
          final absDy = _accumulatedDy.abs();
          if (absDx < _axisDecisionDistance && absDy < _axisDecisionDistance) {
            return;
          }
          // Prefer horizontal week paging when the gesture is not clearly vertical.
          if (absDy <= absDx * 1.15) {
            return;
          }
          _isTrackingVerticalPull = true;
        }

        if (_isTrackingVerticalPull) {
          widget.onPullUpdate(delta.dy);
        }
      },
      onPointerUp: (_) {
        if (_isTrackingVerticalPull) {
          widget.onPullEnd();
        } else {
          widget.onPullCancel();
        }
        _resetTracking();
      },
      onPointerCancel: (_) {
        if (_isTrackingVerticalPull) {
          widget.onPullCancel();
        }
        _resetTracking();
      },
      child: widget.child,
    );
  }
}
