import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/domain/live_activity_logic.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/storage_service.dart';

final _liveSemesterStart2026 = DateTime(2026, 2, 23);

Future<TimetableProvider> _createLiveActivityTestProvider({
  bool enableLiveActivitySync = false,
  TestMiuiLiveActivitiesService? liveActivitiesService,
  TimetableSettings Function(TimetableSettings settings)? configureSettings,
}) async {
  final provider = TimetableProvider(
    autoInitialize: false,
    enableLiveActivitySync: enableLiveActivitySync,
    liveActivitiesService: liveActivitiesService,
  );
  await provider.initialize();
  final baseSettings = provider.settings.copyWith(
    semesterWeekCount: 20,
    semesterStartDate: _liveSemesterStart2026,
    liveEnableBeforeClass: true,
    liveEnableDuringClass: true,
    liveEnableBeforeEnd: true,
    liveShowBeforeClassMinutes: 20,
    liveClassReminderStartMinutes: 0,
    enableHolidayMarking: true,
  );
  await provider.updateTimetableSettings(
    configureSettings?.call(baseSettings) ?? baseSettings,
  );
  return provider;
}

Course _liveMondayCourse({
  required String id,
  required String name,
  int startWeek = 1,
  int endWeek = 16,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  List<int>? customWeeks,
  List<int>? suspendedWeeks,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: startWeek,
    endWeek: endWeek,
    isOddWeek: isOddWeek,
    isEvenWeek: isEvenWeek,
    customWeeks: customWeeks,
    suspendedWeeks: suspendedWeeks,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleLiveActivityStartup(
    TestMiuiLiveActivitiesService liveService,
  ) async {
    await pumpEventQueue();
    liveService.stopLiveUpdateCallCount = 0;
    liveService.startLiveUpdateCallCount = 0;
    liveService.syncScheduleSnapshotCallCount = 0;
  }

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test('switching active profile updates exposed timetable state', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final spring = await provider.createProfile(name: '春季课表');
    await provider.addCourse(
      Course(
        id: 'spring-course',
        name: '高数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final autumn = await provider.createProfile(name: '秋季课表');
    await provider.switchProfile(autumn.id);
    await provider.addCourse(
      Course(
        id: 'autumn-course',
        name: '线代',
        teacher: '王老师',
        location: 'C202',
        dayOfWeek: 3,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );
    await provider.setCurrentWeek(8);

    await provider.switchProfile(spring.id);

    expect(provider.activeProfile?.name, '春季课表');
    expect(provider.courses.single.name, '高数');
    expect(provider.currentWeek, 1);

    await provider.switchProfile(autumn.id);
    expect(provider.courses.single.name, '线代');
    expect(provider.currentWeek, 8);
  });

  test(
    'setCurrentWeek notifies listeners before persistence completes',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      var notificationCount = 0;
      provider.addListener(() {
        notificationCount += 1;
      });

      final future = provider.setCurrentWeek(6);

      expect(provider.currentWeek, 6);
      expect(provider.activeProfile?.currentWeek, 6);
      expect(notificationCount, 1);

      await future;
    },
  );

  test(
    'clearing active profile removes only courses and preserves settings',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        TimetableSettings.defaults().copyWith(
          semesterWeekCount: 24,
          semesterStartDate: DateTime(2026, 2, 23),
        ),
      );
      await provider.setCurrentWeek(6);
      await provider.addCourse(
        Course(
          id: 'course-1',
          name: '数据库',
          teacher: '李老师',
          location: 'B301',
          dayOfWeek: 2,
          startSection: 3,
          endSection: 4,
          startTime: '10:10',
          endTime: '11:50',
        ),
      );

      final cleared = await provider.clearActiveProfileCourses();

      expect(cleared, isTrue);
      expect(provider.courses, isEmpty);
      expect(provider.currentWeek, 6);
      expect(provider.settings.semesterWeekCount, 24);
      expect(provider.settings.semesterStartDate, DateTime(2026, 2, 23));
      expect(provider.activeProfile?.name, '默认课表');
    },
  );

  test('adding a course clamps weeks to the semester week count', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      TimetableSettings.defaults().copyWith(semesterWeekCount: 12),
    );

    await provider.addCourse(
      Course(
        id: 'course-week-range',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    expect(provider.courses.single.startWeek, 1);
    expect(provider.courses.single.endWeek, 12);
  });

  test(
    'importing backup clamps current week to imported semester week count',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final content = provider.dataTransferService.buildBackupJson(
        profileName: '导入课表',
        courses: const [],
        settings: TimetableSettings.defaults().copyWith(semesterWeekCount: 14),
        currentWeek: 20,
      );

      final result = await provider.importAppDataBackup(content);

      expect(result, isNull);
      expect(provider.currentWeek, 14);
      expect(provider.activeProfile?.currentWeek, 14);
    },
  );

  test('course conflict map only marks actual overlapping weeks', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.addCourse(
      Course(
        id: 'odd-course',
        name: '大学英语',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        isOddWeek: true,
      ),
    );
    await provider.addCourse(
      Course(
        id: 'even-course',
        name: '形势与政策',
        teacher: '李老师',
        location: 'A102',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        isEvenWeek: true,
      ),
    );
    await provider.addCourse(
      Course(
        id: 'all-course',
        name: '高等数学',
        teacher: '王老师',
        location: 'B201',
        dayOfWeek: 1,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:35',
      ),
    );

    final conflictMap = provider.courseConflictMap;

    expect(conflictMap.containsKey('odd-course'), isTrue);
    expect(conflictMap.containsKey('all-course'), isTrue);
    expect(conflictMap.containsKey('even-course'), isTrue);
    expect(conflictMap['odd-course']!.map((course) => course.id), [
      'all-course',
    ]);
    expect(conflictMap['even-course']!.map((course) => course.id), [
      'all-course',
    ]);
    expect(conflictMap['all-course']!.map((course) => course.id).toSet(), {
      'odd-course',
      'even-course',
    });
    expect(
      provider.courseConflictMapForWeek(1).containsKey('odd-course'),
      isTrue,
    );
    expect(
      provider.courseConflictMapForWeek(2).containsKey('even-course'),
      isTrue,
    );
    expect(
      provider.courseConflictMapForWeek(1).containsKey('even-course'),
      isFalse,
    );
    expect(
      provider.courseConflictMapForWeek(2).containsKey('odd-course'),
      isFalse,
    );
  });

  test('suspended week is not treated as course conflict', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.addCourse(
      Course(
        id: 'course-a',
        name: '线性代数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        suspendedWeeks: [1],
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-b',
        name: '大学物理',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    // Week 1: A is suspended → no actual overlap week → no conflict map entry.
    expect(
      provider.courseConflictMapForWeek(1).containsKey('course-a'),
      isFalse,
    );
    expect(
      provider.courseConflictMapForWeek(1).containsKey('course-b'),
      isFalse,
    );
    // Week 2: both active and same slot → conflict.
    expect(
      provider.courseConflictMapForWeek(2).containsKey('course-a'),
      isTrue,
    );
    expect(
      provider.courseConflictMapForWeek(2).containsKey('course-b'),
      isTrue,
    );
  });

  test(
    'same slot on different non-overlapping weeks is not conflict',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.addCourse(
        Course(
          id: 'course-first-half',
          name: '大学体育',
          teacher: '张老师',
          location: '操场',
          dayOfWeek: 3,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
          endWeek: 8,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-second-half',
          name: '大学体育',
          teacher: '李老师',
          location: '体育馆',
          dayOfWeek: 3,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
          startWeek: 9,
        ),
      );

      expect(provider.courseConflictMap, isEmpty);
      expect(provider.courseConflictMapForWeek(5), isEmpty);
      expect(provider.courseConflictMapForWeek(12), isEmpty);
    },
  );

  test('applying a time scheme updates active profile sections', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-time-sync',
        name: '离散数学',
        teacher: '赵老师',
        location: 'C101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final scheme = await provider.createTimeScheme(
      name: '夏季作息',
      sections: const [
        SectionTime(startTime: '07:50', endTime: '08:35'),
        SectionTime(startTime: '08:45', endTime: '09:30'),
      ],
    );

    await provider.applyTimeScheme(scheme.id);

    expect(provider.activeTimeScheme?.name, '夏季作息');
    expect(provider.settings.activeTimeSchemeId, scheme.id);
    expect(provider.settings.sectionCount, 2);
    expect(provider.settings.sectionAt(1).displayText, '07:50-08:35');
    expect(provider.courses.single.startTime, '07:50');
    expect(provider.courses.single.endTime, '09:30');
  });

  test(
    'applying a shorter time scheme is rejected when courses exceed it',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final longScheme = await provider.createTimeScheme(
        name: '24时段',
        sections: List<SectionTime>.generate(
          12,
          (index) => SectionTime(
            startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
            endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
          ),
        ),
      );
      final applyLong = await provider.applyTimeScheme(longScheme.id);
      expect(applyLong, isNull);

      await provider.addCourse(
        Course(
          id: 'late-slot',
          name: '晚课',
          teacher: '王老师',
          location: 'D101',
          dayOfWeek: 1,
          startSection: 11,
          endSection: 12,
          startTime: '18:00',
          endTime: '19:45',
        ),
      );

      final shortScheme = await provider.createTimeScheme(
        name: '10节作息',
        sections: List<SectionTime>.generate(
          10,
          (index) => SectionTime(
            startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
            endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
          ),
        ),
      );

      final applyShort = await provider.applyTimeScheme(shortScheme.id);
      expect(applyShort, isNotNull);
      expect(applyShort, contains('section_count_below_usage'));
      expect(provider.settings.activeTimeSchemeId, longScheme.id);
      expect(provider.settings.sectionCount, 12);
    },
  );

  test('updating a time scheme syncs profiles using it', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final scheme = await provider.createTimeScheme(
      name: '本校作息',
      sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
      applyToActiveProfile: true,
    );

    final message = await provider.updateTimeScheme(
      schemeId: scheme.id,
      name: '本校夏季作息',
      sections: const [
        SectionTime(startTime: '07:40', endTime: '08:25'),
        SectionTime(startTime: '08:35', endTime: '09:20'),
      ],
    );

    expect(message, isNull);
    expect(provider.activeTimeScheme?.name, '本校夏季作息');
    expect(provider.settings.sectionCount, 2);
    expect(provider.settings.sectionAt(2).displayText, '08:35-09:20');
  });

  test('updating a time scheme rejects cross-midnight sections', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final scheme = await provider.createTimeScheme(
      name: '夜间作息',
      sections: const [SectionTime(startTime: '20:00', endTime: '20:45')],
      applyToActiveProfile: true,
    );

    final message = await provider.updateTimeScheme(
      schemeId: scheme.id,
      name: '夜间作息',
      sections: const [SectionTime(startTime: '23:30', endTime: '00:15')],
    );

    expect(message, contains('section_end_must_after_start'));
    expect(provider.settings.sectionAt(1).displayText, '20:00-20:45');
  });

  test('course can override active time scheme', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final activeSchemeId = provider.settings.activeTimeSchemeId!;
    final overrideScheme = await provider.createTimeScheme(
      name: '大二下午作息',
      sections: [
        ...provider.settings.sections.take(4),
        const SectionTime(startTime: '14:00', endTime: '14:45'),
        const SectionTime(startTime: '14:55', endTime: '15:40'),
      ],
    );

    await provider.addCourse(
      Course(
        id: 'override-course',
        name: '大学物理',
        teacher: '陈老师',
        location: '理科楼 203',
        dayOfWeek: 2,
        startSection: 5,
        endSection: 6,
        startTime: '14:30',
        endTime: '16:05',
        timeSchemeIdOverride: overrideScheme.id,
      ),
    );

    expect(provider.courses.single.timeSchemeIdOverride, overrideScheme.id);
    expect(provider.courses.single.startTime, '14:00');
    expect(provider.courses.single.endTime, '15:40');

    final anotherScheme = await provider.createTimeScheme(
      name: '夏季主作息',
      sections: [
        ...provider.settings.sections.take(4),
        const SectionTime(startTime: '14:30', endTime: '15:15'),
        const SectionTime(startTime: '15:25', endTime: '16:10'),
      ],
    );

    await provider.applyTimeScheme(anotherScheme.id);

    expect(provider.settings.activeTimeSchemeId, anotherScheme.id);
    expect(provider.courses.single.timeSchemeIdOverride, overrideScheme.id);
    expect(provider.courses.single.startTime, '14:00');
    expect(provider.courses.single.endTime, '15:40');
    expect(
      provider.maxUsedSectionForTimeScheme(activeSchemeId),
      greaterThanOrEqualTo(0),
    );
  });

  test(
    'apply location time rules returns matched courses to automatic routing',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final locationScheme = await provider.createTimeScheme(
        name: '教学楼A作息',
        sections: [
          const SectionTime(startTime: '08:30', endTime: '09:15'),
          const SectionTime(startTime: '09:25', endTime: '10:10'),
          ...provider.settings.sections.skip(2),
        ],
      );
      await provider.createLocationTimeGroup(
        name: 'A楼',
        timeSchemeId: locationScheme.id,
        keywords: const [
          LocationKeyword(
            pattern: '测试教室',
            mode: LocationKeywordMatchMode.contains,
          ),
        ],
      );

      await provider.addCourse(
        Course(
          id: 'loc-apply-course',
          name: '测试 第1节',
          teacher: '测试教师',
          location: '测试教室 01',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 1,
          startTime: '08:00',
          endTime: '08:45',
        ),
      );

      expect(provider.courses.single.timeSchemeIdOverride, isNull);

      final manualScheme = await provider.createTimeScheme(
        name: '手动模板',
        sections: [
          const SectionTime(startTime: '07:30', endTime: '08:15'),
          const SectionTime(startTime: '08:25', endTime: '09:10'),
          ...provider.settings.sections.skip(2),
        ],
      );
      await provider.updateCourse(
        provider.courses.single.copyWith(timeSchemeIdOverride: manualScheme.id),
      );
      expect(provider.courses.single.timeSchemeIdOverride, manualScheme.id);

      final stats = await provider.applyLocationTimeRulesToActiveProfile();

      expect(stats.matchedCount, 1);
      expect(stats.updatedCount, 1);
      expect(provider.courses.single.timeSchemeIdOverride, isNull);
      expect(provider.courses.single.startTime, '08:30');
      expect(provider.courses.single.endTime, '09:15');

      // A later rematch follows the updated location rule without creating a
      // permanent course-level override.
      final otherScheme = await provider.createTimeScheme(
        name: '教学楼A作息-改',
        sections: [
          const SectionTime(startTime: '08:40', endTime: '09:25'),
          const SectionTime(startTime: '09:35', endTime: '10:20'),
          ...provider.settings.sections.skip(2),
        ],
      );
      final group = provider.locationTimeGroups.single;
      await provider.updateLocationTimeGroup(
        group.copyWith(timeSchemeId: otherScheme.id),
      );

      final statsAgain = await provider.applyLocationTimeRulesToActiveProfile();
      expect(statsAgain.matchedCount, 1);
      expect(statsAgain.updatedCount, 0);
      expect(provider.courses.single.timeSchemeIdOverride, isNull);
      expect(provider.courses.single.startTime, '08:40');
      expect(provider.courses.single.endTime, '09:25');
    },
  );

  test(
    'apply location rules rejects overflow without pinning or clock rewrite',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final shortScheme = await provider.createTimeScheme(
        name: '仅4节模板',
        sections: [
          for (var index = 0; index < 4; index++)
            SectionTime(
              startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
              endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
            ),
        ],
      );
      await provider.createLocationTimeGroup(
        name: '测试楼',
        timeSchemeId: shortScheme.id,
        keywords: const [
          LocationKeyword(
            pattern: '测试教室',
            mode: LocationKeywordMatchMode.contains,
          ),
        ],
      );

      await provider.addCourse(
        Course(
          id: 'overflow-course',
          name: '测试 第8节',
          teacher: '测试教师',
          location: '测试教室 08',
          dayOfWeek: 1,
          startSection: 8,
          endSection: 8,
          startTime: '15:00',
          endTime: '15:45',
        ),
      );

      final stats = await provider.applyLocationTimeRulesToActiveProfile();

      // Location may hit the group, but apply is fully rejected → not matched.
      expect(stats.matchedCount, 0);
      expect(stats.sectionOverflowCount, 1);
      expect(stats.updatedCount, 0);
      expect(provider.courses.single.timeSchemeIdOverride, isNull);
      expect(provider.courses.single.startTime, '15:00');
      expect(provider.courses.single.endTime, '15:45');
    },
  );

  test(
    'deleting time scheme referenced by course override is rejected',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final overrideScheme = await provider.createTimeScheme(
        name: '实验楼作息',
        sections: [...provider.settings.sections.take(6)],
      );

      await provider.addCourse(
        Course(
          id: 'scheme-locked-course',
          name: '物理实验',
          teacher: '周老师',
          location: '实验楼 101',
          dayOfWeek: 4,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
          timeSchemeIdOverride: overrideScheme.id,
        ),
      );

      final deleted = await provider.deleteTimeScheme(overrideScheme.id);

      expect(deleted, isFalse);
      expect(
        provider.timeSchemes.any((scheme) => scheme.id == overrideScheme.id),
        isTrue,
      );
    },
  );

  test(
    'updating an override time scheme refreshes referencing courses',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final overrideScheme = await provider.createTimeScheme(
        name: '实验楼作息',
        sections: [
          ...provider.settings.sections.take(4),
          const SectionTime(startTime: '14:00', endTime: '14:45'),
          const SectionTime(startTime: '14:55', endTime: '15:40'),
        ],
      );

      await provider.addCourse(
        Course(
          id: 'override-refresh-course',
          name: '大学物理实验',
          teacher: '王老师',
          location: '实验楼 105',
          dayOfWeek: 4,
          startSection: 5,
          endSection: 6,
          startTime: '14:30',
          endTime: '16:05',
          timeSchemeIdOverride: overrideScheme.id,
        ),
      );

      expect(provider.courses.single.startTime, '14:00');
      expect(provider.courses.single.endTime, '15:40');

      final message = await provider.updateTimeScheme(
        schemeId: overrideScheme.id,
        name: '实验楼作息',
        sections: [
          ...provider.settings.sections.take(4),
          const SectionTime(startTime: '14:10', endTime: '14:55'),
          const SectionTime(startTime: '15:05', endTime: '15:50'),
        ],
      );

      expect(message, isNull);
      expect(provider.courses.single.timeSchemeIdOverride, overrideScheme.id);
      expect(provider.courses.single.startTime, '14:10');
      expect(provider.courses.single.endTime, '15:50');
    },
  );

  test(
    'live activity respects reminder start minutes after class starts',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _liveSemesterStart2026,
          liveEnableBeforeClass: false,
          liveEnableDuringClass: true,
          liveEnableBeforeEnd: true,
          liveClassReminderStartMinutes: 5,
          liveShowDuringClassNotification: false,
        ),
      );

      final now = DateTime(2026, 3, 25, 14, 5);
      await provider.addCourse(
        Course(
          id: 'live-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
        ),
      );

      final earlySelection = provider.getLiveActivityCourseSelection(now: now);
      final lateSelection = provider.getLiveActivityCourseSelection(
        now: DateTime(2026, 3, 25, 15, 36),
      );

      expect(earlySelection, isNull);
      expect(lateSelection?.stage, LiveActivityStage.beforeEnd);
    },
  );

  test(
    'live activity can show status bar stage before end reminder when not immediate',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _liveSemesterStart2026,
          liveEnableBeforeClass: false,
          liveEnableDuringClass: true,
          liveEnableBeforeEnd: true,
          liveClassReminderStartMinutes: 5,
          liveShowDuringClassNotification: true,
        ),
      );

      final now = DateTime(2026, 3, 25, 14, 5);
      await provider.addCourse(
        Course(
          id: 'live-course-status-bar',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: now.weekday,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
        ),
      );

      final earlySelection = provider.getLiveActivityCourseSelection(now: now);
      final lateSelection = provider.getLiveActivityCourseSelection(
        now: DateTime(2026, 3, 25, 15, 36),
      );

      expect(earlySelection?.stage, LiveActivityStage.duringClassStatusBar);
      expect(lateSelection?.stage, LiveActivityStage.beforeEnd);
    },
  );

  test(
    'live activity starts during class immediately when reminder start is 0',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _liveSemesterStart2026,
          liveEnableBeforeClass: false,
          liveEnableDuringClass: true,
          liveEnableBeforeEnd: true,
          liveClassReminderStartMinutes: 0,
        ),
      );

      final now = DateTime(2026, 3, 25, 14, 5);
      await provider.addCourse(
        Course(
          id: 'live-course-immediate',
          name: '线性代数',
          teacher: '李老师',
          location: 'B201',
          dayOfWeek: now.weekday,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
        ),
      );

      final selection = provider.getLiveActivityCourseSelection(now: now);

      expect(selection?.stage, LiveActivityStage.duringClass);
    },
  );

  test('before class reminder waits until previous course ends', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        liveEnableBeforeClass: true,
        liveEnableDuringClass: false,
        liveEnableBeforeEnd: false,
        liveShowBeforeClassMinutes: 30,
      ),
    );

    await provider.addCourse(
      Course(
        id: 'course-12',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: DateTime(2026, 3, 25).weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-34',
        name: '大学英语',
        teacher: '李老师',
        location: 'B201',
        dayOfWeek: DateTime(2026, 3, 25).weekday,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    );

    final earlySelection = provider.getLiveActivityCourseSelection(
      now: DateTime(2026, 3, 25, 9, 35),
    );
    final afterPreviousCourseEnds = provider.getLiveActivityCourseSelection(
      now: DateTime(2026, 3, 25, 9, 40),
    );

    expect(earlySelection, isNull);
    expect(afterPreviousCourseEnds?.stage, LiveActivityStage.beforeClass);
    expect(afterPreviousCourseEnds?.currentCourse.name, '大学英语');
  });

  test('time correction can shift before class reminder by seconds', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        liveEnableBeforeClass: true,
        liveEnableDuringClass: false,
        liveEnableBeforeEnd: false,
        liveShowBeforeClassMinutes: 1,
        liveTimeCorrectionSeconds: -5,
      ),
    );

    await provider.addCourse(
      Course(
        id: 'course-time-correction',
        name: '计算机网络',
        teacher: '王老师',
        location: 'C301',
        dayOfWeek: DateTime(2026, 3, 25).weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final beforeWindow = provider.getLiveActivityCourseSelection(
      now: DateTime(2026, 3, 25, 7, 58, 54),
    );
    final shiftedWindow = provider.getLiveActivityCourseSelection(
      now: DateTime(2026, 3, 25, 7, 58, 56),
    );

    expect(beforeWindow, isNull);
    expect(shiftedWindow?.stage, LiveActivityStage.beforeClass);
    expect(shiftedWindow?.currentCourse.name, '计算机网络');
  });

  test(
    'updating non-section settings does not trigger section capacity guard',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final extendedScheme = await provider.createTimeScheme(
        name: '晚课扩展作息',
        sections: List.generate(
          13,
          (index) => SectionTime(
            startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
            endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
          ),
        ),
      );

      await provider.addCourse(
        Course(
          id: 'high-section-course',
          name: '选修课',
          teacher: '刘老师',
          location: 'D401',
          dayOfWeek: 5,
          startSection: 13,
          endSection: 13,
          startTime: '20:00',
          endTime: '20:45',
          timeSchemeIdOverride: extendedScheme.id,
        ),
      );

      final message = await provider.updateTimetableSettings(
        provider.settings.copyWith(
          liveShowCourseName: !provider.settings.liveShowCourseName,
        ),
      );

      expect(message, isNull);
      expect(provider.settings.liveShowCourseName, isFalse);
    },
  );

  test(
    'ensuring import section capacity duplicates shared active scheme',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      final originalProfileId = provider.activeProfile!.id;
      final originalSchemeId = provider.activeTimeScheme!.id;
      final originalSchemeName = provider.activeTimeScheme!.name;

      await provider.createProfile(name: '第二课表');
      expect(provider.activeTimeScheme?.id, originalSchemeId);

      await provider.switchProfile(originalProfileId);
      final message = await provider.ensureSectionCapacityForImport(11);

      expect(message, isNull);
      expect(provider.settings.sectionCount, 11);
      expect(provider.activeTimeScheme?.id, isNot(originalSchemeId));
      expect(provider.activeTimeScheme?.name, '$originalSchemeName（导入补齐）');

      final secondProfile = provider.profiles.firstWhere(
        (profile) => profile.name == '第二课表',
      );
      expect(secondProfile.settings.activeTimeSchemeId, originalSchemeId);
      expect(secondProfile.settings.sectionCount, 10);
    },
  );

  test('editing one course syncs shared fields to same-name courses', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.addCourse(
      Course(
        id: 'course-a',
        name: '机械设计',
        shortName: '机设',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-b',
        name: '机械设计',
        teacher: '张老师',
        location: 'B202',
        dayOfWeek: 3,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );

    await provider.updateCourse(
      Course(
        id: 'course-a',
        name: '机械设计基础',
        shortName: '机设基',
        teacher: '李老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        courseNature: CourseNature.elective,
        description: '课程简介',
        color: '#FF9800',
      ),
      previousSharedName: '机械设计',
    );

    final syncedCourses = provider.courses
        .where((course) => course.name == '机械设计基础')
        .toList();

    expect(syncedCourses, hasLength(2));
    // Teacher is per-schedule-entry: editing one slot must not rewrite the
    // sibling's teacher (course-b keeps 张老师).
    expect(syncedCourses.map((course) => course.teacher).toSet(), {
      '李老师',
      '张老师',
    });
    expect(syncedCourses.map((course) => course.shortName).toSet(), {'机设基'});
    expect(syncedCourses.map((course) => course.courseNature).toSet(), {
      CourseNature.elective,
    });
    expect(syncedCourses.map((course) => course.description).toSet(), {'课程简介'});
    expect(syncedCourses.map((course) => course.location).toSet(), {
      'A101',
      'B202',
    });
  });

  test(
    'adding same-name course inherits shared description from existing entry',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.addCourse(
        Course(
          id: 'course-range',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          endWeek: 20,
          description: '带计算器',
        ),
      );

      // New single-week schedule entry for the same course name.
      await provider.addCourse(
        Course(
          id: 'course-single-week',
          name: '高等数学',
          teacher: '张老师',
          location: 'B202',
          dayOfWeek: 3,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          startWeek: 8,
          endWeek: 8,
        ),
      );

      final sameNameCourses = provider.courses
          .where((course) => course.name == '高等数学')
          .toList();
      expect(sameNameCourses, hasLength(2));
      expect(sameNameCourses.map((course) => course.description).toSet(), {
        '带计算器',
      });

      final singleWeek = sameNameCourses.singleWhere(
        (course) => course.id == 'course-single-week',
      );
      expect(singleWeek.description, '带计算器');
      expect(singleWeek.location, 'B202');
    },
  );

  test(
    'adding same-name course promotes legacy per-entry note into description',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      // Legacy data: intro only lived on [Course.note], not description.
      await provider.addCourse(
        Course(
          id: 'course-legacy',
          name: '线性代数',
          teacher: '李老师',
          location: 'C101',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          note: '旧版整节课备注',
        ),
      );

      final legacy = provider.courses.singleWhere(
        (course) => course.id == 'course-legacy',
      );
      // Normalize promotes note into shared description on write.
      expect(legacy.description, '旧版整节课备注');

      await provider.addCourse(
        Course(
          id: 'course-new-slot',
          name: '线性代数',
          teacher: '李老师',
          location: 'D303',
          dayOfWeek: 4,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
          startWeek: 5,
          endWeek: 5,
        ),
      );

      final sameNameCourses = provider.courses
          .where((course) => course.name == '线性代数')
          .toList();
      expect(sameNameCourses, hasLength(2));
      expect(sameNameCourses.map((course) => course.description).toSet(), {
        '旧版整节课备注',
      });
    },
  );

  test(
    'updating description on one course syncs to all same-name schedule entries',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '大学英语',
          teacher: '王老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          description: '旧简介',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-b',
          name: '大学英语',
          teacher: '王老师',
          location: 'B202',
          dayOfWeek: 3,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
          startWeek: 10,
          endWeek: 10,
        ),
      );

      final originalA = provider.courses.singleWhere(
        (course) => course.id == 'course-a',
      );
      await provider.updateCourse(
        originalA.copyWith(description: '新课程简介', note: null),
      );

      final sameNameCourses = provider.courses
          .where((course) => course.name == '大学英语')
          .toList();
      expect(sameNameCourses, hasLength(2));
      expect(sameNameCourses.map((course) => course.description).toSet(), {
        '新课程简介',
      });
    },
  );

  test(
    'adding schedule entries keeps each entry teacher instead of using first',
    () async {
      // Mirrors the App create flow (addCourse is called once per entry).
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.addCourse(
        Course(
          id: 'slot-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'slot-2',
          name: '高等数学',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 3,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      );

      final byId = {
        for (final course in provider.courses) course.id: course,
      };
      expect(provider.courses, hasLength(2));
      expect(byId['slot-1']!.teacher, '张老师');
      expect(byId['slot-2']!.teacher, '李老师');
    },
  );

  test('updateCourseGroup preserves each slot teacher', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.addCourse(
      Course(
        id: 'old-slot',
        name: '大学英语',
        teacher: '王老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    await provider.updateCourseGroup('大学英语', [
      Course(
        id: 'slot-a',
        name: '大学英语',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
      Course(
        id: 'slot-b',
        name: '大学英语',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 3,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    ]);

    final byId = {
      for (final course in provider.courses) course.id: course,
    };
    expect(provider.courses, hasLength(2));
    expect(byId['slot-a']!.teacher, '张老师');
    expect(byId['slot-b']!.teacher, '李老师');
  });

  test('addCourseGroup preserves every slot teacher', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.addCourseGroup([
      Course(
        id: 'slot-a',
        name: '线性代数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
      Course(
        id: 'slot-b',
        name: '线性代数',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 3,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    ]);

    final byId = {
      for (final course in provider.courses) course.id: course,
    };
    expect(provider.courses, hasLength(2));
    expect(byId['slot-a']!.teacher, '张老师');
    expect(byId['slot-b']!.teacher, '李老师');
  });

  test(
    'clearing short name falls back to course name for live island payload',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          liveEnableBeforeClass: true,
          liveEnableDuringClass: false,
          liveEnableBeforeEnd: false,
          liveShowBeforeClassMinutes: 30,
        ),
      );

      final day = DateTime(2026, 3, 25);
      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '离散数学',
          shortName: '离散',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: day.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-b',
          name: '离散数学',
          shortName: '离散',
          teacher: '张老师',
          location: 'B202',
          dayOfWeek: 4,
          startSection: 5,
          endSection: 6,
          startTime: '14:00',
          endTime: '15:40',
        ),
      );

      await provider.updateCourse(
        Course(
          id: 'course-a',
          name: '离散数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: day.weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
        previousSharedName: '离散数学',
      );

      final syncedCourses = provider.courses
          .where((course) => course.name == '离散数学')
          .toList();
      final selection = provider.getLiveActivityCourseSelection(
        now: DateTime(2026, 3, 25, 7, 45),
      );

      expect(syncedCourses, hasLength(2));
      expect(syncedCourses.every((course) => course.shortName == null), isTrue);
      expect(provider.resolveCourseShortName(syncedCourses.first), isNull);
      expect(selection?.currentCourse.name, '离散数学');
      expect(selection?.currentCourse.shortName, isNull);
    },
  );

  test(
    'home widget snapshot highlights the next course before class',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(semesterStartDate: DateTime(2026, 3, 23)),
      );
      await provider.addCourse(
        Course(
          id: 'course-next',
          name: '操作系统',
          shortName: '操作系统',
          teacher: '张老师',
          location: 'A203',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );

      final snapshot = provider.buildHomeWidgetSnapshot(
        now: DateTime(2026, 3, 24, 7, 30),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.state, HomeWidgetSnapshotState.upcoming);
      expect(snapshot.currentWeek, 1);
      expect(snapshot.highlightedCourse?.name, '操作系统');
      expect(snapshot.nextCourse?.name, '操作系统');
      expect(snapshot.todayCourses, hasLength(1));
    },
  );

  test('home widget snapshot returns no course state on empty day', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: DateTime(2026, 3, 23)),
    );
    await provider.addCourse(
      Course(
        id: 'course-mon',
        name: '编译原理',
        teacher: '李老师',
        location: 'B104',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    final snapshot = provider.buildHomeWidgetSnapshot(
      now: DateTime(2026, 3, 24, 10),
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.state, HomeWidgetSnapshotState.noCourse);
    expect(snapshot.highlightedCourse, isNull);
    expect(snapshot.nextCourse, isNull);
    expect(snapshot.todayCourses, isEmpty);
  });

  test(
    'home widget snapshot uses selected date week monday as anchor',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(semesterStartDate: DateTime(2026, 3, 25)),
      );

      final snapshot = provider.buildHomeWidgetSnapshot(
        now: DateTime(2026, 3, 30, 8),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentWeek, 2);
    },
  );

  test(
    'rescheduling a single occurrence splits the original course weeks',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.addCourse(
        Course(
          id: 'course-reschedule',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          endWeek: 4,
        ),
      );

      final changed = await provider.rescheduleCourseOccurrence(
        courseId: 'course-reschedule',
        sourceWeek: 2,
        targetWeek: 6,
        targetDayOfWeek: 3,
        targetStartSection: 3,
        targetEndSection: 4,
        targetLocation: 'B201',
      );

      expect(changed, isTrue);
      expect(provider.courses, hasLength(2));

      final remainingCourse = provider.courses.firstWhere(
        (course) => course.id == 'course-reschedule',
      );
      final movedCourse = provider.courses.firstWhere(
        (course) => course.id != 'course-reschedule',
      );

      expect(remainingCourse.activeWeeks, [1, 3, 4]);
      expect(remainingCourse.dayOfWeek, 1);
      expect(remainingCourse.startSection, 1);
      expect(remainingCourse.location, 'A101');

      expect(movedCourse.activeWeeks, [6]);
      expect(movedCourse.dayOfWeek, 3);
      expect(movedCourse.startSection, 3);
      expect(movedCourse.endSection, 4);
      expect(movedCourse.location, 'B201');
    },
  );

  test(
    'deleting a single occurrence keeps the remaining course weeks',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.addCourse(
        Course(
          id: 'course-delete-occurrence',
          name: '大学英语',
          teacher: '李老师',
          location: 'A205',
          dayOfWeek: 2,
          startSection: 3,
          endSection: 4,
          startTime: '10:10',
          endTime: '11:50',
          endWeek: 4,
        ),
      );

      final changed = await provider.deleteCourseOccurrence(
        courseId: 'course-delete-occurrence',
        sourceWeek: 2,
      );

      expect(changed, isTrue);
      expect(provider.courses, hasLength(1));
      expect(provider.courses.single.activeWeeks, [1, 3, 4]);
      expect(provider.courses.single.name, '大学英语');
      expect(provider.courses.single.location, 'A205');
    },
  );

  test(
    'import parsed courses expands semester week count when needed',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(semesterWeekCount: 16),
      );

      await provider.importParsedCourses(
        [
          Course(
            id: 'imported-course',
            name: '机械原理',
            teacher: '王老师',
            location: 'A301',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
            startWeek: 3,
            endWeek: 18,
          ),
        ],
        replaceExisting: true,
        source: 'ai',
      );

      expect(provider.settings.semesterWeekCount, 18);
    },
  );

  test('import parsed courses accepts spreadsheet source', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final count = await provider.importParsedCourses(
      [
        Course(
          id: 'sheet-course',
          name: '表格导入课',
          teacher: '赵老师',
          location: 'D101',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          customWeeks: const [1, 2, 3, 4],
        ),
      ],
      replaceExisting: true,
      source: 'spreadsheet',
    );

    expect(count, 1);
    expect(provider.courses, hasLength(1));
    expect(provider.courses.single.name, '表格导入课');
  });

  test(
    'import parsed courses updates matching same-day course while keeping local metadata',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.addCourse(
        Course(
          id: 'course-a',
          name: '高等数学',
          shortName: '高数',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 3,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          color: '#FF0000',
          customWeeks: const [1, 2, 3, 4, 5, 6],
          note: '本地备注',
        ),
      );
      await provider.addCourse(
        Course(
          id: 'course-stale',
          name: '线性代数',
          teacher: '李老师',
          location: 'C303',
          dayOfWeek: 5,
          startSection: 3,
          endSection: 4,
          startTime: '14:00',
          endTime: '15:40',
          customWeeks: const [1, 2, 3, 4],
        ),
      );

      final updatedCount = await provider.importParsedCourses(
        [
          Course(
            id: 'imported-a',
            name: '高等数学',
            teacher: '张老师',
            location: 'B202',
            dayOfWeek: 3,
            startSection: 3,
            endSection: 4,
            startTime: '10:00',
            endTime: '11:40',
            customWeeks: const [1, 2, 3, 4, 5, 6],
          ),
        ],
        replaceExisting: false,
        source: 'ai',
      );

      expect(updatedCount, 1);
      expect(provider.courses, hasLength(2));
      final updatedCourse = provider.courses.singleWhere(
        (course) => course.id == 'course-a',
      );
      expect(updatedCourse.name, '高等数学');
      expect(updatedCourse.dayOfWeek, 3);
      expect(updatedCourse.startSection, 3);
      expect(updatedCourse.endSection, 4);
      expect(updatedCourse.location, 'B202');
      expect(updatedCourse.shortName, '高数');
      expect(updatedCourse.color, '#FF0000');
      expect(updatedCourse.note, '本地备注');
      expect(
        provider.courses.any((course) => course.id == 'course-stale'),
        isTrue,
      );
    },
  );

  test('live activity returns null when course weeks have passed', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    // 设置学期起始日期和总周数，使周次计算可以基于日期进行
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterWeekCount: 20,
        semesterStartDate: DateTime(2026, 2, 23), // 第1周周一
        liveEnableBeforeClass: true,
        liveEnableDuringClass: true,
        liveEnableBeforeEnd: true,
      ),
    );
    await provider.setCurrentWeek(1);

    // 添加一门 1-16 周的课程，周一 08:00-09:40
    await provider.addCourse(
      Course(
        id: '16week-course',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1, // 周一
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );

    // 第 16 周（课程最后一周）—— 应该能获取到课程
    final week16Time = DateTime(2026, 6, 8, 8, 30); // 第16周周一
    final selectionInWeek = provider.getLiveActivityCourseSelection(
      now: week16Time,
    );
    expect(selectionInWeek, isNotNull);
    expect(selectionInWeek!.currentCourse.name, '高等数学');

    // 第 17 周（课程已结束）—— 应该返回 null
    final week17Time = DateTime(2026, 6, 15, 8, 30); // 第17周周一
    final selectionAfterEnd = provider.getLiveActivityCourseSelection(
      now: week17Time,
    );
    expect(selectionAfterEnd, isNull);
  });

  test(
    'live activity returns null after course end week when semesterWeekCount equals endWeek',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterWeekCount: 16,
          semesterStartDate: DateTime(2026, 2, 23),
          liveEnableBeforeClass: true,
          liveEnableDuringClass: true,
          liveEnableBeforeEnd: true,
        ),
      );
      await provider.addCourse(
        Course(
          id: '16week-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );

      final week16Time = DateTime(2026, 6, 8, 8, 30);
      expect(
        provider.getLiveActivityCourseSelection(now: week16Time),
        isNotNull,
      );

      final week17Time = DateTime(2026, 6, 15, 8, 30);
      expect(provider.getLiveActivityCourseSelection(now: week17Time), isNull);
    },
  );

  test(
    'home widget has no courses after semesterWeekCount even when UI week clamps',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterWeekCount: 16,
          semesterStartDate: DateTime(2026, 2, 23),
        ),
      );
      await provider.addCourse(
        Course(
          id: '16week-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );

      // Week 16 Monday — still teaching.
      final week16Snapshot = provider.buildHomeWidgetSnapshot(
        now: DateTime(2026, 6, 8, 8, 30),
      );
      expect(week16Snapshot, isNotNull);
      expect(week16Snapshot!.currentWeek, 16);
      expect(week16Snapshot.todayCourses, isNotEmpty);

      // Week 17 Monday — past semesterWeekCount; UI would clamp to 16, but
      // widget must not revive week-16 courses.
      final week17Snapshot = provider.buildHomeWidgetSnapshot(
        now: DateTime(2026, 6, 15, 8, 30),
      );
      expect(week17Snapshot, isNotNull);
      expect(week17Snapshot!.currentWeek, 17);
      expect(week17Snapshot.todayCourses, isEmpty);
      expect(week17Snapshot.state, HomeWidgetSnapshotState.noCourse);
    },
  );

  test(
    'live activity stage transition stops when selection null and stage tracked',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = TimetableProvider(
        autoInitialize: false,
        liveActivitiesService: liveService,
      );
      await provider.initialize();
      await settleLiveActivityStartup(liveService);

      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterWeekCount: 20,
          semesterStartDate: DateTime(2026, 2, 23),
          liveEnableBeforeClass: true,
          liveEnableDuringClass: true,
          liveEnableBeforeEnd: true,
        ),
      );
      await provider.addCourse(
        Course(
          id: '16week-course',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await pumpEventQueue();

      provider.seedLiveActivityTrackingForTesting(
        lastStageKey: '16week-course:beforeClass:高等数学:1:2:A101:张老师',
      );
      liveService.stopLiveUpdateCallCount = 0;
      liveService.startLiveUpdateCallCount = 0;

      provider.checkLiveActivityStageTransitionForTesting();
      await pumpEventQueue();

      expect(liveService.stopLiveUpdateCallCount, 1);
      expect(liveService.startLiveUpdateCallCount, 0);
    },
  );

  test(
    'live activity stage transition stops when selection null and debounce key tracked',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = TimetableProvider(
        autoInitialize: false,
        liveActivitiesService: liveService,
      );
      await provider.initialize();
      await settleLiveActivityStartup(liveService);

      provider.seedLiveActivityTrackingForTesting(
        currentCourseId: 'stale-debounce-key',
      );
      liveService.stopLiveUpdateCallCount = 0;

      provider.checkLiveActivityStageTransitionForTesting();
      await pumpEventQueue();

      expect(liveService.stopLiveUpdateCallCount, 1);
    },
  );

  test(
    'live activity stage transition skips stop when selection null and nothing tracked',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = TimetableProvider(
        autoInitialize: false,
        liveActivitiesService: liveService,
      );
      await provider.initialize();
      await settleLiveActivityStartup(liveService);
      liveService.stopLiveUpdateCallCount = 0;

      provider.checkLiveActivityStageTransitionForTesting();
      await pumpEventQueue();

      expect(liveService.stopLiveUpdateCallCount, 0);
    },
  );

  test('update live activity stops when course selection is null', () async {
    final liveService = TestMiuiLiveActivitiesService();
    final provider = TimetableProvider(
      autoInitialize: false,
      liveActivitiesService: liveService,
    );
    await provider.initialize();
    await settleLiveActivityStartup(liveService);
    liveService.stopLiveUpdateCallCount = 0;
    liveService.startLiveUpdateCallCount = 0;

    await provider.updateLiveActivityForTesting(syncScheduleSnapshot: false);
    await pumpEventQueue();

    expect(liveService.stopLiveUpdateCallCount, 1);
    expect(liveService.startLiveUpdateCallCount, 0);
  });

  test(
    'live activity still uses manual currentWeek without semester start (v2.0 behavior)',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.setCurrentWeek(5);
      await provider.addCourse(
        _liveMondayCourse(
          id: 'stale-week-course',
          name: '高等数学',
          startWeek: 5,
          endWeek: 5,
        ),
      );

      final now = DateTime(2026, 4, 13, 8, 30);
      expect(provider.getWeekIndex(now, _liveSemesterStart2026), 8);
      final selection = provider.getLiveActivityCourseSelection(now: now);
      expect(selection, isNotNull);
      expect(selection!.currentCourse.name, '高等数学');
    },
  );

  test(
    'live activity returns null on even week when course is odd-week only',
    () async {
      final provider = await _createLiveActivityTestProvider();
      await provider.addCourse(
        _liveMondayCourse(id: 'odd-week-course', name: '单周课', isOddWeek: true),
      );

      final evenWeekMonday = DateTime(2026, 3, 30, 7, 45);
      final oddWeekMonday = DateTime(2026, 3, 23, 7, 45);
      expect(provider.getWeekIndex(evenWeekMonday, _liveSemesterStart2026), 6);
      expect(provider.getWeekIndex(oddWeekMonday, _liveSemesterStart2026), 5);
      expect(
        provider.getLiveActivityCourseSelection(now: evenWeekMonday),
        isNull,
      );
      expect(
        provider.getLiveActivityCourseSelection(now: oddWeekMonday),
        isNotNull,
      );
    },
  );

  test(
    'live activity returns null on even week when course is even-week only',
    () async {
      final provider = await _createLiveActivityTestProvider();
      await provider.addCourse(
        _liveMondayCourse(
          id: 'even-week-course',
          name: '双周课',
          isEvenWeek: true,
        ),
      );

      final evenWeekMonday = DateTime(2026, 3, 30, 7, 45);
      final oddWeekMonday = DateTime(2026, 3, 23, 7, 45);
      expect(
        provider.getLiveActivityCourseSelection(now: oddWeekMonday),
        isNull,
      );
      expect(
        provider.getLiveActivityCourseSelection(now: evenWeekMonday),
        isNotNull,
      );
    },
  );

  test('live activity returns null when customWeeks excludes today', () async {
    final provider = await _createLiveActivityTestProvider();
    await provider.addCourse(
      _liveMondayCourse(
        id: 'custom-week-course',
        name: '自定义周次课',
        customWeeks: const [2, 4, 6],
      ),
    );

    final week5Monday = DateTime(2026, 3, 23, 8, 30);
    final week6Monday = DateTime(2026, 3, 30, 7, 45);
    expect(provider.getLiveActivityCourseSelection(now: week5Monday), isNull);
    expect(
      provider.getLiveActivityCourseSelection(now: week6Monday),
      isNotNull,
    );
  });

  test('live activity returns null when week is suspended', () async {
    final provider = await _createLiveActivityTestProvider();
    await provider.addCourse(
      _liveMondayCourse(
        id: 'suspended-week-course',
        name: '停课周课程',
        suspendedWeeks: const [5],
      ),
    );

    final week5Monday = DateTime(2026, 3, 23, 8, 30);
    expect(provider.getLiveActivityCourseSelection(now: week5Monday), isNull);
  });

  test(
    'live activity returns null on holiday and stops live update on refresh',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = await _createLiveActivityTestProvider(
        enableLiveActivitySync: true,
        liveActivitiesService: liveService,
      );
      await settleLiveActivityStartup(liveService);
      await provider.addCourse(
        _liveMondayCourse(id: 'holiday-course', name: '假期课'),
      );
      await provider.addCustomHoliday(
        HolidayEntry(
          date: DateTime(2026, 4, 13),
          name: '测试假期',
          type: HolidayType.vacation,
          groupId: 'custom-test-holiday',
        ),
      );
      await pumpEventQueue();

      final holidayMonday = DateTime(2026, 4, 13, 8, 30);
      expect(provider.isHoliday(holidayMonday), isTrue);
      expect(
        provider.getLiveActivityCourseSelection(now: holidayMonday),
        isNull,
      );

      liveService.stopLiveUpdateCallCount = 0;
      liveService.startLiveUpdateCallCount = 0;
      await provider.updateLiveActivityForTesting(syncScheduleSnapshot: false);
      await pumpEventQueue();

      expect(liveService.stopLiveUpdateCallCount, 1);
      expect(liveService.startLiveUpdateCallCount, 0);
    },
  );

  test(
    'adding custom holiday for today stops live update via surface sync',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = await _createLiveActivityTestProvider(
        enableLiveActivitySync: true,
        liveActivitiesService: liveService,
      );
      await settleLiveActivityStartup(liveService);
      await provider.addCourse(
        _liveMondayCourse(id: 'today-holiday-course', name: '今日假期课'),
      );
      provider.seedLiveActivityTrackingForTesting(
        lastStageKey: 'seeded-stage',
        currentCourseId: 'seeded-course',
      );

      liveService.stopLiveUpdateCallCount = 0;
      liveService.startLiveUpdateCallCount = 0;
      final today = DateTime.now();
      await provider.addCustomHoliday(
        HolidayEntry(
          date: DateTime(today.year, today.month, today.day),
          name: '今日放假',
          type: HolidayType.vacation,
          groupId: 'custom-today-holiday',
        ),
      );
      await pumpEventQueue();

      expect(provider.isHoliday(today), isTrue);
      expect(provider.getLiveActivityCourseSelection(now: today), isNull);
      expect(liveService.stopLiveUpdateCallCount, greaterThanOrEqualTo(1));
      expect(liveService.startLiveUpdateCallCount, 0);
    },
  );

  test(
    'home widget snapshot uses full isHoliday semantics for custom vacation',
    () async {
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: DateTime(2026, 3, 23),
          enableHolidayMarking: true,
        ),
      );
      await provider.addCourse(
        Course(
          id: 'holiday-widget-course',
          name: '操作系统',
          teacher: '张老师',
          location: 'A203',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.addCustomHoliday(
        HolidayEntry(
          date: DateTime(2026, 4, 13),
          name: '测试假期',
          type: HolidayType.vacation,
          groupId: 'custom-widget-holiday',
        ),
      );
      await pumpEventQueue();

      final snapshot = provider.buildHomeWidgetSnapshot(
        now: DateTime(2026, 4, 13, 8, 30),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.state, HomeWidgetSnapshotState.holiday);
      expect(snapshot.holidayName, '测试假期');
      expect(snapshot.todayCourses, isEmpty);
      expect(snapshot.highlightedCourse, isNull);
      expect(snapshot.nextCourse, isNull);
      expect(snapshot.totalTodayCourseCount, 0);
    },
  );

  test('live activity returns null before before-class window opens', () async {
    final provider = await _createLiveActivityTestProvider(
      configureSettings: (settings) =>
          settings.copyWith(liveShowBeforeClassMinutes: 20),
    );
    await provider.addCourse(
      _liveMondayCourse(id: 'window-course', name: '窗口课'),
    );

    final beforeWindow = DateTime(2026, 3, 23, 7, 30);
    final insideWindow = DateTime(2026, 3, 23, 7, 45);
    expect(provider.getLiveActivityCourseSelection(now: beforeWindow), isNull);
    expect(
      provider.getLiveActivityCourseSelection(now: insideWindow)?.stage,
      LiveActivityStage.beforeClass,
    );
  });

  test(
    'live activity returns null after class and stops live update',
    () async {
      final liveService = TestMiuiLiveActivitiesService();
      final provider = await _createLiveActivityTestProvider(
        enableLiveActivitySync: true,
        liveActivitiesService: liveService,
      );
      await settleLiveActivityStartup(liveService);
      await provider.addCourse(
        _liveMondayCourse(id: 'after-class-course', name: '课后课'),
      );
      await pumpEventQueue();

      final afterClass = DateTime(2026, 3, 23, 10);
      expect(provider.getLiveActivityCourseSelection(now: afterClass), isNull);

      liveService.stopLiveUpdateCallCount = 0;
      liveService.startLiveUpdateCallCount = 0;
      await provider.updateLiveActivityForTesting(syncScheduleSnapshot: false);
      await pumpEventQueue();

      expect(liveService.stopLiveUpdateCallCount, 1);
      expect(liveService.startLiveUpdateCallCount, 0);
    },
  );

  test('live activity selection matches kotlin scheduler vectors', () async {
    final provider = await _createLiveActivityTestProvider();
    await provider.addCourse(
      _liveMondayCourse(id: 'parity-course', name: '对齐课', isOddWeek: true),
    );

    final activeNow = DateTime(2026, 3, 23, 7, 45);
    final inactiveWeekNow = DateTime(2026, 3, 30, 8, 30);
    final afterEndWeekNow = DateTime(2026, 6, 15, 8, 30);
    final beforeWindowNow = DateTime(2026, 3, 23, 7, 30);
    final afterClassNow = DateTime(2026, 3, 23, 10);

    expect(
      provider.getLiveActivityCourseSelection(now: activeNow)?.currentCourse.id,
      'parity-course',
    );
    expect(
      provider.getLiveActivityCourseSelection(now: inactiveWeekNow),
      isNull,
    );
    expect(
      provider.getLiveActivityCourseSelection(now: afterEndWeekNow),
      isNull,
    );
    expect(
      provider.getLiveActivityCourseSelection(now: beforeWindowNow),
      isNull,
    );
    expect(provider.getLiveActivityCourseSelection(now: afterClassNow), isNull);

    final startTime = LiveActivityLogic.buildCourseDateTime(activeNow, '08:00');
    final endTime = LiveActivityLogic.buildCourseDateTime(activeNow, '09:40');
    expect(startTime, isNotNull);
    expect(endTime, isNotNull);
    expect(
      LiveActivityLogic.resolveLiveActivityStage(
        currentTime: activeNow,
        startTime: startTime!,
        endTime: endTime!,
        aheadTime: startTime.subtract(const Duration(minutes: 20)),
        settings: provider.settings,
        endReminderWindow: const Duration(minutes: 10),
      ),
      LiveActivityStage.beforeClass,
    );
    expect(
      LiveActivityLogic.resolveLiveActivityStage(
        currentTime: beforeWindowNow,
        startTime: startTime,
        endTime: endTime,
        aheadTime: startTime.subtract(const Duration(minutes: 20)),
        settings: provider.settings,
        endReminderWindow: const Duration(minutes: 10),
      ),
      isNull,
    );
    expect(
      LiveActivityLogic.resolveLiveActivityStage(
        currentTime: afterClassNow,
        startTime: startTime,
        endTime: endTime,
        aheadTime: startTime.subtract(const Duration(minutes: 20)),
        settings: provider.settings,
        endReminderWindow: const Duration(minutes: 10),
      ),
      isNull,
    );
  });
}
