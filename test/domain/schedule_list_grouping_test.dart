import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/schedule_list_grouping.dart';
import 'package:university_timetable/models/schedule_item.dart';

ScheduleItem _item({
  required String id,
  String title = '日程',
  required DateTime startDate,
  DateTime? endDate,
  String startTime = '08:00',
  String endTime = '09:00',
  ScheduleRecurrence recurrence = ScheduleRecurrence.none,
  bool enabled = true,
  String? seriesId,
  DateTime? occurrenceDate,
}) {
  return ScheduleItem(
    id: id,
    title: title,
    startDate: startDate,
    endDate: endDate ?? startDate,
    startTime: startTime,
    endTime: endTime,
    createdAt: DateTime(2026, 8),
    updatedAt: DateTime(2026, 8),
    recurrence: recurrence,
    enabled: enabled,
    seriesId: seriesId,
    occurrenceDate: occurrenceDate,
  );
}

// 参考日 2026-09-02（周三）；2026-09-01 为周二。
void main() {
  group('ScheduleListGrouper.group', () {
    test('系列单次覆盖不进入列表分组', () {
      final groups = ScheduleListGrouper.group([
        _item(id: 'root', startDate: DateTime(2026, 9, 3)),
        _item(
          id: 'override-1',
          startDate: DateTime(2026, 9, 3),
          seriesId: 'root',
          occurrenceDate: DateTime(2026, 9, 3),
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.upcoming, hasLength(1));
      expect(groups.upcoming.single.item.id, 'root');
      expect(groups.past, isEmpty);
      expect(groups.paused, isEmpty);
    });

    test('未来的单次日程进入即将到来', () {
      final groups = ScheduleListGrouper.group([
        _item(id: 'a', startDate: DateTime(2026, 9, 3)),
      ], DateTime(2026, 9, 2));
      expect(groups.upcoming.single.nextDate, DateTime(2026, 9, 3));
      expect(groups.upcoming.single.ongoing, isFalse);
    });

    test('当天发生的单次日程仍算即将到来', () {
      final groups = ScheduleListGrouper.group([
        _item(id: 'a', startDate: DateTime(2026, 9, 2)),
      ], DateTime(2026, 9, 2, 18));
      expect(groups.upcoming, hasLength(1));
    });

    test('跨天进行中的单次日程标记 ongoing 且取开始日', () {
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'a',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2026, 9, 4),
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.upcoming.single.ongoing, isTrue);
      expect(groups.upcoming.single.nextDate, DateTime(2026, 9));
    });

    test('已结束的跨天日程进入已过期', () {
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'a',
          startDate: DateTime(2026, 8, 30),
          endDate: DateTime(2026, 9),
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.past, hasLength(1));
      expect(groups.upcoming, isEmpty);
    });

    test('重复日程在重复结束日内找到下一个发生日', () {
      // 2026-09-01 为周二，weekly 以周二重复；参考日周三 → 下次 9/8。
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'w',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2026, 9, 30),
          recurrence: ScheduleRecurrence.weekly,
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.upcoming.single.nextDate, DateTime(2026, 9, 8));
    });

    test('重复日程命中当天时取当天', () {
      // 2026-09-02 周三是 daily 的发生日。
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'd',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2026, 9, 30),
          recurrence: ScheduleRecurrence.daily,
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.upcoming.single.nextDate, DateTime(2026, 9, 2));
    });

    test('重复结束日已过的重复日程进入已过期', () {
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'w',
          startDate: DateTime(2026, 8, 25),
          endDate: DateTime(2026, 9),
          recurrence: ScheduleRecurrence.weekly,
        ),
      ], DateTime(2026, 9, 2));
      expect(groups.past, hasLength(1));
      expect(groups.upcoming, isEmpty);
    });

    test('暂停日程独立成组，不看时间状态', () {
      final groups = ScheduleListGrouper.group([
        _item(id: 'future', startDate: DateTime(2026, 9, 3), enabled: false),
        _item(id: 'past', startDate: DateTime(2026, 8), enabled: false),
      ], DateTime(2026, 9, 2));
      expect(groups.paused, hasLength(2));
      expect(groups.upcoming, isEmpty);
      expect(groups.past, isEmpty);
      // 暂停组按时间性下次发生日新的在前。
      expect(groups.paused.first.item.id, 'future');
    });

    test('即将到来组按下次发生日与开始时间排序', () {
      final groups = ScheduleListGrouper.group([
        _item(
          id: 'late',
          startDate: DateTime(2026, 9, 3),
          startTime: '20:00',
        ),
        _item(
          id: 'early-same-day',
          startDate: DateTime(2026, 9, 3),
          startTime: '07:00',
        ),
        _item(id: 'earlier-day', startDate: DateTime(2026, 9, 2)),
      ], DateTime(2026, 9, 2));
      expect(
        groups.upcoming.map((entry) => entry.item.id).toList(),
        ['earlier-day', 'early-same-day', 'late'],
      );
    });

    test('已过期组按结束日期新的在前', () {
      final groups = ScheduleListGrouper.group([
        _item(id: 'old', startDate: DateTime(2026, 8)),
        _item(id: 'recent', startDate: DateTime(2026, 9)),
      ], DateTime(2026, 9, 2));
      expect(groups.past.map((entry) => entry.item.id).toList(), [
        'recent',
        'old',
      ]);
    });

    test('全空列表返回空分组', () {
      final groups = ScheduleListGrouper.group([], DateTime(2026, 9, 2));
      expect(groups.isEmpty, isTrue);
    });
  });
}
