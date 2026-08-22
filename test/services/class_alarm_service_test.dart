import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart'
    show SectionTime;
import 'package:university_timetable/services/class_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/system_alarm');
  final recorded = <MethodCall>[];

  setUp(() {
    recorded.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recorded.add(call);
      return <String, Object>{'launched': true, 'skipUi': false};
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ClassAlarmLogic.parseClockMinutes', () {
    test('parses valid clock times', () {
      expect(ClassAlarmLogic.parseClockMinutes('08:00'), 480);
      expect(ClassAlarmLogic.parseClockMinutes('21:35'), 1295);
    });

    test('rejects malformed times', () {
      expect(ClassAlarmLogic.parseClockMinutes('25:00'), isNull);
      expect(ClassAlarmLogic.parseClockMinutes('08:60'), isNull);
      expect(ClassAlarmLogic.parseClockMinutes(''), isNull);
      expect(ClassAlarmLogic.parseClockMinutes('8点'), isNull);
    });
  });

  group('ClassAlarmLogic.firstSectionStartMinutes', () {
    test('returns earliest section start', () {
      final minutes = ClassAlarmLogic.firstSectionStartMinutes(
        buildSections(['10:00-11:40', '08:00-09:40', '14:00-15:40']),
      );
      expect(minutes, 480);
    });

    test('returns null when nothing parses', () {
      expect(ClassAlarmLogic.firstSectionStartMinutes(const []), isNull);
    });
  });

  group('ClassAlarmLogic.weekdayBit', () {
    test('maps ISO weekdays onto Calendar constants used by EXTRA_DAYS', () {
      // SUNDAY=1, MONDAY=2 ... SATURDAY=7 in java.util.Calendar.
      expect(ClassAlarmLogic.weekdayBit(1), 2);
      expect(ClassAlarmLogic.weekdayBit(5), 32);
      expect(ClassAlarmLogic.weekdayBit(7), 1);
      expect(ClassAlarmLogic.weekdayBit(0), 0);
      expect(ClassAlarmLogic.weekdayBit(8), 0);
    });
  });

  group('ClassAlarmLogic.clampLeadMinutes', () {
    test('clamps into [0, 120]', () {
      expect(ClassAlarmLogic.clampLeadMinutes(-5), 0);
      expect(ClassAlarmLogic.clampLeadMinutes(30), 30);
      expect(ClassAlarmLogic.clampLeadMinutes(999), 120);
    });
  });

  group('ClassAlarmLogic.buildSingleShotPlan', () {
    test('subtracts lead from course start', () {
      final plan = ClassAlarmLogic.buildSingleShotPlan(
        courseStartTime: '08:00',
        label: '轻屿 · 数学',
        now: DateTime(2026, 2, 23, 6, 0),
        leadMinutes: 30,
      );
      expect(plan, isNotNull);
      expect(plan!.hour, 7);
      expect(plan.minute, 30);
      expect(plan.isOneShot, isTrue);
      expect(plan.repeatDays, isEmpty);
      expect(plan.label, '轻屿 · 数学');
    });

    test('returns null when the class already started', () {
      final plan = ClassAlarmLogic.buildSingleShotPlan(
        courseStartTime: '08:00',
        label: 'x',
        now: DateTime(2026, 2, 23, 8, 0),
      );
      expect(plan, isNull);
    });
  });

  group('ClassAlarmLogic.groupFromOccurrences', () {
    test('merges weekdays sharing the same first-class time', () {
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [
          row(1, '08:00'),
          row(3, '08:00'),
          row(5, '14:00'),
        ],
        leadMinutes: 30,
      );
      expect(grouping.variableDays, isEmpty);
      expect(grouping.groups.length, 2);
      final morning = grouping.groups.first;
      expect(morning.dayOfWeeks, [1, 3]);
      expect(morning.plan.hour, 7);
      expect(morning.plan.minute, 30);
      expect(morning.plan.repeatDays, [2, 8]);
      final afternoon = grouping.groups.last;
      expect(afternoon.dayOfWeeks, [5]);
      expect(afternoon.plan.hour, 13);
      expect(afternoon.plan.minute, 30);
    });

    test('reports weekdays whose first-class time varies between weeks', () {
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [
          // 第 4 周周三是 08:00，第 5 周周三是 14:00 —— 无法合并成单一闹钟。
          row(3, '08:00'),
          row(3, '14:00'),
          row(1, '08:00'),
        ],
        leadMinutes: 30,
      );
      expect(grouping.variableDays, [3]);
      expect(grouping.groups.single.dayOfWeeks, [1]);
    });

    test('collapses duplicate rows (same weekday, same time)', () {
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [row(2, '10:00'), row(2, '10:00'), row(2, '10:00')],
        leadMinutes: 20,
      );
      expect(grouping.variableDays, isEmpty);
      expect(grouping.groups.single.dayOfWeeks, [2]);
      expect(grouping.groups.single.plan.minute, 40);
      expect(grouping.groups.single.plan.hour, 9);
    });

    test('wraps ring times below midnight without corrupting the mask', () {
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [row(1, '00:20')],
        leadMinutes: 30,
      );
      final plan = grouping.groups.single.plan;
      expect(plan.hour, 23);
      expect(plan.minute, 50);
      expect(plan.repeatDays, [2]);
    });
  });

  group('ClassAlarmLogic.buildCourseWeeklyPlan', () {
    test('builds one weekly alarm on the course weekday minus lead', () {
      final plan = ClassAlarmLogic.buildCourseWeeklyPlan(
        dayOfWeek: 3,
        startTime: '14:00',
        label: '轻屿 · 物理',
        leadMinutes: 45,
      );
      expect(plan, isNotNull);
      expect(plan!.hour, 13);
      expect(plan.minute, 15);
      expect(plan.repeatDays, [8]);
      expect(plan.isOneShot, isFalse);
    });

    test('rejects malformed input', () {
      expect(
        ClassAlarmLogic.buildCourseWeeklyPlan(
          dayOfWeek: 9,
          startTime: '14:00',
          label: 'x',
        ),
        isNull,
      );
      expect(
        ClassAlarmLogic.buildCourseWeeklyPlan(
          dayOfWeek: 3,
          startTime: 'bad',
          label: 'x',
        ),
        isNull,
      );
    });
  });

  group('ClassAlarmService.addAlarm', () {
    test('passes hour, minute, label and weekday mask to the channel', () async {
      final result = await ClassAlarmService.addAlarm(
        const ClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: '轻屿',
          repeatDays: [2, 8],
          skipUi: false,
          isOneShot: false,
        ),
      );
      expect(result.launched, isTrue);
      expect(recorded.single.method, 'setAlarm');
      expect(recorded.single.arguments['hour'], 7);
      expect(recorded.single.arguments['minute'], 30);
      expect(recorded.single.arguments['label'], '轻屿');
      expect(recorded.single.arguments['days'], [2, 8]);
    });

    test('omits days for one-shot plans', () async {
      await ClassAlarmService.addAlarm(
        const ClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: '轻屿',
          repeatDays: [],
          skipUi: true,
          isOneShot: true,
        ),
      );
      expect(recorded.single.arguments['days'], isNull);
      expect(recorded.single.arguments['skipUi'], isTrue);
    });

    test('degrades platform exceptions to launched=false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'alarm_not_available');
      });
      final result = await ClassAlarmService.addAlarm(
        const ClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: '轻屿',
          repeatDays: [],
          skipUi: false,
          isOneShot: true,
        ),
      );
      expect(result.launched, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('ClassAlarmService.openSystemAlarms', () {
    test('returns true when the channel reports success', () async {
      expect(await ClassAlarmService.openSystemAlarms(), isTrue);
      expect(recorded.single.method, 'showAlarms');
    });
  });
}

ClassAlarmDayFirstSection row(int dayOfWeek, String start) =>
    ClassAlarmDayFirstSection(dayOfWeek: dayOfWeek, startTime: start);

List<SectionTime> buildSections(List<String> ranges) => [
      for (final range in ranges)
        () {
          final parts = range.split('-');
          return SectionTime(startTime: parts[0], endTime: parts[1]);
        }(),
    ];
