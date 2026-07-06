import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosSwitchTile', () {
    testWidgets('uses HyperosSwitch and toggles on row tap', (tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: 'Dark mode',
                  subtitle: 'Follow system',
                  value: value,
                  onChanged: (v) => value = v,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HyperosSwitch), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Follow system'), findsOneWidget);

      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('disabled tile does not toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosSwitchTile(
              title: 'Locked',
              value: false,
              onChanged: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(find.byType(HyperosSwitch), findsOneWidget);
    });
  });

  group('HyperosSlider', () {
    testWidgets('renders with Miuix track height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HyperosSlider(value: 0.5, onChanged: (_) {})),
        ),
      );

      final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(box.height, HyperosMiuixSlider.minHeight);
    });
  });

  group('HyperosControlCard', () {
    testWidgets('shows title and child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosControlCard(
              title: 'Layout',
              subtitle: 'Adjust spacing',
              child: const Text('body'),
            ),
          ),
        ),
      );

      expect(find.text('Layout'), findsOneWidget);
      expect(find.text('Adjust spacing'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('HyperosButton', () {
    testWidgets('primary button fires onPressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosButton(label: 'Save', onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('loading disables tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosButton(
              label: 'Save',
              loading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HyperosButton));
      await tester.pump();
      expect(tapped, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
