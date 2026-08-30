import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/miuix_fling_number_picker.dart';
import 'package:university_timetable/widgets/miuix_time_picker_sheet.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHarness(void Function(BuildContext) onOpen) {
    return MiuixTheme(
      data: MiuixThemeData.light(),
      child: TestApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onOpen(context),
              child: const Text('打开时间'),
            ),
          ),
        ),
      ),
    );
  }

  Future<(Future<TimeOfDay?>?, WidgetTester)> openSheet(
    WidgetTester tester,
  ) async {
    Future<TimeOfDay?>? resultFuture;
    await tester.pumpWidget(
      buildHarness((context) {
        resultFuture = showMiuixTimePickerSheet(
          context,
          initialTime: const TimeOfDay(hour: 8, minute: 5),
          title: '开始时间',
        );
      }),
    );
    await tester.tap(find.text('打开时间'));
    await tester.pumpAndSettle();
    return (resultFuture, tester);
  }

  testWidgets('未拨动滚轮时确认返回初始时间', (tester) async {
    final (resultFuture, _) = await openSheet(tester);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(await resultFuture, const TimeOfDay(hour: 8, minute: 5));
  });

  testWidgets('甩动分轮后立即确认使用最终落点而非旧值', (tester) async {
    final (resultFuture, _) = await openSheet(tester);

    final pickerFinder = find.byType(MiuixFlingNumberPicker);
    expect(pickerFinder, findsNWidgets(2));
    // 分轮快速下甩（往更小分钟方向环绕），惯性动画进行中直接点确认。
    await tester.fling(pickerFinder.at(1), const Offset(0, 200), 30000);
    await tester.pump();

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    final selected = await resultFuture;
    expect(selected, isNotNull);
    expect(selected!.hour, 8);
    // 旧实现会在惯性未结束时回传初始分钟 5；确认必须同步结算投影落点。
    expect(selected.minute, isNot(5));
  });
}
