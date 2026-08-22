import 'dart:async';
import 'dart:convert';

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

// Regression context: a post-build, unawaited updateCourseGroup used to starve
// outside the mutation-gate queue forever in widget tests. Two mechanisms were
// at play (validated with minimal probes): (1) creating the provider inside
// tester.runAsync leaves every gate Future in the real zone, so fake-async
// pumps can never drain them — fixed by issuing ONE bridge op from the test
// zone after seeding; (2) a persisted mutation crosses the plugin message
// channel mid-action, so its completion lives on the real event loop anyway —
// hence the runAsync polling loop instead of pump-driven waiting.

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
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

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
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

  testWidgets('post-build course group update lands and notifies on plain week view', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final now = DateTime.now();

    // Seed inside the real zone: initialization-time I/O must not race the
    // seeding mutations, and none of these futures may outlive this block.
    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(now),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await provider.addCourse(
        Course(
          id: 'today-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(provider.courses.first.color, isNotNull);

    // Bridge: hand the mutation gate tail back to the test (fake-async) zone.
    // Without this, the unawaited mutation below starves forever (see header).
    var bridged = false;
    unawaited(provider.setCurrentWeek(1).then((_) => bridged = true));
    for (var i = 0; i < 40 && !bridged; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(bridged, true, reason: 'bridge op must land so the gate tail returns to the test zone');

    var notified = 0;
    provider.addListener(() => notified++);

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Post-build mutation, not awaited (mirrors the async on-device save flow).
    final group = provider.courseGroupForCourse(provider.courses.first)!;
    final updated = group.courses.map((c) => c.copyWith(color: '#4CAF50')).toList();
    unawaited(provider.updateCourseGroup(group.name, updated));

    // Persistence inside the mutation crosses the plugin message channel, so
    // its futures complete on the real event loop: poll with runAsync (the
    // repo-wide pattern, cf. add_course_screen_test) instead of fake pumps.
    var landed = false;
    for (var i = 0; i < 60 && !landed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // The colour flips mid-action; only notifyListeners (after persist)
      // proves the whole mutation completed.
      landed = provider.courses.first.color == '#4CAF50' && notified > 0;
    }
    expect(landed, true, reason: 'post-build updateCourseGroup must land while frames pump');
    expect(notified, greaterThan(0),
        reason: 'landing must notifyListeners so the agenda card repaints');
  });
}
