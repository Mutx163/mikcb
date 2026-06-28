import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/holiday_entry.dart';

void main() {
  group('HolidayEntry', () {
    test('serializes and restores json', () {
      final entry = HolidayEntry(
        date: DateTime(2026, 10, 1),
        name: '国庆节',
        type: HolidayType.vacation,
        groupId: 'national-day-2026',
      );

      final restored = HolidayEntry.fromJson(entry.toJson());

      expect(restored.name, '国庆节');
      expect(restored.type, HolidayType.vacation);
      expect(restored.groupId, 'national-day-2026');
      expect(restored.date, DateTime(2026, 10, 1));
      expect(restored.shouldHideCourses, isTrue);
      expect(restored.isAdjustedWorkday, isFalse);
    });

    test('type helpers distinguish vacation and makeup workday', () {
      final vacation = HolidayEntry(
        date: DateTime(2026, 10, 1),
        name: '国庆节',
        type: HolidayType.vacation,
      );
      final makeup = HolidayEntry(
        date: DateTime(2026, 10, 10),
        name: '调休上班',
        type: HolidayType.adjustedWorkday,
      );

      expect(vacation.shouldHideCourses, isTrue);
      expect(makeup.shouldHideCourses, isFalse);
      expect(makeup.isAdjustedWorkday, isTrue);
    });
  });

  group('HolidayData', () {
    HolidayData buildSampleData() {
      return HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: DateTime(2026, 10, 1),
            name: '国庆节',
            type: HolidayType.vacation,
            groupId: 'national-day-2026',
          ),
          HolidayEntry(
            date: DateTime(2026, 10, 2),
            name: '国庆节',
            type: HolidayType.vacation,
            groupId: 'national-day-2026',
          ),
          HolidayEntry(
            date: DateTime(2026, 10, 10),
            name: '调休上班',
            type: HolidayType.adjustedWorkday,
            groupId: 'national-day-2026',
          ),
          HolidayEntry(
            date: DateTime(2026, 12, 25),
            name: '校历放假',
            type: HolidayType.vacation,
            groupId: 'custom-school-break',
          ),
        ],
      );
    }

    test('entryForDate returns matching day', () {
      final data = buildSampleData();

      expect(
        data.entryForDate(DateTime(2026, 10, 1, 15, 30))?.name,
        '国庆节',
      );
      expect(data.entryForDate(DateTime(2026, 3, 1)), isNull);
    });

    test('isHoliday treats vacation days as holidays', () {
      final data = buildSampleData();

      expect(data.isHoliday(DateTime(2026, 10, 1)), isTrue);
      expect(data.isHoliday(DateTime(2026, 10, 2)), isTrue);
    });

    test('isHoliday treats makeup workdays as non-holidays', () {
      final data = buildSampleData();

      expect(data.isHoliday(DateTime(2026, 10, 10)), isFalse);
      expect(data.isAdjustedWorkday(DateTime(2026, 10, 10)), isTrue);
    });

    test('custom vacation overrides makeup workday on same date', () {
      final data = HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: DateTime(2026, 5, 4),
            name: '调休上班',
            type: HolidayType.adjustedWorkday,
            groupId: 'labor-day-2026',
          ),
          HolidayEntry(
            date: DateTime(2026, 5, 4),
            name: '学校放假',
            type: HolidayType.vacation,
            groupId: 'custom-school-closure',
          ),
        ],
      );

      expect(data.isHoliday(DateTime(2026, 5, 4)), isTrue);
      expect(data.isAdjustedWorkday(DateTime(2026, 5, 4)), isFalse);
    });

    test('entriesForGroup returns sorted group members', () {
      final data = buildSampleData();

      final group = data.entriesForGroup('national-day-2026');

      expect(group, hasLength(3));
      expect(group.first.date, DateTime(2026, 10, 1));
      expect(group.last.date, DateTime(2026, 10, 10));
    });

    test('json roundtrip preserves entries', () {
      final data = buildSampleData();

      final restored = HolidayData.fromJson(data.toJson());

      expect(restored.year, 2026);
      expect(restored.version, 1);
      expect(restored.entries, hasLength(4));
      expect(restored.isHoliday(DateTime(2026, 10, 1)), isTrue);
    });
  });
}
