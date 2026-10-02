import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 回归钉（2026-10-02 审查第 7 轮，统计「时间利用」的钟点比较）：
///
/// `calculateTimeUtilization`（statistics_service.dart:577-594）拿
/// `String.compareTo` 直接比钟点串，而同文件已经有 `_startMinutes/_endMinutes`
/// （:757-761）专门为这件事写，注释点名两种错：空串（作息按位补空的洞）比任何值
/// 都小、未补零的 `8:00` 又比 `08:00` 大。`statistics_metric_scope_test.dart:12-16`
/// 把这条定性为 bug 时只改了 achievements / morning_ratio 两处，这一路径漏改。
///
/// 触发入口是真的：表格导入「开始时间」列填 `8:00`
/// （`spreadsheet_import_service.dart:633` `_normalizeTimeOrDefault` 原样保留、
/// 不补零），作息洞产生的空钟点也由 `timetable_settings.dart:1030` 的补位策略产生。
/// 用户在统计页看到的就是：早八没算进上午、反倒算进「晚间课时」，
/// 「最早上课时间」显示 09:00 而不是 8:00。
void main() {
  Course course(
    String id, {
    required String startTime,
    required String endTime,
    int dayOfWeek = 1,
    int startSection = 1,
    int endSection = 1,
    String location = 'A101',
  }) => Course(
    id: id,
    name: '课$id',
    teacher: '张老师',
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
  );

  test('未补零的 8:00 早课算进上午，不算进晚间', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [course('a', startTime: '8:00', endTime: '8:45')],
      currentWeek: 1,
    );

    // 修复前：'8:00'.compareTo('12:00') > 0（'8' > '1'）→ 上午 0 节；
    // '8:45'.compareTo('18:00') > 0 → 晚间 1 节。
    expect(stats.morningSections, 1);
    expect(stats.eveningSections, 0);
    expect(stats.noonSections, 0);
  });

  test('最早/最晚读数按分钟数而不是字典序', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [
        course('a', startTime: '09:00', endTime: '09:45'),
        course('b', startTime: '8:00', endTime: '8:45'),
      ],
      currentWeek: 1,
    );

    // 修复前：'09:00' < '8:00'（'0' < '8'），最早被报成 09:00。
    expect(stats.earliestStart, '8:00');
    expect(stats.latestEnd, '09:45');
  });

  test('空钟点（作息按位补空的洞）不进任何时段桶', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [
        course('hole', startTime: '', endTime: '', location: 'B202'),
        course('a', startTime: '10:00', endTime: '11:40'),
      ],
      currentWeek: 1,
    );

    // 修复前：'' 比任何串都小 → 被算进上午，并把「最早上课时间」显示成空。
    expect(stats.morningSections, 1);
    expect(stats.earliestStart, '10:00');
    expect(stats.latestEnd, '11:40');
  });

  test('晚自习写到 24:00 时按当天结束计入晚间与最晚下课', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [
        course(
          'evening',
          startTime: '22:00',
          endTime: '24:00',
          startSection: 9,
          endSection: 10,
        ),
      ],
      currentWeek: 1,
    );

    expect(stats.eveningSections, 2);
    expect(stats.latestEnd, '24:00');
    expect(stats.morningSections, 0);
  });

  test('午后跨 12:00 的课仍然只算「中午」一次（阈值用分钟）', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [course('a', startTime: '11:00', endTime: '12:40')],
      currentWeek: 1,
    );

    expect(stats.morningSections, 1);
    expect(stats.noonSections, 1);
    expect(stats.eveningSections, 0);
  });

  test('畸形钟点整条忽略，不撑大任何读数', () {
    final stats = StatisticsService.calculateTimeUtilization(
      allCourses: [
        course('bad', startTime: '25:00', endTime: '26:00'),
        course('a', startTime: '08:00', endTime: '09:40'),
      ],
      currentWeek: 1,
    );

    expect(stats.earliestStart, '08:00');
    expect(stats.latestEnd, '09:40');
    expect(stats.morningSections, 1);
    expect(stats.eveningSections, 0);
  });
}
