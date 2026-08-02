import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/ui/debug/blackbox_host.dart';
import 'package:university_timetable/ui/debug/debug_tuning_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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
