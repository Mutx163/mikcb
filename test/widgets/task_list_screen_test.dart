import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/screens/task_list_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('task filters use Miuix contour tabs and unique course names', (
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
    final second = first.copyWith(
      id: 'course-2',
      dayOfWeek: 3,
      startSection: 3,
      endSection: 4,
    );
    await runRealAsync(tester, () async {
      await provider.addCourse(first);
      await provider.addCourse(second);
      await provider.addTask(
        CourseTask(
          id: 'task-1',
          title: '完成作业',
          courseId: first.id,
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8),
        ),
      );
    });

    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const TaskListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiuixTabRowWithContour), findsOneWidget);
    await tester.tap(find.text('课程筛选'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(HyperosChoiceGroup),
        matching: find.text('高等数学'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
