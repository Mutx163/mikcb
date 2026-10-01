import '../domain/week_calculator.dart';
import '../models/course.dart';

class ImportWeekAlignmentService {
  const ImportWeekAlignmentService();

  int inferFirstCourseWeek({
    required DateTime semesterStartDate,
    required DateTime firstCourseDate,
  }) {
    final from = WeekCalculator.startOfWeek(semesterStartDate);
    final to = WeekCalculator.startOfWeek(firstCourseDate);
    // 按「日历日」而不是「绝对经过时间」算跨度：本地 DateTime 直接相减在夏令时
    // 那一周会拿到 167h（inDays == 6），于是 7 天被算成 6 天、整门课被提前一周
    // 对齐，单双周标志也随之错位。WeekCalculator.getWeekIndex 内部正是用
    // DateTime.utc 重算来绕开这个坑，这里保持同一口径。
    final days = DateTime.utc(to.year, to.month, to.day).difference(
      DateTime.utc(from.year, from.month, from.day),
    ).inDays;
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

  DateTime startOfWeek(DateTime date) => WeekCalculator.startOfWeek(date);

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
}
