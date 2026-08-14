import 'package:flutter/material.dart';

import '../models/course.dart';

/// 学期统计总览（账单式）
class SemesterStats {
  final int totalCourses; // 总课程门数（去重）
  final int totalSections; // 总课时数（整个学期，截至当前周）
  final int totalWeeks; // 学期总周数
  final int longestStreak; // 最长连续上课天数
  final List<DailyAverageStats> dailyAverages; // 每日平均课时
  final CourseNatureStats natureStats; // 必修/选修比例
  final List<CourseSemesterStat> courseRanking; // 课程排行

  const SemesterStats({
    required this.totalCourses,
    required this.totalSections,
    required this.totalWeeks,
    required this.longestStreak,
    required this.dailyAverages,
    required this.natureStats,
    required this.courseRanking,
  });
}

/// 每日平均课时统计
class DailyAverageStats {
  final int dayOfWeek; // 1-7
  final double averageSections; // 平均课时数
  final int totalSections; // 总课时数（整个学期）
  final int courseCount; // 课程门数

  const DailyAverageStats({
    required this.dayOfWeek,
    required this.averageSections,
    required this.totalSections,
    required this.courseCount,
  });
}

/// 成就系统（文案由 widget 层 l10n 按 [id] 组装）
///
/// [progressCurrent] / [progressTarget] 为可选进度（如 学霸 86/100），
/// 用于展示解锁进度；已解锁时仍保留进度值。
class Achievement {
  final String id;
  final IconData icon;
  final bool isUnlocked;
  final int? progressCurrent;
  final int? progressTarget;

  const Achievement({
    required this.id,
    required this.icon,
    required this.isUnlocked,
    this.progressCurrent,
    this.progressTarget,
  });

  /// 是否携带进度信息
  bool get hasProgress =>
      progressCurrent != null && progressTarget != null && progressTarget! > 0;
}

/// 数据故事（结构化数据，文案由 widget 层 l10n 组装）
class DataStory {
  final StoryType type;
  final IconData icon;
  final int? dayOfWeek; // 1-7, busiestDay / lightestDay
  final int? weekNumber;
  final double? averageSections; // busiestDay / lightestDay
  final String? room; // favoriteRoom
  final int? visitCount; // favoriteRoom
  final int? buildingCount; // buildingCount
  final String? earliestTime; // timeRange
  final String? latestTime; // timeRange

  const DataStory({
    required this.type,
    required this.icon,
    this.dayOfWeek,
    this.weekNumber,
    this.averageSections,
    this.room,
    this.visitCount,
    this.buildingCount,
    this.earliestTime,
    this.latestTime,
  });
}

enum StoryType {
  busiestDay, // 最忙的一天
  lightestDay, // 最轻松的一天
  favoriteRoom, // 最常去的教室
  buildingCount, // 教学楼数量
  timeRange, // 时间跨度
}

/// 课程学期统计（用于排行榜）
class CourseSemesterStat {
  final String name;
  final String teacher;
  final CourseNature nature;
  final int totalSections; // 整学期总课时
  final List<CourseSlot> slots; // 上课时间列表

  const CourseSemesterStat({
    required this.name,
    required this.teacher,
    required this.nature,
    required this.totalSections,
    required this.slots,
  });
}

/// 周统计概览
class WeeklyStats {
  final int weekNumber;
  final int totalCourses; // 课程门数（去重）
  final int totalSections; // 总课时数
  final List<DailyStats> dailyStats; // 每日统计
  final CourseNatureStats natureStats; // 必修/选修统计
  final List<CourseStat> courseStats; // 各课程统计

  const WeeklyStats({
    required this.weekNumber,
    required this.totalCourses,
    required this.totalSections,
    required this.dailyStats,
    required this.natureStats,
    required this.courseStats,
  });

  /// 最忙的一天（1-7），无课返回 null
  int? get busiestDay {
    DailyStats? max;
    for (final day in dailyStats) {
      if (day.sectionCount == 0) continue;
      if (max == null || day.sectionCount > max.sectionCount) {
        max = day;
      }
    }
    return max?.dayOfWeek;
  }
}

/// 每日统计
class DailyStats {
  final int dayOfWeek; // 1-7 (周一至周日)
  final int sectionCount; // 当天课时数
  final int courseCount; // 当天课程门数

  const DailyStats({
    required this.dayOfWeek,
    required this.sectionCount,
    required this.courseCount,
  });
}

/// 必修/选修统计
class CourseNatureStats {
  final int requiredCount; // 必修课门数
  final int electiveCount; // 选修课门数
  final int requiredSections; // 必修课时数
  final int electiveSections; // 选修课时数

  const CourseNatureStats({
    required this.requiredCount,
    required this.electiveCount,
    required this.requiredSections,
    required this.electiveSections,
  });

  int get totalCount => requiredCount + electiveCount;
  int get totalSections => requiredSections + electiveSections;

  double get requiredRatio => totalCount > 0 ? requiredCount / totalCount : 0;
  double get electiveRatio => totalCount > 0 ? electiveCount / totalCount : 0;
}

