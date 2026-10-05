import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 回归钉（第二十二轮，数据故事卡「时间跨度」）：
///
/// `generateDataStories`（statistics_service.dart:349-350）取"最早/最晚"用的是
/// **字典序**：`allCourses.map((c) => c.startTime).toList()..sort()` 再拿
/// `.first`/`.last`。同一个缺陷在**同文件**的另一条路径上早就改掉并写了注释
/// （:591-596 逐条列出三种确定错法），由
/// `statistics_time_utilization_clock_test.dart` 钉住；故事卡这一份副本漏改。
///
/// 触发入口是真的：`Course.fromJson`（models/course.dart:298）原样收下
/// `json['startTime'] as String`，表格导入的「开始时间」列填 `8:00`
/// 也不会补零（spreadsheet_import_service.dart:633）；作息按位补空产生空钟点
/// 课（timetable_settings.dart:1030）。用户在统计页与导出的分享图上看到的是：
/// 早八被写成"最晚"、"最早"是空读数。
void main() {
  Course course(
    String id, {
    required String startTime,
    required String endTime,
    int dayOfWeek = 1,
    int startSection = 1,
    int endSection = 1,
  }) => Course(
    id: id,
    name: '课$id',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
  );

  DataStory timeRange(List<Course> courses) => StatisticsService
      .generateDataStories(allCourses: courses, currentWeek: 1)
      .firstWhere(
        (story) => story.type == StoryType.timeRange,
        orElse: () => throw StateError('缺少时间跨度故事卡'),
      );

  test('未补零的 8:00 是「最早」，不是「最晚」', () {
    final story = timeRange([
      course('a', startTime: '09:00', endTime: '09:45'),
      course('b', startTime: '8:00', endTime: '8:45'),
    ]);

    // 修复前：'09:00' 字典序在 '8:00' 之前 → 最早显示 09:00。
    expect(story.earliestTime, '8:00');
    expect(story.latestTime, '09:45');
  });

  test('末节 10:00 下课不会输给 9:40', () {
    final story = timeRange([
      course('a', startTime: '8:00', endTime: '8:45'),
      course('b', startTime: '9:00', endTime: '9:40'),
      course('c', startTime: '10:00', endTime: '10:00'),
    ]);

    expect(story.earliestTime, '8:00');
    // 修复前：'10:00' 排在 '8:00'/'9:40' 之前 → 最晚显示成 9:40。
    expect(story.latestTime, '10:00');
  });

  test('作息按位补空的空钟点课不会把「最早」显示成空白', () {
    final story = timeRange([
      course('hole', startTime: '', endTime: ''),
      course('a', startTime: '10:00', endTime: '11:40'),
    ]);

    // 修复前：'' 字典序最小 → earliestTime=''，卡片渲染出空读数。
    expect(story.earliestTime, '10:00');
    expect(story.latestTime, '11:40');
  });

  test('畸形钟点不参与「最晚下课」', () {
    final story = timeRange([
      course('bad', startTime: '08:00', endTime: '26:00'),
      course('a', startTime: '09:00', endTime: '09:40'),
    ]);

    // 修复前：'26:00' 字典序最大 → 故事卡宣称最晚下课 26:00。
    expect(story.earliestTime, '08:00');
    expect(story.latestTime, '09:40');
  });

  test('晚自习写到 24:00 按当天结束算最晚', () {
    final story = timeRange([
      course('evening', startTime: '22:00', endTime: '24:00'),
      course('a', startTime: '08:00', endTime: '09:40'),
    ]);

    expect(story.earliestTime, '08:00');
    expect(story.latestTime, '24:00');
  });

  test('全是读不出钟点的课时，不产出一条空的时间跨度故事', () {
    final stories = StatisticsService.generateDataStories(
      allCourses: [course('hole', startTime: '', endTime: '')],
      currentWeek: 1,
    );

    // 修复前：'' 既是"最早"也是"最晚"，照样生成一条两个读数都空的故事卡。
    expect(
      stories.where((story) => story.type == StoryType.timeRange),
      isEmpty,
    );
  });
}
