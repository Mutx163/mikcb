import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

typedef HyperosDurationScaler = Duration Function(int baseMilliseconds);

/// Bumped when [HyperosMotionPlatform] scalers change (e.g. after Android refresh).
final ValueNotifier<int> hyperosMotionRevision = ValueNotifier<int>(0);

void notifyHyperosMotionChanged() {
  // 先刷新长命控制器，再通知重建：顺序无所谓（重建读的是同一个 scaler），
  // 但放在这里意味着**任何**通知路径都自动带上控制器刷新，调用方不必记得
  // 多调一次。钩子装在 [HyperosMotionPlatform] 内部，见那边的说明。
  HyperosMotionPlatform.refreshBoundControllers();
  hyperosMotionRevision.value++;
}

/// App-wired motion values (set from [lib/ui/hyperos_motion_bridge.dart]).
abstract final class HyperosMotionPlatform {
  static HyperosDurationScaler durationScaler = _identityDurationScaler;

  static double displayCornerRadiusDp =
      HyperosMiuixNavigation.pageCornerRadiusFallback;

  static void Function(double speed)? onUserTransitionSpeedChanged;

  static Duration _identityDurationScaler(int baseMilliseconds) {
    return Duration(milliseconds: baseMilliseconds);
  }

  static Duration scaledDuration(int baseMilliseconds) {
    return durationScaler(baseMilliseconds);
  }

  static Duration get transitionDuration {
    return scaledDuration(HyperosMiuixNavigation.programmaticDurationMs);
  }

  static void applyUserTransitionSpeed(double speed) {
    final clamped = speed.clamp(0.5, 2.5);
    onUserTransitionSpeedChanged?.call(clamped);
  }

  // ── 长命动画控制器跟随速度（2026-10-20）───────────────────────────────
  //
  // 「页面转场速度」这个设置要覆盖**全应用所有动画**（用户口径 2026-10-20：
  // 「那个调节应该要覆盖整个软件所有的动画」）。但 `AnimationController.duration`
  // 是构造时写死的字段：控制器建好之后，用户中途把速度从 1.0 拖到 2.0，
  // 屏幕上正在用的那个控制器**不会**跟着变 —— 表现为「去设置里调完，回来动效
  // 还是原来的快慢，要杀进程才生效」。
  //
  // 短命控制器（弹层每次打开都新建）构造时读一次 [scaledDuration] 就够了；
  // 随页面常住的长命控制器（日视图展开、玻璃发光等）必须在这里登记基础毫秒数，
  // 速度变更时由 [refreshBoundControllers] 统一重新赋值。

  /// 控制器 → 基础毫秒数（速度 1.0 时的时长）。
  ///
  /// 用 [Expando] 而不是 `Map<AnimationController, int>`：Expando **不阻止**
  /// 控制器被 GC。控制器 dispose 后如果忘了 [unbindController]，Map 会把整个
  /// 控制器（连同它持有的 Ticker、回调、State 闭包）永远钉在内存里；Expando
  /// 没有这个风险，键被回收时条目自动消失。
  ///
  /// 代价是 Expando 不能遍历，所以同时维护一个 [WeakReference] 列表供
  /// [refreshBoundControllers] 扫描（死引用在扫描时顺手剔除）。
  static final Expando<int> _boundBaseMs = Expando<int>('hyperosBoundBaseMs');

  /// 登记过的控制器（弱引用），仅用于速度变更时遍历刷新。
  static final List<WeakReference<AnimationController>> _boundRefs =
      <WeakReference<AnimationController>>[];

  /// 登记 [controller] 的基础时长并立即按当前速度赋值；返回同一控制器便于链式。
  ///
  /// 登记是**弱引用**的，控制器被 GC 后条目自动消失、不需要强制配对
  /// [unbindController]。仍然建议在 `dispose()` 里调一下，让刷新列表更干净。
  static AnimationController bindController(
    AnimationController controller,
    int baseMilliseconds,
  ) {
    _boundBaseMs[controller] = baseMilliseconds;
    final alreadyTracked = _boundRefs.any((ref) => ref.target == controller);
    if (!alreadyTracked) {
      _boundRefs.add(WeakReference<AnimationController>(controller));
    }
    _applyBoundDuration(controller, baseMilliseconds);
    return controller;
  }

