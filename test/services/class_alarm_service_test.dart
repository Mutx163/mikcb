import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      // 午夜边界必须可用：跨午夜回绕依赖 00:00-00:59 的合法解析。
      expect(ClassAlarmLogic.parseClockMinutes('00:00'), 0);
      expect(ClassAlarmLogic.parseClockMinutes('23:59'), 1439);
    });

    test('rejects malformed times', () {
      expect(ClassAlarmLogic.parseClockMinutes('25:00'), isNull);
      expect(ClassAlarmLogic.parseClockMinutes('08:60'), isNull);
      expect(ClassAlarmLogic.parseClockMinutes(''), isNull);
      expect(ClassAlarmLogic.parseClockMinutes('8点'), isNull);
    });
  });

  group('ClassAlarmLogic.formatClock', () {
    test('formats within one day', () {
      expect(ClassAlarmLogic.formatClock(0), '00:00');
      expect(ClassAlarmLogic.formatClock(480), '08:00');
      expect(ClassAlarmLogic.formatClock(1439), '23:59');
    });

    test('normalizes out-of-range minutes into one day', () {
      expect(ClassAlarmLogic.formatClock(1440), '00:00');
      expect(ClassAlarmLogic.formatClock(1440 + 480), '08:00');
    });
  });

  group('ClassAlarmLogic.calendarWeekday', () {
    test(
        'maps ISO weekdays onto java.util.Calendar constants used by EXTRA_DAYS',
        () {
      // java.util.Calendar: SUNDAY=1, MONDAY=2 ... SATURDAY=7。
      // 回归背景：曾误用 2 的幂位掩码，导致周二错天、周三~周六重复日被丢弃。
      expect(ClassAlarmLogic.calendarWeekday(1), 2); // Monday
      expect(ClassAlarmLogic.calendarWeekday(2), 3); // Tuesday
      expect(ClassAlarmLogic.calendarWeekday(3), 4); // Wednesday
      expect(ClassAlarmLogic.calendarWeekday(4), 5); // Thursday
      expect(ClassAlarmLogic.calendarWeekday(5), 6); // Friday
      expect(ClassAlarmLogic.calendarWeekday(6), 7); // Saturday
      expect(ClassAlarmLogic.calendarWeekday(7), 1); // Sunday
    });

    test('returns 0 for out-of-range input', () {
      expect(ClassAlarmLogic.calendarWeekday(0), 0);
      expect(ClassAlarmLogic.calendarWeekday(8), 0);
      expect(ClassAlarmLogic.calendarWeekday(-1), 0);
    });
  });

  group('ClassAlarmLogic.clampLeadMinutes', () {
    test('clamps into [0, 120]', () {
      expect(ClassAlarmLogic.clampLeadMinutes(-5), 0);
      expect(ClassAlarmLogic.clampLeadMinutes(0), 0);
      expect(ClassAlarmLogic.clampLeadMinutes(30), 30);
      expect(ClassAlarmLogic.clampLeadMinutes(120), 120);
      expect(ClassAlarmLogic.clampLeadMinutes(999), 120);
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
      // Calendar 常量：周一=2、周三=4。
      expect(morning.plan.repeatDays, [2, 4]);
      final afternoon = grouping.groups.last;
      expect(afternoon.dayOfWeeks, [5]);
      expect(afternoon.plan.hour, 13);
      expect(afternoon.plan.minute, 30);
      expect(afternoon.plan.repeatDays, [6]);
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
      expect(grouping.groups.single.plan.repeatDays, [3]); // Calendar.TUESDAY
    });

    test(
        'shifts wrapped ring times below midnight to the previous weekday',
        () {
      // 周一 00:20 的课提前 30 分钟应在周日 23:50 响铃，
      // 而不是周一 23:50（晚近 24 小时）。
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [row(1, '00:20')],
        leadMinutes: 30,
      );
      final plan = grouping.groups.single.plan;
      expect(plan.hour, 23);
      expect(plan.minute, 50);
      expect(grouping.groups.single.dayOfWeeks, [7]);
      expect(plan.repeatDays, [1]); // Calendar.SUNDAY
    });

    test('keeps weekday unchanged when ring time does not wrap', () {
      final grouping = ClassAlarmLogic.groupFromOccurrences(
        rows: [row(1, '08:00')],
        leadMinutes: 30,
      );
      final plan = grouping.groups.single.plan;
      expect(plan.hour, 7);
      expect(plan.minute, 30);
      expect(grouping.groups.single.dayOfWeeks, [1]);
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
      expect(plan.repeatDays, [4]); // Calendar.WEDNESDAY
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

    test('wraps below midnight onto the previous weekday', () {
      final plan = ClassAlarmLogic.buildCourseWeeklyPlan(
        dayOfWeek: 1,
        startTime: '00:20',
        label: 'x',
        leadMinutes: 30,
      );
      expect(plan, isNotNull);
      expect(plan!.hour, 23);
      expect(plan.minute, 50);
      expect(plan.repeatDays, [1]); // Calendar.SUNDAY
    });
  });

  group('ClassAlarmService.addAlarm', () {
    test('passes hour, minute, label and weekday constants to the channel',
        () async {
      final result = await ClassAlarmService.addAlarm(
        const ClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: '轻屿',
          repeatDays: [2, 4],
          skipUi: false,
        ),
      );
      expect(result.launched, isTrue);
      expect(recorded.single.method, 'setAlarm');
      expect(recorded.single.arguments['hour'], 7);
      expect(recorded.single.arguments['minute'], 30);
      expect(recorded.single.arguments['label'], '轻屿');
      expect(recorded.single.arguments['days'], [2, 4]);
      expect(recorded.single.arguments['skipUi'], false);
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
          repeatDays: [2],
          skipUi: true,
        ),
      );
      expect(result.launched, isFalse);
      expect(result.error, isNotNull);
    });

    test('degrades MissingPluginException to unsupported_platform', () async {
      // 非 Android 平台未注册通道时引擎回空信封，服务层须降级而非抛出。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final result = await ClassAlarmService.addAlarm(
        const ClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: '轻屿',
          repeatDays: <int>[],
          skipUi: false,
        ),
      );
      expect(result.launched, isFalse);
      expect(result.error, 'unsupported_platform');
    });
  });

  group('ClassAlarmService.openSystemAlarms', () {
    test('returns true when the channel reports success', () async {
      expect(await ClassAlarmService.openSystemAlarms(), isTrue);
      expect(recorded.single.method, 'showAlarms');
    });

    test('returns false when the channel is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await ClassAlarmService.openSystemAlarms(), isFalse);
    });
  });
}

ClassAlarmDayFirstSection row(int dayOfWeek, String start) =>
    ClassAlarmDayFirstSection(dayOfWeek: dayOfWeek, startTime: start);
