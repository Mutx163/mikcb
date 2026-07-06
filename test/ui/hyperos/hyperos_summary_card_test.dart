import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosSummaryCard', () {
    testWidgets('shows title, subtitle, and leading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HyperosSummaryCard(
              leading: Icon(Icons.school_outlined, size: 44),
              title: '第 3 周 / 共 20 周',
              subtitle: '学期开始：2026-02-17',
            ),
          ),
        ),
      );

      expect(find.text('第 3 周 / 共 20 周'), findsOneWidget);
      expect(find.text('学期开始：2026-02-17'), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('invokes onTap when pressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosSummaryCard(
              leading: const Icon(Icons.school_outlined, size: 44),
              title: 'Summary',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Summary'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
