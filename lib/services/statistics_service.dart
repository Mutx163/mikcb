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
    required int semesterWeekCount,
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
      totalWeeks: semesterWeekCount,
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

    // 全勤课程数（周排课口径）
    final perfectAttendanceCount = allCourses
        .where((c) => _hasPerfectAttendance(c, currentWeek))
        .length;

    // 早八 / 晚间 / 周末 课时（周排课口径）
    final earlyBirdSections = allCourses
        .where((c) => c.startTime.compareTo('08:00') <= 0)
        .fold<int>(0, (sum, c) => sum + c.sectionCount);
    final eveningSections = allCourses
        .where((c) => c.endTime.compareTo('18:00') > 0)
        .fold<int>(0, (sum, c) => sum + c.sectionCount);
    final weekendSections = allCourses
        .where((c) => c.dayOfWeek >= 6)
        .fold<int>(0, (sum, c) => sum + c.sectionCount);

    // 每日课时差（均衡度）
    final balanceGap = _calculateDailyBalanceGap(allCourses);

    // 单日跨教学楼最大值
    final dailyMaxBuildings = _calculateDailyMaxBuildings(allCourses);

    // 早间课时占比（周排课口径，12:00 前开始）
    final totalWeeklySections = allCourses.fold<int>(
      0,
      (sum, c) => sum + c.sectionCount,
    );
    final morningRatio = _calculateMorningRatio(
      allCourses,
      totalWeeklySections,
    );

    // 单日最长课间空档（节）
    final maxDailyGap = _calculateMaxDailyGap(allCourses);

    return [
      Achievement(
        id: 'early_bird',
        icon: Icons.wb_sunny_rounded,
        isUnlocked: earlyBirdSections > 0,
        progressCurrent: earlyBirdSections,
        progressTarget: 1,
      ),
      Achievement(
        id: 'perfect_attendance',
        icon: Icons.star_rounded,
        isUnlocked: perfectAttendanceCount > 0,
        progressCurrent: perfectAttendanceCount,
        progressTarget: allCourses.length,
      ),
      Achievement(
        id: 'weekend_warrior',
        icon: Icons.emoji_events_rounded,
        isUnlocked: weekendSections > 0,
        progressCurrent: weekendSections,
        progressTarget: 1,
      ),
      Achievement(
        id: 'class_king',
        icon: Icons.workspace_premium_rounded,
        isUnlocked: dailyMaxSections >= 6,
        progressCurrent: dailyMaxSections,
        progressTarget: 6,
      ),
      Achievement(
        id: 'scholar',
        icon: Icons.auto_stories_rounded,
        isUnlocked: totalSections >= 100,
        progressCurrent: totalSections,
        progressTarget: 100,
      ),
      Achievement(
        id: 'balanced',
        icon: Icons.balance_rounded,
        isUnlocked: balanceGap <= 2,
        progressCurrent: balanceGap,
        progressTarget: 2,
      ),
      Achievement(
        id: 'night_owl',
        icon: Icons.nights_stay_rounded,
        isUnlocked: eveningSections > 0,
        progressCurrent: eveningSections,
        progressTarget: 1,
      ),
      Achievement(
        id: 'explorer',
        icon: Icons.explore_rounded,
        isUnlocked: allRooms.length >= 5,
        progressCurrent: allRooms.length,
        progressTarget: 5,
      ),
      Achievement(
        id: 'full_day_king',
        icon: Icons.local_fire_department_rounded,
        isUnlocked: dailyMaxSections >= 8,
        progressCurrent: dailyMaxSections,
        progressTarget: 8,
      ),
      Achievement(
        id: 'building_hopper',
        icon: Icons.domain_rounded,
        isUnlocked: dailyMaxBuildings >= 3,
        progressCurrent: dailyMaxBuildings,
        progressTarget: 3,
      ),
      Achievement(
        id: 'morning_person',
        icon: Icons.wb_twilight_rounded,
        isUnlocked: morningRatio >= 0.5,
        progressCurrent: (morningRatio * 100).round(),
        progressTarget: 50,
      ),
      Achievement(
        id: 'gap_master',
        icon: Icons.av_timer_rounded,
        isUnlocked: maxDailyGap <= 2,
        progressCurrent: maxDailyGap,
        progressTarget: 2,
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

  /// 计算每周课时趋势（计划口径，覆盖整个学期）
  static List<WeeklyTrendPoint> calculateWeeklyTrend({
    required List<Course> allCourses,
    required int semesterWeekCount,
  }) {
    if (allCourses.isEmpty || semesterWeekCount < 1) {
      return const [];
    }

    return List.generate(semesterWeekCount, (index) {
      final week = index + 1;
      final active = allCourses
          .where((c) => c.isActiveInWeek(week))
          .toList();

      int sections = 0;
      int requiredSections = 0;
      int electiveSections = 0;
      final names = <String>{};
      final days = <int>{};
      for (final course in active) {
        sections += course.sectionCount;
        days.add(course.dayOfWeek);
        names.add(course.name);
        if (course.courseNature == CourseNature.required) {
          requiredSections += course.sectionCount;
        } else {
          electiveSections += course.sectionCount;
        }
      }

      return WeeklyTrendPoint(
        weekNumber: week,
        sections: sections,
        courseCount: names.length,
        requiredSections: requiredSections,
        electiveSections: electiveSections,
        activeDayCount: days.length,
      );
    });
  }

  /// 计算学期进度（校历对齐）
  static SemesterProgress calculateSemesterProgress({
    required List<Course> allCourses,
    required int currentWeek,
    required int semesterWeekCount,
    DateTime? semesterStartDate,
  }) {
    int sectionsDone = 0;
    int sectionsTotal = 0;
    for (final course in allCourses) {
      sectionsDone +=
          course.sectionCount * _countActiveWeeks(course, currentWeek);
      sectionsTotal += course.sectionCount * _countScheduledWeeks(course);
    }

    final remaining = sectionsTotal > sectionsDone
        ? sectionsTotal - sectionsDone
        : 0;

    DateTime? currentDate;
    DateTime? endDate;
    if (semesterStartDate != null) {
      currentDate = semesterStartDate
          .add(Duration(days: currentWeek * 7 - 1));
      endDate = semesterStartDate
          .add(Duration(days: semesterWeekCount * 7 - 1));
    }

    return SemesterProgress(
      semesterStartDate: semesterStartDate,
      currentDate: currentDate,
      semesterEndDate: endDate,
      weeksElapsed: currentWeek < 1 ? 0 : currentWeek,
      totalWeeks: semesterWeekCount < 1 ? 0 : semesterWeekCount,
      sectionsDone: sectionsDone,
      sectionsTotal: sectionsTotal,
      remainingSections: remaining,
    );
  }

  /// 计算学期热力图（周 × 天课时密度，计划口径；未来周由 UI 裁剪）
  static SemesterHeatmap calculateHeatmap({
    required List<Course> allCourses,
    required int semesterWeekCount,
  }) {
    final rows = List.generate(7, (_) => List<int>.filled(semesterWeekCount, 0));
    var maxSections = 0;

    for (final course in allCourses) {
      final day = course.dayOfWeek - 1;
      if (day < 0 || day >= 7) continue;
      for (var week = 1; week <= semesterWeekCount; week++) {
        if (course.isActiveInWeek(week)) {
          final value = rows[day][week - 1] + course.sectionCount;
          rows[day][week - 1] = value;
          if (value > maxSections) maxSections = value;
        }
      }
    }

    return SemesterHeatmap(
      weekCount: semesterWeekCount,
      maxSections: maxSections,
      rows: rows,
    );
  }

  /// 计算时间利用统计（周排课口径）
  static TimeUtilizationStats calculateTimeUtilization({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    String? earliest;
    String? latest;
    int morningSections = 0;
    int noonSections = 0;
    int eveningSections = 0;
    int weekendSections = 0;

    // 单日最大课间空档（节）
    final gapsByDay = <int, List<int>>{};
    final slotsByDay = <int, List<Course>>{};

    for (final course in allCourses) {
      if (_countActiveWeeks(course, currentWeek) == 0) continue;
      final start = course.startTime;
      final end = course.endTime;
      if (earliest == null || start.compareTo(earliest) < 0) {
        earliest = start;
      }
      if (latest == null || end.compareTo(latest) > 0) {
        latest = end;
      }
      if (start.compareTo('12:00') < 0) {
        morningSections += course.sectionCount;
      }
      if (start.compareTo('14:00') < 0 && end.compareTo('12:00') > 0) {
        noonSections += course.sectionCount;
      }
      if (end.compareTo('18:00') > 0) {
        eveningSections += course.sectionCount;
      }
      if (course.dayOfWeek >= 6) {
        weekendSections += course.sectionCount;
      }
      slotsByDay.putIfAbsent(course.dayOfWeek, () => []).add(course);
    }

    for (final slots in slotsByDay.values) {
      final sorted = [...slots]
        ..sort((a, b) => a.startSection.compareTo(b.startSection));
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].startSection -
            sorted[i - 1].endSection -
            1;
        if (gap > 0) {
          gapsByDay.putIfAbsent(sorted[i].dayOfWeek, () => []).add(gap);
        }
      }
    }

    var maxGap = 0;
    for (final gaps in gapsByDay.values) {
      for (final gap in gaps) {
        if (gap > maxGap) maxGap = gap;
      }
    }

    return TimeUtilizationStats(
      earliestStart: earliest ?? '',
      latestEnd: latest ?? '',
      morningSections: morningSections,
      noonSections: noonSections,
      eveningSections: eveningSections,
      weekendSections: weekendSections,
      maxDailyGapSections: maxGap,
      activeCourseCount: slotsByDay.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      ),
    );
  }

  /// 计算教室与教学楼统计
  static VenueStats calculateVenueStats({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    final roomCounts = <String, int>{};
    for (final course in allCourses) {
      if (course.location.isEmpty) continue;
      final activeWeeks = _countActiveWeeks(course, currentWeek);
      if (activeWeeks == 0) continue;
      roomCounts[course.location] =
          (roomCounts[course.location] ?? 0) + activeWeeks;
    }

    final topRooms = roomCounts.entries
        .map((e) => RoomVisitStat(name: e.key, visits: e.value))
        .toList()
      ..sort((a, b) => b.visits.compareTo(a.visits));

    final buildingSections = <String, int>{};
    for (final entry in roomCounts.entries) {
      final building = _buildingOf(entry.key);
      buildingSections[building] =
          (buildingSections[building] ?? 0) + entry.value;
    }
    final buildings = buildingSections.entries
        .map((e) => BuildingStat(name: e.key, sections: e.value))
        .toList()
      ..sort((a, b) => b.sections.compareTo(a.sections));

    return VenueStats(
      topRooms: topRooms.take(5).toList(growable: false),
      buildings: buildings,
    );
  }

  /// 计算教师课时排行
  static List<TeacherStat> calculateTeacherStats({
    required List<Course> allCourses,
    required int currentWeek,
  }) {
    final byTeacher = <String, List<Course>>{};
    for (final course in allCourses) {
      final teacher = course.teacher.trim();
      if (teacher.isEmpty) continue;
      if (_countActiveWeeks(course, currentWeek) == 0) continue;
      byTeacher.putIfAbsent(teacher, () => []).add(course);
    }

    final stats = byTeacher.entries.map((entry) {
      int sections = 0;
      final names = <String>{};
      for (final course in entry.value) {
        sections +=
            course.sectionCount * _countActiveWeeks(course, currentWeek);
        names.add(course.name);
      }
      return TeacherStat(
        name: entry.key,
        sections: sections,
        courseCount: names.length,
      );
    }).toList()..sort((a, b) => b.sections.compareTo(a.sections));

    return stats.take(10).toList(growable: false);
  }

  /// 本周 vs 上周 vs 学期平均 对比
  static WeeklyComparison calculateWeeklyComparison({
    required List<Course> allCourses,
    required int currentWeek,
    required int semesterWeekCount,
  }) {
    final weekSections = currentWeek >= 1 && currentWeek <= semesterWeekCount
        ? calculate(allCourses: allCourses, week: currentWeek).totalSections
        : 0;
    final lastWeekSections = currentWeek > 1
        ? calculate(allCourses: allCourses, week: currentWeek - 1).totalSections
        : 0;

    final semester = calculateSemester(
      allCourses: allCourses,
      currentWeek: currentWeek,
      semesterWeekCount: semesterWeekCount,
    );
    final average = currentWeek > 0 ? semester.totalSections / currentWeek : 0.0;

    return WeeklyComparison(
      weekSections: weekSections,
      lastWeekSections: lastWeekSections,
      semesterAverageSections: average,
      deltaVsLastWeek: weekSections - lastWeekSections,
      deltaVsAverage: weekSections - average,
    );
  }

  /// 提取教学楼前缀（字母开头），无字母则原样返回
  static String _buildingOf(String room) {
    return RegExp(r'^[A-Za-z]+').stringMatch(room) ?? room;
  }

  /// 单日最大跨教学楼数
  static int _calculateDailyMaxBuildings(List<Course> allCourses) {
    final byDay = <int, Set<String>>{};
    for (final course in allCourses) {
      byDay.putIfAbsent(course.dayOfWeek, () => {}).add(_buildingOf(course.location));
    }
    var max = 0;
    for (final buildings in byDay.values) {
      if (buildings.length > max) max = buildings.length;
    }
    return max;
  }

  /// 早间课时占比（12:00 前开始的课时 / 总课时，周排课口径）
  static double _calculateMorningRatio(
    List<Course> allCourses,
    int totalWeeklySections,
  ) {
    if (totalWeeklySections <= 0) return 0;
    final morning = allCourses
        .where((c) => c.startTime.compareTo('12:00') < 0)
        .fold<int>(0, (sum, c) => sum + c.sectionCount);
    return morning / totalWeeklySections;
  }

  /// 单日最长课间空档（节）
  static int _calculateMaxDailyGap(List<Course> allCourses) {
    final slotsByDay = <int, List<Course>>{};
    for (final course in allCourses) {
      slotsByDay.putIfAbsent(course.dayOfWeek, () => []).add(course);
    }
    var maxGap = 0;
    for (final slots in slotsByDay.values) {
      final sorted = [...slots]
        ..sort((a, b) => a.startSection.compareTo(b.startSection));
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].startSection -
            sorted[i - 1].endSection -
            1;
        if (gap > maxGap) maxGap = gap;
      }
    }
    return maxGap;
  }

  /// 每日课时最大差值（均衡度）
  static int _calculateDailyBalanceGap(List<Course> allCourses) {
    final dailySections = <int, int>{};
    for (final course in allCourses) {
      final day = course.dayOfWeek;
      dailySections[day] = (dailySections[day] ?? 0) + course.sectionCount;
    }
    if (dailySections.isEmpty) return 0;
    final values = dailySections.values.toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    return max - min;
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
