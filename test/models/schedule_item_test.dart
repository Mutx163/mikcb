import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_item.dart';

void main() {
  final createdAt = DateTime.utc(2026, 4, 1, 10);
  final updatedAt = DateTime.utc(2026, 4, 2, 11);

  ScheduleItem buildItem({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String startTime = '08:00',
    String endTime = '09:00',
    Object recurrence = ScheduleRecurrence.none,
    Iterable<DateTime>? exceptionDates,
    String? seriesId,
    DateTime? occurrenceDate,
    int? reminderMinutesBefore,
    bool enabled = true,
  }) {
    return ScheduleItem(
      id: 'item-1',
      title: '社团活动',
      location: '活动中心',
      note: '带学生证',
      date: date,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      color: '#5B9CF6',
      createdAt: createdAt,
      updatedAt: updatedAt,
      recurrence: recurrence,
      exceptionDates: exceptionDates,
      seriesId: seriesId,
      occurrenceDate: occurrenceDate,
      reminderMinutesBefore: reminderMinutesBefore,
      enabled: enabled,
    );
  }

  group('ScheduleItem construction', () {
    test('normalizes date to calendar day and aliases date to startDate', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 16, 15, 30),
        endDate: DateTime(2026, 4, 18, 9),
      );

      expect(item.startDate, DateTime(2026, 4, 16));
      expect(item.endDate, DateTime(2026, 4, 18));
      expect(item.date, item.startDate);
    });

    test('clamps endDate up to startDate when end is earlier', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 20),
        endDate: DateTime(2026, 4, 10),
      );

      expect(item.startDate, DateTime(2026, 4, 20));
      expect(item.endDate, DateTime(2026, 4, 20));
    });

    test('defaults endDate to startDate when omitted', () {
      final item = buildItem(startDate: DateTime(2026, 5, 1));

      expect(item.endDate, DateTime(2026, 5, 1));
    });

    test('legacy date constructor argument fills start and end', () {
      final item = buildItem(date: DateTime(2026, 6, 1, 12));

      expect(item.startDate, DateTime(2026, 6, 1));
      expect(item.endDate, DateTime(2026, 6, 1));
    });
  });

  group('ScheduleItem json', () {
    test('round-trips full fields through toJson/fromJson', () {
      final original = buildItem(
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 17),
      );

      final restored = ScheduleItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.location, original.location);
      expect(restored.note, original.note);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.color, original.color);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('fromJson accepts legacy date-only payload', () {
      final restored = ScheduleItem.fromJson({
        'id': 'legacy-1',
        'title': '旧日程',
        'date': '2026-03-10T00:00:00.000',
        'startTime': '14:00',
        'endTime': '15:30',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      });

      expect(restored.startDate, DateTime(2026, 3, 10));
      expect(restored.endDate, DateTime(2026, 3, 10));
      expect(restored.startTime, '14:00');
      expect(restored.endTime, '15:30');
      expect(restored.color, '#5B9CF6');
    });

    test('fromJson fills defaults for missing optional fields', () {
      final restored = ScheduleItem.fromJson({
        'id': 'minimal-1',
        'title': null,
        'startDate': '2026-07-01T08:00:00.000',
        'createdAt': 'not-a-date',
        'updatedAt': 'also-bad',
      });

      expect(restored.title, '');
      expect(restored.startTime, '08:00');
      expect(restored.endTime, '09:00');
      expect(restored.color, '#5B9CF6');
      expect(restored.startDate, DateTime(2026, 7, 1));
      expect(restored.endDate, DateTime(2026, 7, 1));
    });

    test('json string helpers round-trip', () {
      final original = buildItem(startDate: DateTime(2026, 8, 1));
      final restored = ScheduleItem.fromJsonString(original.toJsonString());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.startDate, original.startDate);
    });

    test('round-trips recurrence and local exception dates', () {
      final original = buildItem(
        startDate: DateTime.utc(2026, 4, 16, 23),
        endDate: DateTime(2026, 4, 20, 9),
        recurrence: ScheduleRecurrence.daily,
        exceptionDates: [
          DateTime(2026, 4, 18, 18),
          DateTime.utc(2026, 4, 18, 2),
        ],
      );

      final json = original.toJson();
      final restored = ScheduleItem.fromJson(json);

      expect(json['date'], isNotNull);
      expect(json['startDate'], isNotNull);
      expect(json['endDate'], isNotNull);
      expect(json['recurrence'], 'daily');
      expect(restored.recurrence, ScheduleRecurrence.daily);
      expect(restored.exceptionDates, [DateTime(2026, 4, 18)]);
    });

    test('legacy payload without recurrence remains a one-time item', () {
      final restored = ScheduleItem.fromJson({
        'id': 'legacy-one-off',
        'title': '旧日程',
        'date': '2026-03-10T00:00:00.000',
        'startTime': '14:00',
        'endTime': '15:30',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      });

      expect(restored.recurrence, ScheduleRecurrence.none);
      expect(
        restored.expandDates(
          fromDate: DateTime(2026, 3, 10),
          toDate: DateTime(2026, 3, 20),
        ),
        [DateTime(2026, 3, 10)],
      );
    });

    test('round-trips reminder and enabled pause state', () {
      final original = buildItem(
        startDate: DateTime(2026, 8, 1),
        reminderMinutesBefore: 15,
        enabled: false,
      );

      final restored = ScheduleItem.fromJson(original.toJson());

      expect(restored.reminderMinutesBefore, 15);
      expect(restored.enabled, isFalse);
    });
  });

  group('ScheduleItem copyWith and coversDate', () {
    test('copyWith can clear location and note with sentinel', () {
      final original = buildItem(startDate: DateTime(2026, 4, 16));
      final cleared = original.copyWith(location: null, note: null);

      expect(cleared.location, isNull);
      expect(cleared.note, isNull);
      expect(cleared.title, original.title);
    });

    test('copyWith date overrides startDate when startDate omitted', () {
      final original = buildItem(startDate: DateTime(2026, 4, 16));
      final moved = original.copyWith(date: DateTime(2026, 4, 20));

      expect(moved.startDate, DateTime(2026, 4, 20));
    });

    test('coversDate is inclusive on both ends', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 18),
      );

      expect(item.coversDate(DateTime(2026, 4, 15, 23)), isFalse);
      expect(item.coversDate(DateTime(2026, 4, 16, 8)), isTrue);
      expect(item.coversDate(DateTime(2026, 4, 17, 12)), isTrue);
      expect(item.coversDate(DateTime(2026, 4, 18, 23)), isTrue);
      expect(item.coversDate(DateTime(2026, 4, 19)), isFalse);
    });

    test(
      'daily recurrence expands every local date through the end boundary',
      () {
        final item = buildItem(
          startDate: DateTime(2026, 4, 16, 23),
          endDate: DateTime(2026, 4, 19, 1),
          recurrence: ScheduleRecurrence.daily,
        );

        final instances = item.expandInstances(
          fromDate: DateTime(2026, 4, 15, 22),
          toDate: DateTime(2026, 4, 20),
        );

        expect(instances.map((instance) => instance.date), [
          DateTime(2026, 4, 16),
          DateTime(2026, 4, 17),
          DateTime(2026, 4, 18),
          DateTime(2026, 4, 19),
        ]);
        expect(instances.last.occurrenceId, 'item-1@2026-04-19');
      },
    );

    test('weekly recurrence uses the start date weekday', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 5, 1),
        recurrence: ScheduleRecurrence.weekly,
      );

      expect(
        item.occurrenceDates(
          fromDate: DateTime(2026, 4, 15),
          toDate: DateTime(2026, 5, 1),
        ),
        [DateTime(2026, 4, 16), DateTime(2026, 4, 23), DateTime(2026, 4, 30)],
      );
      expect(item.occursOn(DateTime(2026, 4, 17)), isFalse);
    });

    test('exceptions are normalized, deduplicated, and excluded', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 16),
        endDate: DateTime(2026, 4, 20),
        recurrence: ScheduleRecurrence.daily,
        exceptionDates: [
          DateTime(2026, 4, 18, 20),
          DateTime.utc(2026, 4, 18, 1),
          DateTime(2026, 4, 19),
        ],
      );

      expect(item.exceptionDates, [
        DateTime(2026, 4, 18),
        DateTime(2026, 4, 19),
      ]);
      expect(
        item.occurrenceDates(
          fromDate: DateTime(2026, 4, 16),
          toDate: DateTime(2026, 4, 20),
        ),
        [DateTime(2026, 4, 16), DateTime(2026, 4, 17), DateTime(2026, 4, 20)],
      );
      expect(item.copyWith(exceptionDates: []).exceptionDates, isEmpty);
    });

    test('override occurrence id remains tied to the original series date', () {
      final item = buildItem(
        startDate: DateTime(2026, 4, 20),
        seriesId: 'series-1',
        occurrenceDate: DateTime(2026, 4, 16),
      );

      final instance = item
          .expandInstances(
            fromDate: DateTime(2026, 4, 20),
            toDate: DateTime(2026, 4, 20),
          )
          .single;

      expect(instance.date, DateTime(2026, 4, 20));
      expect(instance.occurrenceDate, DateTime(2026, 4, 16));
      expect(instance.occurrenceId, 'series-1@2026-04-16');
    });
  });
}
