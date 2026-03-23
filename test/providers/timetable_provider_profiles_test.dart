import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

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
    expect(conflictMap['odd-course']!.map((course) => course.id), ['all-course']);
    expect(conflictMap['even-course']!.map((course) => course.id), ['all-course']);
    expect(
      conflictMap['all-course']!.map((course) => course.id).toSet(),
      {'odd-course', 'even-course'},
    );
    expect(provider.courseConflictMapForWeek(1).containsKey('odd-course'), isTrue);
    expect(provider.courseConflictMapForWeek(2).containsKey('even-course'), isTrue);
    expect(provider.courseConflictMapForWeek(1).containsKey('even-course'), isFalse);
    expect(provider.courseConflictMapForWeek(2).containsKey('odd-course'), isFalse);
  });

  test('same slot on different non-overlapping weeks is not conflict', () async {
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
    expect(syncedCourses.map((course) => course.location).toSet(), {'A101', 'B202'});
  });
}