/// 单门课程的统计信息
class CourseStat {
  final String name;
  final String teacher;
  final CourseNature nature;
  final int weeklySections; // 周课时数
  final List<CourseSlot> slots; // 上课时间列表

  const CourseStat({
    required this.name,
    required this.teacher,
    required this.nature,
    required this.weeklySections,
    required this.slots,
  });
}

/// 课程的单个时间槽
class CourseSlot {
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final String location;

  const CourseSlot({
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.location,
  });
}

/// 每周课时趋势点（计划口径，覆盖整个学期）
class WeeklyTrendPoint {
  final int weekNumber;
  final int sections; // 该周计划课时（含单双周/停课扣除）
  final int courseCount; // 该周有效课程门数（去重）
  final int requiredSections;
  final int electiveSections;
  final int activeDayCount; // 该周有课的天数

  const WeeklyTrendPoint({
    required this.weekNumber,
    required this.sections,
    required this.courseCount,
    required this.requiredSections,
    required this.electiveSections,
    required this.activeDayCount,
  });
}

/// 学期进度（校历对齐）
class SemesterProgress {
  final DateTime? semesterStartDate; // 开学日期（可为空）
  final DateTime? currentDate; // 截至当前周的日期（周日起算）
  final DateTime? semesterEndDate; // 学期结束日期
  final int weeksElapsed; // 已过周数（当前周）
  final int totalWeeks; // 学期总周数
  final int sectionsDone; // 已上课时（截至当前周）
  final int sectionsTotal; // 学期计划总课时
  final int remainingSections; // 剩余课时

  const SemesterProgress({
    required this.semesterStartDate,
    required this.currentDate,
    required this.semesterEndDate,
    required this.weeksElapsed,
    required this.totalWeeks,
    required this.sectionsDone,
    required this.sectionsTotal,
    required this.remainingSections,
  });

  double get percent => sectionsTotal > 0 ? sectionsDone / sectionsTotal : 0;
}

/// 本周小结（周对比）
class WeeklyComparison {
  final int weekSections; // 本周课时
  final int lastWeekSections; // 上周课时
  final double semesterAverageSections; // 学期每周平均课时
  final int deltaVsLastWeek; // 较上周差值（正=变多）
  final double deltaVsAverage; // 较平均差值

  const WeeklyComparison({
    required this.weekSections,
    required this.lastWeekSections,
    required this.semesterAverageSections,
    required this.deltaVsLastWeek,
    required this.deltaVsAverage,
  });
}

/// 学期热力图（周 × 天课时密度）
class SemesterHeatmap {
  final int weekCount;
  final int maxSections; // 单格最大值（用于配色标度）

  /// [rows] 7 行（周一~周日），每行 [weekCount] 列，值为该周该天课时数
  final List<List<int>> rows;

  const SemesterHeatmap({
    required this.weekCount,
    required this.maxSections,
    required this.rows,
  });

  /// 未来周（超过 [currentWeek]）置 0 后返回新实例
  SemesterHeatmap clippedToWeek(int currentWeek) {
    final clipped = List.generate(7, (day) {
      return List<int>.generate(weekCount, (week) {
        return week + 1 <= currentWeek ? rows[day][week] : 0;
      });
    });
    var max = 0;
    for (final row in clipped) {
      for (final v in row) {
        if (v > max) max = v;
      }
    }
    return SemesterHeatmap(weekCount: weekCount, maxSections: max, rows: clipped);
  }
}

/// 时间利用统计
class TimeUtilizationStats {
  final String earliestStart; // 最早上课时间 HH:mm
  final String latestEnd; // 最晚下课时间 HH:mm
  final int morningSections; // 早间课时（12:00 前开始）
  final int noonSections; // 午间课时（与 12:00-14:00 相交）
  final int eveningSections; // 晚间课时（18:00 后结束）
  final int weekendSections; // 周末课时
  final int maxDailyGapSections; // 单日最长课间空档（节）
  final int activeCourseCount; // 参与统计的排课条目数

  const TimeUtilizationStats({
    required this.earliestStart,
    required this.latestEnd,
    required this.morningSections,
    required this.noonSections,
    required this.eveningSections,
    required this.weekendSections,
    required this.maxDailyGapSections,
    required this.activeCourseCount,
  });

  bool get isEmpty => activeCourseCount == 0;
}

/// 教室到访统计
class RoomVisitStat {
  final String name;
  final int visits; // 到访次数（条目数 × 有效周数加权）

  const RoomVisitStat({required this.name, required this.visits});
}

/// 教学楼统计
class BuildingStat {
  final String name;
  final int sections; // 总课时

  const BuildingStat({required this.name, required this.sections});
}

/// 教室与教学楼统计
class VenueStats {
  final List<RoomVisitStat> topRooms;
  final List<BuildingStat> buildings;

  const VenueStats({required this.topRooms, required this.buildings});

  bool get isEmpty => topRooms.isEmpty && buildings.isEmpty;
}

/// 教师课时统计
class TeacherStat {
  final String name;
  final int sections; // 学期总课时
  final int courseCount; // 任教课程门数（去重）

  const TeacherStat({
    required this.name,
    required this.sections,
    required this.courseCount,
  });
}
