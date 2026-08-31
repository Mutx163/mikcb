import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

void main() {
  group('LiquidGlassDegradation.shouldDegradeFor', () {
    const base = MediaQueryData();

    test('false by default (no accessibility flags)', () {
      expect(LiquidGlassDegradation.shouldDegradeFor(base), isFalse);
    });

    test('false under accessibleNavigation (MIUI screenshot false positive)', () {
      // MIUI/HyperOS 截图悬浮窗会打开系统 touch exploration，引擎误报
      // accessibleNavigation=true（flutter/flutter#128409），玻璃不随该信号
      // 降级，否则截图预览悬浮窗存在期间全部玻璃回落实体。
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(accessibleNavigation: true),
        ),
        isFalse,
      );
    });

    test('true under disableAnimations (system "remove animations")', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(disableAnimations: true),
        ),
        isTrue,
      );
    });

    test('true under highContrast', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(highContrast: true),
        ),
        isTrue,
      );
    });

    test('true when any flag is set among several', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(accessibleNavigation: false, highContrast: true),
        ),
        isTrue,
      );
    });

    test('false again once all flags clear', () {
      expect(
        LiquidGlassDegradation.shouldDegradeFor(
          base.copyWith(highContrast: true).copyWith(highContrast: false),
        ),
        isFalse,
      );
    });
  });

  group('liquid glass surfaces downgrade under system degradation', () {
    const liquidAppearance = FrostedAppearance(
      sheetBlurSigma: 15,
      sheetTintAlpha: 0.7,
      sheetBarrierAlpha: 0.2,
      glassMode: FrostedGlassMode.liquidGlass,
    );

    // Sanity: without any accessibility flag the liquid-glass sheet still
    // spawns its glass surface, so the downgrade assertions below are
    // meaningful (they fail because of degradation, not by accident).
    testWidgets('liquid sheet builds HyperosLiquidGlassSurface by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          home: FrostedAppearanceScope(
            appearance: liquidAppearance,
            child: HyperosSheetFrame(
              child: SizedBox(width: 120, height: 120),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    });

    Widget degradedSheet({required bool highContrast}) {
      return TestApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: const FrostedAppearanceScope(
                appearance: liquidAppearance,
                child: HyperosSheetFrame(
                  child: SizedBox(width: 120, height: 120),
                ),
              ),
            );
          },
        ),
      );
    }

    testWidgets('liquid sheet downgrades to solid under high contrast', (
      tester,
    ) async {
      await tester.pumpWidget(degradedSheet(highContrast: true));
      await tester.pump();
      // Degradation skips the liquid-glass branch; the sheet falls through to
      // the solid Material surface instead of spawning a glass surface.
      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('liquid sheet is restored when high contrast clears', (
      tester,
    ) async {
      await tester.pumpWidget(degradedSheet(highContrast: true));
      await tester.pump();
      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      await tester.pumpWidget(degradedSheet(highContrast: false));
      await tester.pump();
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    });
  });
}
