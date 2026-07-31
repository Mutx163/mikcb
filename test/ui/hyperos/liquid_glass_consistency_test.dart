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

  group('modal liquid glass sampling', () {
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
}
