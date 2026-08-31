import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import '../helpers_test_app.dart';

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final settings = TimetableSettings.defaults();
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
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

  testWidgets('home timetable shows conflict badge when enabled', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '软件工程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-b',
          name: '计算机网络',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 2,
          endSection: 3,
          startTime: '08:55',
          endTime: '10:35',
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('冲突'), findsWidgets);

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(showConflictBadgeOnTimetable: false),
      );
    });
    await _pumpTimetableFrame(tester);

    expect(find.text('冲突'), findsNothing);
  });

  testWidgets('home timetable renders overlapping conflict courses together', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '软件工程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-b',
          name: '计算机网络',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 2,
          endSection: 3,
          startTime: '08:55',
          endTime: '10:35',
        ),
      );
    });

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          showConflictBadgeOnTimetable: false,
          timetableConflictCourseOpacity: 0.6,
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('软件工程'), findsOneWidget);
    expect(find.text('计算机网络'), findsOneWidget);
  });

  testWidgets('tapping a conflicting course shows both course cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '软件工程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'course-b',
          name: '计算机网络',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 2,
          endSection: 3,
          startTime: '08:55',
          endTime: '10:35',
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.text('软件工程'));
    await _pumpTimetableFrame(tester);

    // Selected course is shown fully; related conflicts start collapsed.
    expect(
      find.byKey(const ValueKey('course-action-content-course-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-action-reschedule-course-a')),
      findsOneWidget,
    );
    expect(find.text('计算机网络'), findsWidgets);

    // Expand the related panel so the conflicting course detail is available.
    final conflictPanel = find.textContaining('冲突');
    expect(conflictPanel, findsWidgets);
    await tester.tap(conflictPanel.first);
    await _pumpTimetableFrame(tester);
    expect(find.text('计算机网络'), findsWidgets);
  });

  testWidgets('home timetable can show non-current-week courses separately', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.setCurrentWeek(1);
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'current-course',
          name: '本周课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          endWeek: 1,
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'other-week-course',
          name: '非本周课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          startWeek: 2,
          endWeek: 2,
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('本周课程'), findsOneWidget);
    expect(find.text('非本周课程'), findsNothing);

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(timetableShowNonCurrentWeekCourses: true),
      );
    });
    await _pumpTimetableFrame(tester);

    expect(find.text('本周课程'), findsOneWidget);
    expect(find.text('非本周课程'), findsOneWidget);
  });

  testWidgets('non-current-week course does not overlap current-week course', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.setCurrentWeek(1);
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'current-course',
          name: '本周课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          endWeek: 1,
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'other-week-course',
          name: '非本周课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 2,
          endWeek: 2,
        ),
      );
    });

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(timetableShowNonCurrentWeekCourses: true),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('本周课程'), findsOneWidget);
    expect(find.text('非本周课程'), findsNothing);
    expect(find.text('非本周'), findsNothing);
  });

  testWidgets('non-current-week course shows overline when displayed', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.setCurrentWeek(1);
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'other-week-course',
          name: '非本周课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          startWeek: 2,
          endWeek: 2,
        ),
      );
    });

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(timetableShowNonCurrentWeekCourses: true),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('非本周课程'), findsOneWidget);
    expect(find.text('非本周'), findsOneWidget);
  });

  testWidgets('overlapping non-current-week courses only show nearest one', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
      await provider.setCurrentWeek(5);
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'near-course',
          name: '较近非本周课',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 6,
          endWeek: 6,
        ),
      );
    });
    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'far-course',
          name: '较远非本周课',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 10,
          endWeek: 10,
        ),
      );
    });

    await runRealAsync(tester, () async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(timetableShowNonCurrentWeekCourses: true),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('较近非本周课'), findsOneWidget);
    expect(find.text('较远非本周课'), findsNothing);
    expect(find.text('非本周'), findsOneWidget);
  });
}
