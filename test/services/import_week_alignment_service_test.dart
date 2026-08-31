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
