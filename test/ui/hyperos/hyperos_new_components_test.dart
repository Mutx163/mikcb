import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HyperosDialog', () {
    testWidgets('shows title, message, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showHyperosDialog<void>(
                    context: context,
                    title: 'Delete item',
                    message: 'This cannot be undone.',
                    actions: [
                      HyperosDialogAction(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                      HyperosDialogAction(
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete item'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('confirm dialog returns true on confirm', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await showHyperosConfirmDialog(
                    context: context,
                    title: 'Confirm',
                    message: 'Proceed?',
                    cancelLabel: 'No',
                    confirmLabel: 'Yes',
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('HyperosNavTile', () {
    testWidgets('navigates without icon badge', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosNavTile(
                  title: 'Advanced',
                  details: 'On',
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HyperosIconBadge), findsNothing);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('HyperosDangerTile', () {
    testWidgets('fires onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosDangerTile(
                  title: 'Clear data',
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Clear data'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('HyperosTextField', () {
    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosTextField(
              controller: controller,
              label: 'Name',
              hint: 'Enter name',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Alice');
      expect(controller.text, 'Alice');
    });
  });

  group('HyperosTabRow', () {
    testWidgets('changes selection', (tester) async {
      var index = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosTabRow(
              tabs: const ['A', 'B'],
              selectedIndex: index,
              onChanged: (v) => index = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(index, 1);
    });
  });

  group('HyperosCheckbox', () {
    testWidgets('toggles value', (tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosCheckbox(value: value, onChanged: (v) => value = v),
          ),
        ),
      );

      await tester.tap(find.byType(HyperosCheckbox));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });
  });

  group('HyperosNumberPicker', () {
    testWidgets('renders wheel with selected value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosNumberPicker(
              min: 1,
              max: 3,
              value: 2,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('2'), findsWidgets);
    });
  });

  group('HyperosListTile', () {
    testWidgets('keeps one character gap between details and chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HyperosListTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                details: 'Light',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final detailsRect = tester.getRect(find.text('Light'));
      final chevronRect = tester.getRect(find.byType(HyperosChevron));

      expect(
        chevronRect.left - detailsRect.right,
        greaterThanOrEqualTo(HyperosTokens.detailChevronGap - 1),
      );
    });

    testWidgets('uses standard trailing inset for icon rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosListTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(HyperosListGroup));
      final titleRect = tester.getRect(find.text('Appearance'));
      final chevronRect = tester.getRect(find.byType(HyperosChevron));
      final leadingInset = titleRect.left - cardRect.left;
      final trailingInset = cardRect.right - chevronRect.right;

      expect(leadingInset, greaterThan(HyperosTokens.rowPaddingUniform.left));
      expect(trailingInset, closeTo(HyperosTokens.rowPaddingUniform.right, 1));
    });
  });

  group('HyperosEmptyState', () {
    testWidgets('shows title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HyperosEmptyState(
              title: 'No courses',
              subtitle: 'Add one to get started',
            ),
          ),
        ),
      );

      expect(find.text('No courses'), findsOneWidget);
      expect(find.text('Add one to get started'), findsOneWidget);
    });
  });

  group('HyperosIconButton', () {
    testWidgets('fires onPressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosIconButton(
              icon: Icons.settings,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HyperosIconButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('HyperosBadge', () {
    testWidgets('shows numeric label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HyperosBadge(
              label: '3',
              child: Icon(Icons.notifications_outlined),
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('HyperosCheckboxTile', () {
    testWidgets('toggles on row tap', (tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosCheckboxTile(
                  title: 'Option',
                  value: value,
                  onChanged: (v) => value = v,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Option'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });
  });

  group('HyperosLinearProgress', () {
    testWidgets('renders determinate bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HyperosLinearProgress(value: 0.5)),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('HyperosColorChip', () {
    testWidgets('selects color on tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosColorChip(
              color: Colors.blue,
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HyperosColorChip));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('HyperosNavigationBar', () {
    testWidgets('changes destination', (tester) async {
      var index = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosNavigationBar(
              destinations: const [
                HyperosNavigationDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                ),
                HyperosNavigationDestination(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
              selectedIndex: index,
              onDestinationSelected: (v) => index = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(index, 1);
    });
  });

  group('HyperosTag', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HyperosTag(label: 'Beta')),
        ),
      );
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  group('HyperosHintBanner', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HyperosHintBanner(title: Text('Hint text'))),
        ),
      );
      expect(find.text('Hint text'), findsOneWidget);
    });
  });

  group('HyperosAccordion', () {
    testWidgets('expands section on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosAccordion(
              items: const [
                HyperosAccordionItem(
                  title: Text('Section'),
                  child: Text('Body'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Body'), findsNothing);
      await tester.tap(find.text('Section'));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
    });
  });

  group('showHyperosRichSnackBar', () {
    testWidgets('shows message and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showHyperosRichSnackBar(
                      context,
                      message: 'Saved',
                      description: 'Changes applied',
                      duration: const Duration(seconds: 10),
                    );
                  },
                  child: const Text('toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Changes applied'), findsOneWidget);
      hideHyperosToast(animated: false);
      await tester.pump();
    });
  });

  group('HyperosSwitchTile two-line', () {
    testWidgets('subtitle row does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: 'Dark mode',
                  subtitle: 'Follow system',
                  value: false,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('subtitle row does not overflow when width is narrow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: HyperosListGroup(
                children: [
                  HyperosSwitchTile(
                    title: '课中状态提醒',
                    subtitle: '下课前尝试切到超级岛 / 重点提醒',
                    value: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
