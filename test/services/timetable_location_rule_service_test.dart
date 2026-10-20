import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_location_rule_service.dart';

/// 假端口：内存状态 + 钩子计数；钟点同步用简化实现（固定写 09:00-09:45），
/// 让服务自己的匹配/越界/计数逻辑成为被测对象。
class _FakePort implements TimetableLocationRulePort {
  _FakePort({
    List<Course> courses = const <Course>[],
    List<TimetableProfile> profiles = const <TimetableProfile>[],
    List<LocationTimeGroup> groups = const <LocationTimeGroup>[],
    TimetableSettings? settings,
    List<TimeScheme> schemes = const <TimeScheme>[],
    this.activeProfileIdValue,
    this.activeSchemeValue,
  }) : courses = List<Course>.from(courses),
       profiles = List<TimetableProfile>.from(profiles),
       locationTimeGroups = List<LocationTimeGroup>.from(groups),
       settings = settings ?? TimetableSettings.defaults(),
       timeSchemes = schemes;

  @override
  List<Course> courses;

  @override
  List<TimetableProfile> profiles;

  @override
  List<LocationTimeGroup> locationTimeGroups;

  @override
  TimetableSettings settings;

  @override
  final List<TimeScheme> timeSchemes;

  final String? activeProfileIdValue;

  final TimeScheme? activeSchemeValue;

  int initializeCalls = 0;
  int persistGroupCalls = 0;
  int saveProfileCalls = 0;
  int notifySyncCalls = 0;
  int notifyCalls = 0;
  int clearLiveCalls = 0;
  int updateLiveCalls = 0;
  int persistActiveCalls = 0;
  bool failPersistGroups = false;
  bool failPersistActive = false;
  final List<Course> syncedSingle = <Course>[];

  @override
  TimetableProfile? get activeProfile => null;

  @override
  String? get activeProfileId => activeProfileIdValue;

  @override
  TimeScheme? get activeTimeScheme => activeSchemeValue;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> persistActiveProfileState() async {
    persistActiveCalls++;
    if (failPersistActive) {
      throw StateError('disk down');
    }
  }

  @override
  Future<void> persistLocationTimeGroups() async {
    persistGroupCalls++;
    if (failPersistGroups) {
      throw StateError('groups disk down');
    }
  }

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    saveProfileCalls++;
    this.profiles = profiles;
  }

  @override
  void notifySyncDataChanged() => notifySyncCalls++;

  @override
  void notifyStateChanged() => notifyCalls++;

  @override
  void clearCurrentLiveCourseId() => clearLiveCalls++;

  @override
  Future<void> updateLiveActivity() async => updateLiveCalls++;

  @override
  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  }) {
    return source
        .map(
          (course) =>
              course.copyWith(startTime: '09:00', endTime: '09:45'),
        )
        .toList();
  }

  @override
  Course syncCourseWithEffectiveTimeScheme(
    Course course, {
    TimetableSettings? settings,
    bool debugTrace = false,
  }) {
    syncedSingle.add(course);
    return course.copyWith(startTime: '09:00', endTime: '09:45');
  }

  @override
  TimetableSettings settingsFromProfile(TimetableProfile profile) =>
      profile.settings;
}

const SectionTime _section1 = SectionTime(
  startTime: '08:00',
  endTime: '08:45',
);

const SectionTime _section2 = SectionTime(
  startTime: '09:00',
  endTime: '09:45',
);

