import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/holiday_resolver.dart';
import 'package:university_timetable/models/holiday_entry.dart';

HolidayData _data(List<HolidayEntry> entries) =>
    HolidayData(year: 2026, version: 1, entries: entries);

final _vacation = HolidayEntry(
  date: DateTime(2026, 10, 1),
  name: '国庆节',
  type: HolidayType.vacation,
  groupId: 'national-day-2026',
);

final _makeupWorkday = HolidayEntry(
  date: DateTime(2026, 9, 26),
  name: '调休上班',
  type: HolidayType.adjustedWorkday,
  groupId: 'national-day-2026',
);

final _customRest = HolidayEntry(
  date: DateTime(2026, 9, 26),
  name: '自定义休息',
  type: HolidayType.vacation,
  groupId: 'custom-user-1',
);

void main() {
  group('HolidayResolver.isHoliday（三层展示策略）', () {
    test('无数据时视为无假期（开关全开）', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 1),
          data: null,
          overrideEnabled: false,
          markingEnabled: true,
        ),
        isFalse,
      );
    });

    test('假期标记关闭时假期日不隐藏', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 1),
          data: _data([_vacation]),
          overrideEnabled: false,
          markingEnabled: false,
        ),
        isFalse,
      );
    });

    test('覆盖模式开启时法定假期隐藏', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 1),
          data: _data([_vacation]),
          overrideEnabled: true,
          markingEnabled: true,
        ),
        isTrue,
      );
    });

    test('调休上班日优先级最高——覆盖模式下也显示课程', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 9, 26),
          data: _data([_makeupWorkday]),
          overrideEnabled: true,
          markingEnabled: true,
        ),
        isFalse,
      );
    });

    test('普通开关下法定假期隐藏', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 1),
          data: _data([_vacation]),
          overrideEnabled: false,
          markingEnabled: true,
        ),
        isTrue,
      );
    });

    test('普通日期不隐藏', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 12),
          data: _data([_vacation]),
          overrideEnabled: false,
          markingEnabled: true,
        ),
        isFalse,
      );
    });

    test('带时间成分的日期也能命中（按日归零比较）', () {
      expect(
        HolidayResolver.isHoliday(
          DateTime(2026, 10, 1, 8, 30),
          data: _data([_vacation]),
          overrideEnabled: false,
          markingEnabled: true,
        ),
        isTrue,
      );
    });
  });

  group('HolidayResolver.isAdjustedWorkday', () {
    test('调休上班日为真', () {
      expect(
        HolidayResolver.isAdjustedWorkday(
          DateTime(2026, 9, 26),
          data: _data([_makeupWorkday]),
        ),
        isTrue,
      );
    });

    test('法定假期不是调休上班日', () {
      expect(
        HolidayResolver.isAdjustedWorkday(
          DateTime(2026, 10, 1),
          data: _data([_vacation]),
        ),
        isFalse,
      );
    });

    test('自定义休息覆盖同日调休上班时不视为上班日', () {
      expect(
        HolidayResolver.isAdjustedWorkday(
          DateTime(2026, 9, 26),
          data: _data([_makeupWorkday, _customRest]),
        ),
        isFalse,
      );
    });

    test('无数据时为假', () {
      expect(
        HolidayResolver.isAdjustedWorkday(DateTime(2026, 9, 26), data: null),
        isFalse,
      );
    });
  });
}
