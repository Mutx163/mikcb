import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_task_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

/// 作业表单保存后**真正落到 provider 上的数据**（2026-10-21）。
///
/// 判据本身在 `test/domain/task_form_defaults_test.dart`（纯函数）。这里验证的
/// 是另一层：页面确实用了那套判据，且「只填标题点保存」这条路走通、存下来的
/// 作业能在「今日」里被看见。
///
/// 背景：新建时截止日期原先默认关闭，用户从「今日」tab 点 + 记一件事，回到列表
/// 却是空的（无日期的作业在日视图、今日、本周三处全不可见），看着像没保存。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Course course() => Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  Future<TimetableProvider> pumpForm(
    WidgetTester tester, {
    CourseTask? task,
    Course? initialCourse,
    int? initialWeek,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390x844
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: AddTaskScreen(
            task: task,
            initialCourse: initialCourse,
            initialWeek: initialWeek,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await runRealAsync(tester, () async {
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pump();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('纯新建 + 只填标题 → 存下来的作业带今天，且能在「今日」里看到', (
    WidgetTester tester,
  ) async {
    final provider = await pumpForm(tester);

    await tester.enterText(find.byType(TextField).first, '记一件事');
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(provider.tasks, hasLength(1), reason: '只填标题就该能存');
    final saved = provider.tasks.single;
    expect(saved.title, '记一件事');
    expect(
      saved.dueDate,
      CourseTask.dateOnly(DateTime.now()),
      reason: '无日期的作业在日视图与「今日」里都不可见，默认必须是今天',
    );
    expect(
      saved.isDueOn(DateTime.now()),
      isTrue,
      reason: '这条作业应当出现在清单页的「今日」筛选里',
    );
  });

  testWidgets('纯新建：打开时不显示「不设日期」的后果提示', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);

    expect(
      find.text('不设截止日期，日视图就不显示'),
      findsNothing,
      reason: '默认已填今天，不该再出现这句灰字',
    );
  });

  testWidgets('编辑已有作业 → 原有截止日不被覆盖成今天', (
    WidgetTester tester,
  ) async {
    // 不挂课程：provider 里没有 'c1'，挂上会被 `_validateTask` 以
    // `task_course_not_found` 拒掉（那是另一个校验，不该混进这条用例）。
    final task = CourseTask(
      id: 't1',
      title: '第三章习题',
      dueDate: DateTime(2026, 11, 20),
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );
    final provider = await pumpForm(tester, task: task);
    // 编辑态走 `updateTask`，它在条目不存在时**静默返回**（`index == -1`），
    // 所以必须先把这条作业放进 provider，否则保存什么都不会发生。
    await runRealAsync(tester, () async {
      await provider.addTask(task);
    });
    await tapSave(tester);

    final saved = provider.tasks.where((t) => t.id == 't1').firstOrNull;
    expect(saved, isNotNull);
    expect(
      saved!.dueDate,
      DateTime(2026, 11, 20),
      reason: '「默认今天」只对新建生效；编辑态沿用原值',
    );
  });

  testWidgets('编辑已有作业：标题是「编辑任务」，不是「添加任务」', (
    WidgetTester tester,
  ) async {
    final task = CourseTask(
      id: 't1',
      title: '第三章习题',
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );
    await pumpForm(tester, task: task);

    // 顶栏与折叠大标题各渲染一份，用 findsWidgets。
    expect(find.text('编辑任务'), findsWidgets);
    expect(find.text('添加任务'), findsNothing);
  });

  testWidgets('从课程加作业 → 课程与周次都落到存下来的作业上', (
    WidgetTester tester,
  ) async {
    final provider = await pumpForm(
      tester,
      initialCourse: course(),
      initialWeek: 2,
    );
    // 课程必须真的存在于 provider 里，否则保存会被 `task_course_not_found`
    // 拒掉——那验的就不是本次改动了。
    await runRealAsync(tester, () async {
      await provider.addCourse(course());
    });
    await tester.enterText(find.byType(TextField).first, '预习第三章');
    await tester.pumpAndSettle();
    await tapSave(tester);

    final saved = provider.tasks.where((t) => t.title == '预习第三章').firstOrNull;
    expect(saved, isNotNull);
    expect(saved!.courseId, 'c1');
    expect(saved.sourceWeek, 2);
  });
}
