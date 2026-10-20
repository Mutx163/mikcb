import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_time_scheme_service.dart';

/// 假端口：内存状态 + 落盘计数。方案补齐故意做"写死 09:00–09:45"的简化实现，
/// 让被测对象是服务自己的校验、快照与补偿落盘逻辑。
class _FakePort implements TimetableTimeSchemePort {
  _FakePort({
    List<TimeScheme> schemes = const <TimeScheme>[],
    List<TimetableProfile> profiles = const <TimetableProfile>[],
    List<Course> courses = const <Course>[],
    List<LocationTimeGroup> groups = const <LocationTimeGroup>[],
    List<ScheduleDateRule> rules = const <ScheduleDateRule>[],
    TimetableSettings? settings,
    this.activeProfileIdValue,
  }) : timeSchemes = List<TimeScheme>.from(schemes),
       profiles = List<TimetableProfile>.from(profiles),
       courses = List<Course>.from(courses),
       locationTimeGroups = List<LocationTimeGroup>.from(groups),
       scheduleDateRules = List<ScheduleDateRule>.from(rules),
       settings = settings ?? TimetableSettings.defaults();

  @override
  List<TimeScheme> timeSchemes;

  @override
  List<TimetableProfile> profiles;

  @override
  List<Course> courses;

  @override
  List<LocationTimeGroup> locationTimeGroups;

  @override
  List<ScheduleDateRule> scheduleDateRules;

  @override
  TimetableSettings settings;

  final String? activeProfileIdValue;

  int initializeCalls = 0;
  int persistSchemeCalls = 0;
  int persistActiveCalls = 0;
  int saveProfileCalls = 0;
  int notifyCalls = 0;
  int clearLiveCalls = 0;
  int updateLiveCalls = 0;
  int mergeCalls = 0;
  bool failPersistScheme = false;
  bool failPersistActive = false;
  bool failSaveProfiles = false;

  @override
  String? get activeProfileId => activeProfileIdValue;

  @override
  TimeScheme? get activeTimeScheme {
    for (final scheme in timeSchemes) {
      if (scheme.id == settings.activeTimeSchemeId) {
        return scheme;
      }
    }
    return timeSchemes.isEmpty ? null : timeSchemes.first;
  }

  @override
  TimeScheme? timeSchemeById(String? schemeId) {
    for (final scheme in timeSchemes) {
      if (scheme.id == schemeId) {
        return scheme;
      }
    }
    return null;
  }

  @override
  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  }) => source
      .map((course) => course.copyWith(startTime: '09:00', endTime: '09:45'))
      .toList();

  @override
  TimetableSettings settingsFromProfile(TimetableProfile profile) =>
      profile.settings;

  @override
  void mergeActiveProfileIntoProfilesList() => mergeCalls++;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> persistTimeSchemes() async {
    persistSchemeCalls++;
    if (failPersistScheme) {
      throw StateError('scheme disk down');
    }
  }

  @override
  Future<void> persistActiveProfileState() async {
    persistActiveCalls++;
    if (failPersistActive) {
      throw StateError('active disk down');
    }
  }

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    saveProfileCalls++;
    if (failSaveProfiles) {
      throw StateError('profiles disk down');
    }
    this.profiles = profiles;
  }

  @override
  void notifyStateChanged() => notifyCalls++;

  @override
  void clearCurrentLiveCourseId() => clearLiveCalls++;

  @override
  Future<void> updateLiveActivity() async => updateLiveCalls++;
}

List<SectionTime> _sections(int count) => <SectionTime>[
  for (var index = 0; index < count; index++)
    SectionTime(
      startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
      endTime: '${(8 + index).toString().padLeft(2, '0')}:45',
    ),
];

TimeScheme _scheme(String id, {String name = '作息', int sectionCount = 4}) =>
    TimeScheme(
      id: id,
      name: name,
      sections: _sections(sectionCount),
      createdAt: DateTime(2026, 3),
      updatedAt: DateTime(2026, 3),
    );

Course _course(String id, {int endSection = 2, String startTime = '08:00'}) =>
    Course(
      id: id,
      name: '数学',
      teacher: '',
      location: '',
      dayOfWeek: 1,
      startSection: 1,
      endSection: endSection,
      startTime: startTime,
      endTime: '09:45',
    );

