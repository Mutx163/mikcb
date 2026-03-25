import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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

  test('clearing active profile removes only courses and preserves settings',
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
  });

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
        startWeek: 1,
        endWeek: 16,
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
        startWeek: 1,
        endWeek: 16,
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
        startWeek: 1,
        endWeek: 16,
      ),
    );

    final conflictMap = provider.courseConflictMap;

    expect(conflictMap.containsKey('odd-course'), isTrue);
    expect(conflictMap.containsKey('all-course'), isTrue);
    expect(conflictMap.containsKey('even-course'), isTrue);
    expect(
        conflictMap['odd-course']!.map((course) => course.id), ['all-course']);
    expect(
        conflictMap['even-course']!.map((course) => course.id), ['all-course']);
    expect(
      conflictMap['all-course']!.map((course) => course.id).toSet(),
      {'odd-course', 'even-course'},
    );
    expect(
        provider.courseConflictMapForWeek(1).containsKey('odd-course'), isTrue);
    expect(provider.courseConflictMapForWeek(2).containsKey('even-course'),
        isTrue);
    expect(provider.courseConflictMapForWeek(1).containsKey('even-course'),
        isFalse);
    expect(provider.courseConflictMapForWeek(2).containsKey('odd-course'),
        isFalse);
  });

  test('same slot on different non-overlapping weeks is not conflict',
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
        startWeek: 1,
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
        endWeek: 16,
      ),
    );

    expect(provider.courseConflictMap, isEmpty);
    expect(provider.courseConflictMapForWeek(5), isEmpty);
    expect(provider.courseConflictMapForWeek(12), isEmpty);
  });

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

  test('updating a time scheme syncs profiles using it', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final scheme = await provider.createTimeScheme(
      name: '本校作息',
      sections: const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
      ],
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
      sections: const [
        SectionTime(startTime: '20:00', endTime: '20:45'),
      ],
      applyToActiveProfile: true,
    );

    final message = await provider.updateTimeScheme(
      schemeId: scheme.id,
      name: '夜间作息',
      sections: const [
        SectionTime(startTime: '23:30', endTime: '00:15'),
      ],
    );

    expect(message, contains('跨 0 点课程'));
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
    expect(provider.maxUsedSectionForTimeScheme(activeSchemeId),
        greaterThanOrEqualTo(0));
  });

  test('deleting time scheme referenced by course override is rejected',
      () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    final overrideScheme = await provider.createTimeScheme(
      name: '实验楼作息',
      sections: [
        ...provider.settings.sections.take(6),
      ],
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
  });

  test('updating an override time scheme refreshes referencing courses',
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
  });

  test('live activity respects reminder start minutes after class starts',
      () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        liveEnableBeforeClass: false,
        liveEnableDuringClass: true,
        liveEnableBeforeEnd: true,
        liveClassReminderStartMinutes: 5,
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
  });

  test('live activity starts during class immediately when reminder start is 0',
      () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(
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
  });

  test('updating non-section settings does not trigger section capacity guard',
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
  });

  test('ensuring import section capacity duplicates shared active scheme',
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
  });

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

    final syncedCourses =
        provider.courses.where((course) => course.name == '机械设计基础').toList();

    expect(syncedCourses, hasLength(2));
    expect(syncedCourses.map((course) => course.teacher).toSet(), {'李老师'});
    expect(syncedCourses.map((course) => course.shortName).toSet(), {'机设基'});
    expect(
      syncedCourses.map((course) => course.courseNature).toSet(),
      {CourseNature.elective},
    );
    expect(
      syncedCourses.map((course) => course.description).toSet(),
      {'课程简介'},
    );
    expect(syncedCourses.map((course) => course.location).toSet(),
        {'A101', 'B202'});
  });

  test('home widget snapshot highlights the next course before class',
      () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 3, 23),
      ),
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
  });

  test('home widget snapshot returns no course state on empty day', () async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 3, 23),
      ),
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
      now: DateTime(2026, 3, 24, 10, 00),
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.state, HomeWidgetSnapshotState.noCourse);
    expect(snapshot.highlightedCourse, isNull);
    expect(snapshot.nextCourse, isNull);
    expect(snapshot.todayCourses, isEmpty);
  });
}
