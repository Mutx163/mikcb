import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/morning_class_alarm_service.dart';

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

  group('MorningClassAlarmLogic.parseClockMinutes', () {
    test('parses valid clock times', () {
      expect(MorningClassAlarmLogic.parseClockMinutes('08:00'), 480);
      expect(MorningClassAlarmLogic.parseClockMinutes('21:35'), 1295);
    });

    test('rejects malformed times', () {
      expect(MorningClassAlarmLogic.parseClockMinutes('25:00'), isNull);
      expect(MorningClassAlarmLogic.parseClockMinutes('08:60'), isNull);
      expect(MorningClassAlarmLogic.parseClockMinutes(''), isNull);
      expect(MorningClassAlarmLogic.parseClockMinutes('8点'), isNull);
    });
  });

  group('MorningClassAlarmLogic.firstSectionStartMinutes', () {
    test('returns earliest section start', () {
      final minutes = MorningClassAlarmLogic.firstSectionStartMinutes([
        const SectionTime(startTime: '10:00', endTime: '11:40'),
        const SectionTime(startTime: '08:00', endTime: '09:40'),
        const SectionTime(startTime: '14:00', endTime: '15:40'),
      ]);
      expect(minutes, 480);
    });

    test('returns null when nothing parses', () {
      expect(
        MorningClassAlarmLogic.firstSectionStartMinutes(const []),
        isNull,
      );
    });
  });

  group('MorningClassAlarmLogic.weekdayBit', () {
    test('maps ISO weekdays onto Calendar constants used by EXTRA_DAYS', () {
      // SUNDAY=1, MONDAY=2 ... SATURDAY=7 in java.util.Calendar.
      expect(MorningClassAlarmLogic.weekdayBit(1), 2); // Mon
      expect(MorningClassAlarmLogic.weekdayBit(5), 32); // Fri
      expect(MorningClassAlarmLogic.weekdayBit(7), 1); // Sun
    });
  });

  group('MorningClassAlarmLogic.buildSingleShotPlan', () {
    test('subtracts lead time and stays one-shot', () {
      final plan = MorningClassAlarmLogic.buildSingleShotPlan(
        courseStartTime: '08:00',
        label: 'qingyu-gaoshu',
        now: DateTime(2026, 9, 14, 7, 0),
        leadMinutes: 30,
      );
      expect(plan, isNotNull);
      expect(plan!.isOneShot, isTrue);
      expect(plan.repeatDays, isEmpty);
      expect(plan.hour, 7);
      expect(plan.minute, 30);
    });

    test('rejects classes that already started', () {
      final plan = MorningClassAlarmLogic.buildSingleShotPlan(
        courseStartTime: '08:00',
        label: 'x',
        now: DateTime(2026, 9, 14, 8, 0),
        leadMinutes: 30,
      );
      expect(plan, isNull);
    });

    test('clamps oversized lead into [0, 120]', () {
      final plan = MorningClassAlarmLogic.buildSingleShotPlan(
        courseStartTime: '08:00',
        label: 'x',
        now: DateTime(2026, 9, 14, 5, 0),
        leadMinutes: 500,
      );
      expect(plan, isNotNull);
      expect(plan!.hour, 6); // 08:00 - 120min
      expect(plan.minute, 0);
    });
  });

  group('MorningClassAlarmLogic.buildWeeklyPlan', () {
    test('uses earliest first-section start and merges day bits', () {
      final plan = MorningClassAlarmLogic.buildWeeklyPlan(
        days: [
          const MorningClassDayFirstSection(dayOfWeek: 1, startTime: '08:00'),
          const MorningClassDayFirstSection(dayOfWeek: 3, startTime: '08:30'),
          const MorningClassDayFirstSection(dayOfWeek: 5, startTime: '08:20'),
        ],
        label: 'zaoba',
        leadMinutes: 20,
      );
      expect(plan, isNotNull);
      expect(plan!.hour, 7);
      expect(plan.minute, 40);
      // Mon(2) + Wed(8) + Fri(32), sorted ascending.
      expect(plan.repeatDays, [2, 8, 32]);
      expect(plan.isOneShot, isFalse);
    });

    test('wraps below midnight without shifting the repeat mask', () {
      final plan = MorningClassAlarmLogic.buildWeeklyPlan(
        days: [
          const MorningClassDayFirstSection(dayOfWeek: 1, startTime: '00:20'),
        ],
        label: 'x',
        leadMinutes: 30,
      );
      expect(plan, isNotNull);
      expect(plan!.repeatDays, [2]);
      expect(plan.hour, 23); // previous evening 23:50
      expect(plan.minute, 50);
    });

    test('returns null for empty or invalid input', () {
      expect(
        MorningClassAlarmLogic.buildWeeklyPlan(days: [], label: 'x'),
        isNull,
      );
      expect(
        MorningClassAlarmLogic.buildWeeklyPlan(
          days: const [
            MorningClassDayFirstSection(dayOfWeek: 9, startTime: 'bogus'),
          ],
          label: 'x',
        ),
        isNull,
      );
    });
  });

  group('MorningClassAlarmService.addAlarm', () {
    test('sends one-shot payload without EXTRA_DAYS', () async {
      final result = await MorningClassAlarmService.addAlarm(
        const MorningClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: 'qingyu-zaoba',
          repeatDays: [],
          skipUi: false,
          isOneShot: true,
        ),
      );
      expect(result.launched, isTrue);
      expect(recorded, hasLength(1));
      expect(recorded.single.method, 'setAlarm');
      expect(recorded.single.arguments['days'], isNull);
      expect(recorded.single.arguments['skipUi'], false);
    });

    test('passes weekly repeat days through', () async {
      final result = await MorningClassAlarmService.addAlarm(
        const MorningClassAlarmPlan(
          hour: 7,
          minute: 40,
          label: 'qingyu-zaoba',
          repeatDays: [2, 8],
          skipUi: true,
          isOneShot: false,
        ),
      );
      expect(result.launched, isTrue);
      expect(recorded.single.arguments['days'], [2, 8]);
      expect(recorded.single.arguments['skipUi'], true);
    });

    test('degrades gracefully on platform errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'SET_ALARM_FAILED', message: 'boom');
      });
      final result = await MorningClassAlarmService.addAlarm(
        const MorningClassAlarmPlan(
          hour: 7,
          minute: 30,
          label: 'x',
          repeatDays: [],
          skipUi: false,
          isOneShot: true,
        ),
      );
      expect(result.launched, isFalse);
      expect(result.error, 'boom');
    });

    test('degrades gracefully when plugin is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final result = await MorningClassAlarmService.openSystemAlarms();
      expect(result, isFalse);
    });
  });

  group('TimetableSettings morning-alarm fields', () {
    test('defaults persist through JSON round-trip', () {
      const settings = TimetableSettings(sections: []);
      final json = settings.toJson();
      expect(json['morningClassAlarmEnabled'], false);
      expect(json['morningClassAlarmLeadMinutes'], 30);
      expect(json['morningClassAlarmSkipUi'], false);

      final restored = TimetableSettings.fromJson(json);
      expect(restored.morningClassAlarmEnabled, isFalse);
      expect(restored.morningClassAlarmLeadMinutes, 30);
      expect(restored.morningClassAlarmSkipUi, isFalse);
    });

    test('copyWith overrides individual fields', () {
      const settings = TimetableSettings(sections: []);
      final updated = settings.copyWith(
        morningClassAlarmEnabled: true,
        morningClassAlarmLeadMinutes: 20,
        morningClassAlarmSkipUi: true,
      );
      expect(updated.morningClassAlarmEnabled, isTrue);
      expect(updated.morningClassAlarmLeadMinutes, 20);
      expect(updated.morningClassAlarmSkipUi, isTrue);
      // Original untouched.
      expect(settings.morningClassAlarmEnabled, isFalse);
    });
  });
}