TimeScheme _scheme(String id) => TimeScheme(
  id: id,
  name: '模板$id',
  sections: const <SectionTime>[_section1, _section2],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Course _course(
  String id, {
  String location = '',
  int startSection = 1,
  int endSection = 1,
  bool hasCustomTime = false,
}) {
  return Course(
    id: id,
    name: '课程$id',
    teacher: '老师',
    location: location,
    dayOfWeek: 1,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '08:45',
    hasCustomTime: hasCustomTime,
  );
}

LocationTimeGroup _group(String id, String schemeId, String keyword) =>
    LocationTimeGroup(
      id: id,
      name: '地点组$id',
      timeSchemeId: schemeId,
      keywords: <LocationKeyword>[LocationKeyword(pattern: keyword)],
    );

TimetableProfile _profile(
  String id, {
  required List<Course> courses,
  TimetableSettings? settings,
}) => TimetableProfile(
  id: id,
  name: '课表$id',
  courses: courses,
  settings: settings ?? TimetableSettings.defaults(),
  currentWeek: 1,
  createdAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
);

void main() {
  group('分组 CRUD 的校验与收口', () {
    test('名字为空 → 参数错误，什么都不落盘', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1')]);

      await expectLater(
        TimetableLocationRuleService.createGroup(
          port,
          name: '   ',
          timeSchemeId: 's1',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'location_time_group_name_required',
          ),
        ),
      );
      expect(port.persistGroupCalls, 0);
      expect(port.locationTimeGroups, isEmpty);
    });

    test('作息模板不存在 → 参数错误', () async {
      final port = _FakePort();

      await expectLater(
        TimetableLocationRuleService.createGroup(
          port,
          name: '教学楼',
          timeSchemeId: 'missing',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'time_scheme_not_found',
          ),
        ),
      );
    });

    test('创建成功：追加分组、落盘并全表重算', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        profiles: <TimetableProfile>[
          _profile('p1', courses: <Course>[_course('c1')]),
        ],
      );

      final group = await TimetableLocationRuleService.createGroup(
        port,
        name: '  教学楼  ',
        timeSchemeId: 's1',
        keywords: const <LocationKeyword>[LocationKeyword(pattern: 'A楼')],
      );

      expect(group.id, isNotEmpty);
      expect(group.name, '教学楼');
      expect(port.locationTimeGroups, hasLength(1));
      expect(port.persistGroupCalls, 1);
      expect(port.saveProfileCalls, 1);
      expect(port.notifySyncCalls, 1);
    });

    test('删除不存在 → false 且不落盘；存在 → true', () async {
      final port = _FakePort(
        groups: <LocationTimeGroup>[_group('g1', 's1', 'A楼')],
        schemes: <TimeScheme>[_scheme('s1')],
      );

      expect(
        await TimetableLocationRuleService.deleteGroup(port, 'missing'),
        isFalse,
      );
      expect(port.persistGroupCalls, 0);

      expect(await TimetableLocationRuleService.deleteGroup(port, 'g1'), isTrue);
      expect(port.locationTimeGroups, isEmpty);
      expect(port.persistGroupCalls, 1);
    });
  });

  group('commitGroupChange：四份内存状态整体退回', () {
    test('写入失败 → 分组/课表/设置/课程全退，补偿落盘后上抛原错', () async {
      final originalSettings = TimetableSettings.defaults();
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        profiles: <TimetableProfile>[
          _profile('p1', courses: <Course>[_course('c1')]),
        ],
        groups: <LocationTimeGroup>[_group('g1', 's1', 'A楼')],
        settings: originalSettings,
      );
      final previousGroups = List<LocationTimeGroup>.from(
        port.locationTimeGroups,
      );

      await expectLater(
        TimetableLocationRuleService.commitGroupChange(
          port,
          previousGroups,
          () async {
            port.locationTimeGroups = const <LocationTimeGroup>[];
            port.profiles = const <TimetableProfile>[];
            port.settings = originalSettings.copyWith(appLocaleTag: 'en');
            port.courses = const <Course>[];
            throw StateError('write failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.locationTimeGroups, hasLength(1));
      expect(port.profiles, hasLength(1));
      expect(port.courses, hasLength(1));
      expect(port.settings.appLocaleTag, originalSettings.appLocaleTag);
      expect(port.persistGroupCalls, 1);
    });

    test('补偿落盘也失败时不遮住原始错误', () async {
      final port = _FakePort()..failPersistGroups = true;

      await expectLater(
        TimetableLocationRuleService.commitGroupChange(
          port,
          const <LocationTimeGroup>[],
          () async => throw StateError('original'),
        ),
        throwsA(
          isA<StateError>().having((error) => error.message, 'message', 'original'),
        ),
      );
    });
  });

  group('resyncAllProfiles：按分组重算每份课表', () {
    test('每份课表按新钟点重写，活动档同步回内存并通知', () async {
      final enSettings = TimetableSettings.defaults().copyWith(
        appLocaleTag: 'en',
      );
      final port = _FakePort(
        profiles: <TimetableProfile>[
          _profile(
            'p1',
            courses: <Course>[_course('c1')],
            settings: enSettings,
          ),
        ],
        activeProfileIdValue: 'p1',
      );

      await TimetableLocationRuleService.resyncAllProfiles(port);

      expect(port.profiles.single.courses.single.startTime, '09:00');
      expect(port.courses.single.startTime, '09:00');
      expect(port.settings.appLocaleTag, 'en');
      expect(port.saveProfileCalls, 1);
      expect(port.notifySyncCalls, 1);
      expect(port.clearLiveCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.updateLiveCalls, 1);
    });

    test('notify=false 时不刷新界面，其余副作用照常', () async {
      final port = _FakePort(
        profiles: <TimetableProfile>[
          _profile('p1', courses: <Course>[_course('c1')]),
        ],
      );

      await TimetableLocationRuleService.resyncAllProfiles(
        port,
        notify: false,
      );

      expect(port.notifyCalls, 0);
      expect(port.saveProfileCalls, 1);
      expect(port.updateLiveCalls, 1);
    });
  });

  group('applyToActiveProfile：只改写完整坐进模板的课程', () {
    _FakePort buildPort() {
      return _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        groups: <LocationTimeGroup>[_group('g1', 's1', 'A楼')],
        activeSchemeValue: _scheme('s1'),
        activeProfileIdValue: 'p1',
        courses: <Course>[
          _course('matched', location: 'A楼101'),
          _course('overflow', location: 'A楼202', endSection: 3),
          _course('nomatch', location: 'B楼'),
          _course('custom', location: 'A楼101', hasCustomTime: true),
        ],
      );
    }

    test('计数与改写：命中 1、越界 1、未命中 1、自定义钟点不动', () async {
      final port = buildPort();

      final stats = await TimetableLocationRuleService.applyToActiveProfile(
        port,
      );

      expect(stats.unlockedCount, 4);
      expect(stats.matchedCount, 1);
      expect(stats.updatedCount, 1);
      expect(stats.sectionOverflowCount, 1);
      expect(stats.sectionOverflowCourseNames, <String>['课程overflow']);
      expect(port.syncedSingle.map((course) => course.id), <String>['matched']);
      expect(port.courses.firstWhere((c) => c.id == 'matched').startTime, '09:00');
      expect(port.courses.firstWhere((c) => c.id == 'custom').startTime, '08:00');
      expect(port.courses.firstWhere((c) => c.id == 'overflow').startTime, '08:00');
      expect(port.persistActiveCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.clearLiveCalls, 1);
      expect(port.updateLiveCalls, 1);
    });

    test('落盘失败时课程表整份退回，不上抛以外的东西', () async {
      final port = buildPort()..failPersistActive = true;
      final original = port.courses
          .map((course) => course.startTime)
          .toList(growable: false);

      await expectLater(
        TimetableLocationRuleService.applyToActiveProfile(port),
        throwsA(isA<StateError>()),
      );

      expect(
        port.courses.map((course) => course.startTime),
        original,
      );
      expect(port.notifyCalls, 0);
    });

    test('没有可改写的课程时不落盘、不通知', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        activeSchemeValue: _scheme('s1'),
        courses: <Course>[_course('nomatch', location: 'B楼')],
      );

      final stats = await TimetableLocationRuleService.applyToActiveProfile(
        port,
      );

      expect(stats.updatedCount, 0);
      expect(stats.matchedCount, 0);
      expect(port.persistActiveCalls, 0);
      expect(port.notifyCalls, 0);
      expect(port.updateLiveCalls, 0);
    });
  });
}
