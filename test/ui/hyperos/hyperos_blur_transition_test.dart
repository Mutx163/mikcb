import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_page_collaborators.dart';

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

  group('hyperosContentUnderHeader', () {
    test('false at scroll top', () {
      expect(hyperosContentUnderHeader(scrollPixels: 0), isFalse);
      expect(hyperosContentUnderHeader(scrollPixels: -40), isFalse);
    });

    test('true once content moves under header', () {
      expect(hyperosContentUnderHeader(scrollPixels: 1), isTrue);
      expect(hyperosContentUnderHeader(scrollPixels: 120), isTrue);
    });
  });

  group('HyperosRouteBlurGate', () {
    test('repeated settled-path sync does not notify every tick', () {
      var notifyCount = 0;
      final gate = HyperosRouteBlurGate(
        isLiveBlurActive: () => true,
        onChanged: () => notifyCount++,
      );
      gate.isMounted = () => true;
      // No ModalRoute animation attached → treated as settled (value 1.0).
      gate.blurSettled = true;

      for (var i = 0; i < 8; i++) {
        gate.syncRouteTransitioning();
      }

      // Previously always called onChanged when current+settled; that caused
      // whole-page rebuilds (and headerExtension remeasure loops) every tick.
      expect(notifyCount, 0);
    });

    test('markBlurSettled notifies only once per settle', () {
      var notifyCount = 0;
      final gate = HyperosRouteBlurGate(
        isLiveBlurActive: () => true,
        onChanged: () => notifyCount++,
      );
      gate.isMounted = () => true;

      gate.markBlurSettled(source: 'test');
      gate.markBlurSettled(source: 'test-again');

      expect(notifyCount, 1);
      expect(gate.blurSettled, isTrue);
    });
  });
}
