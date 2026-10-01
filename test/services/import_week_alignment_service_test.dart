import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/import_week_alignment_service.dart';

void main() {
  const service = ImportWeekAlignmentService();

  test('infer first course week uses selected date week as anchor', () {
    final week = service.inferFirstCourseWeek(
      semesterStartDate: DateTime(2026, 2, 25),
      firstCourseDate: DateTime(2026, 3, 2),
    );

    expect(week, 2);
  });

  test('锚定按日历日，不受夏令时那少掉的一小时影响', () {
    // 回归钉（CODE_REVIEW 2026-10-02）：旧实现用本地 DateTime 相减取 inDays，
    // 跨夏令时起始周的两个周一之间只有 167h → inDays == 6 → (6 ~/ 7) + 1 == 1，
    // 整门课被提前一周对齐，单双周标志也随之错位。现在按 DateTime.utc 重算日历日
    // （与 WeekCalculator.getWeekIndex 同一口径）。
    // 2026-03-08 是美国夏令时切换日：锚定周一 03-02 → 03-09 正好差 7 个日历日。
    final week = service.inferFirstCourseWeek(
      semesterStartDate: DateTime(2026, 3, 4, 23, 30),
      firstCourseDate: DateTime(2026, 3, 9, 1),
    );

    expect(week, 2);
  });

  test('开学前的第一节课仍然锚到第 1 周', () {
    expect(
      service.inferFirstCourseWeek(
        semesterStartDate: DateTime(2026, 9, 7),
        firstCourseDate: DateTime(2026, 9, 1),
      ),
      1,
    );
  });

  test('shift courses offsets custom weeks directly', () {
    final courses = service.shiftCoursesToSemesterWeeks([
      Course(
        id: 'course-custom',
        name: '程序设计',
        teacher: '黄老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        endWeek: 3,
        customWeeks: const [1, 3, 5],
      ),
    ], firstCourseWeek: 3);

    expect(courses.single.customWeeks, const [3, 5, 7]);
    expect(courses.single.startWeek, 3);
    expect(courses.single.endWeek, 7);
  });

  test('shift courses flips odd even flags when offset is odd', () {
    final courses = service.shiftCoursesToSemesterWeeks([
      Course(
        id: 'course-odd',
        name: '高数',
        teacher: '张老师',
        location: 'A201',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
        isOddWeek: true,
      ),
    ], firstCourseWeek: 2);

    expect(courses.single.startWeek, 2);
    expect(courses.single.endWeek, 17);
    expect(courses.single.isOddWeek, isFalse);
    expect(courses.single.isEvenWeek, isTrue);
  });
}
