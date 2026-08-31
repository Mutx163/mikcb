import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/schedule_item_expander.dart';
import 'package:university_timetable/models/schedule_item.dart';

ScheduleItem _item({
  required String id,
  String title = '日程',
  DateTime? startDate,
  DateTime? endDate,
  String startTime = '08:00',
  String endTime = '09:00',
  ScheduleRecurrence recurrence = ScheduleRecurrence.none,
  List<DateTime> exceptionDates = const [],
  String? seriesId,
  DateTime? occurrenceDate,
}) {
  final start = startDate ?? DateTime(2026, 9);
  return ScheduleItem(
    id: id,
    title: title,
    startDate: start,
    endDate: endDate ?? start,
    startTime: startTime,
    endTime: endTime,
    createdAt: DateTime(2026, 8),
    updatedAt: DateTime(2026, 8),
    recurrence: recurrence,
    exceptionDates: exceptionDates,
    seriesId: seriesId,
    occurrenceDate: occurrenceDate,
  );
}

// 2026-09-01 为周二；weekly 以开始日的星期重复。
void main() {
  group('ScheduleItemExpander.instancesForDate', () {
    test('单次日程命中当天', () {
      final items = [_item(id: 'a', startDate: DateTime(2026, 9))];
      final result = ScheduleItemExpander.instancesForDate(
        items,
        DateTime(2026, 9, 1, 14, 30), // 带时间成分也应命中
      );
      expect(result, hasLength(1));
      expect(result.single.item.id, 'a');
    });

    test('其它日期不命中', () {
      final items = [_item(id: 'a', startDate: DateTime(2026, 9))];
      expect(
        ScheduleItemExpander.instancesForDate(
          items,
          DateTime(2026, 9, 2),
        ),
        isEmpty,
      );
    });

    test('weekly 日程在相同星期展开', () {
      final items = [
        _item(
          id: 'w',
          startDate: DateTime(2026, 9), // 周二
          endDate: DateTime(2026, 9, 30),
          recurrence: ScheduleRecurrence.weekly,
        ),
      ];
      // 2026-09-08 也是周二 → 命中；09-09 周三 → 不命中
      expect(
        ScheduleItemExpander.instancesForDate(
          items,
          DateTime(2026, 9, 8),
        ),
        hasLength(1),
      );
      expect(
        ScheduleItemExpander.instancesForDate(
          items,
          DateTime(2026, 9, 9),
        ),
        isEmpty,
      );
    });

    test('例外日期被排除', () {
      final items = [
        _item(
          id: 'w',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2026, 9, 30),
          recurrence: ScheduleRecurrence.weekly,
          exceptionDates: [DateTime(2026, 9, 8)],
        ),
      ];
      expect(
        ScheduleItemExpander.instancesForDate(
          items,
          DateTime(2026, 9, 8),
        ),
        isEmpty,
      );
    });
  });

  group('ScheduleItemExpander.instancesForRange（去重 + 排序）', () {
    test('同源例外覆盖原系列实例（同一天显示时）', () {
      // 系列：周二每周（09-01 无例外，正常展开）；同日存在移动后的覆盖项，
      // 两者 key 相同（sourceItemId@2026-09-01），覆盖项胜出。
      final series = _item(
        id: 'series',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2026, 9, 30),
        recurrence: ScheduleRecurrence.weekly,
      );
      final override = _item(
        id: 'override-1',
        title: '移动后的日程',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2026, 9),
        seriesId: 'series',
        occurrenceDate: DateTime(2026, 9),
      );
      final result = ScheduleItemExpander.instancesForRange(
        [series, override],
        DateTime(2026, 9),
        DateTime(2026, 9),
      );
      expect(result, hasLength(1));
      expect(result.single.item.id, 'override-1');
      expect(result.single.isSeriesOverride, isTrue);
      // occurrence id 仍指向系列原始日期
      expect(result.single.occurrenceId, contains('2026-09-01'));
    });

    test('多键排序：日期 → 开始时间 → occurrenceId', () {
      final early = _item(
        id: 'b',
        startDate: DateTime(2026, 9),
      );
      final late = _item(
        id: 'a',
        startDate: DateTime(2026, 9, 2),
        startTime: '07:00',
        endTime: '08:00',
      );
      final result = ScheduleItemExpander.instancesForRange(
        [late, early],
        DateTime(2026, 9),
        DateTime(2026, 9, 2),
      );
      expect(result.map((r) => r.item.id).toList(), ['b', 'a']);

      final sameTime = [
        _item(id: 'z', startDate: DateTime(2026, 9)),
        _item(id: 'y', startDate: DateTime(2026, 9)),
      ];
      final tied = ScheduleItemExpander.instancesForRange(
        sameTime,
        DateTime(2026, 9),
        DateTime(2026, 9),
      );
      expect(tied.map((r) => r.item.id).toList(), ['y', 'z']);
    });

    test('结果不可变', () {
      final result = ScheduleItemExpander.instancesForRange(
        [_item(id: 'a')],
        DateTime(2026, 9),
        DateTime(2026, 9),
      );
      expect(
        () => result.add(
          ScheduleItemInstance(item: _item(id: 'x'), date: DateTime(2026, 9)),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('ScheduleItemExpander.putByDisplayDate / sort（单独可用）', () {
    test('普通实例先入，例外覆盖后入可以顶掉', () {
      final map = <String, ScheduleItemInstance>{};
      final normal = ScheduleItemInstance(
        item: _item(id: 's', startDate: DateTime(2026, 9)),
        date: DateTime(2026, 9),
      );
      ScheduleItemExpander.putByDisplayDate(map, normal);
      final override = ScheduleItemInstance(
        item: _item(
          id: 'o',
          startDate: DateTime(2026, 9),
          seriesId: 's',
          occurrenceDate: DateTime(2026, 9),
        ),
        date: DateTime(2026, 9),
      );
      ScheduleItemExpander.putByDisplayDate(map, override);
      expect(map.values.single.item.id, 'o');
    });
  });
}
