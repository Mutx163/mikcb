import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 回归钉（2026-10-05 审查第 16 轮）：学期结束日要按周边界算。
///
/// `statistics_service.dart:470` 用 `addDays(semesterStartDate, totalWeeks*7-1)`
/// 从**原始开学日**数天数，而同文件的周次判定（`_calendarWeekForDate`、
/// `_countSectionsDoneByDate`）都是先 `_weekStart` 对齐到周一再算。开学日不是
/// 周一时两边差出 `weekday(开学日)-1` 天（最多 6 天），后果有两个：
/// 卡片显示的学期结束日与同一份数据在 ICS 导出（`ics_export_screen.dart:278`
/// 用 `_mondayOf`）和传输预览（`unified_transfer_service.dart:942` 用
/// `semesterStartWeek`）里算出的结束日不一致；而且在最后那几天里
/// `phase` 已经是 `ended`，卡片上印着的结束日却还在未来 —— 自相矛盾。
void main() {
  SemesterProgress progress({
    required DateTime semesterStartDate,
    required int semesterWeekCount,
    required DateTime now,
  }) {
    return StatisticsService.calculateSemesterProgress(
      allCourses: const [],
      currentWeek: semesterWeekCount,
      semesterWeekCount: semesterWeekCount,
      semesterStartDate: semesterStartDate,
      now: now,
    );
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  test('周三开学：结束日是最后一教学周的周日，不是从开学日数出来的那天', () {
    // 2026-09-09 是周三；周一起算第 1 周为 09-07..09-13，第 16 周为 12-21..12-27。
    final result = progress(
      semesterStartDate: DateTime(2026, 9, 9),
      semesterWeekCount: 16,
      now: DateTime(2026, 12, 20),
    );

    expect(result.semesterEndDate, isNotNull);
    expect(sameDay(result.semesterEndDate!, DateTime(2026, 12, 27)), isTrue);
  });

  test('phase 已结束时，当前日期不能再早于卡片显示的结束日', () {
    // 修复前 12-28 那天：周次已是 17 → ended，而显示的结束日还是 12-29（未来）。
    for (final day in [
      DateTime(2026, 12, 27),
      DateTime(2026, 12, 28),
      DateTime(2026, 12, 29),
      DateTime(2027, 1, 3),
    ]) {
      final result = progress(
        semesterStartDate: DateTime(2026, 9, 9),
        semesterWeekCount: 16,
        now: day,
      );
      if (result.phase == SemesterProgressPhase.ended) {
        expect(
          result.currentDate!.isAfter(result.semesterEndDate!) ||
              sameDay(result.currentDate!, result.semesterEndDate!),
          isTrue,
          reason: '$day 时 phase=ended 但结束日还在未来',
        );
      }
    }
  });

  test('对照：周一开学时结束日与旧口径一致（既有断言不受影响）', () {
    final result = progress(
      semesterStartDate: DateTime(2026, 9, 7),
      semesterWeekCount: 16,
      now: DateTime(2026, 9, 7),
    );

    expect(
      result.semesterEndDate,
      DateTime(2026, 9, 7).add(const Duration(days: 16 * 7 - 1)),
    );
  });

  test('对照：周六开学同样落到当周周日', () {
    // 2026-09-12 是周六，第 1 周 09-07..09-13；2 周学期结束于 09-20。
    final result = progress(
      semesterStartDate: DateTime(2026, 9, 12),
      semesterWeekCount: 2,
      now: DateTime(2026, 9, 12),
    );

    expect(sameDay(result.semesterEndDate!, DateTime(2026, 9, 20)), isTrue);
  });
}
