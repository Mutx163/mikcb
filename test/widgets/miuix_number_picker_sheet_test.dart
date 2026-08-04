import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/miuix_fling_number_picker.dart';
import 'package:university_timetable/widgets/miuix_number_picker_sheet.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('快速甩动后立即确认返回最终节次', (tester) async {
    Future<int?>? resultFuture;

    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(),
        child: TestApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  resultFuture = showMiuixNumberPickerSheet(
                    context,
                    title: '开始节次',
                    currentValue: 8,
                    minValue: 1,
                    maxValue: 13,
                    label: (value) => '第$value节',
                  );
                },
                child: const Text('打开选择器'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();

    final picker = find.byType(MiuixFlingNumberPicker);
    expect(picker, findsOneWidget);
    await tester.fling(picker, const Offset(0, -90), 3000);
    await tester.pump();

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(resultFuture, isNotNull);
    expect(await resultFuture, 13);
  });
}
