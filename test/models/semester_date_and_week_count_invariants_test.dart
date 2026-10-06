import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 开学日与学期周数这两条不变式在解析侧没守住（第 35 轮）。
///
/// 一、`parseSemesterStartDate`（timetable_settings.dart:2006-2024）只判
/// `month 1..12 / day 1..31`，不判"这一天真的存在"：`2026-04-31` 与 `2026-02-31`
/// 会被 `DateTime(year, month, day)` **静默归一**成 2026-05-01 / 2026-03-03。
/// 实测（直接调用该函数）：
///   2026-02-31 -> 2026-03-03
///   2026-04-31 -> 2026-05-01
/// 开学日挪几天 → `WeekCalculator.startOfWeek` 落到别的星期 → **整学期周次 +1/−1、
/// 单双周整体翻转**，而设置页显示的日期"看着还是那个数"。函数自己的注释
/// （:2002-2004）承诺的是"文本坏了宁可让用户重设，也不要悄悄用一周错误的课表"；
/// 同仓另一份实现 `warehouse_course_import_logic.dart:44-56` 正是用 round-trip
/// 判掉顺延并写着"silently accepting a rollover corrupts a whole semester"。
///
/// 二、`semesterWeekCount` 的"至少 1 周"守了两处（`timetable_profile.dart:24-27`、
/// `lan_edit_provider_host.dart:475`）漏了两处：`fromJson:2358` 与 `copyWith` 都不钳。
/// 存量数据里出现 0/负数（老版本、手改备份、跨端同步）时
/// `availableWeeks`（:3570-3572 的 `List.generate`）给出空表，
/// 而 `add_course_screen.dart:1584/1762`、`timetable_screen.dart:7355` 都取
/// `.first` → StateError，**添加课程页直接打不开**。
void main() {
  group('开学日必须是真实存在的日历日', () {
    test('2026-04-31 不能悄悄顺延成 5 月 1 日', () {
      expect(
        TimetableSettings.parseSemesterStartDate('2026-04-31', null),
        isNull,
      );
    });

    test('2026-02-31 同理，不落到 3 月 3 日', () {
      expect(
        TimetableSettings.parseSemesterStartDate('2026-02-31', null),
        isNull,
      );
    });

    test('合法日期照旧解析（含未补零写法）', () {
      expect(
        TimetableSettings.parseSemesterStartDate('2026-09-07', null),
        DateTime(2026, 9, 7),
      );
      expect(
        TimetableSettings.parseSemesterStartDate('2026-9-7', null),
        DateTime(2026, 9, 7),
      );
      expect(
        TimetableSettings.parseSemesterStartDate('2026-02-29', null),
        isNull,
        reason: '2026 不是闰年',
      );
      expect(
        TimetableSettings.parseSemesterStartDate('2024-02-29', null),
        DateTime(2024, 2, 29),
      );
    });

    test('从 JSON 读回来时同样不接受顺延的日期', () {
      final restored = TimetableSettings.fromJson({
        'semesterStartDateText': '2026-04-31',
      });

      expect(restored.semesterStartDate, isNull);
    });
  });

  group('学期周数至少 1 周', () {
    test('解析到 0 或负数时钳成 1，availableWeeks 不为空', () {
      for (final raw in [0, -5]) {
        final settings = TimetableSettings.fromJson({'semesterWeekCount': raw});

        expect(settings.semesterWeekCount, 1, reason: 'raw=$raw');
        expect(settings.availableWeeks, isNotEmpty, reason: 'raw=$raw');
        expect(settings.availableWeeks.first, 1, reason: 'raw=$raw');
      }
    });

    test('availableWeeks 对内存里已存在的 0 也不抛（getter 自己守住）', () {
      final settings = TimetableSettings.defaults().copyWith(
        semesterWeekCount: 0,
      );

      expect(settings.availableWeeks, [1]);
    });

    test('正常周数不受影响', () {
      final settings = TimetableSettings.fromJson({'semesterWeekCount': 19});

      expect(settings.semesterWeekCount, 19);
      expect(settings.availableWeeks, hasLength(19));
      expect(settings.availableWeeks.last, 19);
    });
  });
}
