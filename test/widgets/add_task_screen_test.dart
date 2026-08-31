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

  testWidgets('new task saves completion toggle state', (tester) async {
    final provider = await createInitializedTestProvider(tester);

    // Provider 必须包在 MaterialApp 之上：push 出来的新路由看不到 home 内部的 provider。
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: _TaskEditorLauncher()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-task-editor'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '写读书笔记');
    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(_switchValue(tester, '已完成'), isTrue);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump(const Duration(milliseconds: 120));

    // 持久化要跨插件消息通道：用 runAsync 驱动真实时间等待落库，
    // 再等关页过渡动画结束（repo 通用模式）。
    var landed = false;
    for (var i = 0; i < 60 && !landed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      landed = provider.tasks.isNotEmpty;
    }
    expect(landed, isTrue);
    await _pumpUntilClosed(tester);

    expect(provider.tasks, hasLength(1));
    expect(provider.tasks.first.title, '写读书笔记');
    expect(provider.tasks.first.isCompleted, isTrue);
    expect(provider.tasks.first.courseId, isNull);
  });

  testWidgets('edit task reflects completion state and can uncomplete', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    final task = CourseTask(
      id: 'task-1',
      title: '完成作业',
      isCompleted: true,
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
    );
    await runRealAsync(tester, () => provider.addTask(task));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: _TaskEditorLauncher(task: task)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-task-editor'));
    await tester.pumpAndSettle();

    // 已完成任务的编辑页应回显完成状态。
    expect(_switchValue(tester, '已完成'), isTrue);

    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(_switchValue(tester, '已完成'), isFalse);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump(const Duration(milliseconds: 120));

    var landed = false;
    for (var i = 0; i < 60 && !landed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      landed = provider.tasks.firstOrNull?.isCompleted == false;
    }
    expect(landed, isTrue);
    await _pumpUntilClosed(tester);

    expect(provider.tasks, hasLength(1));
    expect(provider.tasks.first.isCompleted, isFalse);
    expect(provider.tasks.first.title, '完成作业');
  });
}

/// 通过真实导航推入任务编辑页，让保存后的 Navigator.pop 有可回退的路由。
class _TaskEditorLauncher extends StatelessWidget {
  const _TaskEditorLauncher({this.task});

  final CourseTask? task;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => AddTaskScreen(task: task)),
          ),
          child: const Text('open-task-editor'),
        ),
      ),
    );
  }
}

bool _switchValue(WidgetTester tester, String label) {
  return tester
      .widget<HyperosSwitch>(
        find.descendant(
          of: find.widgetWithText(HyperosSwitchTile, label),
          matching: find.byType(HyperosSwitch),
        ),
      )
      .value;
}

Future<void> _pumpUntilClosed(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(AddTaskScreen).evaluate().isEmpty) {
      break;
    }
  }
}
