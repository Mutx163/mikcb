import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    /// Mirrors [ScrollPosition.applyUserOffset]: `pixels -= applied`.
    double advancePixels(double pixels, double applied) => pixels - applied;

    test('hard-caps overscroll relative to viewport minus header inset', () {
      const viewport = 400.0;
      const headerInset = 100.0;
      const withHeader = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
        topInset: headerInset,
      );
      final maxOverscroll =
          (viewport - headerInset) * HyperosMiuixAnim.maxOverscrollFraction;

      expect(
        withHeader.applyBoundaryConditions(
          metrics(pixels: 0, viewportDimension: viewport),
          -maxOverscroll - 1,
        ),
        -1,
      );
      expect(
        withHeader.applyBoundaryConditions(
          metrics(pixels: 0, viewportDimension: viewport),
          -maxOverscroll,
        ),
        0,
      );
    });

    test('hard-caps overscroll at half viewport via boundary conditions', () {
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;

      expect(
        physics.applyBoundaryConditions(metrics(pixels: 0), -maxOverscroll - 50),
        -50,
      );
      expect(
        physics.applyBoundaryConditions(metrics(pixels: 0), -maxOverscroll),
        0,
      );
      expect(
        physics.applyBoundaryConditions(
          metrics(pixels: -maxOverscroll, viewportDimension: viewport),
          -maxOverscroll + 40,
        ),
        0,
      );
    });

    test(
      'boundary result never exceeds delta when pixels already past boundary',
      () {
        // Simulates floating-point drift where pixels is already slightly
        // beyond the overscroll boundary.  The framework asserts
        // |applyBoundaryConditions()| <= |delta|; verify we stay within.
        const viewport = 400.0;
        final maxOverscroll =
            viewport * HyperosMiuixAnim.maxOverscrollFraction;
        final minBound = -maxOverscroll;

        // pixels slightly past minBound due to FP drift
        final driftedPixels = minBound - 0.0000001;
        final value = minBound - 5.0;

        final result = physics.applyBoundaryConditions(
          metrics(pixels: driftedPixels, viewportDimension: viewport),
          value,
        );
        final delta = value - driftedPixels;
        expect(result.abs(), lessThanOrEqualTo(delta.abs()));

        // Same for the max-bound direction
        final maxBound = 100.0 + maxOverscroll;
        final maxDrifted = maxBound + 0.0000001;
        final maxValue = maxBound + 5.0;
        final maxResult = physics.applyBoundaryConditions(
          metrics(
            pixels: maxDrifted,
            maxScrollExtent: 100,
            viewportDimension: viewport,
          ),
          maxValue,
        );
        final maxDelta = maxValue - maxDrifted;
        expect(maxResult.abs(), lessThanOrEqualTo(maxDelta.abs()));
      },
    );

    test('applies friction while overscrolling deeper', () {
      final offset = physics.applyPhysicsToUserOffset(
        metrics(pixels: -40),
        20,
      );
      expect(offset, greaterThan(0));
      expect(offset, lessThan(20));
    });

    test(
      'crossing top edge from rest applies rubber-band to overscroll portion',
      () {
        const fastPull = HyperosOverscrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
        final offset = fastPull.applyPhysicsToUserOffset(
          metrics(pixels: 0),
          200,
        );
        expect(offset, greaterThan(0));
        expect(offset, lessThan(200));
      },
    );

    test('resistance nears zero as blank gap approaches cap', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;

      final nearStart = pull.applyPhysicsToUserOffset(
        metrics(pixels: -20, viewportDimension: viewport),
        40,
      );
      final nearCap = pull.applyPhysicsToUserOffset(
        metrics(pixels: -maxOverscroll + 20, viewportDimension: viewport),
        40,
      );

      expect(nearStart.abs(), greaterThan(nearCap.abs()));
      expect(nearCap.abs(), lessThan(8));
    });

    test('applies growing resistance after entering overscroll', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      final first = pull.applyPhysicsToUserOffset(metrics(pixels: -80), 80);
      final second = pull.applyPhysicsToUserOffset(metrics(pixels: -160), 80);
      expect(first.abs(), lessThan(80));
      expect(second.abs(), lessThan(first.abs()));
    });

    test('stops drag overscroll at half viewport with resistance', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;

      var pixels = 0.0;
      for (var i = 0; i < 500; i++) {
        final metricsAt = metrics(
          pixels: pixels,
          viewportDimension: viewport,
        );
        final delta = pull.applyPhysicsToUserOffset(metricsAt, 120);
        if (delta == 0) {
          break;
        }
        var next = advancePixels(pixels, delta);
        final over = pull.applyBoundaryConditions(metricsAt, next);
        if (over != 0) {
          next -= over;
        }
        pixels = next;
        if ((pixels + maxOverscroll).abs() < 0.5) {
          break;
        }
      }
      expect(pixels, closeTo(-maxOverscroll, 0.5));
    });

    test('continuous drag cannot exceed half viewport blank gap', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;

      var pixels = 0.0;
      for (var round = 0; round < 12; round++) {
        for (var i = 0; i < 50; i++) {
          final metricsAt = metrics(
            pixels: pixels,
            viewportDimension: viewport,
          );
          final delta = pull.applyPhysicsToUserOffset(metricsAt, 200);
          if (delta == 0) {
            continue;
          }
          var next = advancePixels(pixels, delta);
          final over = pull.applyBoundaryConditions(metricsAt, next);
          if (over != 0) {
            next -= over;
          }
          pixels = next;
        }
      }
      expect(pixels, greaterThanOrEqualTo(-maxOverscroll - 0.5));
      expect(pixels, lessThanOrEqualTo(-maxOverscroll + 0.5));
    });

    test('free zone follows finger 1:1 at overscroll start', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

      final fromRest = pull.applyPhysicsToUserOffset(
        metrics(pixels: 0),
        12,
      );
      final inZone = pull.applyPhysicsToUserOffset(
        metrics(pixels: -8),
        6,
      );

      expect(fromRest, 12);
      expect(inZone, 6);
    });

    test('deep overscroll strongly resists finger movement', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;
      const finger = 80.0;

      final applied = pull.applyPhysicsToUserOffset(
        metrics(pixels: -maxOverscroll * 0.55, viewportDimension: viewport),
        finger,
      );

      expect(applied.abs(), lessThan(finger.abs() * 0.2));
    });

    test('large delta at moderate overscroll has low transfer ratio', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const finger = 80.0;

      final applied = pull.applyPhysicsToUserOffset(
        metrics(pixels: -80),
        finger,
      );

      expect(applied.abs(), lessThan(finger.abs() * 0.35));
      expect(applied.abs(), greaterThan(finger.abs() * 0.08));
    });

    test('drag transfer ratio falls after free zone', () {
      const max = 200.0;
      expect(
        HyperosOverscrollPhysics.dragTransferRatio(0, max),
        1.0,
      );
      expect(
        HyperosOverscrollPhysics.dragTransferRatio(16, max),
        1.0,
      );
      expect(
        HyperosOverscrollPhysics.dragTransferRatio(100, max),
        lessThan(0.25),
      );
      expect(
        HyperosOverscrollPhysics.dragTransferRatio(180, max),
        lessThan(0.08),
      );
    });

    test('continuous drag transfer ratio decreases over time', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
      const viewport = 400.0;
      const finger = 60.0;

      var pixels = 0.0;
      final ratios = <double>[];
      for (var i = 0; i < 10; i++) {
        final metricsAt = metrics(
          pixels: pixels,
          viewportDimension: viewport,
        );
        final applied = pull.applyPhysicsToUserOffset(metricsAt, finger);
        if (applied == 0) {
          break;
        }
        ratios.add(applied.abs() / finger.abs());
        pixels = advancePixels(pixels, applied);
      }

      expect(ratios.length, greaterThan(3));
      final early = ratios.take(3).reduce((a, b) => a + b) / 3;
      final late = ratios.skip(ratios.length - 3).reduce((a, b) => a + b) / 3;
      expect(late, lessThan(early));
    });

    test('returns zero delta when already at max overscroll', () {
      const viewport = 400.0;
      final maxOverscroll = viewport * HyperosMiuixAnim.maxOverscrollFraction;

      expect(
        physics.applyPhysicsToUserOffset(
          metrics(pixels: -maxOverscroll, viewportDimension: viewport),
          40,
        ),
        0,
      );
      expect(
        physics.applyPhysicsToUserOffset(
          metrics(
            pixels: 100 + maxOverscroll,
            maxScrollExtent: 100,
            viewportDimension: viewport,
          ),
          -40,
        ),
        0,
      );
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

    test(
      'pull back from bottom overscroll follows finger and scrolls content',
      () {
        const pull = HyperosOverscrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );

        final applied = pull.applyPhysicsToUserOffset(
          metrics(pixels: 350, maxScrollExtent: 100),
          280,
        );

        expect(applied, 280);
        expect(advancePixels(350, applied), lessThan(100));
      },
    );

    test(
      'pull back from top overscroll follows finger and scrolls content',
      () {
        const pull = HyperosOverscrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );

        final applied = pull.applyPhysicsToUserOffset(
          metrics(pixels: -150, maxScrollExtent: 2000),
          -200,
        );

        expect(applied, -200);
        expect(advancePixels(-150, applied), greaterThan(0));
      },
    );

    test('rapid bottom overscroll then pull up enters list content', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

      var pixels = 1800.0;
      const maxExtent = 2000.0;
      for (var i = 0; i < 6; i++) {
        pixels = advancePixels(
          pixels,
          pull.applyPhysicsToUserOffset(
            metrics(pixels: pixels, maxScrollExtent: maxExtent),
            -120,
          ),
        );
      }
      expect(pixels, greaterThan(maxExtent));

      final applied = pull.applyPhysicsToUserOffset(
        metrics(pixels: pixels, maxScrollExtent: maxExtent),
        400,
      );
      pixels = advancePixels(pixels, applied);

      expect(applied, 400);
      expect(pixels, lessThan(maxExtent));
    });

    test('rapid top overscroll then pull down enters list content', () {
      const pull = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

      var pixels = 400.0;
      const maxExtent = 2000.0;
      for (var i = 0; i < 6; i++) {
        pixels = advancePixels(
          pixels,
          pull.applyPhysicsToUserOffset(
            metrics(pixels: pixels, maxScrollExtent: maxExtent),
            120,
          ),
        );
      }
      expect(pixels, lessThan(0));

      final applied = pull.applyPhysicsToUserOffset(
        metrics(pixels: pixels, maxScrollExtent: maxExtent),
        -240,
      );
      pixels = advancePixels(pixels, applied);

      expect(applied, lessThan(-150));
      expect(pixels, greaterThan(0));
    });

    test('zigzag bottom overscroll unwind stays responsive', () {
      const physics = HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

      var pixels = 100.0;
      const fingerDelta = 120.0;
      final pattern = <double>[
        -fingerDelta,
        -fingerDelta,
        -fingerDelta,
        fingerDelta,
        -fingerDelta,
        fingerDelta,
      ];

      for (var i = 0; i < pattern.length; i++) {
        final finger = pattern[i];
        final metricsAt = metrics(pixels: pixels, maxScrollExtent: 100);
        final applied = physics.applyPhysicsToUserOffset(metricsAt, finger);

        final unwindingBottomOverscroll =
            finger > 0 && pixels > metricsAt.maxScrollExtent;
        final unwindingTopOverscroll = finger < 0 && pixels < 0;
        if (unwindingBottomOverscroll || unwindingTopOverscroll) {
          expect(
            applied,
            finger,
            reason: 'pull-back should follow finger at step $i: pixels=$pixels',
          );
        }
        pixels = advancePixels(pixels, applied);
      }
    });
  });
}
