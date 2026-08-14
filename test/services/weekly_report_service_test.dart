import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/weekly_report_service.dart';

void main() {
  group('WeeklyReportService', () {
    test('nextFireAt should land on Sunday 21:00 in the future', () {
      final now = DateTime(2026, 9, 1, 12); // 周二
      final fire = WeeklyReportService.nextFireAt(now: now);
      expect(fire.weekday, DateTime.sunday);
      expect(fire.hour, 21);
      expect(fire.minute, 0);
      expect(fire.isAfter(now), true);
      expect(fire.difference(now).inDays, inInclusiveRange(1, 7));
    });

    test('nextFireAt on Sunday morning should fire the same day', () {
      // 找到 2026-09 里最近的一个周日
      final base = DateTime(2026, 9, 1);
      final daysUntilSunday = (DateTime.sunday - base.weekday + 7) % 7;
      final sunday = base.add(Duration(days: daysUntilSunday));
      final morning = DateTime(sunday.year, sunday.month, sunday.day, 8);
      final fire = WeeklyReportService.nextFireAt(now: morning);
      expect(fire.day, sunday.day);
      expect(fire.hour, 21);
      expect(fire.isAfter(morning), true);
    });

    test('nextFireAt after Sunday 21:00 should roll to next Sunday', () {
      final base = DateTime(2026, 9, 1);
      final daysUntilSunday = (DateTime.sunday - base.weekday + 7) % 7;
      final sunday = base.add(Duration(days: daysUntilSunday));
      final late = DateTime(sunday.year, sunday.month, sunday.day, 22);
      final fire = WeeklyReportService.nextFireAt(now: late);
      expect(fire.weekday, DateTime.sunday);
      expect(fire.hour, 21);
      expect(fire.isAfter(late), true);
      expect(fire.difference(late).inDays, inInclusiveRange(1, 7));
    });

    test('buildBody should summarize week sections and courses', () {
      final l10n = AppLocalizationsZh();
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
          courseNature: CourseNature.required,
        ),
        Course(
          id: '2',
          name: '英语',
          teacher: '李四',
          location: 'B201',
          dayOfWeek: 2,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          courseNature: CourseNature.elective,
        ),
      ];
      final body = WeeklyReportService.buildBody(
        l10n: l10n,
        allCourses: courses,
        currentWeek: 5,
        semesterWeekCount: 16,
      );
      expect(body, contains('5')); // 第 5 周
      expect(body, contains('4')); // 4 节
      expect(body, contains('2')); // 2 门课
    });

    test('buildBody should handle empty courses', () {
      final l10n = AppLocalizationsZh();
      final body = WeeklyReportService.buildBody(
        l10n: l10n,
        allCourses: [],
        currentWeek: 5,
        semesterWeekCount: 16,
      );
      expect(body, isNotEmpty);
    });
  });
}
