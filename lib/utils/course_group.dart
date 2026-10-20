import '../l10n/app_localizations.dart';
import '../models/course.dart';

/// 同一时段的冲突课程对（[course] 与 [otherCourse] 在同一周次、同一天、节次重叠）。
class CourseConflict {
  final Course course;
  final Course otherCourse;

  const CourseConflict({required this.course, required this.otherCourse});
}

/// 同名课程聚合（同一门课的多个上课时段）。
///
/// 纯 UI 层聚合：底层存储仍是独立的 [Course]。2026-10-20 从
/// `TimetableProvider` 主文件搬出（provider 只保留一个委托 getter + 一条
/// `export`，调用方 import 不变）——它是模型，不是状态管理职责。
class CourseGroup {
  final String name;
  final List<Course> courses;

  const CourseGroup({required this.name, required this.courses});

  /// 按名字分组（保持课程在列表中的出现顺序）。
  static List<CourseGroup> buildFrom(List<Course> courses) {
    final Map<String, List<Course>> grouped = {};
    for (final course in courses) {
      grouped.putIfAbsent(course.name, () => []).add(course);
    }
    return grouped.entries
        .map((entry) => CourseGroup(name: entry.key, courses: entry.value))
        .toList();
  }

  /// Shared fields taken from the first course in the group.
  String get teacher => courses.first.teacher;
  String get color => courses.first.color;
  String? get shortName => courses.first.shortName;
  CourseNature get courseNature => courses.first.courseNature;
  String? get description => courses.first.description;
  String? get note => courses.first.note;

  /// Summarised schedule chips, e.g. ["周一1-2节", "周三3-4节"].
  List<String> scheduleChipLabels(AppLocalizations l10n) {
    return courses.map((c) {
      final dayLabel = _weekdayShortLabel(l10n, c.dayOfWeek);
      return l10n.weekdaySectionSummary(dayLabel, c.startSection, c.endSection);
    }).toList();
  }

  /// Earliest day/slot for sorting.
  int get earliestDayOfWeek =>
      courses.map((c) => c.dayOfWeek).reduce((a, b) => a < b ? a : b);
  int get earliestStartSection =>
      courses.map((c) => c.startSection).reduce((a, b) => a < b ? a : b);
}

String _weekdayShortLabel(AppLocalizations l10n, int dayOfWeek) {
  return switch (dayOfWeek) {
    1 => l10n.weekdayShortMonday,
    2 => l10n.weekdayShortTuesday,
    3 => l10n.weekdayShortWednesday,
    4 => l10n.weekdayShortThursday,
    5 => l10n.weekdayShortFriday,
    6 => l10n.weekdayShortSaturday,
    7 => l10n.weekdayShortSunday,
    _ => dayOfWeek.toString(),
  };
}
