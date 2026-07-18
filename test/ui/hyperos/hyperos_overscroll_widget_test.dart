import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overscroll.dart';

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

  int lightImpactCount(List<MethodCall> log) {
    return log
        .where(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.lightImpact',
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

  testWidgets('edge haptic fires once when crossing top overscroll', (
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
    await gesture.moveBy(Offset(0, viewport * 0.3));
    await tester.pump();
    await gesture.moveBy(Offset(0, viewport * 0.2));
    await tester.pump();

    expect(state.position.pixels, lessThan(0));
    expect(lightImpactCount(hapticLog), 1);

    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('edge haptic re-fires after returning in-range then re-pull', (
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
    final viewport = tester
        .state<ScrollableState>(scrollable)
        .position
        .viewportDimension;

    final firstPull = await tester.startGesture(tester.getCenter(scrollable));
    await firstPull.moveBy(Offset(0, viewport * 0.4));
    await tester.pump();
    await firstPull.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(lightImpactCount(hapticLog), 1);

    final secondPull = await tester.startGesture(tester.getCenter(scrollable));
    await secondPull.moveBy(Offset(0, viewport * 0.4));
    await tester.pump();
    await secondPull.up();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(lightImpactCount(hapticLog), 2);
  });
}
