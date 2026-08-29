import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/screens/add_task_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('add task course sheet shows one row per course and scrolls', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    final first = Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
    // 同一门课的第二个时段：绑定弹窗里只应出现一次「高等数学」。
    final second = first.copyWith(
      id: 'course-2',
      dayOfWeek: 3,
      startSection: 3,
      endSection: 4,
    );
    final other = first.copyWith(
      id: 'course-3',
      name: '大学英语',
      dayOfWeek: 2,
      startSection: 1,
      endSection: 2,
    );
    await runRealAsync(tester, () async {
      await provider.addCourse(first);
      await provider.addCourse(second);
      await provider.addCourse(other);
    });

    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const AddTaskScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('无关联课程').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(HyperosChoiceGroup),
        matching: find.text('高等数学'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(HyperosChoiceGroup),
        matching: find.text('大学英语'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsWidgets);

    // 选中分组后绑定到该组的第一个课时：表单行显示课程名，弹窗关闭。
    await tester.tap(find.text('高等数学'));
    await tester.pumpAndSettle();
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.byType(HyperosChoiceGroup), findsNothing);

    // 截止日期开关打开后，日期只应显示一次（下方选择行），开关行不重复显示。
    await tester.tap(find.text('截止日期'));
    await tester.pumpAndSettle();
    final expectedDate = DateFormat.yMMMMd(
      'zh',
    ).format(CourseTask.dateOnly(DateTime.now()));
    expect(find.text(expectedDate), findsOneWidget);
  });
}
