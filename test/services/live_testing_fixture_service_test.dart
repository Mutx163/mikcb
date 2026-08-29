import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/live_testing_fixture_service.dart';
import 'package:university_timetable/services/storage_service.dart';

DateTime _atClock(DateTime day, String clock) {
  final parts = clock.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

/// Provider 级用例的基准时间：用真实当前时间构建预设课。管线路径
/// （[_liveUpdateActivityBody] 顶部）会按真实时钟判定预设课是否已结束，
/// 过去日期的预设课会在任何一次刷新时被立即摘除；午夜前 10 分钟内无法
/// 构建不跨日预设课，统一回拨保证可构建。
DateTime _testBaseNow() {
  final now = DateTime.now();
  if (now.hour == 23 && now.minute >= 50) {
    return now.subtract(const Duration(minutes: 10));
  }
  return now;
}

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

  group('self-check preset courses', () {
    test('buildPresetCourses creates two back-to-back courses for today', () {
      final now = DateTime(2026, 3, 23, 10, 15);
      final presets = LiveTestingFixtureService.buildPresetCourses(
        now: now,
        targetWeek: 1,
        semesterWeekCount: 20,
      );

      expect(presets, hasLength(2));
      expect(presets[0].id, LiveTestingFixtureService.presetCourseIdA);
      expect(presets[1].id, LiveTestingFixtureService.presetCourseIdB);
      expect(presets[0].startTime, '10:16');
      expect(presets[0].endTime, '10:19');
      expect(presets[1].startTime, '10:20');
      expect(presets[1].endTime, '10:23');
      expect(presets.every((c) => c.dayOfWeek == now.weekday), isTrue);
      expect(
        presets.every(LiveTestingFixtureService.isPresetCourse),
        isTrue,
      );
      expect(
        presets.every(LiveTestingFixtureService.isFixtureCourse),
        isTrue,
      );
    });

    test('preset week span covers pre-semester and post-semester weeks', () {
      final now = DateTime(2026, 3, 23, 10, 15);
      final preSemester = LiveTestingFixtureService.buildPresetCourses(
        now: now,
        targetWeek: 0,
        semesterWeekCount: 20,
      );
      expect(preSemester.every((c) => c.isInWeek(0)), isTrue);
      expect(preSemester.every((c) => c.isInWeek(1)), isTrue);

      final afterTerm = LiveTestingFixtureService.buildPresetCourses(
        now: now,
        targetWeek: 25,
        semesterWeekCount: 20,
      );
      expect(afterTerm.every((c) => c.isInWeek(25)), isTrue);
      expect(afterTerm.every((c) => !c.isInWeek(26)), isTrue);
    });

    test('buildPresetCourses rejects ranges crossing midnight', () {
      expect(
        () => LiveTestingFixtureService.buildPresetCourses(
          now: DateTime(2026, 3, 23, 23, 58),
          targetWeek: 1,
          semesterWeekCount: 20,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'presets feed live selection but never enter the real timetable',
      () async {
        final provider = TimetableProvider(
          autoInitialize: false,
          enableLiveActivitySync: false,
        );
        await provider.initialize();
        final now = _testBaseNow();
        final presets = LiveTestingFixtureService.buildPresetCourses(
          now: now,
          targetWeek: provider.liveSelectionCalendarWeek,
          semesterWeekCount: provider.settings.semesterWeekCount,
        );
        provider.armLiveTestFixtureCourses(presets);
        expect(provider.hasLiveTestFixtureCourses, isTrue);

        // 真实课表与 UI/小组件用的课程路径都看不到预设课。
        expect(
          provider.courses.where(LiveTestingFixtureService.isPresetCourse),
          isEmpty,
        );
        expect(
          provider
              .getActiveCoursesForDay(now.weekday, week: 1)
              .where(LiveTestingFixtureService.isPresetCourse),
          isEmpty,
        );

        // 超级岛选课路径能选中预设课 A（课前态），且下节课指向 B。
        final selection = provider.getLiveActivityCourseSelection(
          now: now.add(const Duration(seconds: 30)),
          week: 1,
        );
        expect(
          selection?.currentCourse.id,
          LiveTestingFixtureService.presetCourseIdA,
        );
        expect(
          selection?.nextCourse?.id,
          LiveTestingFixtureService.presetCourseIdB,
        );

        // A 结束后 B 接棒（A: +1min..+4min，B: +5min..+8min）。
        final second = provider.getLiveActivityCourseSelection(
          now: now.add(const Duration(minutes: 5, seconds: 30)),
          week: 1,
        );
        expect(
          second?.currentCourse.id,
          LiveTestingFixtureService.presetCourseIdB,
        );
        provider.dispose();
      },
    );

    test('real course wins while active; preset takes over after it', () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      final now = _testBaseNow();
      // 自建时间方案：真实课窗口完全可控 = [floor(now), floor(now+2min)]，
      // 解析开始时间永远严格早于预设课 A（floor(now+1min)，必落在下一分钟）。
      final schemeStart = LiveTestingFixtureService.formatClock(now);
      final schemeEnd = LiveTestingFixtureService.formatClock(
        now.add(const Duration(minutes: 2)),
      );
      await provider.createTimeScheme(
        name: '自检排序测试方案',
        sections: [SectionTime(startTime: schemeStart, endTime: schemeEnd)],
        applyToActiveProfile: true,
      );
      await provider.addCourse(
        Course(
          id: 'real_section_1',
          name: '真实课',
          teacher: '真实教师',
          location: '真实教室',
          dayOfWeek: now.weekday,
          startSection: 1,
          endSection: 1,
          startTime: schemeStart,
          endTime: schemeEnd,
          color: '#4C6FFF',
          startWeek: 1,
          endWeek: 20,
        ),
      );

      final presets = LiveTestingFixtureService.buildPresetCourses(
        now: now,
        targetWeek: 1,
        semesterWeekCount: 20,
      );
      provider.armLiveTestFixtureCourses(presets);

      // 真实课窗口内（45s 处）：真实课排在预设课之前且阶段有效 → 胜出。
      expect(
        provider
            .getLiveActivityCourseSelection(
              now: now.add(const Duration(seconds: 45)),
              week: 1,
            )
            ?.currentCourse
            .id,
        'real_section_1',
      );
      // 真实课结束后（2min5s 处，方案节次已结束）：预设课 A 接管。
      expect(
        provider
            .getLiveActivityCourseSelection(
              now: now.add(const Duration(minutes: 2, seconds: 5)),
              week: 1,
            )
            ?.currentCourse
            .id,
        LiveTestingFixtureService.presetCourseIdA,
      );
      provider.dispose();
    });

    test('overlay disarms once every preset has finished', () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      final now = _testBaseNow();
      final presets = LiveTestingFixtureService.buildPresetCourses(
        now: now,
        targetWeek: 1,
        semesterWeekCount: 20,
      );
      provider.armLiveTestFixtureCourses(presets);

      // B 结束前：保持挂载。
      final lastEnd = _atClock(now, presets[1].endTime);
      expect(
        provider.disarmLiveTestFixtureCoursesIfFinished(
          lastEnd.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(provider.hasLiveTestFixtureCourses, isTrue);

      // 全部结束后：摘除，选课回到空。
      expect(
        provider.disarmLiveTestFixtureCoursesIfFinished(
          lastEnd.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(provider.hasLiveTestFixtureCourses, isFalse);
      expect(
        provider.getLiveActivityCourseSelection(
          now: lastEnd.add(const Duration(minutes: 1)),
          week: 1,
        ),
        isNull,
      );

      // 空批次不改变挂载状态。
      provider.armLiveTestFixtureCourses(const []);
      expect(provider.hasLiveTestFixtureCourses, isFalse);
      provider.dispose();
    });
  });
}
