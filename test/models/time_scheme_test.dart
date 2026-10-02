import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  test('time scheme serializes complete state', () {
    final scheme = TimeScheme(
      id: 'summer',
      name: '夏季作息',
      sections: const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '08:55', endTime: '09:40'),
      ],
      createdAt: DateTime(2026, 3, 22, 9),
      updatedAt: DateTime(2026, 3, 22, 10),
    );

    final restored = TimeScheme.fromJson(scheme.toJson());

    expect(restored.id, 'summer');
    expect(restored.name, '夏季作息');
    expect(restored.sectionCount, 2);
    expect(restored.sections.first.displayText, '08:00-08:45');
    expect(restored.createdAt, DateTime(2026, 3, 22, 9));
    expect(restored.updatedAt, DateTime(2026, 3, 22, 10));
  });

  test('quick section builder generates full schedule by periods', () {
    final sections = buildQuickSectionTimes(
      morningCount: 2,
      afternoonCount: 2,
      eveningCount: 1,
      morningStartTime: '08:00',
      afternoonStartTime: '14:00',
      eveningStartTime: '19:00',
      classDurationMinutes: 45,
      breakDurationMinutes: 10,
    );

    expect(sections.map((item) => item.displayText).toList(), [
      '08:00-08:45',
      '08:55-09:40',
      '14:00-14:45',
      '14:55-15:40',
      '19:00-19:45',
    ]);
  });

  test('quick section builder supports overriding long breaks', () {
    final sections = buildQuickSectionTimes(
      morningCount: 3,
      afternoonCount: 0,
      eveningCount: 0,
      morningStartTime: '08:00',
      afternoonStartTime: null,
      eveningStartTime: null,
      classDurationMinutes: 45,
      breakDurationMinutes: 10,
      breakOverrideRules: const [
        BreakOverrideRule(afterSection: 2, breakDurationMinutes: 25),
      ],
    );

    expect(sections.map((item) => item.displayText).toList(), [
      '08:00-08:45',
      '08:55-09:40',
      '10:05-10:50',
    ]);
  });

  test('quick section builder rejects schedules that cross midnight', () {
    expect(
      () => buildQuickSectionTimes(
        morningCount: 1,
        afternoonCount: 0,
        eveningCount: 0,
        morningStartTime: '23:30',
        afternoonStartTime: null,
        eveningStartTime: null,
        classDurationMinutes: 45,
        breakDurationMinutes: 10,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('section_crosses_midnight'),
        ),
      ),
    );
  });

  test('section validation rejects end time before start time', () {
    expect(
      validateSectionTimes(const [
        SectionTime(startTime: '23:30', endTime: '00:15'),
      ]),
      contains('section_end_must_after_start'),
    );
  });

  test('fromJson keeps section positions when an entry is malformed', () {
    // 回归钉（CODE_REVIEW 2026-10-01 A5）：Course.startSection 是把节次表当
    // 位置下标用的（time_scheme_logic 的 sections[startIndex]）。此前一条坏
    // 记录被直接跳过，12 节的模板丢掉第 4 节后，第 4 节起每门课都显示后一节的
    // 时间，界面看不出异常，学生按错时间到教室。
    final scheme = TimeScheme.fromJson({
      'id': 'scheme-align',
      'name': '对齐测试',
      'sections': [
        {'startTime': '08:00', 'endTime': '08:45'},
        {'startTime': '09:00'}, // bad：缺 endTime
        'not-a-map',
        {'startTime': '10:00', 'endTime': '10:45'},
      ],
    });

    // 位置必须保持：第 4 节仍是第 4 节，而不是被前移成第 2 节。
    expect(scheme.sections.length, 4);
    expect(scheme.sections[0].startTime, '08:00');
    expect(scheme.sections[3].startTime, '10:00');
    expect(scheme.sections[3].endTime, '10:45');
    // 补出来的空洞留空时间（作息管理页渲染为 `-`），不拿别处模板冒充真实铃点。
    expect(scheme.sections[1].startTime, isEmpty);
    expect(scheme.sections[1].endTime, isEmpty);
    expect(scheme.sections[2].startTime, isEmpty);
  });

  test('well-formed section tables round-trip unchanged', () {
    final original = TimeScheme.fromJson({
      'id': 'scheme-clean',
      'name': '正常模板',
      'sections': [
        {'startTime': '08:00', 'endTime': '08:45'},
        {'startTime': '08:55', 'endTime': '09:40'},
        {'startTime': '10:00', 'endTime': '10:45'},
      ],
    });

    expect(original.sections.length, 3);
    expect(
      TimeScheme.fromJsonString(
        original.toJsonString(),
      ).sections.map((s) => s.displayText),
      original.sections.map((s) => s.displayText),
    );
  });

  // `_clockMinutes` 原先只检查「两段 + 是数字」，不检查范围，于是 `25:00` 被算成
  // 1500 分钟、`26:00` 被算成 1560 分钟 —— 「25:00 - 26:00」这种墙上不存在的节次
  // 也能通过 validateSectionTimes 落库并被应用。而超级岛（LiveActivityLogic）与
  // 闹钟（ClassReminderService / SystemAlarmLogic）各自都判它无效：课表上挂着这一节，
  // 显示的时间对不上，也永远不会通知。
  group('validateSectionTimes 的范围守卫', () {
    test('越界钟点被判为非法时间格式', () {
      for (final bad in [
        ['25:00', '26:00'],
        ['08:00', '08:75'],
        ['-1:00', '02:00'],
        ['08:00', '09:60'],
      ]) {
        expect(
          () => validateSectionTimes([
            SectionTime(startTime: bad[0], endTime: bad[1]),
          ]),
          throwsFormatException,
          reason: '${bad[0]}-${bad[1]} 不是合法节次时间',
        );
      }
    });

    test('24:00 作为当天结束仍然合法', () {
      expect(
        validateSectionTimes(const [
          SectionTime(startTime: '22:00', endTime: '24:00'),
        ]),
        isNull,
      );
      // 24:30 不是「当天结束」的写法，仍然拒绝。
      expect(
        () => validateSectionTimes(const [
          SectionTime(startTime: '22:00', endTime: '24:30'),
        ]),
        throwsFormatException,
      );
    });

    test('正常节次表与顺序校验不受影响', () {
      expect(
        validateSectionTimes(const [
          SectionTime(startTime: '08:00', endTime: '08:45'),
          SectionTime(startTime: '09:00', endTime: '09:45'),
        ]),
        isNull,
      );
      expect(
        validateSectionTimes(const [
          SectionTime(startTime: '08:00', endTime: '09:00'),
          SectionTime(startTime: '08:30', endTime: '09:30'),
        ]),
        contains('section_start_before_previous_end'),
      );
    });
  });
}
