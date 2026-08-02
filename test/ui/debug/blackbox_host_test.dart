import 'package:flutter/material.dart';
import 'package:flutter_blackbox/flutter_blackbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/debug/blackbox_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps the app child visible in the BlackBox host', (tester) async {
    try {
      BlackBox.setup(
        enabled: true,
        trigger: const BlackBoxTrigger.none(),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BlackBoxOverlayHost(
            child: Scaffold(body: Text('app child')),
          ),
        ),
      );

      expect(find.text('app child'), findsOneWidget);
      expect(find.byType(BlackBoxOverlay), findsOneWidget);
    } finally {
      BlackBox.dispose();
      await tester.pump();
    }
  });
}
