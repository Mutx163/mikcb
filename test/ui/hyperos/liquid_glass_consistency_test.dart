import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_tokens.dart';

import '../../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('liquid glass settings are unified', () {
    for (final brightness in Brightness.values) {
      test('sheet/nested/course use the same settings for $brightness', () {
        final sheet = MikcbLiquidGlassTokens.sheetSettingsFor(brightness);
        final nested = MikcbLiquidGlassTokens.nestedTileSettingsFor(brightness);
        final course = MikcbLiquidGlassTokens.courseCardSettingsFor(brightness);

        expect(nested, sheet);
        expect(course, sheet);
      });
    }

    test('tuning role methods do not scale sheet settings', () {
      const tuning = LiquidGlassTuning(thickness: 18, blur: 8, tintAlpha: 0.25);
      const brightness = Brightness.light;
      final sheet = tuning.toSheetSettings(brightness: brightness);

      expect(tuning.toNestedTileSettings(brightness: brightness), sheet);
      expect(tuning.toCourseCardSettings(brightness: brightness), sheet);
    });
  });

  group('modal appearance scope is preserved across popup routes', () {
    const gaussianAppearance = FrostedAppearance(
      sheetBlurSigma: 15,
      sheetTintAlpha: 0.7,
      sheetBarrierAlpha: 0.2,
      glassMode: FrostedGlassMode.gaussian,
    );

    testWidgets('sheet keeps the caller appearance mode', (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosSheet<void>(
                  context: context,
                  builder: (_) => const HyperosSheetFrame(
                    child: SizedBox(width: 180, height: 120),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.byType(HyperosSheetFrame), findsOneWidget);
    });

    testWidgets('anchored list popup keeps the caller appearance mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosListPopup<String>(
                  context: context,
                  position: const RelativeRect.fromLTRB(24, 24, 200, 500),
                  items: const [
                    HyperosPopupMenuItem(label: 'Option A', value: 'a'),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('anchored select popup keeps the caller appearance mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: gaussianAppearance,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showHyperosSelectPopup<String>(
                  context: context,
                  anchorRect: const Rect.fromLTWH(24, 24, 160, 48),
                  items: const {'Option A': 'a'},
                  currentValue: 'a',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(HyperosLiquidGlassSurface), findsNothing);
      expect(find.text('Option A'), findsOneWidget);
    });
  });

  group('modal liquid glass sampling', () {
    test('all modal roles resolve identical liquid settings', () {
      for (final brightness in Brightness.values) {
        final header = HyperosLiquidGlassSurface.settingsForRole(
          role: HyperosLiquidGlassRole.header,
          brightness: brightness,
        );
        final modal = HyperosLiquidGlassSurface.settingsForRole(
          role: HyperosLiquidGlassRole.modal,
          brightness: brightness,
        );

        expect(modal, header);
      }
    });

    testWidgets('showHyperosSheet builds an undimmed capture group', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showHyperosSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      return const SizedBox(
                        width: 240,
                        height: 160,
                        child: Center(child: Text('sheet body')),
                      );
                    },
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets('showHyperosListPopup builds an undimmed capture group', (
      tester,
    ) async {
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return GestureDetector(
                key: anchorKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showHyperosListPopup<String>(
                    context: context,
                    position: hyperosPopupPositionBelow(context, anchorKey),
                    items: const [
                      HyperosPopupMenuItem(label: 'Option A', value: 'a'),
                      HyperosPopupMenuItem(label: 'Option B', value: 'b'),
                    ],
                  );
                },
                child: const SizedBox(
                  width: 120,
                  height: 48,
                  child: Center(child: Text('open')),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
    });

    testWidgets('showHyperosSelectPopup builds an undimmed capture group', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showHyperosSelectPopup<String>(
                    context: context,
                    anchorRect: const Rect.fromLTWH(24, 24, 160, 48),
                    items: const {'Option A': 'a'},
                    currentValue: 'a',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropGroup), findsOneWidget);
      expect(find.byType(UndimmedBackdropCapture), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
    });
  });

  group('modal liquid glass surface dim', () {
    test('modal surface dim halves the liquid-glass barrier alpha', () {
      expect(
        liquidGlassModalSurfaceDimAlpha,
        HyperosBlurredHeader.liquidGlassModalBarrierAlpha / 2,
      );
    });

    testWidgets('modal role paints a dim wash over the glass', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 10,
              sheetTintAlpha: 0.2,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.liquidGlass,
            ),
            child: HyperosLiquidGlassSurface(
              role: HyperosLiquidGlassRole.modal,
              child: SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );
      await tester.pump();

      // The modal surface must stack a black wash at half the barrier
      // alpha under the child, so the bright glass reads halfway toward
      // the dimmed backdrop instead of glaring.
      final dimBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color.a > 0)
          .toList();
      expect(
        dimBoxes.any(
          (box) =>
              box.color ==
              Colors.black.withValues(alpha: liquidGlassModalSurfaceDimAlpha),
        ),
        isTrue,
      );
    });

    testWidgets('header role stays undimmed', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance(
              sheetBlurSigma: 10,
              sheetTintAlpha: 0.2,
              sheetBarrierAlpha: 0.2,
              glassMode: FrostedGlassMode.liquidGlass,
            ),
            child: HyperosLiquidGlassSurface(
              role: HyperosLiquidGlassRole.header,
              child: SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );
      await tester.pump();

      final dimBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color.a > 0)
          .toList();
      expect(
        dimBoxes.any(
          (box) =>
              box.color ==
              Colors.black.withValues(alpha: liquidGlassModalSurfaceDimAlpha),
        ),
        isFalse,
      );
    });
  });
}
