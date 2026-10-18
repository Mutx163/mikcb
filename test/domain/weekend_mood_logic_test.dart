import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/weekend_mood_logic.dart';

/// 「周末文案」档位判定的边界用例。
///
/// 这份测试刻意把入参全给死（不建课表、不建假期数据）：判定规则一旦在这里
/// 钉住，安卓侧 `widgetResolveWeekendMood` 就得照抄同一组输入输出，
/// 两边才不会出现「App 开着显示周末愉快、杀掉重启后变成今日无课」。
void main() {
  group('WeekendMood 取值', () {
    test('三个档位的 value 与安卓侧字符串一致', () {
      expect(WeekendMood.none.value, 'none');
      expect(WeekendMood.rest.value, 'rest');
      expect(WeekendMood.ahead.value, 'ahead');
    });

    test('从快照读回：认识已知档位，未知值回落 none', () {
      expect(WeekendMoodX.fromValue('rest'), WeekendMood.rest);
      expect(WeekendMoodX.fromValue('ahead'), WeekendMood.ahead);
      expect(WeekendMoodX.fromValue('none'), WeekendMood.none);
      // 老版本快照没有这个键 / 原生塞了脏值，都不能炸。
      expect(WeekendMoodX.fromValue(null), WeekendMood.none);
      expect(WeekendMoodX.fromValue(''), WeekendMood.none);
      expect(WeekendMoodX.fromValue('holiday'), WeekendMood.none);
    });
  });

  group('周末两天', () {
    // 2026-03-28 / 03-29 是周六 / 周日。
    test('周六没排课 → 周末愉快', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 28, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.rest,
      );
    });

    test('周日没排课 → 周末愉快，直到周日 24 点都成立', () {
      for (final hour in [0, 9, 18, 23]) {
        expect(
          resolveWeekendMood(
            now: DateTime(2026, 3, 29, hour),
            hasAnyCourseToday: false,
            hasRemainingCourseToday: false,
            isHolidayToday: false,
            isAdjustedWorkdayToday: false,
            isAdjustedWorkdayTomorrow: false,
          ),
          WeekendMood.rest,
          reason: '周日 $hour 点',
        );
      }
    });

    test('周六有课 → 走课程呈现，绝不冒充周末', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 28, 10),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: true,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周六的课已经上完 → 仍走「今日已结束」，不是周末文案', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 28, 18),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周六的课全被停课 → 同样不算周末（那天确实排了课）', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 28, 10),
          // 原始排了 2 节、当前 active 列表为空（全停课）。
          hasAnyCourseToday: true,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('调休补班的周六没课 → 不说周末愉快', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 5, 9, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: true,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周末撞上法定假期 → 假期文案优先，不叠加周末档', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 10, 10, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: true,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });
  });

  group('周五收课', () {
    // 2026-03-27 是周五，明天 03-28 是周六。
    test('周五课都上完了 → 周末要开始了', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 27, 18),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.ahead,
      );
    });

    test('周五最后一节课刚下课那一分钟就切文案', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 27, 17, 35),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.ahead,
      );
    });

    test('周五还有课要上 → 照旧显示课程', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 27, 16, 40),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: true,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周五正在上课 → 照旧显示课程', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 27, 14, 30),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: true,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周五整天没排课 → 从零点就显示「周末要开始了」', () {
      for (final hour in [0, 8, 12, 23]) {
        expect(
          resolveWeekendMood(
            now: DateTime(2026, 3, 27, hour),
            hasAnyCourseToday: false,
            hasRemainingCourseToday: false,
            isHolidayToday: false,
            isAdjustedWorkdayToday: false,
            isAdjustedWorkdayTomorrow: false,
          ),
          WeekendMood.ahead,
          reason: '周五 $hour 点',
        );
      }
    });

    test('明天周六是调休补班 → 不说周末要开始了', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 27, 18),
          hasAnyCourseToday: true,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: true,
        ),
        WeekendMood.none,
      );
    });

    test('周五当天是法定假期 → 假期文案优先', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 4, 3, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: true,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('跨年的周五照样认明天是周六', () {
      // 2027-01-01 是周五，2027-01-02 是周六：星期跨年连续，
      // 不允许因为「换了年份」而漏判。
      final friday = DateTime(2027, 1, 1, 20);
      expect(friday.weekday, DateTime.friday);
      expect(friday.add(const Duration(days: 1)).weekday, DateTime.saturday);
      expect(
        resolveWeekendMood(
          now: friday,
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.ahead,
      );
    });
  });

  group('工作日', () {
    test('周一没课 → 维持「今日无课」', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 3, 30, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });

    test('周四没课 → 什么都不显示（明天还是工作日）', () {
      expect(
        resolveWeekendMood(
          now: DateTime(2026, 4, 2, 10),
          hasAnyCourseToday: false,
          hasRemainingCourseToday: false,
          isHolidayToday: false,
          isAdjustedWorkdayToday: false,
          isAdjustedWorkdayTomorrow: false,
        ),
        WeekendMood.none,
      );
    });
  });
}
