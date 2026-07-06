import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_widgets.dart';

import '../helpers_test_app.dart';

const _bg = Colors.white;
const _highlight = Color(0xFFE0E0E0);
const _transitionHighlight = Duration(
  milliseconds: HyperosMiuixNavigation.transitionDurationMs,
);

Widget _pressableRow({
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  bool holdHighlightThroughTransition = false,
}) {
  return HyperosListScrollScope(
    isUserScrolling: false,
    pressHighlightGeneration: 0,
    child: HyperosPressableRow(
      onTap: onTap,
      onLongPress: onLongPress,
      holdHighlightThroughTransition: holdHighlightThroughTransition,
      backgroundColor: _bg,
      highlightColor: _highlight,
      child: const SizedBox(height: 56, child: Center(child: Text('Row'))),
    ),
  );
}

Color _rowBackground(WidgetTester tester) {
  return tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byType(HyperosPressableRow),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hold tap highlights after deferred delay', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: _pressableRow(onTap: () {}, holdHighlightThroughTransition: true),
      ),
    );

    final center = tester.getCenter(find.text('Row'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 30));

    expect(_rowBackground(tester), _highlight);

    await gesture.up();
    await tester.pump();
    expect(_rowBackground(tester), _highlight);

    await tester.pump(_transitionHighlight);
    expect(_rowBackground(tester), _bg);
  });

  testWidgets('quick tap clears highlight on release by default', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      TestApp(home: _pressableRow(onTap: () => tapped = true)),
    );

    await tester.tap(find.text('Row'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(_rowBackground(tester), _bg);
  });

  testWidgets('quick tap keeps highlight through page transition', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      TestApp(
        home: _pressableRow(
          onTap: () => tapped = true,
          holdHighlightThroughTransition: true,
        ),
      ),
    );

    await tester.tap(find.text('Row'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(_rowBackground(tester), _highlight);

    await tester.pump(const Duration(milliseconds: 200));
    expect(_rowBackground(tester), _highlight);

    await tester.pump(_transitionHighlight);
    expect(_rowBackground(tester), _bg);
  });

  testWidgets('vertical drag does not highlight row', (tester) async {
    await tester.pumpWidget(TestApp(home: _pressableRow(onTap: () {})));

    final center = tester.getCenter(find.text('Row'));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();

    expect(_rowBackground(tester), _bg);
    await gesture.up();
  });

  testWidgets('pressHighlightGeneration bump clears highlight', (tester) async {
    var generation = 0;
    late void Function(void Function()) setState;

    await tester.pumpWidget(
      TestApp(
        home: StatefulBuilder(
          builder: (context, markNeedsBuild) {
            setState = markNeedsBuild;
            return HyperosListScrollScope(
              isUserScrolling: false,
              pressHighlightGeneration: generation,
              child: HyperosPressableRow(
                onTap: () {},
                backgroundColor: _bg,
                highlightColor: _highlight,
                child: const SizedBox(
                  height: 56,
                  child: Center(child: Text('Row')),
                ),
              ),
            );
          },
        ),
      ),
    );

    final center = tester.getCenter(find.text('Row'));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 30));
    expect(_rowBackground(tester), _highlight);

    setState(() => generation++);
    await tester.pump();
    expect(_rowBackground(tester), _bg);

    await gesture.up();
  });
}
