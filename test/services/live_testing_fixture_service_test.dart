import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/live_testing_fixture_service.dart';

void main() {
  test('buildHourlySections spans 24 distinct hourly slots', () {
    final sections = LiveTestingFixtureService.buildHourlySections();

    expect(sections, hasLength(24));
    expect(sections.first.startTime, '00:00');
    expect(sections.first.endTime, '01:00');
    expect(sections[8].startTime, '08:00');
    expect(sections[8].endTime, '09:00');
    expect(sections.last.startTime, '23:00');
    expect(sections.last.endTime, '23:59');
    expect(
      sections.map((section) => section.startTime).toSet(),
      hasLength(24),
    );
  });

  test('buildTwentyFourHourGrid maps each course to its own section', () {
    final now = DateTime(2026, 3, 23, 10, 30);
    final grid = LiveTestingFixtureService.buildTwentyFourHourGrid(
      now: now,
      semesterWeekCount: 20,
      timeSchemeId: 'scheme-live-test',
    );

    expect(grid, hasLength(24));
    expect(grid[0].startSection, 1);
    expect(grid[0].startTime, '00:00');
    expect(grid[8].startSection, 9);
    expect(grid[8].startTime, '08:00');
    expect(grid[23].startSection, 24);
    expect(grid[23].startTime, '23:00');
    expect(
      grid.map((course) => course.timeSchemeIdOverride).toSet(),
      {'scheme-live-test'},
    );
    expect(grid.every((course) => course.dayOfWeek == now.weekday), isTrue);
  });

  test('buildTimedTestCourse shifts start and end by lead duration', () {
    final now = DateTime(2026, 3, 23, 10, 15);
    final template = LiveTestingFixtureService.buildSlotTemplate(
      hour: 10,
      dayOfWeek: now.weekday,
      semesterWeekCount: 20,
      timeSchemeId: 'scheme-live-test',
    );
    final timed = LiveTestingFixtureService.buildTimedTestCourse(
      template: template,
      now: now,
      lead: const Duration(minutes: 3),
      duration: const Duration(minutes: 3),
    );

    expect(timed.startTime, '10:18');
    expect(timed.endTime, '10:21');
    expect(timed.dayOfWeek, now.weekday);
  });

  test('nextHourSlot wraps at midnight', () {
    expect(
      LiveTestingFixtureService.nextHourSlotFor(
        DateTime(2026, 3, 23, 23, 10),
      ),
      0,
    );
  });
}
