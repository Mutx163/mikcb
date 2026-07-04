import 'package:flutter/material.dart';

import '../models/course.dart';

/// 学期统计总览（账单式）
class SemesterStats {
  final int totalCourses; // 总课程门数（去重）
  final int totalSections; // 总课时数（整个学期）
  final int totalWeeks; // 上课周数
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
class Achievement {
  final String id;
  final IconData icon;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.icon,
    required this.isUnlocked,
  });
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
