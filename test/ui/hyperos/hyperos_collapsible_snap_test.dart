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

  testWidgets('short-page title and body share one spring progress', (
    tester,
  ) async {
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
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, -40),
          primaryDelta: -40,
        ),
      ),
    );
    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(30),
        context: notificationContext,
      ),
    );

    expect(behavior.shortPageSpringReleasePixels, 40);
    expect(behavior.shortPageSpringTargetPixels, 0);
    expect(behavior.shortPageSpringProgressForPixels(30), closeTo(0.25, 0.001));
    expect(behavior.state.heightOffset, closeTo(-41.5, 0.001));

    // The body transform consumes this same progress value rather than a
    // second release anchor captured by the page shell.
    expect(behavior.shortPageSpringProgressForPixels(20), closeTo(0.5, 0.001));
  });

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

  testWidgets('short-page in-range release animates instead of jumping', (
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
            height: 160,
            child: HyperosCollapsibleScrollListener(
              behavior: behavior,
              child: ListView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                children: const [SizedBox(height: 95), SizedBox(height: 95)],
              ),
            ),
          ),
        ),
      ),
    );

    expect(controller.position.maxScrollExtent, closeTo(30, 0.001));
    controller.jumpTo(25);
    await tester.pump();
    expect(behavior.state.heightOffset, closeTo(-25, 0.001));

    final scrollable = find.byType(ListView);
    behavior.handleScroll(
      ScrollEndNotification(
        metrics: controller.position,
        context: tester.element(scrollable),
      ),
    );
    await tester.pump();

    // The target is the collapsed title, but the first animation frame must
    // still preserve the release state instead of assigning -expansion.
    expect(behavior.state.heightOffset, greaterThan(-expansion));
    expect(behavior.shortPageSpringReleasePixels, 25);
    expect(behavior.shortPageSpringTargetPixels, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(behavior.state.heightOffset, lessThan(-25));
    expect(behavior.state.heightOffset, greaterThan(-expansion));

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(controller.position.pixels, 0);
    expect(behavior.state.heightOffset, -expansion);
  });

  testWidgets('a reverse short-page drag takes over the spring session', (
    tester,
  ) async {
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
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, -40),
          primaryDelta: -40,
        ),
      ),
    );
    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(30),
        context: notificationContext,
      ),
    );
    expect(behavior.shortPageSpringReleasePixels, 40);

    behavior.handleScroll(
      ScrollStartNotification(
        metrics: metrics(30),
        context: notificationContext,
        dragDetails: DragStartDetails(globalPosition: Offset.zero),
      ),
    );
    expect(behavior.shortPageSpringReleasePixels, isNull);

    behavior.handleScroll(
      ScrollUpdateNotification(
        metrics: metrics(10),
        context: notificationContext,
        dragDetails: DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, -20),
          primaryDelta: -20,
        ),
      ),
    );
    expect(behavior.state.heightOffset, -10);
    expect(behavior.shortPageSpringProgressForPixels(10), isNull);
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

  testWidgets('half-cut threshold keeps its upper/lower-half contract', (
    tester,
  ) async {
    const cuts = <({double cut, double expectedOffset})>[
      (cut: textHeight * 0.49, expectedOffset: 0),
      (cut: textHeight * 0.50, expectedOffset: -expansion),
      (cut: textHeight * 0.51, expectedOffset: -expansion),
    ];

    for (final cutCase in cuts) {
      final harness = await pumpHarness(tester);
      harness.controller.jumpTo(cutCase.cut);
      await tester.pump();

      final scrollable = find.byType(ListView);
      harness.behavior.handleScroll(
        ScrollEndNotification(
          metrics: harness.controller.position,
          context: tester.element(scrollable),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(harness.behavior.state.heightOffset, cutCase.expectedOffset);
    }
  });
}