TimetableProfile _profile(
  String id, {
  String? activeSchemeId,
  List<Course>? courses,
}) => TimetableProfile(
  id: id,
  name: '课表$id',
  courses: courses ?? <Course>[_course('c_$id')],
  settings: TimetableSettings.defaults().copyWith(
    activeTimeSchemeId: activeSchemeId,
  ),
  currentWeek: 1,
  createdAt: DateTime(2026, 3),
  lastUsedAt: DateTime(2026, 3),
);

void main() {
  group('新建作息', () {
    test('沿用当前生效作息或设置的节次，落盘后通知', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1', sectionCount: 6)],
      );

      final created = await TimetableTimeSchemeService.create(
        port,
        name: '  新课表  ',
      );

      expect(created.name, '新课表');
      expect(created.sections, hasLength(6));
      expect(port.timeSchemes, hasLength(2));
      expect(port.persistSchemeCalls, 1);
      expect(port.notifyCalls, 1);
    });

    test('落盘失败：刚加的那条摘掉并上抛（不留幻影作息）', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1')]);
      port.failPersistScheme = true;

      await expectLater(
        TimetableTimeSchemeService.create(port, name: '新课表'),
        throwsA(isA<StateError>()),
      );
      expect(port.timeSchemes, hasLength(1));
      expect(port.notifyCalls, 0);
    });

    test('带 applyToActiveProfile：顺手套用并重排课程钟点', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1', startTime: '07:30')],
      );

      await TimetableTimeSchemeService.create(
        port,
        name: '新课表',
        applyToActiveProfile: true,
      );

      expect(port.courses.single.startTime, '09:00');
      expect(port.persistActiveCalls, 1);
      expect(port.notifyCalls, 1);
    });
  });

  group('套用作息', () {
    test('作息不存在 → 消息编码，不动内存', () async {
      final port = _FakePort();

      expect(
        await TimetableTimeSchemeService.apply(port, 'missing'),
        'time_scheme_not_found',
      );
      expect(port.persistActiveCalls, 0);
    });

    test('目标作息节次不够放现有课程 → 报单条容量超限，不改设置', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1', sectionCount: 2)],
        courses: <Course>[_course('c1', endSection: 5)],
      );

      final message = await TimetableTimeSchemeService.apply(port, 's1');

      expect(message, contains('section_count_below_usage'));
      expect(port.settings.activeTimeSchemeId, isNot('s1'));
      expect(port.persistActiveCalls, 0);
    });

    test('套用成功：设置指向新作息并重排课程钟点', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1', sectionCount: 8)],
        courses: <Course>[_course('c1', startTime: '07:30')],
      );

      expect(await TimetableTimeSchemeService.apply(port, 's1'), isNull);
      expect(port.settings.activeTimeSchemeId, 's1');
      expect(port.courses.single.startTime, '09:00');
      expect(port.persistActiveCalls, 1);
      expect(port.clearLiveCalls, 1);
    });

    test('套用落盘失败：设置/课程/档案三份退回', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        courses: <Course>[_course('c1', startTime: '07:30')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersistActive = true;

      await expectLater(
        TimetableTimeSchemeService.apply(port, 's1'),
        throwsA(isA<StateError>()),
      );
      expect(port.settings.activeTimeSchemeId, isNot('s1'));
      expect(port.courses.single.startTime, '07:30');
      expect(port.profiles, hasLength(1));
      expect(port.notifyCalls, 0);
    });
  });

  group('改名 / 复制 / 删除', () {
    test('改名：trim 后落盘；找不到返回 null', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1')]);

      final renamed = await TimetableTimeSchemeService.rename(
        port,
        's1',
        '  秋季作息 ',
      );

      expect(renamed!.name, '秋季作息');
      expect(port.persistSchemeCalls, 1);
      expect(await TimetableTimeSchemeService.rename(port, 'x', 'y'), isNull);
    });

    test('改名落盘失败：换回原名', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1', name: '原名')]);
      port.failPersistScheme = true;

      await expectLater(
        TimetableTimeSchemeService.rename(port, 's1', '新名'),
        throwsA(isA<StateError>()),
      );
      expect(port.timeSchemes.single.name, '原名');
    });

    test('复制：新 id、默认名字加"副本"、节次独立', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1', name: '秋季')]);

      final copy = await TimetableTimeSchemeService.duplicate(port, 's1');

      expect(copy!.id, isNot('s1'));
      expect(copy.name, '秋季 副本');
      expect(copy.sections, hasLength(4));
      expect(port.timeSchemes, hasLength(2));
    });

    test('删除：被档案引用时拒绝且不落盘；未被引用才真删', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1'), _scheme('s2')],
        profiles: <TimetableProfile>[_profile('p1', activeSchemeId: 's1')],
      );

      expect(
        await TimetableTimeSchemeService.delete(port, 's1'),
        isFalse,
        reason: '档案还在用这套作息',
      );
      expect(port.persistSchemeCalls, 0);

      expect(await TimetableTimeSchemeService.delete(port, 's2'), isTrue);
      expect(port.timeSchemes.map((scheme) => scheme.id), <String>['s1']);
    });

    test('删除落盘失败：原位插回', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1'), _scheme('s2'), _scheme('s3')],
      );
      port.failPersistScheme = true;

      await expectLater(
        TimetableTimeSchemeService.delete(port, 's2'),
        throwsA(isA<StateError>()),
      );
      expect(
        port.timeSchemes.map((scheme) => scheme.id),
        <String>['s1', 's2', 's3'],
        reason: '插回原位，顺序不能变',
      );
    });
  });

  group('改节次表', () {
    test('节次表本身不合法 → 直接返回消息编码，不落盘', () async {
      final port = _FakePort(schemes: <TimeScheme>[_scheme('s1')]);

      final message = await TimetableTimeSchemeService.update(
        port,
        schemeId: 's1',
        name: '作息',
        sections: <SectionTime>[
          const SectionTime(startTime: '09:00', endTime: '09:45'),
          const SectionTime(startTime: '08:00', endTime: '08:45'),
        ],
      );

      expect(message, isNotNull);
      expect(port.persistSchemeCalls, 0);
    });

    test('收窄到放不下现有课程 → 报明细（哪份课表哪门课）', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1', sectionCount: 8)],
        profiles: <TimetableProfile>[
          _profile(
            'p1',
            activeSchemeId: 's1',
            courses: <Course>[_course('c1', endSection: 6)],
          ),
        ],
      );

      final message = await TimetableTimeSchemeService.update(
        port,
        schemeId: 's1',
        name: '作息',
        sections: _sections(2),
      );

      expect(message, isNotNull);
      expect(port.persistSchemeCalls, 0);
    });

    test('改成功：作息/档案/设置一起改，两次落盘', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        profiles: <TimetableProfile>[_profile('p1', activeSchemeId: 's1')],
        courses: <Course>[_course('c1')],
        settings: TimetableSettings.defaults().copyWith(
          activeTimeSchemeId: 's1',
          sections: _sections(4),
        ),
        activeProfileIdValue: 'p1',
      );

      expect(
        await TimetableTimeSchemeService.update(
          port,
          schemeId: 's1',
          name: '秋季作息',
          sections: _sections(6),
        ),
        isNull,
      );
      expect(port.timeSchemes.single.name, '秋季作息');
      expect(port.timeSchemes.single.sections, hasLength(6));
      expect(port.settings.sections, hasLength(6));
      expect(port.persistSchemeCalls, 1);
      expect(port.saveProfileCalls, 1);
      expect(port.mergeCalls, 1);
      expect(port.notifyCalls, 1);
    });

    test('第二笔落盘失败：四份内存退回，并补偿回写旧作息表', () async {
      final port = _FakePort(
        schemes: <TimeScheme>[_scheme('s1')],
        profiles: <TimetableProfile>[_profile('p1', activeSchemeId: 's1')],
        courses: <Course>[_course('c1')],
        settings: TimetableSettings.defaults().copyWith(
          activeTimeSchemeId: 's1',
          sections: _sections(4),
        ),
        activeProfileIdValue: 'p1',
      );
      port.failSaveProfiles = true;

      await expectLater(
        TimetableTimeSchemeService.update(
          port,
          schemeId: 's1',
          name: '秋季作息',
          sections: _sections(6),
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.timeSchemes.single.name, '作息');
      expect(port.timeSchemes.single.sections, hasLength(4));
      expect(port.settings.sections, hasLength(4));
      expect(
        port.persistSchemeCalls,
        2,
        reason: '第一笔已落盘，失败后必须再写一次旧表做补偿',
      );
      expect(port.notifyCalls, 0);
    });
  });
}
