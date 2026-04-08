import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  testWidgets('editing course shows delete action', (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final course = Course(
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

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: AddCourseScreen(course: course),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('删除课程'), findsOneWidget);
  });

  testWidgets('single lesson mode shows simplified week selector',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: AddCourseScreen(
            mode: CourseEditorMode.singleLesson,
            initialWeek: 4,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.text('添加单节课'), findsOneWidget);
    expect(find.text('上课周次'), findsOneWidget);
    expect(find.text('连续周'), findsNothing);
  });

  testWidgets('single lesson mode can prefill from existing course',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-template',
        name: '大学英语',
        shortName: '英语',
        teacher: '李老师',
        location: 'A101',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:10',
        endTime: '11:50',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: AddCourseScreen(
            mode: CourseEditorMode.singleLesson,
            initialWeek: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大学英语 · 英语 · 李老师').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final fieldValues = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((widget) => widget.controller.text)
        .toList();

    expect(fieldValues, contains('大学英语'));
    expect(fieldValues, contains('李老师'));
    expect(fieldValues, isNot(contains('A101')));
  });

  testWidgets('single lesson template dropdown does not overflow on long text',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-long-template',
        name: '大学英语精读与跨文化交流',
        teacher: '李老师',
        location: '教学楼A区101多媒体智慧教室超长地点',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:10',
        endTime: '11:50',
      ),
    );

    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: AddCourseScreen(
            mode: CourseEditorMode.singleLesson,
            initialWeek: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('手动填写'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('大学英语精读与跨文化交流').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('custom week grid wraps earlier on narrow screens',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: AddCourseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义周'));
    await tester.pumpAndSettle();

    final weekOne = find.widgetWithText(FilledButton, '1');
    final weekFive = find.widgetWithText(FilledButton, '5');

    expect(weekOne, findsOneWidget);
    expect(weekFive, findsOneWidget);
    expect(tester.getTopLeft(weekFive).dy,
        greaterThan(tester.getTopLeft(weekOne).dy));
    expect(tester.getSize(weekOne).height, greaterThanOrEqualTo(44));
  });

  testWidgets('range week filter uses compact parity chips', (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: AddCourseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));

    await tester.tap(find.widgetWithText(ChoiceChip, '单周'));
    await tester.pumpAndSettle();

    final selectedChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '单周'),
    );
    expect(selectedChip.selected, isTrue);
    expect(find.text('只保留范围内的单周。'), findsOneWidget);
  });
}
