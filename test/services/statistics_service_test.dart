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
