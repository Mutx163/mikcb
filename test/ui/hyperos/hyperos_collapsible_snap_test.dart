import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_collapsible_top_app_bar.dart';

/// Reproduces the release-mid-collapse snap requirement:
/// - release with the large title cut less than half → scroll back to top
/// - release with the large title cut more than half → park fully collapsed,
///   tightened so the first content row sits flush under the small-title band
///   (1px shy of the frost threshold — header must not turn frosted).
void main() {
  const double expansion = 46.0; // measured large-title block height
  const double textHeight = 38.4; // large title glyph height (32sp * 1.2)

  Future<
    ({
      HyperosExitUntilCollapsedScrollBehavior behavior,
      ScrollController controller,
    })
  >
  pumpHarness(WidgetTester tester) async {
    final behavior = HyperosExitUntilCollapsedScrollBehavior();
    behavior.state.heightOffsetLimit = -expansion;
    behavior.state.largeTitleTextHeight = textHeight;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HyperosCollapsibleScrollListener(
            behavior: behavior,
            child: ListView.builder(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              itemCount: 60,
              itemBuilder: (context, index) =>
                  SizedBox(height: 56, child: Text('item $index')),
            ),
          ),
        ),
      ),
    );
    return (behavior: behavior, controller: controller);
  }

  testWidgets('release above half-cut snaps back to fully expanded', (
    tester,
  ) async {
    final harness = await pumpHarness(tester);

    // Drag up less than half the title text height (cut in the upper half).
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -(textHeight * 0.5 - 5)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(harness.controller.offset, 0.0);
    expect(harness.behavior.state.heightOffset, 0.0);
  });

  testWidgets('release below half-cut snaps to fully collapsed', (
    tester,
  ) async {
    final harness = await pumpHarness(tester);

    // Drag up past half the title text height (cut in the lower half).
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -(textHeight * 0.5 + 5)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Parks past the collapse point by the tighten distance: content top rests
    // flush under the small-title band, 1px before the frost threshold.
    expect(
      harness.controller.offset,
      expansion + HyperosCollapsibleTopAppBarDefaults.collapseSnapRestTighten,
    );
    expect(harness.behavior.state.heightOffset, -expansion);
  });
}
