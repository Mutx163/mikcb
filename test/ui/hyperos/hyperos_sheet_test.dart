import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderOpacity;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// Cumulative alpha applied to [finder]'s render object by ancestor
/// [RenderOpacity] layers (1.0 when nothing fades it).
double effectiveOpacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOpacity) {
      opacity *= renderObject.opacity;
    }
    return true;
  });
  return opacity;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showHomeHyperosSheet drag-to-dismiss', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const HyperosSheetFrame(
                          // Keep the panel solid: BackdropFilter / shader
                          // rendering is not the point of these tests.
                          frosted: false,
                          child: SizedBox(
                            width: 300,
                            height: 400,
                            child: Center(child: Text('Sheet content')),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('sheet content stays fully opaque while dragged down', (
      tester,
    ) async {
      await openSheet(tester);

      final content = find.text('Sheet content');
      expect(content, findsOneWidget);
      expect(effectiveOpacityOf(tester, content), 1.0);
      final topBeforeDrag = tester.getTopLeft(content).dy;

      final gesture = await tester.startGesture(tester.getCenter(content));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();

      // Dragging must never fade the panel — an Opacity layer over frosted /
      // liquid glass content flickers (the regression this guards against).
      expect(effectiveOpacityOf(tester, content), 1.0);
      // The panel actually moved down with the finger.
      expect(tester.getTopLeft(content).dy, greaterThan(topBeforeDrag));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('drag past the distance threshold dismisses the sheet', (
      tester,
    ) async {
      await openSheet(tester);

      final content = find.text('Sheet content');
      final topBeforeDrag = tester.getTopLeft(content).dy;

      final gesture = await tester.startGesture(tester.getCenter(content));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(tester.getTopLeft(content).dy, greaterThan(topBeforeDrag));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(content, findsNothing);
    });

    testWidgets('small drag springs back to rest without dismissing', (
      tester,
    ) async {
      await openSheet(tester);

      final content = find.text('Sheet content');
      final topBeforeDrag = tester.getTopLeft(content).dy;

      final gesture = await tester.startGesture(tester.getCenter(content));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(content).dy, greaterThan(topBeforeDrag));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(content, findsOneWidget);
      expect(tester.getTopLeft(content).dy, closeTo(topBeforeDrag, 0.1));
    });
  });

  group('showHomeHyperosSheet edge chrome sizing', () {
    Future<void> openFrostedEdgeSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const HyperosSheetFrame(
                          child: SizedBox(
                            width: 300,
                            height: 200,
                            child: Center(child: Text('Edge sheet content')),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('frosted edge sheet hugs content instead of full screen', (
      tester,
    ) async {
      await openFrostedEdgeSheet(tester);

      final content = find.text('Edge sheet content');
      expect(content, findsOneWidget);

      // Bottom-aligned edge sheet: the 200dp content (+ padding) hugs the
      // bottom of the 600dp test screen. The old all-Positioned Stack sized
      // itself to constraints.biggest and pinned the content to the top of a
      // full-screen panel (content top ~16dp instead of ~384dp).
      expect(tester.getTopLeft(content).dy, greaterThan(300));
    });
  });

  group('HyperosAdaptiveCard on frosted panels', () {
    testWidgets('choice group card turns translucent inside a frosted sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showHomeHyperosSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        return const HyperosSheetFrame(
                          child: HyperosChoiceGroup(
                            children: [
                              HyperosChoiceTile(title: 'Profile A'),
                              HyperosChoiceTile(title: 'Profile B'),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The list card must let the liquid glass / frosted panel show through:
      // an opaque white card here defeats the whole point of the glass sheet.
      final cardMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(HyperosAdaptiveCard),
          matching: find.byType(Material),
        ),
      );
      expect(cardMaterial.color, isNotNull);
      expect(cardMaterial.color!.a, lessThan(1.0));
    });

    testWidgets('choice group card stays opaque on a plain settings page', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          home: Scaffold(
            body: HyperosChoiceGroup(
              children: [
                HyperosChoiceTile(title: 'Profile A'),
                HyperosChoiceTile(title: 'Profile B'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(HyperosAdaptiveCard),
          matching: find.byType(Material),
        ),
      );
      expect(cardMaterial.color, isNotNull);
      expect(cardMaterial.color!.a, 1.0);
    });
  });
}
