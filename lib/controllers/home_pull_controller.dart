import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../ui/hyperos/hyperos_home_pull.dart';

/// 首页下拉快捷导入的手势/弹簧/看门狗状态机（2026-10-20 从 `TimetableScreen`
/// State 搬出）。
///
/// 只持有下拉进度、冻结快照、指针登记与收尾弹簧；真正触发导入、触觉反馈与
/// 取消回调由 State 注入。所有状态变化 `notifyListeners()`，外层监听后重建。
class HomePullController extends ChangeNotifier {
  HomePullController({
    required TickerProvider vsync,
    required this.onTriggerImport,
    required this.onSelectionHaptic,
  }) {
    _spring = AnimationController.unbounded(vsync: vsync)
      ..addListener(_driveSettle);
  }

  static const double triggerDistance = HyperosHomePullPhysics.triggerDistance;
  static const double _maxDistance = HyperosHomePullPhysics.maxVisualDistance;
  static const double _dampingRange = HyperosHomePullPhysics.dampingRange;

  final Future<void> Function() onTriggerImport;
  final VoidCallback onSelectionHaptic;

  late final AnimationController _spring;
  double _touchDistance = 0;
  double _dragDistance = 0;
  bool _hapticArmed = true;
  bool _gestureStartedAtTop = false;
  bool _frozeScrollForEvent = false;
  bool _running = false;
  bool Function()? _cancel;
  int _settleGeneration = 0;
  final Set<int> _livePointers = <int>{};
  int? _primaryPointer;
  bool _disposed = false;

  double get dragDistance => _dragDistance;
  bool get isRunning => _running;
  bool get isFrozen => _frozeScrollForEvent;

