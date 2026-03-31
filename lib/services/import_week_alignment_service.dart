import '../models/course.dart';

class ImportWeekAlignmentService {
  const ImportWeekAlignmentService();

  int inferFirstCourseWeek({
    required DateTime semesterStartDate,
    required DateTime firstCourseDate,
  }) {
    final days = _startOfWeek(firstCourseDate)
        .difference(_startOfWeek(semesterStartDate))
        .inDays;
    if (days <= 0) {
      return 1;
    }
    return (days ~/ 7) + 1;
  }

  List<Course> shiftCoursesToSemesterWeeks(
    List<Course> courses, {
    required int firstCourseWeek,
  }) {
    final weekOffset = firstCourseWeek - 1;
    if (weekOffset == 0) {
      return List<Course>.from(courses);
    }
    return courses.map((course) => _shiftCourse(course, weekOffset)).toList();
  }

  DateTime startOfWeek(DateTime date) => _startOfWeek(date);

  Course _shiftCourse(Course course, int weekOffset) {
    final customWeeks = course.normalizedCustomWeeks;
    if (customWeeks != null) {
      final shiftedWeeks = customWeeks.map((week) => week + weekOffset).toList()
        ..sort();
      return course.copyWith(
        startWeek: shiftedWeeks.first,
        endWeek: shiftedWeeks.last,
        customWeeks: shiftedWeeks,
        isOddWeek: false,
        isEvenWeek: false,
      );
    }

    final flipParity = weekOffset.isOdd;
    return course.copyWith(
      startWeek: course.startWeek + weekOffset,
      endWeek: course.endWeek + weekOffset,
      isOddWeek: flipParity ? course.isEvenWeek : course.isOddWeek,
      isEvenWeek: flipParity ? course.isOddWeek : course.isEvenWeek,
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }
}
