import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/course_overview_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import '../helpers_test_app.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
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

  setUp(() async {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    // Ensure mock prefs are live before any StorageService.init().
    await SharedPreferences.getInstance();
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

  testWidgets('course overview marks actual conflicts', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
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
    });
    await runRealAsync(tester, () async {
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
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: CourseOverviewScreen()),
      ),
    );
    await _pumpScreen(tester);

    // Single entry into the dedicated conflict page (not the old banner/split list).
    expect(find.text('查看冲突详情'), findsOneWidget);
    // Two schedule entries participate in the conflict → "冲突 2 节".
    expect(find.text('冲突 2 节'), findsOneWidget);
    // Each conflicting course group is tagged in the main list.
    expect(find.text('冲突'), findsNWidgets(2));
    expect(find.text('线性代数'), findsOneWidget);
    expect(find.text('大学物理'), findsOneWidget);
  });

  testWidgets('course overview does not mark same slot on different weeks', (
    tester,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    await runRealAsync(tester, () async {
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
    });
    await runRealAsync(tester, () async {
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
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: CourseOverviewScreen()),
      ),
    );
    await _pumpScreen(tester);

    expect(find.text('查看冲突详情'), findsNothing);
    expect(find.textContaining('冲突 '), findsNothing);
    expect(find.text('冲突'), findsNothing);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('大学英语'), findsOneWidget);
  });
}
