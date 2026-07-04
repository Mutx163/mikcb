import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/statistics_models.dart';

/// 课程统计计算服务
class StatisticsService {
  StatisticsService._();

  /// 计算指定周的完整统计数据
  static WeeklyStats calculate({
    required List<Course> allCourses,
    required int week,
  }) {
    // 过滤当前周有效课程
    final activeCourses = allCourses
        .where((c) => c.isActiveInWeek(week))
        .toList();

    // 按课程名称分组
    final grouped = _groupByCourseName(activeCourses);

    // 计算每日分布
    final dailyStats = _calculateDailyStats(activeCourses);

    // 计算必修/选修比例
    final natureStats = _calculateNatureStats(activeCourses);

    // 计算各课程统计
    final courseStats = _calculateCourseStats(grouped, week);

    // 总课时
    final totalSections = activeCourses.fold<int>(
      0,
      (sum, c) => sum + c.sectionCount,
    );

    return WeeklyStats(
      weekNumber: week,
      totalCourses: grouped.length,
      totalSections: totalSections,
      dailyStats: dailyStats,
      natureStats: natureStats,
      courseStats: courseStats,
    );
  }

  /// 计算整个学期的统计数据（账单式）
  static SemesterStats calculateSemester({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    if (allCourses.isEmpty || currentWeek < 1) {
      return const SemesterStats(
        totalCourses: 0,
        totalSections: 0,
        totalWeeks: 0,
        longestStreak: 0,
        dailyAverages: [],
        natureStats: CourseNatureStats(
          requiredCount: 0,
          electiveCount: 0,
          requiredSections: 0,
          electiveSections: 0,
        ),
        courseRanking: [],
      );
    }

    // 按课程名称分组（去重）
    final grouped = _groupByCourseName(allCourses);

    // 计算整个学期的总课时
    int totalSections = 0;
    for (final course in allCourses) {
      final activeWeeks = _countActiveWeeks(course, currentWeek);
      totalSections += course.sectionCount * activeWeeks;
    }

    // 计算每日平均课时
    final dailyAverages = _calculateDailyAverages(allCourses, currentWeek);

    // 计算最长连续上课天数
    final longestStreak = _calculateLongestStreak(allCourses, currentWeek);

    // 计算必修/选修比例（整个学期）
    final natureStats = _calculateSemesterNatureStats(allCourses, currentWeek);

    // 计算课程排行（按整个学期课时排序）
    final courseRanking = _calculateCourseRanking(allCourses, currentWeek);

    return SemesterStats(
      totalCourses: grouped.length,
      totalSections: totalSections,
      totalWeeks: currentWeek,
      longestStreak: longestStreak,
      dailyAverages: dailyAverages,
      natureStats: natureStats,
      courseRanking: courseRanking,
    );
  }

  /// 计算成就系统
  static List<Achievement> calculateAchievements({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    if (allCourses.isEmpty) {
      return const [];
    }

    // 计算整个学期的总课时
    int totalSections = 0;
    for (final course in allCourses) {
      final activeWeeks = _countActiveWeeks(course, currentWeek);
      totalSections += course.sectionCount * activeWeeks;
    }

    // 计算每日最大课时
    final dailyMaxSections = _calculateDailyMaxSections(allCourses);

    // 收集所有教室
    final allRooms = allCourses.map((c) => c.location).toSet();

    // 收集所有时间
    final allStartTimes = allCourses.map((c) => c.startTime).toList();
    final allEndTimes = allCourses.map((c) => c.endTime).toList();

    return [
      Achievement(
        id: 'early_bird',
        icon: Icons.wb_sunny_rounded,
        isUnlocked: allStartTimes.any((t) => t.compareTo('08:00') <= 0),
      ),
      Achievement(
        id: 'perfect_attendance',
        icon: Icons.star_rounded,
        isUnlocked: allCourses.any(
          (c) => _hasPerfectAttendance(c, currentWeek),
        ),
      ),
      Achievement(
        id: 'weekend_warrior',
        icon: Icons.emoji_events_rounded,
        isUnlocked: allCourses.any((c) => c.dayOfWeek >= 6),
      ),
      Achievement(
        id: 'class_king',
        icon: Icons.workspace_premium_rounded,
        isUnlocked: dailyMaxSections >= 6,
      ),
      Achievement(
        id: 'scholar',
        icon: Icons.auto_stories_rounded,
        isUnlocked: totalSections >= 100,
      ),
      Achievement(
        id: 'balanced',
        icon: Icons.balance_rounded,
        isUnlocked: _isBalanced(allCourses),
      ),
      Achievement(
        id: 'night_owl',
        icon: Icons.nights_stay_rounded,
        isUnlocked: allEndTimes.any((t) => t.compareTo('18:00') > 0),
      ),
      Achievement(
        id: 'explorer',
        icon: Icons.explore_rounded,
        isUnlocked: allRooms.length >= 5,
      ),
    ];
  }

  /// 生成数据故事
  static List<DataStory> generateDataStories({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    if (allCourses.isEmpty) {
      return const [];
    }

    final stories = <DataStory>[];

    // 计算每日总课时
    final dailySections = _calculateDailyTotalSections(allCourses, currentWeek);
    final activeDays = dailySections.where((s) => s > 0).toList();

    if (activeDays.isNotEmpty) {
      // 最忙的一天
      final maxSections = activeDays.reduce((a, b) => a > b ? a : b);
      final busiestDayIndex = dailySections.indexOf(maxSections);
      final busiestAvg = maxSections.toDouble() / currentWeek;

      stories.add(
        DataStory(
          type: StoryType.busiestDay,
          icon: Icons.calendar_today_rounded,
          dayOfWeek: busiestDayIndex + 1,
          weekNumber: currentWeek,
          averageSections: busiestAvg,
        ),
      );

      // 最轻松的一天（排除无课天）
      final minSections = activeDays.reduce((a, b) => a < b ? a : b);
      final lightestDayIndex = dailySections.indexOf(minSections);
      if (lightestDayIndex != busiestDayIndex) {
        final lightestAvg = minSections.toDouble() / currentWeek;

        stories.add(
          DataStory(
            type: StoryType.lightestDay,
            icon: Icons.sentiment_satisfied_rounded,
            dayOfWeek: lightestDayIndex + 1,
            weekNumber: currentWeek,
            averageSections: lightestAvg,
          ),
        );
      }
    }

    // 最常去的教室（口径：排课条目数 × 各条目 activeWeeks 之和）
    final roomCounts = <String, int>{};
    for (final course in allCourses) {
      if (course.location.isNotEmpty) {
        roomCounts[course.location] =
            (roomCounts[course.location] ?? 0) +
            _countActiveWeeks(course, currentWeek);
      }
    }
    if (roomCounts.isNotEmpty) {
      final sortedRooms = roomCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final favorite = sortedRooms.first;
      stories.add(
        DataStory(
          type: StoryType.favoriteRoom,
          icon: Icons.location_on_rounded,
          room: favorite.key,
          visitCount: favorite.value,
          weekNumber: currentWeek,
        ),
      );

      // 教学楼数量
      final buildings = roomCounts.keys
          .map((r) => RegExp(r'^[A-Za-z]+').stringMatch(r) ?? r)
          .toSet();
      if (buildings.length > 1) {
        stories.add(
          DataStory(
            type: StoryType.buildingCount,
            icon: Icons.domain_rounded,
            buildingCount: buildings.length,
            weekNumber: currentWeek,
          ),
        );
      }
    }

    // 时间跨度
    final allStartTimes = allCourses.map((c) => c.startTime).toList()..sort();
    final allEndTimes = allCourses.map((c) => c.endTime).toList()..sort();
    if (allStartTimes.isNotEmpty && allEndTimes.isNotEmpty) {
      stories.add(
        DataStory(
          type: StoryType.timeRange,
          icon: Icons.access_time_rounded,
          earliestTime: allStartTimes.first,
          latestTime: allEndTimes.last,
        ),
      );
    }

    return stories;
  }

  /// 按课程名称分组
  static Map<String, List<Course>> _groupByCourseName(List<Course> courses) {
    final map = <String, List<Course>>{};
    for (final course in courses) {
      map.putIfAbsent(course.name, () => []).add(course);
    }
    return map;
  }

  /// 计算每日课时分布（周一至周日）
  static List<DailyStats> _calculateDailyStats(List<Course> courses) {
    final sectionMap = <int, int>{};
    final courseMap = <int, Set<String>>{};

    for (final course in courses) {
      final day = course.dayOfWeek;
      sectionMap[day] = (sectionMap[day] ?? 0) + course.sectionCount;
      courseMap.putIfAbsent(day, () => {}).add(course.name);
    }

    return List.generate(7, (index) {
      final day = index + 1;
      return DailyStats(
        dayOfWeek: day,
        sectionCount: sectionMap[day] ?? 0,
        courseCount: courseMap[day]?.length ?? 0,
      );
    });
  }

  /// 计算必修/选修比例
  static CourseNatureStats _calculateNatureStats(List<Course> courses) {
    int requiredCount = 0;
    int electiveCount = 0;
    int requiredSections = 0;
    int electiveSections = 0;

    // 按名称去重统计门数
    final seenRequired = <String>{};
    final seenElective = <String>{};

    for (final course in courses) {
      final isRequired = course.courseNature == CourseNature.required;
      if (isRequired) {
        requiredSections += course.sectionCount;
        if (seenRequired.add(course.name)) {
          requiredCount++;
        }
      } else {
        electiveSections += course.sectionCount;
        if (seenElective.add(course.name)) {
          electiveCount++;
        }
      }
    }

    return CourseNatureStats(
      requiredCount: requiredCount,
      electiveCount: electiveCount,
      requiredSections: requiredSections,
      electiveSections: electiveSections,
    );
  }

  /// 计算各课程统计
  static List<CourseStat> _calculateCourseStats(
    Map<String, List<Course>> grouped,
    int week,
  ) {
    final stats = grouped.entries.map((entry) {
      final name = entry.key;
      final courses = entry.value;
      final first = courses.first;

      final slots =
          courses.map((c) {
            return CourseSlot(
              dayOfWeek: c.dayOfWeek,
              startSection: c.startSection,
              endSection: c.endSection,
              location: c.location,
            );
          }).toList()..sort((a, b) {
            final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCmp != 0) return dayCmp;
            return a.startSection.compareTo(b.startSection);
          });

      final weeklySections = courses.fold<int>(
        0,
        (sum, c) => sum + c.sectionCount,
      );

      return CourseStat(
        name: name,
        teacher: first.teacher,
        nature: first.courseNature,
        weeklySections: weeklySections,
        slots: slots,
      );
    }).toList()..sort((a, b) => b.weeklySections.compareTo(a.weeklySections));

    return stats;
  }

  /// 计算课程在指定周次前的有效周数
  static int _countActiveWeeks(Course course, int currentWeek) {
    int count = 0;
    for (int week = 1; week <= currentWeek; week++) {
      if (course.isActiveInWeek(week)) {
        count++;
      }
    }
    return count;
  }

  /// 计算每日平均课时（整个学期）
  static List<DailyAverageStats> _calculateDailyAverages(
    List<Course> allCourses,
    int currentWeek,
  ) {
    // 按星期几分组
    final dayMap = <int, List<Course>>{};
    for (final course in allCourses) {
      dayMap.putIfAbsent(course.dayOfWeek, () => []).add(course);
    }

    return List.generate(7, (index) {
      final day = index + 1;
      final dayCourses = dayMap[day] ?? [];

      // 计算该天在整个学期的总课时
      int totalSections = 0;
      int courseCount = 0;
      final seenNames = <String>{};

      for (final course in dayCourses) {
        final activeWeeks = _countActiveWeeks(course, currentWeek);
        totalSections += course.sectionCount * activeWeeks;
        if (seenNames.add(course.name)) {
          courseCount++;
        }
      }

      final averageSections = currentWeek > 0
          ? totalSections / currentWeek
          : 0.0;

      return DailyAverageStats(
        dayOfWeek: day,
        averageSections: averageSections,
        totalSections: totalSections,
        courseCount: courseCount,
      );
    });
  }

  /// 计算每日总课时（整个学期）
  static List<int> _calculateDailyTotalSections(
    List<Course> allCourses,
    int currentWeek,
  ) {
    final result = List<int>.filled(7, 0);
    for (final course in allCourses) {
      final dayIndex = course.dayOfWeek - 1;
      final activeWeeks = _countActiveWeeks(course, currentWeek);
      result[dayIndex] += course.sectionCount * activeWeeks;
    }
    return result;
  }

  /// 计算每日最大课时（用于成就判定）
  static int _calculateDailyMaxSections(List<Course> allCourses) {
    final dailySections = <int, int>{};
    for (final course in allCourses) {
      final day = course.dayOfWeek;
      dailySections[day] = (dailySections[day] ?? 0) + course.sectionCount;
    }
    if (dailySections.isEmpty) return 0;
    return dailySections.values.reduce((a, b) => a > b ? a : b);
  }

  /// 判断是否均衡（每天课时差距 ≤ 2）
  static bool _isBalanced(List<Course> allCourses) {
    final dailySections = <int, int>{};
    for (final course in allCourses) {
      final day = course.dayOfWeek;
      dailySections[day] = (dailySections[day] ?? 0) + course.sectionCount;
    }
    if (dailySections.isEmpty) return true;
    final values = dailySections.values.toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    return (max - min) <= 2;
  }

  /// 计算最长连续上课天数
  static int _calculateLongestStreak(List<Course> allCourses, int currentWeek) {
    if (allCourses.isEmpty) return 0;

    // 计算每天在整个学期是否有课
    final hasClassDay = List<bool>.filled(7, false);
    for (final course in allCourses) {
      if (_countActiveWeeks(course, currentWeek) > 0) {
        hasClassDay[course.dayOfWeek - 1] = true;
      }
    }

    // 展开两轮（14 天）单趟扫描，跨周边界自然处理，上限 7 天
    final expanded = [...hasClassDay, ...hasClassDay];
    int maxStreak = 0;
    int currentStreak = 0;
    for (final has in expanded) {
      if (has) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }
    return maxStreak.clamp(0, 7);
  }

  /// 课程完整开课周期内的计划周数（含单双周/自定义周次，不含停课）
  static int _countScheduledWeeks(Course course) {
    int count = 0;
    for (int week = course.startWeek; week <= course.endWeek; week++) {
      if (course.isInWeek(week)) count++;
    }
    return count;
  }

  /// 全勤：有效周数 == 完整开课周期的计划周数
  static bool _hasPerfectAttendance(Course course, int currentWeek) {
    final scheduled = _countScheduledWeeks(course);
    if (scheduled == 0) return false;
    final active = _countActiveWeeks(course, currentWeek);
    return active == scheduled;
  }

  /// 计算整个学期的必修/选修比例
  static CourseNatureStats _calculateSemesterNatureStats(
    List<Course> allCourses,
    int currentWeek,
  ) {
    int requiredCount = 0;
    int electiveCount = 0;
    int requiredSections = 0;
    int electiveSections = 0;

    final seenRequired = <String>{};
    final seenElective = <String>{};

    for (final course in allCourses) {
      final activeWeeks = _countActiveWeeks(course, currentWeek);
      final semesterSections = course.sectionCount * activeWeeks;

      final isRequired = course.courseNature == CourseNature.required;
      if (isRequired) {
        requiredSections += semesterSections;
        if (seenRequired.add(course.name)) {
          requiredCount++;
        }
      } else {
        electiveSections += semesterSections;
        if (seenElective.add(course.name)) {
          electiveCount++;
        }
      }
    }

    return CourseNatureStats(
      requiredCount: requiredCount,
      electiveCount: electiveCount,
      requiredSections: requiredSections,
      electiveSections: electiveSections,
    );
  }

  /// 计算课程排行（按整个学期课时排序）
  static List<CourseSemesterStat> _calculateCourseRanking(
    List<Course> allCourses,
    int currentWeek,
  ) {
    final grouped = _groupByCourseName(allCourses);

    final stats = grouped.entries.map((entry) {
      final name = entry.key;
      final courses = entry.value;
      final first = courses.first;

      int totalSections = 0;
      for (final course in courses) {
        final activeWeeks = _countActiveWeeks(course, currentWeek);
        totalSections += course.sectionCount * activeWeeks;
      }

      final slots =
          courses.map((c) {
            return CourseSlot(
              dayOfWeek: c.dayOfWeek,
              startSection: c.startSection,
              endSection: c.endSection,
              location: c.location,
            );
          }).toList()..sort((a, b) {
            final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCmp != 0) return dayCmp;
            return a.startSection.compareTo(b.startSection);
          });

      return CourseSemesterStat(
        name: name,
        teacher: first.teacher,
        nature: first.courseNature,
        totalSections: totalSections,
        slots: slots,
      );
    }).toList()..sort((a, b) => b.totalSections.compareTo(a.totalSections));

    return stats;
  }
}
