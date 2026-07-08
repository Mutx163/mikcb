import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

void main() {
  testWidgets('overscroll snaps back after drag release at top', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: hyperosHandleOverscrollSnapBack,
            child: ListView(
              physics: const HyperosOverscrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: List.generate(
                5,
                (i) => SizedBox(height: 100, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final state = tester.state<ScrollableState>(scrollable);
    final viewport = state.position.viewportDimension;

    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    await gesture.moveBy(Offset(0, viewport * 0.8));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      state.position.pixels,
      closeTo(0, 1),
      reason: 'overscroll should spring back after release at cap',
    );
  });

  testWidgets('capped overscroll springs back after fast downward release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: hyperosHandleOverscrollSnapBack,
            child: ListView(
              physics: const HyperosOverscrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: List.generate(
                5,
                (i) => SizedBox(height: 100, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final state = tester.state<ScrollableState>(scrollable);
    final viewport = state.position.viewportDimension;
    final maxOverscroll = viewport * 0.5;

    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    await gesture.moveBy(Offset(0, viewport * 2));
    await tester.pump();
    await gesture.moveBy(Offset(0, viewport));
    await tester.pump();

    expect(state.position.pixels, lessThan(0));
    expect(state.position.pixels, greaterThanOrEqualTo(-maxOverscroll - 1));
    expect(state.position.pixels, lessThanOrEqualTo(-maxOverscroll + 1));

    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(state.position.pixels, closeTo(0, 1));
  });
}
