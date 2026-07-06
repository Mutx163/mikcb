import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_page.dart';

void main() {
  group('hyperosIsRouteTransitioning', () {
    test('current route: only primary animation matters', () {
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 1,
          secondaryAnimationValue: 0.5,
          isRouteCurrent: true,
        ),
        isFalse,
      );
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 0.42,
          secondaryAnimationValue: 0,
          isRouteCurrent: true,
        ),
        isTrue,
      );
    });

    test('covered route: secondary animation blocks rebuild', () {
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 1,
          secondaryAnimationValue: 0.18,
          isRouteCurrent: false,
        ),
        isTrue,
      );
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 1,
          secondaryAnimationValue: 0,
          isRouteCurrent: false,
        ),
        isFalse,
      );
    });

    test('current route settled when primary at rest', () {
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 1,
          secondaryAnimationValue: 0,
          isRouteCurrent: true,
        ),
        isFalse,
      );
      expect(
        hyperosIsRouteTransitioning(
          animationValue: 0.9995,
          secondaryAnimationValue: 0.0005,
          isRouteCurrent: true,
        ),
        isFalse,
      );
    });
  });

  group('hyperosIsIncomingRouteSettled', () {
    test('treats near-complete animation as settled', () {
      expect(hyperosIsIncomingRouteSettled(animationValue: 1), isTrue);
      expect(hyperosIsIncomingRouteSettled(animationValue: 0.999), isTrue);
      expect(hyperosIsIncomingRouteSettled(animationValue: 0.998), isFalse);
    });
  });
}
