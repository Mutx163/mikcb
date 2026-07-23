import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/live_testing_fixture_service.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  const sampleSections = [
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '08:55', endTime: '09:40'),
    SectionTime(startTime: '10:00', endTime: '10:45'),
    SectionTime(startTime: '10:55', endTime: '11:40'),
    SectionTime(startTime: '14:00', endTime: '14:45'),
  ];

  test('buildHourlySections spans 24 section-aligned hourly slots', () {
    final sections = LiveTestingFixtureService.buildHourlySections();

    expect(sections, hasLength(24));
    expect(sections.first.startTime, '00:00');
    expect(sections.first.endTime, '01:00');
    expect(sections[10].startTime, '10:00');
    expect(sections[10].endTime, '11:00');
    expect(sections.last.startTime, '23:00');
    expect(sections.last.endTime, '23:59');
  });

  test('hourly grid keeps section index aligned with scheme times', () {
    final now = DateTime(2026, 3, 23, 10, 30);
    final sections = LiveTestingFixtureService.buildHourlySections();
    final grid = LiveTestingFixtureService.buildSectionGrid(
      now: now,
      semesterWeekCount: 20,
      sections: sections,
    );

    expect(grid, hasLength(24));
    expect(grid[10].startSection, 11);
    expect(grid[10].endSection, 11);
    expect(grid[10].startTime, '10:00');
    expect(grid[10].endTime, '11:00');
    expect(grid[10].name, '测试 第11节');
  });

  test('buildSectionGrid maps each course to its own section times', () {
    final now = DateTime(2026, 3, 23, 10, 30);
    final grid = LiveTestingFixtureService.buildSectionGrid(
      now: now,
      semesterWeekCount: 20,
      sections: sampleSections,
    );

    expect(grid, hasLength(5));
    expect(grid[0].startSection, 1);
    expect(grid[0].endSection, 1);
    expect(grid[0].startTime, '08:00');
    expect(grid[0].endTime, '08:45');
    expect(grid[0].name, '测试 第1节');
    expect(grid[0].timeSchemeIdOverride, isNull);

    expect(grid[2].startSection, 3);
    expect(grid[2].startTime, '10:00');
    expect(grid[2].endTime, '10:45');
    expect(grid[2].name, '测试 第3节');

    expect(grid.every((course) => course.dayOfWeek == now.weekday), isTrue);
    expect(grid.map((course) => course.id).toSet(), {
      'live_test_01',
      'live_test_02',
      'live_test_03',
      'live_test_04',
      'live_test_05',
    });
  });

  test('sectionNumberForTime prefers in-progress then upcoming section', () {
    expect(
      LiveTestingFixtureService.sectionNumberForTime(
        DateTime(2026, 3, 23, 7, 30),
        sampleSections,
      ),
      1,
    );
    expect(
      LiveTestingFixtureService.sectionNumberForTime(
        DateTime(2026, 3, 23, 8, 10),
        sampleSections,
      ),
      1,
    );
    expect(
      LiveTestingFixtureService.sectionNumberForTime(
        DateTime(2026, 3, 23, 10, 20),
        sampleSections,
      ),
      3,
    );
    expect(
      LiveTestingFixtureService.sectionNumberForTime(
        DateTime(2026, 3, 23, 22, 0),
        sampleSections,
      ),
      5,
    );
  });

  test('nextSectionNumberForTime wraps after last section', () {
    expect(
      LiveTestingFixtureService.nextSectionNumberForTime(
        DateTime(2026, 3, 23, 14, 10),
        sampleSections,
      ),
      1,
    );
    expect(
      LiveTestingFixtureService.nextSectionNumberForTime(
        DateTime(2026, 3, 23, 8, 10),
        sampleSections,
      ),
      2,
    );
  });

  test('buildTimedTestCourse shifts clock only, keeps section indices', () {
    final now = DateTime(2026, 3, 23, 10, 15);
    final template = LiveTestingFixtureService.buildSlotTemplate(
      sectionNumber: 3,
      section: sampleSections[2],
      dayOfWeek: now.weekday,
      semesterWeekCount: 20,
      totalSections: sampleSections.length,
    );
    final timed = LiveTestingFixtureService.buildTimedTestCourse(
      template: template,
      now: now,
      lead: const Duration(minutes: 3),
      duration: const Duration(minutes: 3),
    );

    expect(timed.startTime, '10:18');
    expect(timed.endTime, '10:21');
    expect(timed.startSection, 3);
    expect(timed.endSection, 3);
    expect(timed.dayOfWeek, now.weekday);
  });

  test('buildTimedTestCourse rejects a range that crosses midnight', () {
    final now = DateTime(2026, 3, 23, 23, 58);
    final template = LiveTestingFixtureService.buildSlotTemplate(
      sectionNumber: 24,
      section: const SectionTime(startTime: '23:00', endTime: '23:59'),
      dayOfWeek: now.weekday,
      semesterWeekCount: 20,
    );

    expect(
      () => LiveTestingFixtureService.buildTimedTestCourse(
        template: template,
        now: now,
        lead: const Duration(minutes: 1),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'upsert keeps fixture clocks and production Live can select it',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      final now = DateTime(2026, 3, 23, 10, 15);

      final timed = await LiveTestingFixtureService.upsertTimedFixtureCourse(
        provider: provider,
        sectionNumber: 1,
        now: now,
        lead: const Duration(minutes: 3),
      );

      expect(provider.getCourseById(timed.id)?.startTime, '10:18');
      expect(provider.getCourseById(timed.id)?.endTime, '10:21');
      expect(
        provider
            .getLiveActivityCourseSelection(now: now, week: 1)
            ?.currentCourse
            .id,
        timed.id,
      );
      provider.dispose();
    },
  );
}
