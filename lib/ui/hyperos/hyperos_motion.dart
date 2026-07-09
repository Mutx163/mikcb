import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

typedef HyperosDurationScaler = Duration Function(int baseMilliseconds);

/// Bumped when [HyperosMotionPlatform] scalers change (e.g. after Android refresh).
final ValueNotifier<int> hyperosMotionRevision = ValueNotifier<int>(0);

void notifyHyperosMotionChanged() {
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
    return scaledDuration(HyperosMiuixNavigation.transitionDurationMs);
  }

  static void applyUserTransitionSpeed(double speed) {
    final clamped = speed.clamp(0.5, 2.5);
    onUserTransitionSpeedChanged?.call(clamped);
  }
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