  /// 速度变更后刷新所有登记中的控制器。
  ///
  /// **正在播放的跳过**：改 duration 会让 `value` 与已走过的行程错位，画面
  /// 会跳一下。这类控制器在下一次 `forward()` 之前由调用方自己重新读一次
  /// [scaledDuration]（本仓的长命控制器都在 `forward` 前的 `_syncDuration`
  /// 里做），或等下一次速度变更。
  static void refreshBoundControllers() {
    // 顺带剔除已被 GC 的控制器，列表不会无限增长。
    _boundRefs.removeWhere((ref) => ref.target == null);
    for (final ref in List<WeakReference<AnimationController>>.of(_boundRefs)) {
      final controller = ref.target;
      if (controller == null) {
        continue;
      }
      final baseMs = _boundBaseMs[controller];
      if (baseMs == null) {
        continue;
      }
      _applyBoundDuration(controller, baseMs);
    }
  }

  static void _applyBoundDuration(AnimationController controller, int baseMs) {
    if (controller.isAnimating) {
      return;
    }
    controller.duration = scaledDuration(baseMs);
  }

  /// 摘除登记（可选：控制器被 GC 后条目本就会消失）。
  static void unbindController(AnimationController controller) {
    _boundBaseMs[controller] = null;
    _boundRefs.removeWhere((ref) => ref.target == controller);
  }

  /// 当前登记数，仅供测试断言「dispose 之后没有泄漏」。
  @visibleForTesting
  static int get debugBoundControllerCount {
    _boundRefs.removeWhere((ref) => ref.target == null);
    return _boundRefs.length;
  }

  @visibleForTesting
  static void debugClearBoundControllers() {
    for (final ref in _boundRefs) {
      final controller = ref.target;
      if (controller != null) {
        _boundBaseMs[controller] = null;
      }
    }
    _boundRefs.clear();
  }
}

/// 把「基础毫秒数」按当前动效速度换算成实际时长。
///
/// 全应用的动画时长统一走这里，写法：
/// ```dart
/// AnimatedContainer(duration: 180.scaledMs, …)
/// _controller = AnimationController(duration: 360.scaledMs, …)
/// Navigator.push(route) // 路由自己换算，不用管
/// ```
///
/// **禁止**在动画参数位直接写 `Duration(milliseconds: …)`：那样写死的时长
/// 不跟随「页面转场速度」设置。`test/architecture/animation_duration_guard_test.dart`
/// 会拦住新增的裸写法。
extension HyperosScaledMilliseconds on int {
  Duration get scaledMs => HyperosMotionPlatform.scaledDuration(this);
}

/// Snapshot passed through [HyperosMotionScope].
class HyperosMotionData {
  const HyperosMotionData({
    required this.durationScaler,
    this.displayCornerRadiusDp =
        HyperosMiuixNavigation.pageCornerRadiusFallback,
    this.onUserTransitionSpeedChanged,
  });

  final HyperosDurationScaler durationScaler;
  final double displayCornerRadiusDp;
  final ValueChanged<double>? onUserTransitionSpeedChanged;

  static HyperosMotionData fromPlatform() {
    return HyperosMotionData(
      durationScaler: HyperosMotionPlatform.durationScaler,
      displayCornerRadiusDp: HyperosMotionPlatform.displayCornerRadiusDp,
      onUserTransitionSpeedChanged: (speed) {
        HyperosMotionPlatform.onUserTransitionSpeedChanged?.call(
          speed.clamp(0.5, 2.5),
        );
      },
    );
  }

  Duration scaledDuration(int baseMilliseconds) {
    return durationScaler(baseMilliseconds);
  }

  void applyUserTransitionSpeed(double speed) {
    onUserTransitionSpeedChanged?.call(speed.clamp(0.5, 2.5));
  }
}

class HyperosMotionScope extends InheritedWidget {
  const HyperosMotionScope({
    required this.motion,
    required super.child,
    super.key,
  });

  final HyperosMotionData motion;

  static HyperosMotionData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HyperosMotionScope>();
    return scope?.motion ?? HyperosMotionData.fromPlatform();
  }

  @override
  bool updateShouldNotify(covariant HyperosMotionScope oldWidget) {
    return motion.displayCornerRadiusDp !=
            oldWidget.motion.displayCornerRadiusDp ||
        motion.durationScaler != oldWidget.motion.durationScaler;
  }
}

/// Rebuilds [HyperosMotionScope] when platform motion values change.
class HyperosMotionHost extends StatefulWidget {
  const HyperosMotionHost({required this.child, super.key});

  final Widget child;

  @override
  State<HyperosMotionHost> createState() => _HyperosMotionHostState();
}

class _HyperosMotionHostState extends State<HyperosMotionHost> {
  @override
  void initState() {
    super.initState();
    hyperosMotionRevision.addListener(_onMotionRevision);
  }

  @override
  void dispose() {
    hyperosMotionRevision.removeListener(_onMotionRevision);
    super.dispose();
  }

  void _onMotionRevision() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return HyperosMotionScope(
      motion: HyperosMotionData.fromPlatform(),
      child: widget.child,
    );
  }
}
