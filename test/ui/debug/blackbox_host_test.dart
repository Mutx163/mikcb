import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/ui/debug/blackbox_host.dart';
import 'package:university_timetable/ui/debug/blackbox_overlay_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('defaults to hidden so the overlay never runs unless enabled', () async {
    // 回归守卫：浮层默认必须关闭。它一旦挂载就带上常驻订阅与整树
    // RepaintBoundary 包裹，曾经因为「默认开启 + 悬浮球无限脉冲动画」
    // 让性能版静止时持续 120fps 出帧 / 205% CPU（2026-09-13）。
    SharedPreferences.setMockInitialValues({});
    await BlackBoxOverlayPreferences.instance.load();
    expect(BlackBoxOverlayPreferences.instance.visible, isFalse);
  });

  testWidgets('shows BlackBox when the debug UI setting is enabled', (
    tester,
  ) async {
    try {
      await tester.runAsync(
        () => BlackBoxOverlayPreferences.instance.setVisible(true),
      );
      BlackBox.setup(enabled: true, trigger: const BlackBoxTrigger.none());

      await tester.pumpWidget(
        const MaterialApp(
          home: BlackBoxOverlayHost(child: Scaffold(body: Text('app child'))),
        ),
      );

      expect(find.text('app child'), findsOneWidget);
      expect(find.byType(BlackBoxOverlay), findsOneWidget);
    } finally {
      BlackBox.dispose();
      await tester.pump();
    }
  });

  testWidgets('hides BlackBox when the debug UI setting is disabled', (
    tester,
  ) async {
    try {
      await tester.runAsync(
        () => BlackBoxOverlayPreferences.instance.setVisible(false),
      );
      BlackBox.setup(enabled: true, trigger: const BlackBoxTrigger.none());

      await tester.pumpWidget(
        const MaterialApp(
          home: BlackBoxOverlayHost(child: Scaffold(body: Text('app child'))),
        ),
      );

      expect(find.text('app child'), findsOneWidget);
      expect(find.byType(BlackBoxOverlay), findsNothing);
    } finally {
      BlackBox.dispose();
      await tester.runAsync(
        () => BlackBoxOverlayPreferences.instance.setVisible(true),
      );
      await tester.pump();
    }
  });
}
