import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 回归钉（第 27 轮，同一张统计页两张卡对「晚间课时」口径不一致）。
///
/// `_endMinutes`（statistics_service.dart:818-819）解析 `endTime` 时没传
/// `allowEndOfDay: true`，于是 `24:00` 解析成 null；消费点 :143-148 判的是
/// `minutes != null && minutes > 18*60`，整门课被剔出成就卡「夜猫子」的
/// `eveningSections`（:215-220 `isUnlocked` / `progressCurrent`）。
///
/// 同一个文件里另外两条等价路径都显式放行并写了理由：
/// - `calculateTimeUtilization`（:626-630）「末节课 / 晚自习写 `24:00` 是本仓认可的
///   『当天结束』（time_scheme.dart 的 `_clockMinutes` 专门放行），这里同样允许它
///   参与比较，**否则晚间课时与最晚下课会少算**」；
/// - 数据故事卡的时间跨度（:365-368）同一句话。
/// 只有成就这条副本没跟上 —— 快速生成作息会把末节写成 `24:00`
/// （`test/models/time_scheme_quick_generate_midnight_test.dart:41-50` 钉着），
/// 于是统计页「时间利用」卡把这门晚自习算进晚间，同一页的「夜猫子」成就没算，
/// 两张卡的数字互相打脸，成就进度虚低甚至永不解锁。
void main() {
  Course lesson(
    String id, {
    required String endTime,
    int startSection = 1,
    int endSection = 2,
  }) => Course(
    id: id,
    name: '课程$id',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: startSection,
    endSection: endSection,
    startTime: '19:00',
    endTime: endTime,
  );

  Achievement nightOwl(List<Course> courses) => StatisticsService
    .calculateAchievements(allCourses: courses, currentWeek: 1)
    .firstWhere((achievement) => achievement.id == 'night_owl');

  test('24:00 结束的晚自习计入「夜猫子」成就进度', () {
    final courses = [lesson('owl', endTime: '24:00')];

    final achievement = nightOwl(courses);
    expect(
      achievement.isUnlocked,
      isTrue,
      reason: '修复前 24:00 解析为 null → 整门课被剔出 eveningSections',
    );
    expect(achievement.progressCurrent, 2);
  });

  test('成就卡与时间利用卡的晚间课时必须同数', () {
    final courses = [
      lesson('owl', endTime: '24:00'),
      lesson('normal', endTime: '21:30'),
      lesson('morning', endTime: '08:45', startSection: 1, endSection: 1),
    ];

    final utilization = StatisticsService.calculateTimeUtilization(
      allCourses: courses,
      currentWeek: 1,
    );
    expect(
      nightOwl(courses).progressCurrent,
      utilization.eveningSections,
      reason: '同一页两张卡按同一规则归类，否则数字互相打脸',
    );
  });

  test('常规晚间钟点（21:30）两侧都算得到', () {
    final courses = [lesson('normal', endTime: '21:30')];
    expect(nightOwl(courses).progressCurrent, 2);
    expect(
      StatisticsService.calculateTimeUtilization(
        allCourses: courses,
        currentWeek: 1,
      ).eveningSections,
      2,
    );
  });

  test('畸形钟点仍然不算（allowEndOfDay 只放行 24:00）', () {
    final courses = [lesson('bad', endTime: '26:00')];
    expect(nightOwl(courses).progressCurrent, 0);
    expect(nightOwl(courses).isUnlocked, isFalse);
  });
}
