import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

void main() {
  group('HyperosOverscrollPhysics', () {
    const physics = HyperosOverscrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );

    FixedScrollMetrics metrics({
      required double pixels,
      double maxScrollExtent = 100,
      double viewportDimension = 400,
    }) {
      return FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: maxScrollExtent,
        pixels: pixels,
        viewportDimension: viewportDimension,
        devicePixelRatio: 1,
        axisDirection: AxisDirection.down,
      );
    }

    test('does not hard-cap overscroll via boundary conditions', () {
      expect(physics.applyBoundaryConditions(metrics(pixels: 0), -20), 0);
      expect(physics.applyBoundaryConditions(metrics(pixels: 0), -800), 0);
    });

    test('applies friction while overscrolling', () {
      final offset = physics.applyPhysicsToUserOffset(metrics(pixels: -40), 20);
      expect(offset, greaterThan(0));
      expect(offset, lessThan(20));
    });

    test('crossing top edge from rest follows finger on first overscroll delta', () {
      const fastPull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      final offset = fastPull.applyPhysicsToUserOffset(
        metrics(pixels: 0),
        -200,
      );
      expect(offset, -200);
    });

    test('applies growing resistance after entering overscroll', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      final first = pull.applyPhysicsToUserOffset(metrics(pixels: -80), -80);
      final second = pull.applyPhysicsToUserOffset(metrics(pixels: -160), -80);
      expect(first.abs(), lessThan(80));
      expect(second.abs(), lessThan(first.abs()));
    });

    test('allows continued overscroll beyond one viewport with resistance', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      var pixels = 0.0;
      for (var i = 0; i < 40; i++) {
        final delta = pull.applyPhysicsToUserOffset(
          metrics(pixels: pixels),
          -80,
        );
        expect(delta, lessThan(0));
        pixels += delta;
      }
      expect(pixels, lessThan(-400));
    });

    test('returns bouncing simulation when out of range', () {
      final simulation = physics.createBallisticSimulation(
        metrics(pixels: -30),
        0,
      );
      expect(simulation, isNotNull);
      expect(simulation!.x(0), -30);
      expect(simulation.x(1.0), greaterThan(-30));
    });

    test('returns bouncing simulation for fast in-range fling', () {
      final simulation = physics.createBallisticSimulation(
        metrics(pixels: 0),
        3000,
      );
      expect(simulation, isNotNull);
    });
  });
}
