import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosBlurredHeader.modalBarrierColor', () {
    Future<Color> barrierOf(
      WidgetTester tester, {
      required FrostedGlassMode glassMode,
      double sheetBarrierAlpha = 0.20,
    }) async {
      late Color barrier;
      await tester.pumpWidget(
        MaterialApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 15,
              sheetTintAlpha: 0.70,
              sheetBarrierAlpha: sheetBarrierAlpha,
              glassMode: glassMode,
            ),
            child: Builder(
              builder: (context) {
                barrier = HyperosBlurredHeader.modalBarrierColor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return barrier;
    }

    testWidgets('gaussian uses configured sheet barrier alpha', (tester) async {
      final barrier = await barrierOf(
        tester,
        glassMode: FrostedGlassMode.gaussian,
      );
      expect(barrier, Colors.black.withValues(alpha: 0.20));
    });

    testWidgets('liquid glass uses a light fixed dim, not transparent', (
      tester,
    ) async {
      final barrier = await barrierOf(
        tester,
        glassMode: FrostedGlassMode.liquidGlass,
        // Even if the stored gaussian alpha is high, liquid stays soft.
        sheetBarrierAlpha: 0.45,
      );
      expect(
        barrier,
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.liquidGlassModalBarrierAlpha,
        ),
      );
      expect(barrier.a, lessThan(0.20));
      expect(barrier.a, greaterThan(0.0));
    });
  });
}
