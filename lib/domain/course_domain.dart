import '../models/course.dart';

/// 同名课程共享元数据的 key：去除首尾空白并转小写。
String buildSharedCourseNameKey(String name) => name.trim().toLowerCase();

/// 课程冲突检测与共享字段领域服务（纯 Dart，无 Flutter / IO 依赖）。
///
/// 解耦阶段 1 自 `TimetableProvider` 收口；`couple_timetable_logic` 的
/// 同源冲突判定已一并去重到 [overlapInWeek]。
class CourseDomain {
  CourseDomain._();

  /// 两条课表项是否构成冲突（同一门课按 id 排除）。
  static bool conflict(Course left, Course right, {int? week}) {
    if (left.id == right.id) return false;
    return overlapInWeek(left, right, week: week);
  }

  /// 两条课表项在同一周是否时段重叠（不含同 id 排除）。
  ///
  /// [week] 给定时只判定该周（优先 [Course.isActiveInWeek]，停课周不会
  /// 误报冲突）；未给定时在两课候选周的并集中寻找共同激活周。使用
  /// `customWeeks`（经 [weekCandidates]），仓库导入常见「外壳 1–16、
  /// customWeeks 在外」的数据不会误报。
  static bool overlapInWeek(Course left, Course right, {int? week}) {
    if (left.dayOfWeek != right.dayOfWeek) {
      return false;
    }
    if (left.endSection < right.startSection ||
        right.endSection < left.startSection) {
      return false;
    }

    if (week != null) {
      return left.isActiveInWeek(week) && right.isActiveInWeek(week);
    }

    final candidateWeeks = <int>{
      ...weekCandidates(left),
      ...weekCandidates(right),
    };
    for (final candidateWeek in candidateWeeks) {
      if (left.isActiveInWeek(candidateWeek) &&
          right.isActiveInWeek(candidateWeek)) {
        return true;
      }
    }
    return false;
  }

  /// 构建整份课表的冲突索引：课程 id → 与之冲突的其它课表项。
  static Map<String, List<Course>> buildConflictMap(
    List<Course> courses, {
    int? week,
  }) {
    final conflictMap = <String, List<Course>>{};
    for (var i = 0; i < courses.length; i++) {
      for (var j = i + 1; j < courses.length; j++) {
        if (!conflict(courses[i], courses[j], week: week)) {
          continue;
        }
        conflictMap.putIfAbsent(courses[i].id, () => []).add(courses[j]);
        conflictMap.putIfAbsent(courses[j].id, () => []).add(courses[i]);
      }
    }
    return conflictMap;
  }

  /// 课程的候选周集合：customWeeks 优先，否则 startWeek–endWeek 区间。
  static Set<int> weekCandidates(Course course) {
    final custom = course.normalizedCustomWeeks;
    if (custom != null && custom.isNotEmpty) {
      return custom.toSet();
    }
    final weeks = <int>{};
    final start = course.startWeek < 1 ? 1 : course.startWeek;
    final end = course.endWeek < start ? start : course.endWeek;
    for (var week = start; week <= end; week++) {
      weeks.add(week);
    }
    return weeks;
  }

  /// 将 [source] 的课程级共享字段覆盖到 [target] 并返回新对象。
  ///
  /// teacher / location 是按课表条目各自的值：同一门课占多个时段时，
  /// 每条保留自己的教师与教室，不在此传播。
  static Course applySharedFields(Course target, Course source) {
    final sharedDescription = () {
      final description = source.description?.trim();
      if (description != null && description.isNotEmpty) {
        return description;
      }
      final legacyNote = source.note?.trim();
      if (legacyNote != null && legacyNote.isNotEmpty) {
        return legacyNote;
      }
      return null;
    }();
    return target.copyWith(
      name: source.name,
      shortName: source.shortName,
      color: source.color,
      textColor: source.textColor,
      courseNature: source.courseNature,
      description: sharedDescription,
    );
  }

  /// [course] 名称对应的共享 key。
  static String sharedKey(Course course) =>
      buildSharedCourseNameKey(course.name);
}