  void resetFreeze() {
    if (_frozeScrollForEvent) {
      _frozeScrollForEvent = false;
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    // 冻结判定必须用**本事件开始时**的下拉状态：原始指针监听先于滚动体收到
    // 同一事件，用实时值的话，手指上移会先把下拉收到 0，紧接着滚动体查到的
    // 就是“下拉已关”→ 列表照滚。
    final open = _dragDistance > 0 || _touchDistance > 0;
    _frozeScrollForEvent = open;
    if (!open) {
      return;
    }
    updateDrag(event.delta.dy);
  }

  void updateDrag(double deltaDy) {
    if (_running) {
      return;
    }
    final atRest = _dragDistance <= 0.5 && _touchDistance <= 0.5;
    if (deltaDy <= 0 && atRest) {
      return;
    }
    // Finger takes over from any in-flight settle spring.
    if (_spring.isAnimating) {
      _settleGeneration++;
      _spring.stop();
    }
    if (deltaDy > 0) {
      _touchDistance = (_touchDistance + deltaDy).clamp(0.0, _dampingRange);
    } else {
      // Retract "feels immediate"; keep raw travel 1:1.
      _touchDistance = (_touchDistance + deltaDy).clamp(0.0, _dampingRange);
    }
    final nextVisual = HyperosHomePullPhysics.visualOffset(
      _touchDistance,
      _dampingRange,
    ).clamp(0.0, _maxDistance);
    const threshold = triggerDistance;
    final crossedUp = _dragDistance < threshold && nextVisual >= threshold;
    final reArmed = _dragDistance >= threshold && nextVisual < threshold * 0.88;
    if (reArmed) _hapticArmed = true;
    if (nextVisual == _dragDistance && !crossedUp) {
      return;
    }
    if (crossedUp && _hapticArmed) {
      _hapticArmed = false;
      onSelectionHaptic();
    }
    _dragDistance = nextVisual;
    notifyListeners();
  }

  void finishDrag() {
    final shouldTrigger = _dragDistance >= triggerDistance;
    settleTo(0);
    _hapticArmed = true;
    if (shouldTrigger) {
      unawaited(onTriggerImport());
    }
  }

  void cancelDrag() {
    settleTo(0);
    _hapticArmed = true;
  }

  /// 全局指针登记（[GestureBinding.pointerRouter] 的全局路由：同一事件先到
  /// 这里，再走命中派发）。只做两件事：登记 / 注销指针；最后一根手指离开
  /// 屏幕时错开这一轮派发做一次兜底收回。
  ///
  /// ⚠️ 兜底必须错开：正常路径的收尾（滚动到顶那条路的 `ScrollEndNotification`
  /// → [finishDrag] 里"够阈值就拉课表"的判定）就在同一批**同步**处理里。抢在
  /// 它前面收回会把那次触发吃掉（用户拉到阈值上方抬手，却什么都没发生）。
  /// 微任务排在事件派发结束之后，判定已经走完。
  void onGlobalPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _primaryPointer ??= event.pointer;
      _livePointers.add(event.pointer);
      return;
    }
    if (event is! PointerUpEvent && event is! PointerCancelEvent) {
      return;
    }
    final endedPrimary = _primaryPointer == event.pointer;
    if (endedPrimary) {
      _primaryPointer = null;
      // 发起这次下拉的手指结束就收尾；不能等第二根手指也离开。
      scheduleMicrotask(_retractOrphaned);
    }
    _livePointers.remove(event.pointer);
    if (_livePointers.isNotEmpty) {
      return;
    }
    scheduleMicrotask(_retractOrphaned);
  }

  void _retractOrphaned() {
    if (_disposed || _running) {
      return;
    }
    if (_dragDistance <= 0 && _touchDistance <= 0) {
      return;
    }
    settleTo(0);
  }

  // --- spring helpers (HyperOS critical-damped, period 0.4s) ---
  void _driveSettle() {
    if (_disposed) return;
    final v = _spring.value;
    _dragDistance = v.clamp(0.0, _maxDistance);
    _touchDistance = HyperosHomePullPhysics.touchForOffset(
      v,
      _dampingRange,
    ).clamp(0.0, _dampingRange);
    notifyListeners();
  }

  void settleTo(double target) {
    if (_disposed) return;
    final generation = ++_settleGeneration;
    _spring.value = _dragDistance;
    final sim = SpringSimulation(
      HyperosHomePullPhysics.spring,
      _spring.value,
      target,
      0,
    );
    // ignore: discarded_futures
    _spring
        .animateWith(sim)
        .then((_) {
          if (_disposed || generation != _settleGeneration) return;
          _dragDistance = target;
          _touchDistance = HyperosHomePullPhysics.touchForOffset(
            target,
            _dampingRange,
          );
          notifyListeners();
        })
        .catchError((Object _) {});
  }

  /// Clamping overscroll at the top of the week/day vertical scrollables.
  ///
  /// 只有「按下时就已经在顶部」的手势才累计下拉（[_gestureStartedAtTop]）：
  /// 滚回顶部的那一拖整段不算，需要到顶部后再拉一次。
  bool handleScrollNotification(ScrollNotification notification) {
    if (_running) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }
    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;

    if (notification is ScrollStartNotification) {
      _gestureStartedAtTop = notification.dragDetails != null && atTop;
      return false;
    }

    // While the pull affordance is open, upward content scroll retracts it.
    //
    // Deliberately does *not* try to undo the scroll: `ScrollPosition.correctBy`
    // is only valid from the layout pass (`applyContentDimensions`), and calling
    // it from a notification callback trips assertions / causes scroll jitter.
    if (_dragDistance > 0 && notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0.0;
      if (scrollDelta > 0) {
        updateDrag(-scrollDelta);
        return false;
      }
    }

    if (notification is OverscrollNotification &&
        atTop &&
        _gestureStartedAtTop) {
      // Negative overscroll = past the leading edge (top) while pulling down.
      if (notification.overscroll < 0) {
        updateDrag(-notification.overscroll);
      } else if (notification.overscroll > 0 && _dragDistance > 0) {
        // Positive overscroll at top while pull is open: treat as retract.
        updateDrag(-notification.overscroll);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      _gestureStartedAtTop = false;
      if (_dragDistance > 0) {
        finishDrag();
        return false;
      }
    }

    return false;
  }

  bool cancelImport() {
    final cancel = _cancel;
    if (cancel == null) {
      return false;
    }
    // 已经进入实际写入阶段时，底层必须先完成并报告真实结果，不能把
    // “取消”按钮变成一个会撒谎的即时返回。
    if (!cancel()) {
      return false;
    }
    _running = false;
    _cancel = null;
    notifyListeners();
    return true;
  }

  void setCancel(bool Function() cancel) {
    if (_disposed) return;
    _cancel = cancel;
    notifyListeners();
  }

  void beginImport() {
    _settleGeneration++;
    _spring.stop();
    _hapticArmed = true;
    _touchDistance = 0;
    _running = true;
    _dragDistance = 0;
    _cancel = null;
    notifyListeners();
  }

  void endImport() {
    if (_disposed) return;
    _running = false;
    _cancel = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // 与旧 State.dispose 同口径：页面销毁时先取消在跑的快捷导入会话，
    // 否则底层 2 分钟会话看门狗会挂到测试/进程退出之后。
    final cancel = _cancel;
    _cancel = null;
    _running = false;
    if (cancel != null) {
      cancel();
    }
    _disposed = true;
    _spring.dispose();
    super.dispose();
  }
}
