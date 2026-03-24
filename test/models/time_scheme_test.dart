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
          contains('跨 0 点课程'),
        ),
      ),
    );
  });

  test('section validation rejects end time before start time', () {
    expect(
      validateSectionTimes(const [
        SectionTime(startTime: '23:30', endTime: '00:15'),
      ]),
      contains('跨 0 点课程'),
    );
  });
}
