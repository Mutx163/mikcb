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
}
