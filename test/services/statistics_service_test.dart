import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

void main() {
  group('StatisticsService', () {
    group('Weekly Stats', () {
      test('should calculate weekly stats correctly', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '数学', 3, 3, 4, CourseNature.required),
          _course('3', '英语', 2, 1, 2, CourseNature.elective),
        ];

        final stats = StatisticsService.calculate(allCourses: courses, week: 1);

        expect(stats.weekNumber, 1);
        expect(stats.totalCourses, 2); // 数学 + 英语
        expect(stats.totalSections, 6); // 2 + 2 + 2
        expect(stats.dailyStats.length, 7);
      });

      test('should handle odd week courses', () {
        final courses = [
          Course(
            id: '1',
            name: '单周课',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 1,
            endWeek: 16,
            isOddWeek: true,
            courseNature: CourseNature.required,
          ),
        ];

        // 单周：第1周有课
        final stats1 = StatisticsService.calculate(
          allCourses: courses,
          week: 1,
        );
        expect(stats1.totalCourses, 1);
        expect(stats1.totalSections, 2);

        // 双周：第2周无课
        final stats2 = StatisticsService.calculate(
          allCourses: courses,
          week: 2,
        );
        expect(stats2.totalCourses, 0);
        expect(stats2.totalSections, 0);
      });

      test('should handle empty courses', () {
        final stats = StatisticsService.calculate(allCourses: [], week: 1);

        expect(stats.totalCourses, 0);
        expect(stats.totalSections, 0);
        expect(stats.dailyStats.length, 7);
        for (final day in stats.dailyStats) {
          expect(day.sectionCount, 0);
          expect(day.courseCount, 0);
        }
        expect(stats.natureStats.requiredCount, 0);
        expect(stats.natureStats.electiveCount, 0);
        expect(stats.courseStats, isEmpty);
      });
    });

    group('Semester Stats', () {
      test('should calculate semester stats correctly', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.elective),
        ];

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        expect(stats.totalCourses, 2);
        expect(stats.totalWeeks, 16);
        // 数学：2节 × 16周 = 32，英语：2节 × 16周 = 32，总计 64
        expect(stats.totalSections, 64);
        expect(stats.dailyAverages.length, 7);
        expect(stats.courseRanking.length, 2);
      });

      test('should handle empty courses', () {
        final stats = StatisticsService.calculateSemester(
          allCourses: [],
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        expect(stats.totalCourses, 0);
        expect(stats.totalSections, 0);
        expect(stats.totalWeeks, 0);
        expect(stats.longestStreak, 0);
        expect(stats.dailyAverages, isEmpty);
        expect(stats.courseRanking, isEmpty);
      });

      test('should handle odd week courses in semester', () {
        final courses = [
          Course(
            id: '1',
            name: '单周课',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 1,
            endWeek: 16,
            isOddWeek: true,
            courseNature: CourseNature.required,
          ),
        ];

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        expect(stats.totalCourses, 1);
        // 单周：第1,3,5,7,9,11,13,15周有课，共8周
        expect(stats.totalSections, 2 * 8);
      });

      test('should handle suspended weeks in semester', () {
        final courses = [
          Course(
            id: '1',
            name: '停课测试',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 1,
            endWeek: 16,
            suspendedWeeks: [3, 5],
            courseNature: CourseNature.required,
          ),
        ];

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        expect(stats.totalCourses, 1);
        // 16周 - 2周停课 = 14周
        expect(stats.totalSections, 2 * 14);
      });

      test('should calculate longest streak correctly', () {
        // 周一到周五都有课
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.required),
          _course('3', '物理', 3, 1, 2, CourseNature.required),
          _course('4', '化学', 4, 1, 2, CourseNature.required),
          _course('5', '生物', 5, 1, 2, CourseNature.required),
        ];

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        // 周一到周五连续5天
        expect(stats.longestStreak, 5);
      });

      test('should cap longest streak at 7 for full week', () {
        final courses = List.generate(
          7,
          (i) => _course(
            '${i + 1}',
            '课程${i + 1}',
            i + 1,
            1,
            2,
            CourseNature.required,
          ),
        );

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        expect(stats.longestStreak, 7);
      });

      test('should calculate cross-week streak correctly', () {
        // 周六、周日、周一都有课
        final courses = [
          _course('1', '数学', 6, 1, 2, CourseNature.required),
          _course('2', '英语', 7, 1, 2, CourseNature.required),
          _course('3', '物理', 1, 1, 2, CourseNature.required),
        ];

        final stats = StatisticsService.calculateSemester(
          allCourses: courses,
          currentWeek: 16,
          semesterWeekCount: 16,
        );

        // 周六-周日-周一连续3天
        expect(stats.longestStreak, 3);
      });
    });

    group('Achievements', () {
      test('should unlock early bird for 8:00 class', () {
        final courses = [
          Course(
            id: '1',
            name: '早课',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            courseNature: CourseNature.required,
          ),
        ];

        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );

        final earlyBird = achievements.firstWhere((a) => a.id == 'early_bird');
        expect(earlyBird.isUnlocked, true);
      });

      test('should unlock weekend warrior for weekend class', () {
        final courses = [_course('1', '周末课', 6, 1, 2, CourseNature.required)];

        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );

        final weekendWarrior = achievements.firstWhere(
          (a) => a.id == 'weekend_warrior',
        );
        expect(weekendWarrior.isUnlocked, true);
      });

      test('should unlock scholar for 100+ sections', () {
        // 10门课，每门2节，16周 = 320节
        final courses = List.generate(
          10,
          (i) =>
              _course('$i', '课程$i', (i % 7) + 1, 1, 2, CourseNature.required),
        );

        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );

        final scholar = achievements.firstWhere((a) => a.id == 'scholar');
        expect(scholar.isUnlocked, true);
      });

      test('should return empty for empty courses', () {
        final achievements = StatisticsService.calculateAchievements(
          allCourses: [],
          currentWeek: 16,
        );

        expect(achievements, isEmpty);
      });

      test('should exclude suspended weeks from perfect attendance denominator', () {
        final course = Course(
          id: 'suspended',
          name: '停课课程',
          teacher: '老师',
          location: '教室',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          startWeek: 1,
          endWeek: 4,
          suspendedWeeks: [2],
          courseNature: CourseNature.required,
        );

        final achievements = StatisticsService.calculateAchievements(
          allCourses: [course],
          currentWeek: 4,
        );
        final perfect = achievements.firstWhere(
          (achievement) => achievement.id == 'perfect_attendance',
        );

        expect(perfect.isUnlocked, true);
        expect(perfect.progressCurrent, 1);
      });

      test('should not unlock perfect attendance mid-semester', () {
        final courses = [
          Course(
            id: '1',
            name: '数学',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 3,
            endWeek: 16,
            courseNature: CourseNature.required,
          ),
        ];

        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 5,
        );

        final perfect = achievements.firstWhere(
          (a) => a.id == 'perfect_attendance',
        );
        expect(perfect.isUnlocked, false);
      });
    });

    group('Data Stories', () {
      test('should generate stories for valid data', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.elective),
        ];

        final stories = StatisticsService.generateDataStories(
          allCourses: courses,
          currentWeek: 16,
        );

        expect(stories, isNotEmpty);
        // 应该有最忙的一天、时间跨度等故事
        expect(stories.any((s) => s.type == StoryType.busiestDay), true);
      });

      test('should return empty for empty courses', () {
        final stories = StatisticsService.generateDataStories(
          allCourses: [],
          currentWeek: 16,
        );

        expect(stories, isEmpty);
      });

      test('should count room visits as entries times active weeks', () {
        final courses = [
          Course(
            id: '1',
            name: '数学',
            teacher: '张三',
            location: 'A301',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            courseNature: CourseNature.required,
          ),
          Course(
            id: '2',
            name: '数学',
            teacher: '张三',
            location: 'A301',
            dayOfWeek: 3,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
            courseNature: CourseNature.required,
          ),
        ];

        final stories = StatisticsService.generateDataStories(
          allCourses: courses,
          currentWeek: 12,
        );

        final roomStory = stories.firstWhere(
          (s) => s.type == StoryType.favoriteRoom,
        );
        expect(roomStory.visitCount, 24);
      });
    });

    group('CourseNatureStats', () {
      test('should calculate ratio correctly', () {
        final stats = CourseNatureStats(
          requiredCount: 3,
          electiveCount: 1,
          requiredSections: 6,
          electiveSections: 2,
        );

        expect(stats.totalCount, 4);
        expect(stats.totalSections, 8);
        expect(stats.requiredRatio, 0.75);
        expect(stats.electiveRatio, 0.25);
      });

      test('should handle zero total', () {
        final stats = CourseNatureStats(
          requiredCount: 0,
          electiveCount: 0,
          requiredSections: 0,
          electiveSections: 0,
        );

        expect(stats.requiredRatio, 0);
        expect(stats.electiveRatio, 0);
      });

    group('Weekly Trend', () {
      test('should produce one point per week', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.elective),
        ];
        final trend = StatisticsService.calculateWeeklyTrend(
          allCourses: courses,
          semesterWeekCount: 16,
        );
        expect(trend.length, 16);
        expect(trend.first.sections, 4);
        expect(trend.first.courseCount, 2);
        expect(trend.first.requiredSections, 2);
        expect(trend.first.electiveSections, 2);
        expect(trend.first.activeDayCount, 2);
      });

      test('should respect odd weeks and suspended weeks', () {
        final courses = [
          Course(
            id: '1',
            name: '单周课',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 1,
            endWeek: 4,
            isOddWeek: true,
            courseNature: CourseNature.required,
          ),
        ];
        final trend = StatisticsService.calculateWeeklyTrend(
          allCourses: courses,
          semesterWeekCount: 4,
        );
        expect(trend[0].sections, 2); // 单周第1周
        expect(trend[1].sections, 0); // 双周第2周
        expect(trend[2].sections, 2); // 单周第3周
      });
    });

    group('Semester Progress', () {
      test('should compute done/total/remaining', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
        ];
        final progress = StatisticsService.calculateSemesterProgress(
          allCourses: courses,
          currentWeek: 10,
          semesterWeekCount: 16,
        );
        expect(progress.sectionsDone, 20);
        expect(progress.sectionsTotal, 32);
        expect(progress.remainingSections, 12);
        expect(progress.weeksElapsed, 10);
        expect((progress.percent * 100).round(), 63); // 20/32 = 62.5%
      });

      test('should resolve calendar dates from semester start', () {
        final start = DateTime(2026, 9, 1);
        final progress = StatisticsService.calculateSemesterProgress(
          allCourses: [
            _course('1', '数学', 1, 1, 2, CourseNature.required),
          ],
          currentWeek: 2,
          semesterWeekCount: 16,
          semesterStartDate: start,
        );
        expect(progress.semesterStartDate, start);
        expect(progress.currentDate, start.add(const Duration(days: 13)));
        expect(progress.semesterEndDate, start.add(const Duration(days: 111)));
      });

      test('should handle empty courses', () {
        final progress = StatisticsService.calculateSemesterProgress(
          allCourses: [],
          currentWeek: 5,
          semesterWeekCount: 16,
        );
        expect(progress.sectionsDone, 0);
        expect(progress.sectionsTotal, 0);
        expect(progress.remainingSections, 0);
        expect(progress.percent, 0);
      });
    });

    group('Heatmap', () {
      test('should fill week x day grid', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 3, 3, 4, CourseNature.elective),
        ];
        final heatmap = StatisticsService.calculateHeatmap(
          allCourses: courses,
          semesterWeekCount: 4,
        );
        expect(heatmap.weekCount, 4);
        expect(heatmap.rows.length, 7);
        expect(heatmap.rows[0][0], 2); // 周一第1周
        expect(heatmap.rows[2][0], 2); // 周三第1周
        expect(heatmap.rows[1][0], 0); // 周二无课
        expect(heatmap.maxSections, 2);
      });

      test('clippedToWeek should zero future weeks', () {
        final heatmap = StatisticsService.calculateHeatmap(
          allCourses: [
            _course('1', '数学', 1, 1, 2, CourseNature.required),
          ],
          semesterWeekCount: 4,
        );
        final clipped = heatmap.clippedToWeek(2);
        expect(clipped.rows[0][0], 2);
        expect(clipped.rows[0][1], 2);
        expect(clipped.rows[0][2], 0);
        expect(clipped.rows[0][3], 0);
        expect(clipped.maxSections, 2);
      });
    });

    group('Time Utilization', () {
      test('should compute time ranges and segments', () {
        final courses = [
          Course(
            id: '1',
            name: '早课',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            courseNature: CourseNature.required,
          ),
          Course(
            id: '2',
            name: '晚课',
            teacher: '李四',
            location: 'B201',
            dayOfWeek: 2,
            startSection: 9,
            endSection: 10,
            startTime: '18:30',
            endTime: '20:10',
            courseNature: CourseNature.elective,
          ),
          Course(
            id: '3',
            name: '周末课',
            teacher: '王五',
            location: 'C301',
            dayOfWeek: 6,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
            courseNature: CourseNature.elective,
          ),
        ];
        final stats = StatisticsService.calculateTimeUtilization(
          allCourses: courses,
          currentWeek: 16,
        );
        expect(stats.earliestStart, '08:00');
        expect(stats.latestEnd, '20:10');
        expect(stats.morningSections, 4); // 早课 2 + 周末课 2
        expect(stats.eveningSections, 2);
        expect(stats.weekendSections, 2);
        expect(stats.noonSections, 0);
        expect(stats.activeCourseCount, 3);
      });

      test('should compute max daily gap', () {
        final courses = [
          _course('1', '早课', 1, 1, 2, CourseNature.required),
          _course('2', '晚课', 1, 9, 10, CourseNature.elective),
        ];
        final stats = StatisticsService.calculateTimeUtilization(
          allCourses: courses,
          currentWeek: 16,
        );
        // 第2节结束 → 第9节开始：空档 = 9 - 2 - 1 = 6
        expect(stats.maxDailyGapSections, 6);
      });
    });

    group('Venue Stats', () {
      test('should rank rooms and buildings', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.elective),
        ];
        final stats = StatisticsService.calculateVenueStats(
          allCourses: courses,
          currentWeek: 16,
        );
        expect(stats.topRooms, isNotEmpty);
        // 同一教室：2 条 × 16 周
        expect(stats.topRooms.first.visits, 32);
        expect(stats.buildings, isNotEmpty);
        // '教室' 无字母前缀 → 原样作为教学楼
        expect(stats.buildings.first.name, '教室');
      });
    });

    group('Teacher Stats', () {
      test('should aggregate sections per teacher', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '物理', 2, 1, 2, CourseNature.required),
          _course('3', '英语', 3, 1, 2, CourseNature.elective),
        ];
        final stats = StatisticsService.calculateTeacherStats(
          allCourses: courses,
          currentWeek: 16,
        );
        expect(stats.length, 1);
        expect(stats.first.sections, 96); // 3 门 × 2 节 × 16 周
        expect(stats.first.courseCount, 3);
      });
    });

    group('Weekly Comparison', () {
      test('should compare weeks', () {
        final courses = [
          _course('1', '数学', 1, 1, 2, CourseNature.required),
          _course('2', '英语', 2, 1, 2, CourseNature.elective),
        ];
        final cmp = StatisticsService.calculateWeeklyComparison(
          allCourses: courses,
          currentWeek: 10,
          semesterWeekCount: 16,
        );
        expect(cmp.weekSections, 4);
        expect(cmp.lastWeekSections, 4);
        expect(cmp.deltaVsLastWeek, 0);
        // 已过 10 周：2 门 × 2 节 × 10 周 = 40 节，周均 4.0
        expect(cmp.semesterAverageSections, closeTo(4.0, 0.001));
        expect(cmp.deltaVsAverage, closeTo(0.0, 0.001));
      });
    });

    group('Achievements Progress', () {
      test('should attach progress to scholar', () {
        final courses = List.generate(
          10,
          (i) => _course('$i', '课程$i', (i % 7) + 1, 1, 2, CourseNature.required),
        );
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final scholar = achievements.firstWhere((a) => a.id == 'scholar');
        expect(scholar.hasProgress, true);
        expect(scholar.progressCurrent, 320);
        expect(scholar.progressTarget, 100);
      });

      test('should unlock full day king at 8+ sections', () {
        // 周一 4 门课 × 2 节 = 8 节
        final courses = List.generate(
          4,
          (i) => _course('$i', '课程$i', 1, i * 2 + 1, i * 2 + 2, CourseNature.required),
        );
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final king = achievements.firstWhere((a) => a.id == 'full_day_king');
        expect(king.isUnlocked, true);
        expect(king.progressCurrent, 8);
        expect(king.progressTarget, 8);
      });

      test('should unlock morning person with 50%+ morning sections', () {
        // 2 门早课（08:00/10:00）+ 1 门晚课（18:30）→ 早间占比 2/3
        final courses = [
          Course(
            id: '1',
            name: '早课A',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            courseNature: CourseNature.required,
          ),
          Course(
            id: '2',
            name: '早课B',
            teacher: '李四',
            location: 'B201',
            dayOfWeek: 2,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
            courseNature: CourseNature.elective,
          ),
          Course(
            id: '3',
            name: '晚课',
            teacher: '王五',
            location: 'C301',
            dayOfWeek: 3,
            startSection: 9,
            endSection: 10,
            startTime: '18:30',
            endTime: '20:10',
            courseNature: CourseNature.elective,
          ),
        ];
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final morning = achievements.firstWhere((a) => a.id == 'morning_person');
        expect(morning.isUnlocked, true);
        expect(morning.progressCurrent, 67); // 4/6 ≈ 67%
        expect(morning.progressTarget, 50);
      });

      test('should unlock gap master with compact schedule', () {
        // 同一门课一天内 1-2 节 + 3-4 节 → 空档 0
        final courses = [
          _course('1', '课A', 1, 1, 2, CourseNature.required),
          _course('2', '课B', 1, 3, 4, CourseNature.elective),
        ];
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final gapMaster = achievements.firstWhere((a) => a.id == 'gap_master');
        expect(gapMaster.isUnlocked, true);
        expect(gapMaster.progressCurrent, 0);
      });

      test('should NOT unlock gap master with long break', () {
        final courses = [
          _course('1', '早课', 1, 1, 2, CourseNature.required),
          _course('2', '晚课', 1, 9, 10, CourseNature.elective),
        ];
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final gapMaster = achievements.firstWhere((a) => a.id == 'gap_master');
        expect(gapMaster.isUnlocked, false);
        expect(gapMaster.progressCurrent, 6);
      });

      test('should unlock building hopper with 3 buildings in a day', () {
        final courses = [
          Course(
            id: '1',
            name: '课A',
            teacher: '张三',
            location: 'A101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            courseNature: CourseNature.required,
          ),
          Course(
            id: '2',
            name: '课B',
            teacher: '李四',
            location: 'B201',
            dayOfWeek: 1,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
            courseNature: CourseNature.required,
          ),
          Course(
            id: '3',
            name: '课C',
            teacher: '王五',
            location: 'C301',
            dayOfWeek: 1,
            startSection: 5,
            endSection: 6,
            startTime: '14:00',
            endTime: '15:40',
            courseNature: CourseNature.elective,
          ),
        ];
        final achievements = StatisticsService.calculateAchievements(
          allCourses: courses,
          currentWeek: 16,
        );
        final hopper = achievements.firstWhere((a) => a.id == 'building_hopper');
        expect(hopper.isUnlocked, true);
        expect(hopper.progressCurrent, 3);
      });
    });
    });
  });
}

Course _course(
  String id,
  String name,
  int dayOfWeek,
  int startSection,
  int endSection,
  CourseNature nature,
) {
  return Course(
    id: id,
    name: name,
    teacher: '老师',
    location: '教室',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    courseNature: nature,
  );
}
