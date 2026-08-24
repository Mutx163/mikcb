import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'hyperos_miuix_spec.dart';

// 首页下拉快捷导入的 HyperOS 质感物理。
// 阻尼曲线 f(x) = x - x^2 + x^3/3, x in [0,1]，与 MIUI / Compose miuix 一致。
// 越拉越沉，打破之前线性 0.62 跟手的廉价感；
// 松手使用与 HyperosOverscrollPhysics 同款临界阻尼弹簧回弹（周期 0.4s、阻尼比 1）。
// range 取可视上限的 3 倍（180 -> 540），使得 f(1)*range = maxVisual。
class HyperosHomePullPhysics {
  HyperosHomePullPhysics._();

  static const double triggerDistance = 120.0;
  static const double maxVisualDistance = 180.0;
  static const double dampingRange = maxVisualDistance * 3; // 540

  @visibleForTesting
  static double dampedFraction(double normalized) {
    final x = normalized.clamp(0.0, 1.0);
    return x - x * x + x * x * x / 3;
  }

  static double visualOffset(double touchDistance, double range) {
    if (range <= 0) return 0;
    final t = touchDistance.clamp(0.0, range);
    final normalized = t / range;
    return dampedFraction(normalized) * range;
  }

  static double touchForOffset(double offset, double range) {
    if (range <= 0) return 0;
    final sign = offset.sign;
    final absOffset = offset.abs().clamp(0.0, dampedFraction(1) * range);
    final base = range - 3 * absOffset;
    final cubeRoot = base == 0
        ? 0.0
        : base.sign * math.pow(base.abs(), 1 / 3).toDouble();
    final touch = range - math.pow(range, 2 / 3).toDouble() * cubeRoot;
    return sign * touch.clamp(0.0, range);
  }

  static SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: math.pow(2 * math.pi / HyperosMiuixAnim.standardSpringPeriod, 2).toDouble(),
        ratio: HyperosMiuixAnim.criticalDampingRatio,
      );
}

@visibleForTesting
double hyperosHomePullDampedFraction(double x) =>
    HyperosHomePullPhysics.dampedFraction(x);

@visibleForTesting
double hyperosHomePullVisualOffset(double touch, double range) =>
    HyperosHomePullPhysics.visualOffset(touch, range);

@visibleForTesting
double hyperosHomePullTouchForOffset(double offset, double range) =>
    HyperosHomePullPhysics.touchForOffset(offset, range);

SpringDescription hyperosHomePullSpring() => HyperosHomePullPhysics.spring;
