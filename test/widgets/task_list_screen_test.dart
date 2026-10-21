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
  testWidgets('切到「今日」时，无截止日期的作业有一条可点提示', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      // 用户从日视图加过一条、后来把截止日期关掉了
      await provider.addTask(
        CourseTask(
          id: 'undated-1',
          title: '忘了设日期的作业',
          createdAt: DateTime(2026, 10, 20),
          updatedAt: DateTime(2026, 10, 20),
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

    // 「全部」档能看到它，此时没有提示（因为没被筛掉）
    expect(find.text('忘了设日期的作业'), findsOneWidget);
    expect(find.textContaining('没设截止日期'), findsNothing);

    // 切到「今日」：作业被筛掉，但出现一条能点回「全部」的提示
    await tester.tap(find.text('今日').first);
    await tester.pumpAndSettle();

    expect(
      find.text('忘了设日期的作业'),
      findsNothing,
      reason: '无日期不归属任何一天，今日不该列出它',
    );
    final hint = find.textContaining('没设截止日期');
    expect(
      hint,
      findsOneWidget,
      reason: '必须告诉用户它去哪了，否则看起来像凭空消失',
    );

    // 点提示 → 切回「全部」→ 又能看到
    await tester.tap(hint);
    await tester.pumpAndSettle();
    expect(find.text('忘了设日期的作业'), findsOneWidget);
  });
}
