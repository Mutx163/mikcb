import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/day_view_paging.dart';

/// 回归钉（2026-10-02 审查第 9 轮，日视图分页口径）：
///
/// 修之前 `timetable_screen.dart:1685` 是
/// `final dayIndex = math.max(0, visibleDays.indexOf(dayOfWeek));`，
/// 越界星期被静默折到周一那一页，而"选中日"这份状态没跟着改 ——
/// 同一帧里内容、表头高亮、添加课程预填三处读到互相矛盾的值。
/// 下面第一组用例把这个静默折叠复现出来（钉住"为什么会错"），
/// 其余用例钉新口径的不变量：先归一再算页号、两个方向严格互逆。
void main() {
  const sevenDays = [1, 2, 3, 4, 5, 6, 7];
  const weekdaysOnly = [1, 2, 3, 4, 5];

  group('旧口径的静默折叠（修复动机的复现）', () {
    test('max(0, indexOf) 把周六折进周一那一页，两天共用一个页号', () {
      int legacyPage(int week, int dayOfWeek) =>
          (week - 1) * weekdaysOnly.length +
          math.max(0, weekdaysOnly.indexOf(dayOfWeek));

      // 周六与周一算出同一页 —— 页号本身"看着能用"，但状态里仍是 6：
      // 内容显示周一、表头拿 6 去比 1..5 一格都不亮、添加课程预填周六。
      expect(legacyPage(1, 6), legacyPage(1, 1));
      expect(legacyPage(3, 7), legacyPage(3, 1));
      // 新口径不再留下这份矛盾：越界星期在算页号之前就先归一。
      expect(
        dayViewGlobalPage(
          visibleDays: weekdaysOnly,
          week: 1,
          dayOfWeek: 6,
        ),
        dayViewGlobalPage(visibleDays: weekdaysOnly, week: 1, dayOfWeek: 1),
      );
      expect(
        normalizeDayOfWeekForVisibleDays(weekdaysOnly, 6),
        1,
        reason: '归一后状态与页号一致，表头与预填跟着对上',
      );
    });
  });

  group('归一星期', () {
    test('可见日内原样返回（两种隐藏周末取值、七个星期全覆盖）', () {
      for (final visible in const [sevenDays, weekdaysOnly]) {
        for (final day in visible) {
          expect(
            normalizeDayOfWeekForVisibleDays(visible, day),
            day,
            reason: '$day 在 $visible 里本该不动',
          );
        }
      }
    });

    test('周末日在隐藏周末时回落到第一个可见日', () {
      expect(normalizeDayOfWeekForVisibleDays(weekdaysOnly, 6), 1);
      expect(normalizeDayOfWeekForVisibleDays(weekdaysOnly, 7), 1);
    });

    test('非 1..7 的脏值同样被收进可见集，不外泄', () {
      expect(normalizeDayOfWeekForVisibleDays(sevenDays, 0), 1);
      expect(normalizeDayOfWeekForVisibleDays(sevenDays, 8), 1);
      expect(normalizeDayOfWeekForVisibleDays(sevenDays, -3), 1);
    });

    test('可见集为空时原样返回（不抛、不返回 0）', () {
      expect(normalizeDayOfWeekForVisibleDays(const [], 4), 4);
    });
  });

  group('页号两个方向互逆', () {
    test('每个周次每个可见日：日 → 页 → 日 必须回到原值', () {
      for (final visible in const [sevenDays, weekdaysOnly]) {
        for (var week = 1; week <= 20; week++) {
          for (final day in visible) {
            final page = dayViewGlobalPage(
              visibleDays: visible,
              week: week,
              dayOfWeek: day,
            );
            final target = dayViewTargetForGlobalPage(visible, page)!;
            expect(target.$1, week, reason: 'week=$day 页号 $page 回到第 ${target.$1} 周');
            expect(target.$2, day, reason: 'week=$week day=$day → 页 $page → ${target.$2}');
          }
        }
      }
    });

    test('越界日归一后仍然互逆，不会造出不可见的星期', () {
      for (final day in [0, 6, 7, 8, 99]) {
        final page = dayViewGlobalPage(
          visibleDays: weekdaysOnly,
          week: 5,
          dayOfWeek: day,
        );
        final target = dayViewTargetForGlobalPage(weekdaysOnly, page)!;
        expect(weekdaysOnly, contains(target.$2));
        expect(page, inInclusiveRange(0, 5 * weekdaysOnly.length - 1));
      }
    });

    test('页号在整个学期内连续且不越界（隐藏周末时学期页数按 5 计）', () {
      const weeks = 20;
      final lastPage = dayViewGlobalPage(
        visibleDays: weekdaysOnly,
        week: weeks,
        dayOfWeek: 5,
      );
      expect(lastPage, weeks * weekdaysOnly.length - 1);
      expect(
        dayViewTargetForGlobalPage(weekdaysOnly, lastPage),
        (weeks, 5),
      );
    });

    test('不同（周次, 可见日）不会撞同一个页号', () {
      for (final visible in const [sevenDays, weekdaysOnly]) {
        final seen = <int>{};
        for (var week = 1; week <= 12; week++) {
          for (final day in visible) {
            final page = dayViewGlobalPage(
              visibleDays: visible,
              week: week,
              dayOfWeek: day,
            );
            expect(seen.add(page), isTrue, reason: '第 $week 周星期 $day 撞页号 $page');
          }
        }
      }
    });

    test('可见集为空时逆运算返回 null 而不是崩溃', () {
      expect(dayViewTargetForGlobalPage(const [], 3), isNull);
    });
  });
}
