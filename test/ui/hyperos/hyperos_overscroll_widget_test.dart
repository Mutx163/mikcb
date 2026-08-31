import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

/// Sets [ScrollPosition] pixels including out-of-range overscroll values.
void _forceScrollPixels(ScrollPosition position, double pixels) {
  // ignore: invalid_use_of_protected_member
  position.forcePixels(pixels);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(hyperosResetOverscrollEdgeHaptics);

  List<MethodCall> installHapticLog() {
    final log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          log.add(call);
          return null;
        });
    return log;
  }

  void clearHapticLog() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }

  int edgeHapticCount(List<MethodCall> log) {
    return log
        .where(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.selectionClick',
        )
        .length;
  }

  testWidgets('overscroll snaps back after drag release at top', (
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

  testWidgets('edge haptic fires once when arriving at top from content', (
    tester,
  ) async {
    final hapticLog = installHapticLog();
    addTearDown(clearHapticLog);

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
                20,
                (i) => SizedBox(height: 100, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    final scrollContext = tester.element(scrollable);

    void notifyAt(double pixels) {
      _forceScrollPixels(position, pixels);
      hyperosHandleOverscrollEdgeHaptic(
        ScrollUpdateNotification(
          metrics: position,
          context: scrollContext,
          scrollDelta: 1,
        ),
      );
    }

    notifyAt(120);
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 1);

    notifyAt(-20);
    notifyAt(-40);
    expect(edgeHapticCount(hapticLog), 1);
  });

  testWidgets('already at top then pull blank gap does not fire edge haptic', (
    tester,
  ) async {
    final hapticLog = installHapticLog();
    addTearDown(clearHapticLog);

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
    await gesture.moveBy(Offset(0, viewport * 0.4));
    await tester.pump();
    await gesture.moveBy(Offset(0, viewport * 0.2));
    await tester.pump();

    expect(state.position.pixels, lessThan(0));
    expect(edgeHapticCount(hapticLog), 0);

    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(edgeHapticCount(hapticLog), 0);
  });

  testWidgets('edge haptic re-fires only after re-arming from interior', (
    tester,
  ) async {
    final hapticLog = installHapticLog();
    addTearDown(clearHapticLog);

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
                20,
                (i) => SizedBox(height: 100, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    final scrollContext = tester.element(scrollable);

    void notifyAt(double pixels) {
      _forceScrollPixels(position, pixels);
      hyperosHandleOverscrollEdgeHaptic(
        ScrollUpdateNotification(
          metrics: position,
          context: scrollContext,
          scrollDelta: 1,
        ),
      );
    }

    notifyAt(120);
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 1);

    final rearmDistance = hyperosOverscrollEdgeHapticRearmDistance(position);

    // Near-edge jiggles (well under half viewport) must not re-arm.
    notifyAt(2);
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 1);
    notifyAt(24);
    notifyAt(0);
    notifyAt(math.min(40, rearmDistance * 0.25));
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 1);
    notifyAt(math.min(rearmDistance * 0.5, position.maxScrollExtent * 0.4));
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 1);

    // Only after traveling ~half a viewport into content can the top re-fire.
    final rearmPixels = math.min(rearmDistance + 8, position.maxScrollExtent);
    expect(
      rearmPixels,
      greaterThan(rearmDistance),
      reason: 'test list must be tall enough to re-arm at half viewport',
    );
    notifyAt(rearmPixels);
    await tester.pump(
      hyperosOverscrollEdgeHapticCooldown + const Duration(milliseconds: 20),
    );
    notifyAt(0);
    expect(edgeHapticCount(hapticLog), 2);
  });

  testWidgets('gradual scroll to top still fires once', (tester) async {
    final hapticLog = installHapticLog();
    addTearDown(clearHapticLog);

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
                20,
                (i) => SizedBox(height: 100, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    final scrollContext = tester.element(scrollable);

    void notifyAt(double pixels) {
      _forceScrollPixels(position, pixels);
      hyperosHandleOverscrollEdgeHaptic(
        ScrollUpdateNotification(
          metrics: position,
          context: scrollContext,
          scrollDelta: 1,
        ),
      );
    }

    for (final pixels in <double>[40, 25, 12, 7, 3, 1, 0, -8, -16]) {
      notifyAt(pixels);
    }
    expect(edgeHapticCount(hapticLog), 1);
  });

  testWidgets('fast ballistic arrival at top fires only once', (tester) async {
    final hapticLog = installHapticLog();
    addTearDown(clearHapticLog);

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
                30,
                (i) => SizedBox(height: 80, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    final scrollContext = tester.element(scrollable);

    void notifyAt(double pixels) {
      _forceScrollPixels(position, pixels);
      hyperosHandleOverscrollEdgeHaptic(
        ScrollUpdateNotification(
          metrics: position,
          context: scrollContext,
          scrollDelta: 1,
        ),
      );
    }

    notifyAt(position.maxScrollExtent);
    notifyAt(position.maxScrollExtent * 0.5);
    notifyAt(40);
    notifyAt(0);
    notifyAt(-30);
    notifyAt(-10);
    notifyAt(0);

    expect(edgeHapticCount(hapticLog), 1);
  });

  testWidgets(
    'real drag from mid-list to top fires via framework FixedScrollMetrics',
    (tester) async {
      final hapticLog = installHapticLog();
      addTearDown(clearHapticLog);

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
                  30,
                  (i) => SizedBox(height: 80, child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );

      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;

      position.jumpTo(400);
      await tester.pumpAndSettle();
      hyperosResetOverscrollEdgeHaptics();
      hapticLog.clear();

      await tester.drag(scrollable, const Offset(0, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        edgeHapticCount(hapticLog),
        greaterThanOrEqualTo(1),
        reason: 'must fire when real ScrollUpdateNotifications reach the top',
      );
    },
  );
}
