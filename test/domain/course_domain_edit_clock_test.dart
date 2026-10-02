import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/course_domain.dart';
import 'package:university_timetable/models/course.dart';

/// 编辑课程时不能把适配脚本钉住的权威钟点丢掉（2026-10-02 审查）。
///
/// `TimeSchemeLogic` 写明"权威时间来自适配脚本，模板不得覆盖"
/// （`lib/domain/time_scheme_logic.dart:436`），但编辑页的条目模型
/// （`add_course_screen.dart` 的 `_ScheduleEntryData`）只有节次，
/// 钟点一律由模板算出（:1924-1927），`toCourse` 也不带 hasCustomTime ——
/// 于是"改个教师/教室"再保存，早读 07:00-07:40 就静默变回模板的 08:00-08:45，
/// 闹钟、超级岛、进度里程碑全跟着变，而课表卡上此前显示的仍是 07:00。
void main() {
  Course course({
    int startSection = 1,
    int endSection = 1,
    String startTime = '08:00',
    String endTime = '08:45',
    bool hasCustomTime = false,
  }) {
    return Course(
      id: 'c1',
      name: '早读',
      teacher: '周老师',
      location: 'A101',
      dayOfWeek: 2,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      hasCustomTime: hasCustomTime,
    );
  }

  test('节次没动时保留钉住的钟点与标志', () {
    final clock = CourseDomain.editCourseClock(
      original: course(
        startTime: '07:00',
        endTime: '07:40',
        hasCustomTime: true,
      ),
      startSection: 1,
      endSection: 1,
      templateStartTime: '08:00',
      templateEndTime: '08:45',
    );

    expect(clock.hasCustomTime, isTrue);
    expect(clock.startTime, '07:00');
    expect(clock.endTime, '07:40');
  });

  test('节次挪走时交回模板', () {
    final clock = CourseDomain.editCourseClock(
      original: course(
        startTime: '07:00',
        endTime: '07:40',
        hasCustomTime: true,
      ),
      startSection: 5,
      endSection: 5,
      templateStartTime: '14:00',
      templateEndTime: '14:45',
    );

    expect(clock.hasCustomTime, isFalse);
    expect(clock.startTime, '14:00');
    expect(clock.endTime, '14:45');
  });

  test('普通课程仍按模板走', () {
    final clock = CourseDomain.editCourseClock(
      original: course(),
      startSection: 1,
      endSection: 2,
      templateStartTime: '08:00',
      templateEndTime: '09:40',
    );

    expect(clock.hasCustomTime, isFalse);
    expect(clock.startTime, '08:00');
    expect(clock.endTime, '09:40');
  });

  test('新建课程没有原值时按模板', () {
    final clock = CourseDomain.editCourseClock(
      startSection: 3,
      endSection: 4,
      templateStartTime: '10:00',
      templateEndTime: '11:40',
    );

    expect(clock.hasCustomTime, isFalse);
    expect(clock.startTime, '10:00');
    expect(clock.endTime, '11:40');
  });

  test('只改了结束节次也算挪动', () {
    final clock = CourseDomain.editCourseClock(
      original: course(
        startTime: '07:00',
        endTime: '07:40',
        hasCustomTime: true,
      ),
      startSection: 1,
      endSection: 2,
      templateStartTime: '08:00',
      templateEndTime: '09:40',
    );

    expect(clock.hasCustomTime, isFalse);
    expect(clock.endTime, '09:40');
  });
}
