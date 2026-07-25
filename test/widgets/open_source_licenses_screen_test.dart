import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/open_source_licenses_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(<String>[
        'demo_package',
      ], 'Demo License\n\nPermission is hereby granted.');
      yield const LicenseEntryWithLineBreaks(<String>[
        'another_package',
      ], 'Another License Body');
    });
  });

  tearDown(LicenseRegistry.reset);

  test('loadOpenSourcePackageLicenses groups and sorts packages', () async {
    final packages = await loadOpenSourcePackageLicenses();
    expect(packages.map((item) => item.packageName), [
      'another_package',
      'demo_package',
    ]);
    expect(
      packages.first.combinedLicenseText,
      contains('Another License Body'),
    );
  });

  testWidgets('OpenSourceLicensesScreen lists packages from registry', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: OpenSourceLicensesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('开源许可'), findsOneWidget);
    expect(find.text('许可说明'), findsOneWidget);
    expect(find.text('demo_package'), findsOneWidget);
    expect(find.text('another_package'), findsOneWidget);

    await tester.tap(find.text('demo_package'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Demo License'), findsOneWidget);
    expect(find.textContaining('Permission is hereby granted'), findsOneWidget);
  });

  testWidgets('license detail keeps body below overlay header and scrolls', (
    tester,
  ) async {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(const <String>[
        'long_package',
      ], List.generate(80, (index) => 'License line $index').join('\n'));
    });

    await tester.pumpWidget(const TestApp(home: OpenSourceLicensesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('long_package'));
    await tester.pumpAndSettle();

    // After push settles, overlay header inset must be applied so the first
    // lines are not stuck under the title bar.
    final scope = tester.widget<HyperosBlurredHeaderScope>(
      find.byType(HyperosBlurredHeaderScope).last,
    );
    expect(scope.contentTopInset, greaterThan(0));

    // children mode uses SingleChildScrollView (keeps form fields mounted).
    final scrollView = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(HyperosListView).last,
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final padding = scrollView.padding!.resolve(TextDirection.ltr);
    expect(padding.top, greaterThanOrEqualTo(scope.contentTopInset));

    final scrollable = find.descendant(
      of: find.byType(HyperosListView).last,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.textContaining('License line 70'), findsOneWidget);
  });

  testWidgets('search filters package list', (tester) async {
    await tester.pumpWidget(const TestApp(home: OpenSourceLicensesScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'demo');
    await tester.pumpAndSettle();

    expect(find.text('demo_package'), findsOneWidget);
    expect(find.text('another_package'), findsNothing);
  });
}
