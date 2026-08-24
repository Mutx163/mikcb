import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_home_pull.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';

void main() {
  group('HyperosHomePullPhysics.dampedFraction', () {
    test('endpoints 0 -> 0, 1 -> 1/3', () {
      expect(hyperosHomePullDampedFraction(0), closeTo(0, 1e-9));
      expect(hyperosHomePullDampedFraction(1), closeTo(1 / 3, 1e-9));
    });

    test('clamps outside [0,1]', () {
      expect(hyperosHomePullDampedFraction(-0.5), closeTo(0, 1e-9));
      expect(hyperosHomePullDampedFraction(2), closeTo(1 / 3, 1e-9));
    });

    test('monotonic increasing', () {
      double prev = -1;
      for (var x = 0.0; x <= 1.0001; x += 0.05) {
        final v = hyperosHomePullDampedFraction(x);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('sublinear after ~0.2 (heavier than linear)', () {
      // At x=0.5 linear in fraction would be 0.5, damped should be ~0.2916
      expect(hyperosHomePullDampedFraction(0.5), closeTo(0.2916666, 1e-4));
      expect(hyperosHomePullDampedFraction(0.5), lessThan(0.5));
    });
  });

  group('visualOffset / touchForOffset', () {
    const range = HyperosHomePullPhysics.dampingRange; // 540
    test('visualOffset 0 -> 0, range -> maxVisual', () {
      expect(hyperosHomePullVisualOffset(0, range), closeTo(0, 1e-9));
      expect(
        hyperosHomePullVisualOffset(range, range),
        closeTo(HyperosHomePullPhysics.maxVisualDistance, 1e-6),
      );
    });

    test('clamps touch beyond range', () {
      expect(
        hyperosHomePullVisualOffset(range + 100, range),
        closeTo(HyperosHomePullPhysics.maxVisualDistance, 1e-6),
      );
      expect(hyperosHomePullVisualOffset(-10, range), closeTo(0, 1e-9));
    });

    test('touchForOffset is inverse of visualOffset', () {
      for (final offset in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0]) {
        final touch = hyperosHomePullTouchForOffset(offset, range);
        final back = hyperosHomePullVisualOffset(touch, range);
        expect(back, closeTo(offset, 1e-6), reason: 'offset=\$offset');
      }
    });

    test('trigger ~120 visual needs ~165 touch', () {
      const trigger = HyperosHomePullPhysics.triggerDistance;
      // Find touch that yields trigger by forward scan
      double foundTouch = 0;
      for (var t = 0.0; t <= range; t += 0.5) {
        if (hyperosHomePullVisualOffset(t, range) >= trigger) {
          foundTouch = t;
          break;
        }
      }
      expect(foundTouch, greaterThan(150));
      expect(foundTouch, lessThan(180));
      expect(hyperosHomePullVisualOffset(foundTouch, range), closeTo(trigger, 1.0));
    });

    test('tight round-trip for intermediates', () {
      for (var touch = 0.0; touch <= range; touch += 37.5) {
        final offset = hyperosHomePullVisualOffset(touch, range);
        final backTouch = hyperosHomePullTouchForOffset(offset, range);
        expect(backTouch, closeTo(touch, 0.8), reason: 'touch=\$touch');
      }
    });
  });

  group('spring spec', () {
    test('uses spec period 0.4s and critical damping', () {
      final s = hyperosHomePullSpring();
      final expectedOmega = 2 * math.pi / HyperosMiuixAnim.standardSpringPeriod;
      final expectedStiffness = expectedOmega * expectedOmega;
      expect(s.stiffness, closeTo(expectedStiffness, 1e-6));
      expect(s.mass, closeTo(1, 1e-9));
      // ratio 1 => damping = 2*sqrt(m*k) ; SpringDescription stores damping via ratio
      expect(s.damping, closeTo(2 * math.sqrt(s.mass * s.stiffness), 1e-4));
    });
  });

  group('constants sanity', () {
    test('trigger < maxVisual < range', () {
      expect(HyperosHomePullPhysics.triggerDistance, lessThan(HyperosHomePullPhysics.maxVisualDistance));
      expect(HyperosHomePullPhysics.maxVisualDistance, lessThan(HyperosHomePullPhysics.dampingRange));
    });
  });
}
