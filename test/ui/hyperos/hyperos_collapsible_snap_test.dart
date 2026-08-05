import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_collapsible_top_app_bar.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

/// Reproduces the release-mid-collapse snap requirement:
/// - release with the large title cut less than half → scroll back to top
/// - release with the large title cut more than half → park fully collapsed,
///   tightened so the first content row sits flush under the small-title band
///   (1px shy of the frost threshold — header must not turn frosted).
void main() {
  const double expansion = 46.0; // measured large-title block height
  const double textHeight = 38.4; // large title glyph height (32sp * 1.2)

  test(
    'small title reveal follows collapse progress without a second clock',
    () {
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(0),
        0,
      );
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(
          HyperosCollapsibleTopAppBarDefaults.smallTitleRevealFraction,
        ),
        0,
      );
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(0.5),
        closeTo(0.25, 0.001),
      );
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(1),
        1,
      );
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(-1),
        0,
      );
      expect(
        HyperosCollapsibleTopAppBarDefaults.smallTitleOpacityForCollapse(2),
        1,
      );
    },
  );

  testWidgets('short-page title follows the overscroll spring', (tester) async {
    late BuildContext notificationContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            notificationContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final behavior = HyperosExitUntilCollapsedScrollBehavior();
    behavior.state.heightOffsetLimit = -expansion;
    behavior.state.largeTitleTextHeight = textHeight;
    behavior.state.heightOffset = -30;

    FixedScrollMetrics metrics(double pixels) {
      return FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 0,
        pixels: pixels,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
    }

    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(40),
        context: notificationContext,
      ),
    );
    expect(behavior.state.heightOffset, -30);

    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(20),
        context: notificationContext,
      ),
    );
    expect(behavior.state.heightOffset, closeTo(-38, 0.001));

    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(0),
        context: notificationContext,
      ),
    );
    expect(behavior.state.heightOffset, -expansion);
  });

  testWidgets('real short-page rebound does not jump the title at release', (
    tester,
  ) async {
    final behavior = HyperosExitUntilCollapsedScrollBehavior();
    behavior.state.heightOffsetLimit = -expansion;
    behavior.state.largeTitleTextHeight = textHeight;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: HyperosCollapsibleScrollListener(
              behavior: behavior,
              child: ListView(
                controller: controller,
                physics: const HyperosOverscrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: List.generate(
                  3,
                  (index) => SizedBox(height: 120, child: Text('item $index')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(ListView);
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.position.pixels, greaterThan(0));
    expect(
      controller.position.pixels,
      greaterThan(controller.position.maxScrollExtent),
    );
    expect(behavior.state.heightOffset, lessThan(0));
    expect(behavior.state.heightOffset, greaterThan(-expansion));

    await tester.pump(const Duration(milliseconds: 120));
    expect(behavior.state.heightOffset, lessThanOrEqualTo(-textHeight * 0.5));
    expect(behavior.state.heightOffset, greaterThan(-expansion));

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(behavior.state.heightOffset, -expansion);
    expect(controller.position.pixels, 0);
  });

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
