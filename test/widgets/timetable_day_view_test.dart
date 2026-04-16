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
import 'package:university_timetable/screens/timetable_screen.dart';

import '../helpers_test_app.dart';

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
  final firstStart = now.subtract(const Duration(minutes: 30));
  final firstEnd = now.subtract(const Duration(minutes: 20));
  final secondStart = now.subtract(const Duration(minutes: 10));
  final secondEnd = now.add(const Duration(minutes: 10));
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

  testWidgets('tap weekday header enters day view and can return to week view',
      (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsNothing,
    );

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('back-to-week-view-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back-to-week-view-button')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsNothing,
    );
  });

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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(
        find.byKey(const ValueKey('timetable-day-view-2-3')), findsOneWidget);
    expect(find.text('已保存日视图课程'), findsWidgets);
  });

  testWidgets('tap same weekday again exits day view', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final targetKey = ValueKey('weekday-header-1-${today.weekday}');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('today day view shows ongoing badge for current course',
      (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.textContaining('正在上课'), findsWidgets);
    expect(find.text('高等数学'), findsWidgets);
  });

  testWidgets('non-today day view does not show ongoing badge', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final anotherDay = today.weekday == 1 ? 2 : 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-$anotherDay')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-$anotherDay')),
      findsOneWidget,
    );
    expect(find.text('正在上课'), findsNothing);
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${now.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${now.weekday}')),
      findsOneWidget,
    );
    expect(find.text('正在上课'), findsNothing);
    expect(find.textContaining('正在上课'), findsNothing);
  });

  testWidgets('back to today jumps to the real current semester week',
      (tester) async {
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('back to today jumps from a boundary-swiped earlier week',
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('back to today updates day content immediately during week jump',
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
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-5-$anotherDay')));
    await _pumpTimetableFrame(tester);

    expect(find.text('其他日课程'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('back-to-today-button')));
    await tester.pump();

    expect(find.text('今日课程'), findsWidgets);
  });

  testWidgets('week view back to current week jumps in one action',
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
        semesterStartDate: currentWeekStart.subtract(const Duration(days: 42)),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    await provider.setCurrentWeek(5);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('back-to-current-week-button')));
    await _pumpFiniteFrames(tester, count: 12);

    expect(provider.currentWeek, 7);
  });

  testWidgets('resume syncs week view to current semester week', (tester) async {
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
    await provider.setCurrentWeek(2);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    expect(provider.currentWeek, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFiniteFrames(tester, count: 12);

    expect(provider.currentWeek, 7);
  });

  testWidgets('day view summary drag follows the same in-week pager',
      (tester) async {
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('day view content swipe switches selected weekday',
      (tester) async {
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('day view content swipe can continue across multiple weekdays',
      (tester) async {
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('day view content swipe at boundary switches week',
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

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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
        find.byKey(const ValueKey('timetable-day-view-2-1')), findsOneWidget);
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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
  });

  testWidgets('day view still shows non-current-week courses when enabled',
      (tester) async {
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);

    expect(find.text('线性代数'), findsWidgets);
    expect(find.text('大学物理'), findsWidgets);
    expect(find.text('冲突'), findsWidgets);
  });

  testWidgets('day view card tap opens edit screen directly', (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
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

  testWidgets('day view add single lesson defaults to selected weekday',
      (tester) async {
    final provider = await _createProviderWithTodayCourse();
    final today = DateTime.now();
    final targetDay = today.weekday == 1 ? 2 : 1;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    await tester.tap(find.byKey(ValueKey('weekday-header-1-$targetDay')));
    await _pumpTimetableFrame(tester);

    expect(find.byKey(ValueKey('timetable-day-view-1-$targetDay')), findsOne);

    await tester.tap(find.byTooltip('更多'));
    await _pumpTimetableFrame(tester);
    await tester.tap(find.text('添加课程'));
    await _pumpTimetableFrame(tester);
    await tester.tap(find.text('单节课'));
    await tester.pump();
    await _pumpFiniteFrames(tester, count: 12);

    expect(find.byType(AddCourseScreen), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await _pumpTimetableFrame(tester);

    final weekdayDropdown = tester
        .widgetList<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .firstWhere((widget) => widget.decoration.labelText == '星期');

    expect(weekdayDropdown.initialValue, targetDay);
  });
}
