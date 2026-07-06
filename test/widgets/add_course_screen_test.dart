import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_widgets.dart';
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

String _weekdayLabelForTest(int weekday) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[weekday - 1];
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
        child: TestApp(home: AddCourseScreen(course: course)),
      ),
    );
    await _pumpScreen(tester);

    expect(find.bySemanticsLabel('删除课程'), findsOneWidget);
  });

  testWidgets('editing course with invalid color still renders', (
    tester,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final course = Course(
      id: 'course-invalid-color',
      name: '离散数学',
      teacher: '周老师',
      location: 'A201',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      color: 'invalid-color',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(home: AddCourseScreen(course: course)),
      ),
    );
    await _pumpScreen(tester);

    expect(find.text('离散数学'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single lesson mode can default to today weekday', (
    tester,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final todayWeekday = DateTime.now().weekday;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: AddCourseScreen(initialWeek: 4, initialDayOfWeek: todayWeekday),
        ),
      ),
    );
    await _pumpScreen(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await _pumpScreen(tester);

    expect(
      find.textContaining(_weekdayLabelForTest(todayWeekday)),
      findsWidgets,
    );
  });

  testWidgets('custom week grid wraps earlier on narrow screens', (
    tester,
  ) async {
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
        child: const TestApp(home: AddCourseScreen()),
      ),
    );
    await _pumpScreen(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await _pumpScreen(tester);
    // Open week picker dialog
    await tester.tap(find.textContaining('哪些周上'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义周'));
    await _pumpScreen(tester);

    final weekOne = find.text('1');
    final weekFive = find.text('5');

    expect(weekOne, findsOneWidget);
    expect(weekFive, findsOneWidget);
    expect(
      tester.getTopLeft(weekFive).dy,
      greaterThan(tester.getTopLeft(weekOne).dy),
    );
    final weekOneTile = find.ancestor(
      of: weekOne,
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(weekOneTile).height, greaterThanOrEqualTo(44));
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
        child: const TestApp(home: AddCourseScreen()),
      ),
    );
    await _pumpScreen(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await _pumpScreen(tester);

    // Open week picker dialog
    await tester.tap(find.textContaining('哪些周上'));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('单周'), findsOneWidget);
    expect(find.text('双周'), findsOneWidget);

    await tester.tap(find.text('单周'));
    await _pumpScreen(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(HyperosChoiceTile, '单周'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });
}
