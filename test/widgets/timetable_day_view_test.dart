import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';

import '../helpers_test_app.dart';

String _weekdayLabelForTest(int weekday) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[weekday - 1];
}

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpFiniteFrames(
  WidgetTester tester, {
  int count = 8,
  Duration step = const Duration(milliseconds: 80),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

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

String _formatClock(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<SectionTime> _inProgressSections(DateTime now) {
  final currentMinutes = now.hour * 60 + now.minute;
  final firstStartMinutes = math.max(0, currentMinutes - 20);
  final firstEndMinutes = math.max(firstStartMinutes + 1, currentMinutes - 10);
  final secondStartMinutes = math.max(firstEndMinutes + 1, currentMinutes - 5);
  final secondEndMinutes = currentMinutes + 10;
  return [
    SectionTime(
      startTime: _formatClock(firstStartMinutes ~/ 60, firstStartMinutes % 60),
      endTime: _formatClock(firstEndMinutes ~/ 60, firstEndMinutes % 60),
    ),
    SectionTime(
      startTime: _formatClock(
        secondStartMinutes ~/ 60,
        secondStartMinutes % 60,
      ),
      endTime: _formatClock(secondEndMinutes ~/ 60, secondEndMinutes % 60),
    ),
  ];
}

List<SectionTime> _outOfProgressSections(DateTime now) {
  if (now.hour <= 21) {
    final firstStart = now.add(const Duration(hours: 1));
    final firstEnd = firstStart.add(const Duration(minutes: 10));
    final secondStart = firstEnd.add(const Duration(minutes: 10));
    final secondEnd = secondStart.add(const Duration(minutes: 20));
    return [
      SectionTime(
        startTime: _formatClock(firstStart.hour, firstStart.minute),
        endTime: _formatClock(firstEnd.hour, firstEnd.minute),
      ),
      SectionTime(
        startTime: _formatClock(secondStart.hour, secondStart.minute),
        endTime: _formatClock(secondEnd.hour, secondEnd.minute),
      ),
    ];
  }

  final firstStart = now.subtract(const Duration(hours: 2));
  final firstEnd = firstStart.add(const Duration(minutes: 10));
  final secondStart = firstEnd.add(const Duration(minutes: 10));
  final secondEnd = secondStart.add(const Duration(minutes: 20));
  return [
    SectionTime(
      startTime: _formatClock(firstStart.hour, firstStart.minute),
      endTime: _formatClock(firstEnd.hour, firstEnd.minute),
    ),
    SectionTime(
      startTime: _formatClock(secondStart.hour, secondStart.minute),
      endTime: _formatClock(secondEnd.hour, secondEnd.minute),
    ),
  ];
}

Future<TimetableProvider> _createProviderWithTodayCourse() async {
  final now = DateTime.now();
  final provider = TimetableProvider(
    autoInitialize: false,
    enableLiveActivitySync: false,
  );
  await provider.initialize();
  await provider.updateTimetableSettings(
    provider.settings.copyWith(
      semesterStartDate: _startOfCurrentWeek(now),
      semesterWeekCount: 20,
      timetableHideWeekends: false,
    ),
  );
  await provider.setCurrentWeek(1);
  final timeScheme = await provider.createTimeScheme(
    name: '测试进行中课程',
    sections: _inProgressSections(now),
  );
  final sections = timeScheme.sections;

  await provider.addCourse(
    Course(
      id: 'today-course',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: now.weekday,
      startSection: 1,
      endSection: 2,
      startTime: sections.first.startTime,
      endTime: sections.last.endTime,
      timeSchemeIdOverride: timeScheme.id,
    ),
  );
  return provider;
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

  testWidgets(
    'tap weekday header enters day view and can return to week view',
    (tester) async {
      final provider = await _createProviderWithTodayCourse();
      final today = DateTime.now();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      expect(
        find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(ValueKey('weekday-header-1-${today.weekday}')),
      );
      await _pumpTimetableFrame(tester);

      expect(
        find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('back-to-week-view-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('back-to-week-view-button')));
      await _pumpTimetableFrame(tester);

      expect(
        find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
        findsNothing,
      );
    },
  );

  testWidgets('screen restores saved day view state on launch', (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        timetableHomeViewMode: TimetableHomeViewMode.day,
        timetableLastViewedDayOfWeek: 3,
      ),
    );
    await provider.setCurrentWeek(2);
    await provider.addCourse(
      Course(
        id: 'saved-day-course',
        name: '已保存日视图课程',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 3,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        customWeeks: const [2],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('timetable-day-view-2-3')),
      findsOneWidget,
    );
    expect(find.text('已保存日视图课程'), findsWidgets);
  });

  testWidgets('tap same weekday again exits day view', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final targetKey = ValueKey('weekday-header-1-${today.weekday}');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(targetKey));
    await _pumpTimetableFrame(tester);
    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(targetKey));
    await _pumpTimetableFrame(tester);
    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsNothing,
    );
  });

  testWidgets('tap another weekday switches current day view', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final anotherDay = today.weekday == 1 ? 2 : 1;

    await provider.addCourse(
      Course(
        id: 'other-day-course',
        name: '离散数学',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: anotherDay,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);
    expect(find.text('高等数学'), findsWidgets);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-$anotherDay')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-$anotherDay')),
      findsOneWidget,
    );
    expect(find.text('离散数学'), findsWidgets);
  });

  testWidgets('add content sheet includes schedule entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProviderWithTodayCourse();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _pumpFiniteFrames(tester, count: 4);
    await tester.tap(find.text('添加课程'));
    await _pumpFiniteFrames(tester, count: 4);
    tester.takeException();
    tester.takeException();

    expect(find.text('添加内容'), findsOneWidget);
    expect(find.text('添加日程'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.event_note_rounded));
    await _pumpTimetableFrame(tester);
    while (tester.takeException() != null) {}

    expect(find.byType(AddScheduleItemScreen), findsOneWidget);
  });

  testWidgets('day view interleaves schedule items between courses by time', (
    tester,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final today = DateTime.now();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: _startOfCurrentWeek(today),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addCourse(
      Course(
        id: 'morning-course',
        name: '早课',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: today.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:30',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'afternoon-course',
        name: '午课',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: today.weekday,
        startSection: 5,
        endSection: 6,
        startTime: '13:00',
        endTime: '14:30',
      ),
    );
    await provider.addScheduleItem(
      ScheduleItem(
        id: 'schedule-middle',
        title: '领取资料',
        location: '行政楼',
        note: '先去前台登记',
        date: DateTime(today.year, today.month, today.day),
        startTime: '10:00',
        endTime: '10:30',
        createdAt: today,
        updatedAt: today,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.text('领取资料'), findsOneWidget);
    expect(find.text('日程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('add-schedule-item-button')),
      findsNothing,
    );

    final morningTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('day-view-edit-card-morning-course')),
        )
        .dy;
    final scheduleTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('day-view-schedule-card-schedule-middle')),
        )
        .dy;
    final afternoonTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('day-view-edit-card-afternoon-course')),
        )
        .dy;

    expect(morningTop, lessThan(scheduleTop));
    expect(scheduleTop, lessThan(afternoonTop));
  });

  testWidgets('cross-day schedule appears on each covered day view', (
    tester,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 4, 13),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addScheduleItem(
      ScheduleItem(
        id: 'cross-day-schedule',
        title: '跨夜值班',
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 17),
        startTime: '22:30',
        endTime: '01:30',
        createdAt: DateTime(2026, 4, 16, 12),
        updatedAt: DateTime(2026, 4, 16, 12),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('weekday-header-1-4')));
    await _pumpTimetableFrame(tester);
    expect(
      find.byKey(const ValueKey('day-view-schedule-card-cross-day-schedule')),
      findsOneWidget,
    );
    expect(find.text('跨日'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('weekday-header-1-5')));
    await _pumpTimetableFrame(tester);
    expect(
      find.byKey(const ValueKey('day-view-schedule-card-cross-day-schedule')),
      findsOneWidget,
    );
  });

  testWidgets('ongoing schedule uses current progress style', (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final now = DateTime.now();
    final startInstant = now.subtract(const Duration(minutes: 10));
    final endInstant = now.add(const Duration(minutes: 20));
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: _startOfCurrentWeek(now),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addScheduleItem(
      ScheduleItem(
        id: 'ongoing-schedule',
        title: '实验室值班',
        location: '创新楼',
        startDate: DateTime(
          startInstant.year,
          startInstant.month,
          startInstant.day,
        ),
        endDate: DateTime(endInstant.year, endInstant.month, endInstant.day),
        startTime: _formatClock(startInstant.hour, startInstant.minute),
        endTime: _formatClock(endInstant.hour, endInstant.minute),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${now.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(
        const ValueKey('day-agenda-progress-schedule-card-ongoing-schedule'),
      ),
      findsOneWidget,
    );
    expect(find.text('实验室值班'), findsWidgets);
  });

  testWidgets('schedule ending soon uses schedule-specific status text', (
    tester,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final now = DateTime.now();
    final startInstant = now.subtract(const Duration(minutes: 30));
    final endInstant = now.add(const Duration(minutes: 5));
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: _startOfCurrentWeek(now),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addScheduleItem(
      ScheduleItem(
        id: 'ending-soon-schedule',
        title: '夜间巡检',
        startDate: DateTime(
          startInstant.year,
          startInstant.month,
          startInstant.day,
        ),
        endDate: DateTime(endInstant.year, endInstant.month, endInstant.day),
        startTime: _formatClock(startInstant.hour, startInstant.minute),
        endTime: _formatClock(endInstant.hour, endInstant.minute),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${now.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.textContaining('即将结束'), findsWidgets);
    expect(find.textContaining('快下课了'), findsNothing);
  });

  testWidgets(
    'opening another weekday after closing day view does not flash stale content',
    (tester) async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(DateTime.now()),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await provider.addCourse(
        Course(
          id: 'thu-course',
          name: '周四课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 4,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'fri-course',
          name: '周五课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 5,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(const ValueKey('weekday-header-1-4')));
      await _pumpTimetableFrame(tester);
      expect(find.text('周四课程'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('back-to-week-view-button')));
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(const ValueKey('weekday-header-1-5')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('timetable-day-view-1-4')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('timetable-day-view-1-5')),
        findsOneWidget,
      );
    },
  );

  testWidgets('today day view shows ongoing badge for current course', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('day-agenda-progress-card-today-course')),
      findsOneWidget,
    );
    expect(find.text('高等数学'), findsWidgets);
  });

  testWidgets('non-today day view does not show ongoing badge', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final anotherDay = today.weekday == 1 ? 2 : 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-$anotherDay')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-$anotherDay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('day-agenda-progress-card-today-course')),
      findsNothing,
    );
  });

  testWidgets(
    'today day view does not show ongoing badge when class is not in progress',
    (tester) async {
      final now = DateTime.now();
      final outOfProgressSections = _outOfProgressSections(now);
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(now),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      final timeScheme = await provider.createTimeScheme(
        name: '测试非进行中课程',
        sections: outOfProgressSections,
      );
      await provider.addCourse(
        Course(
          id: 'today-course-not-live',
          name: '离散数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: outOfProgressSections.first.startTime,
          endTime: outOfProgressSections.last.endTime,
          timeSchemeIdOverride: timeScheme.id,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(ValueKey('weekday-header-1-${now.weekday}')));
      await _pumpTimetableFrame(tester);

      expect(
        find.byKey(ValueKey('timetable-day-view-1-${now.weekday}')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('day-agenda-progress-card-today-course-not-live'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('back to today jumps to the real current semester week', (
    tester,
  ) async {
    final now = DateTime.now();
    final todayWeek = _startOfCurrentWeek(now);
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: todayWeek.subtract(const Duration(days: 7)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(5);
    await provider.addCourse(
      Course(
        id: 'today-course',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '00:00',
        endTime: '23:59',
      ),
    );

    final anotherDay = now.weekday == 1 ? 2 : 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-5-$anotherDay')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-5-$anotherDay')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('back-to-today-button')));
    await _pumpFiniteFrames(tester, count: 12);

    expect(
      find.byKey(ValueKey('timetable-day-view-2-${now.weekday}')),
      findsOneWidget,
    );
  });

  testWidgets('back to today jumps from a boundary-swiped earlier week', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfCurrentWeek(now);
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(7);
    await provider.addCourse(
      Course(
        id: 'today-course',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '00:00',
        endTime: '23:59',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('weekday-header-7-1')));
    await _pumpTimetableFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      const Offset(420, 0),
      warnIfMissed: false,
    );
    await _pumpFiniteFrames(tester, count: 12);

    expect(
      find.byKey(const ValueKey('timetable-day-view-6-7')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('back-to-today-button')));
    await _pumpFiniteFrames(tester, count: 12);

    expect(
      find.byKey(ValueKey('timetable-day-view-7-${now.weekday}')),
      findsOneWidget,
    );
    expect(provider.currentWeek, 7);
  });

  testWidgets(
    'back to today updates day content immediately during week jump',
    (tester) async {
      final now = DateTime.now();
      final currentWeekStart = _startOfCurrentWeek(now);
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: currentWeekStart.subtract(
            const Duration(days: 42),
          ),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(5);
      await provider.addCourse(
        Course(
          id: 'today-course',
          name: '今日课程',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '00:00',
          endTime: '23:59',
        ),
      );

      final anotherDay = now.weekday == 1 ? 2 : 1;
      await provider.addCourse(
        Course(
          id: 'another-day-course',
          name: '其他日课程',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: anotherDay,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(ValueKey('weekday-header-5-$anotherDay')));
      await _pumpTimetableFrame(tester);

      expect(find.text('其他日课程'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('back-to-today-button')));
      await tester.pump();

      expect(find.text('今日课程'), findsWidgets);
    },
  );

  testWidgets('back to today button arrow follows relative day direction', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfCurrentWeek(now);
    final pastProvider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await pastProvider.initialize();
    await pastProvider.updateTimetableSettings(
      pastProvider.settings.copyWith(
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await pastProvider.setCurrentWeek(6);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: pastProvider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);
    await tester.tap(find.byKey(ValueKey('weekday-header-6-${now.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('back-to-today-button')),
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final futureProvider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await futureProvider.initialize();
    await futureProvider.updateTimetableSettings(
      futureProvider.settings.copyWith(
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
        timetableHomeViewMode: TimetableHomeViewMode.week,
      ),
    );
    await futureProvider.setCurrentWeek(8);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: futureProvider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);
    await tester.tap(find.byKey(ValueKey('weekday-header-8-${now.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('back-to-today-button')),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('week view back to current week jumps in one action', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfCurrentWeek(now);
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(5);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('back-to-current-week-button')));
    await _pumpFiniteFrames(tester, count: 12);

    expect(provider.currentWeek, 7);
  });

  testWidgets('week view swipe advances week without extra pager resync', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfCurrentWeek(now);
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: currentWeekStart,
        semesterWeekCount: 20,
        timetableHideWeekends: false,
        timetableHomeViewMode: TimetableHomeViewMode.week,
      ),
    );
    await provider.setCurrentWeek(1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.drag(find.byType(PageView).first, const Offset(-420, 0));
    await _pumpFiniteFrames(tester, count: 12);

    expect(provider.currentWeek, 2);
    expect(find.byKey(const ValueKey('weekday-header-2-1')), findsWidgets);
  });

  testWidgets(
    'week view keeps the latest settled week after a short-interval second swipe',
    (tester) async {
      final now = DateTime.now();
      final currentWeekStart = _startOfCurrentWeek(now);
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: currentWeekStart,
          semesterWeekCount: 20,
          timetableHideWeekends: false,
          timetableHomeViewMode: TimetableHomeViewMode.week,
        ),
      );
      await provider.setCurrentWeek(1);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      final pager = find.byType(PageView).first;
      // First swipe: advance to week 2.
      await tester.drag(pager, const Offset(-420, 0));
      await _pumpFiniteFrames(tester, count: 6);
      // Second swipe before the first settles fully.
      await tester.drag(pager, const Offset(-420, 0));
      await _pumpFiniteFrames(tester, count: 18);

      expect(provider.currentWeek, 3);
      expect(find.byKey(const ValueKey('weekday-header-3-1')), findsWidgets);
    },
  );

  testWidgets('floating back to current week button jumps in one action', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfCurrentWeek(now);
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
        timetableBackToCurrentWeekButtonStyle:
            BackToCurrentWeekButtonStyle.floating,
      ),
    );
    await provider.setCurrentWeek(5);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(const ValueKey('back-to-current-week-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('back-to-current-week-button')));
    await _pumpFiniteFrames(tester, count: 12);

    expect(provider.currentWeek, 7);
  });

  testWidgets(
    'resume refreshes temporal context without resetting viewed week',
    (tester) async {
      final now = DateTime.now();
      final currentWeekStart = _startOfCurrentWeek(now);
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: currentWeekStart.subtract(
            const Duration(days: 42),
          ),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(2);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      expect(provider.currentWeek, 2);
      expect(
        find.byKey(const ValueKey('back-to-current-week-button')),
        findsOneWidget,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpFiniteFrames(tester, count: 12);

      expect(provider.currentWeek, 2);
      expect(provider.currentDateWeek, 7);
      expect(
        find.byKey(const ValueKey('back-to-current-week-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('external week sync keeps day view attached to the new week', (
    tester,
  ) async {
    final today = DateTime.now();
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: _startOfCurrentWeek(today),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(1);
    await provider.addCourse(
      Course(
        id: 'week-two-course',
        name: '同步后课程',
        teacher: '周老师',
        location: 'A201',
        dayOfWeek: today.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        customWeeks: const [2],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
    );

    await provider.setCurrentWeek(2);
    await _pumpFiniteFrames(tester, count: 10);

    expect(provider.currentWeek, 2);
    expect(
      find.byKey(ValueKey('timetable-day-view-2-${today.weekday}')),
      findsOneWidget,
    );
    expect(find.text('同步后课程'), findsWidgets);
  });

  testWidgets('day view summary drag follows the same in-week pager', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final swipesToNextDay = today.weekday < 7;
    final expectedDay = swipesToNextDay ? today.weekday + 1 : today.weekday - 1;

    await provider.addCourse(
      Course(
        id: 'summary-swipe-course',
        name: '周内切日课程',
        teacher: '王老师',
        location: 'C303',
        dayOfWeek: expectedDay,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('day-view-summary')),
      swipesToNextDay ? const Offset(-420, 0) : const Offset(420, 0),
      warnIfMissed: false,
    );
    await _pumpFiniteFrames(tester, count: 10);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-$expectedDay')),
      findsOneWidget,
    );
    expect(find.text('周内切日课程'), findsWidgets);
  });

  testWidgets('day view content swipe switches selected weekday', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final swipesToNextDay = today.weekday < 7;
    final expectedDay = swipesToNextDay ? today.weekday + 1 : today.weekday - 1;

    await provider.addCourse(
      Course(
        id: 'other-day-course',
        name: '离散数学',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: expectedDay,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      swipesToNextDay ? const Offset(-420, 0) : const Offset(420, 0),
    );
    await _pumpFiniteFrames(tester, count: 10);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-$expectedDay')),
      findsOneWidget,
    );
    expect(find.text('离散数学'), findsWidgets);
  });

  testWidgets('weekday header indicator follows day view drag continuously', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final swipesToNextDay = today.weekday < 7;

    await provider.addCourse(
      Course(
        id: 'indicator-follow-course',
        name: '横杠跟手课程',
        teacher: '赵老师',
        location: 'D404',
        dayOfWeek: swipesToNextDay ? today.weekday + 1 : today.weekday - 1,
        startSection: 7,
        endSection: 8,
        startTime: '16:00',
        endTime: '17:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    final indicatorFinder = find.byKey(
      const ValueKey('weekday-selection-indicator-1'),
    );
    expect(indicatorFinder, findsOneWidget);

    final startX = tester.getCenter(indicatorFinder).dx;
    final swipeTarget = find.byKey(const ValueKey('day-view-swipe-area'));
    final gesture = await tester.startGesture(tester.getCenter(swipeTarget));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(
        swipesToNextDay ? const Offset(-35, 0) : const Offset(35, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    final movedX = tester.getCenter(indicatorFinder).dx;
    if (swipesToNextDay) {
      expect(movedX, greaterThan(startX));
    } else {
      expect(movedX, lessThan(startX));
    }

    await gesture.up();
    await _pumpFiniteFrames(tester, count: 10);
  });

  testWidgets('day view content swipe can continue across multiple weekdays', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();

    await provider.addCourse(
      Course(
        id: 'tuesday-course',
        name: '周二课程',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'wednesday-course',
        name: '周三课程',
        teacher: '王老师',
        location: 'C303',
        dayOfWeek: 3,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'thursday-course',
        name: '周四课程',
        teacher: '周老师',
        location: 'D404',
        dayOfWeek: 4,
        startSection: 7,
        endSection: 8,
        startTime: '16:00',
        endTime: '17:40',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('weekday-header-1-1')));
    await _pumpTimetableFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      const Offset(-420, 0),
    );
    await _pumpFiniteFrames(tester, count: 10);
    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      const Offset(-420, 0),
    );
    await _pumpFiniteFrames(tester, count: 10);
    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      const Offset(-420, 0),
    );
    await _pumpFiniteFrames(tester, count: 10);

    expect(
      find.byKey(const ValueKey('timetable-day-view-1-4')),
      findsOneWidget,
    );
    expect(find.text('周四课程'), findsWidgets);
  });

  testWidgets('day view content swipe at boundary switches week', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();

    await provider.addCourse(
      Course(
        id: 'week-two-monday',
        name: '下周一课程',
        teacher: '王老师',
        location: 'A201',
        dayOfWeek: 1,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
        customWeeks: const [2],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('weekday-header-1-7')));
    await _pumpTimetableFrame(tester);

    await tester.drag(
      find.byKey(const ValueKey('day-view-swipe-area')),
      const Offset(-420, 0),
    );
    await _pumpFiniteFrames(tester, count: 12);

    expect(
      find.byKey(const ValueKey('timetable-day-view-2-1')),
      findsOneWidget,
    );
    expect(find.text('下周一课程'), findsWidgets);
  });

  testWidgets(
    'day view boundary swipe then continued swipe moves to next day in new week',
    (tester) async {
      final provider = await _createProviderWithTodayCourse();

      await provider.addCourse(
        Course(
          id: 'week-two-monday',
          name: '下周一课程',
          teacher: '王老师',
          location: 'A201',
          dayOfWeek: 1,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          customWeeks: const [2],
        ),
      );
      await provider.addCourse(
        Course(
          id: 'week-two-tuesday',
          name: '下周二课程',
          teacher: '李老师',
          location: 'B301',
          dayOfWeek: 2,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
          customWeeks: const [2],
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(const ValueKey('weekday-header-1-7')));
      await _pumpTimetableFrame(tester);

      await tester.drag(
        find.byKey(const ValueKey('day-view-swipe-area')),
        const Offset(-420, 0),
      );
      await _pumpFiniteFrames(tester, count: 12);

      expect(
        find.byKey(const ValueKey('timetable-day-view-2-1')),
        findsOneWidget,
      );
      expect(find.text('下周一课程'), findsWidgets);

      await tester.drag(
        find.byKey(const ValueKey('day-view-swipe-area')),
        const Offset(-420, 0),
      );
      await _pumpFiniteFrames(tester, count: 12);

      expect(
        find.byKey(const ValueKey('timetable-day-view-2-2')),
        findsOneWidget,
      );
      expect(find.text('下周二课程'), findsWidgets);
    },
  );

  testWidgets('day view still shows non-current-week courses when enabled', (
    tester,
  ) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(timetableShowNonCurrentWeekCourses: true),
    );
    await provider.addCourse(
      Course(
        id: 'week-two-course',
        name: '实验课',
        teacher: '周老师',
        location: '实验楼 201',
        dayOfWeek: today.weekday,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
        customWeeks: const [2],
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(find.text('实验课'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.text('实验课'), findsWidgets);
    expect(find.text('非本周'), findsWidgets);
    expect(find.byKey(const ValueKey('day-view-summary')), findsOneWidget);
  });

  testWidgets('day view renders conflicting courses together', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await provider.addCourse(
      Course(
        id: 'conflict-a',
        name: '线性代数',
        teacher: '王老师',
        location: 'B201',
        dayOfWeek: today.weekday,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'conflict-b',
        name: '大学物理',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: today.weekday,
        startSection: 3,
        endSection: 4,
        startTime: '10:05',
        endTime: '11:45',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.text('线性代数'), findsWidgets);
    expect(find.text('大学物理'), findsWidgets);
    expect(find.text('冲突'), findsWidgets);
  });

  testWidgets(
    'conflicting in-progress courses both use current progress style',
    (tester) async {
      final now = DateTime.now();
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(now),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      final timeScheme = await provider.createTimeScheme(
        name: '冲突进行中课程',
        sections: _inProgressSections(now),
      );
      final sections = timeScheme.sections;

      await provider.addCourse(
        Course(
          id: 'conflict-live-a',
          name: '线性代数',
          teacher: '王老师',
          location: 'B201',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: sections.first.startTime,
          endTime: sections.last.endTime,
          timeSchemeIdOverride: timeScheme.id,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'conflict-live-b',
          name: '大学物理',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 2,
          startTime: sections.first.startTime,
          endTime: sections.last.endTime,
          timeSchemeIdOverride: timeScheme.id,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
        ),
      );
      await _pumpTimetableFrame(tester);

      await tester.tap(find.byKey(ValueKey('weekday-header-1-${now.weekday}')));
      await _pumpTimetableFrame(tester);

      expect(
        find.byKey(const ValueKey('day-agenda-progress-card-conflict-live-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('day-agenda-progress-card-conflict-live-b')),
        findsOneWidget,
      );
      expect(find.text('线性代数'), findsWidgets);
      expect(find.text('大学物理'), findsWidgets);
    },
  );

  testWidgets('day view card tap opens edit screen directly', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    await tester.tap(
      find.byKey(const ValueKey('day-view-edit-card-today-course')),
    );
    await tester.pump();
    await _pumpFiniteFrames(tester, count: 12);

    expect(find.byType(AddCourseScreen), findsOneWidget);
  });

  testWidgets('day view add single lesson defaults to selected weekday', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final targetDay = today.weekday == 1 ? 2 : 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableScreen(enableUpdateCheck: false, enableProgressTimer: false)),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-$targetDay')));
    await _pumpTimetableFrame(tester);

    expect(find.byKey(ValueKey('timetable-day-view-1-$targetDay')), findsOne);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _pumpFiniteFrames(tester, count: 4);
    await tester.tap(find.text('添加课程'));
    await _pumpFiniteFrames(tester, count: 4);

    expect(find.text('添加内容'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_week_rounded));
    await tester.pump();
    await _pumpFiniteFrames(tester, count: 12);

    expect(find.byType(AddCourseScreen), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await _pumpTimetableFrame(tester);

    expect(
      find.descendant(
        of: find.byType(AddCourseScreen),
        matching: find.text(_weekdayLabelForTest(targetDay)),
      ),
      findsOneWidget,
    );
  });
}
