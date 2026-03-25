import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/course_overview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel =
      MethodChannel('com.example.university_timetable/home_widget');
  const analyticsChannel =
      MethodChannel('com.example.university_timetable/umeng_analytics');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
  });

  testWidgets('course overview marks actual conflicts', (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-a',
        name: '线性代数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-b',
        name: '大学物理',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 2,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:35',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: CourseOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('检测到 2 门排课存在实际冲突'), findsOneWidget);
    expect(find.text('冲突 1 节'), findsNWidgets(2));
    expect(find.textContaining('展开查看冲突详情'), findsWidgets);
    await tester.tap(find.text('线性代数'));
    await tester.pumpAndSettle();
    expect(find.textContaining('冲突课程:'), findsOneWidget);
    expect(find.textContaining('第1-16周'), findsOneWidget);
  });

  testWidgets('course overview does not mark same slot on different weeks',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-a',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 2,
        startWeek: 1,
        endWeek: 8,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-b',
        name: '大学英语',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 2,
        startWeek: 9,
        endWeek: 16,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: CourseOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('检测到'), findsNothing);
    expect(find.textContaining('冲突 '), findsNothing);
    expect(find.textContaining('展开查看冲突详情'), findsNothing);
  });
}
