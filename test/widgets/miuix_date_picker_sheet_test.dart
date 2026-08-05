import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/miuix_date_picker_sheet.dart';
import 'package:university_timetable/widgets/miuix_fling_number_picker.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('日期滚轮快速确认使用最终落点并遵循传入年份范围', (tester) async {
    Future<DateTime?>? resultFuture;

    await tester.pumpWidget(
      MiuixTheme(
        data: MiuixThemeData.light(),
        child: TestApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  resultFuture = showMiuixDatePickerSheet(
                    context,
                    initialDate: DateTime(2026, 3, 2),
                    firstDate: DateTime(1970),
                    lastDate: DateTime(2100, 12, 31),
                    title: '开始日期',
                  );
                },
                child: const Text('打开日期'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开日期'));
    await tester.pumpAndSettle();

    final calendarFinder = find.byType(MiuixDatePicker);
    expect(calendarFinder, findsOneWidget);
    final calendarRect = tester.getRect(calendarFinder);
    await tester.tapAt(Offset(calendarRect.center.dx, calendarRect.top + 32));
    await tester.pumpAndSettle();

    final pickerFinder = find.byType(MiuixFlingNumberPicker);
    expect(pickerFinder, findsNWidgets(3));
    await tester.fling(pickerFinder.first, const Offset(0, 200), 30000);
    await tester.pump();

    await tester.tap(find.text('确认').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(resultFuture, isNotNull);
    final selectedDate = await resultFuture;
    expect(selectedDate, isNotNull);
    expect(selectedDate!.year, lessThan(2020));
    expect(selectedDate.year, greaterThanOrEqualTo(1970));
    expect(selectedDate.month, 3);
    expect(selectedDate.day, 2);
  });
}
