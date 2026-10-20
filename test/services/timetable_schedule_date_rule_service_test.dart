import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/schedule_date_rule_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_schedule_date_rule_service.dart';

/// 假端口：内存状态 + 落盘计数。方案补齐走"写死 09:00–09:45"的简化实现，
/// 被测对象是服务自己的匹配前置条件、越界判定与回滚。
class _FakePort implements TimetableScheduleDateRulePort {
  _FakePort({
    List<ScheduleDateRule> rules = const <ScheduleDateRule>[],
    List<TimeScheme> schemes = const <TimeScheme>[],
    List<TimetableProfile> profiles = const <TimetableProfile>[],
    List<Course> courses = const <Course>[],
    TimetableSettings? settings,
    this.activeProfileIdValue,
    String? lastAppliedSignature,
  }) : scheduleDateRuleLastAppliedSignature = lastAppliedSignature,
       scheduleDateRules = List<ScheduleDateRule>.from(rules),
       timeSchemes = List<TimeScheme>.from(schemes),
       profiles = List<TimetableProfile>.from(profiles),
       courses = List<Course>.from(courses),
       settings = settings ?? TimetableSettings.defaults();

  @override
  List<ScheduleDateRule> scheduleDateRules;

  @override
  List<TimeScheme> timeSchemes;

  @override
  List<TimetableProfile> profiles;

  @override
  List<Course> courses;

  @override
  List<LocationTimeGroup> locationTimeGroups = <LocationTimeGroup>[];

  @override
  TimetableSettings settings;

  final String? activeProfileIdValue;

  @override
  String? scheduleDateRuleLastAppliedSignature;

  int initializeCalls = 0;
  int saveProfileCalls = 0;
  int saveSignatureCalls = 0;
  int notifySyncCalls = 0;
  int notifyCalls = 0;
  int clearLiveCalls = 0;
  int updateLiveCalls = 0;
  int mergeCalls = 0;
  bool failSaveProfiles = false;
  bool failSaveSignature = false;

  @override
  String? get activeProfileId => activeProfileIdValue;

  @override
  TimeScheme? get activeTimeScheme => null;

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
  Future<void> persistTimeSchemes() async {}

  @override
  Future<void> persistActiveProfileState() async {}

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    saveProfileCalls++;
    if (failSaveProfiles) {
      throw StateError('profiles disk down');
    }
    this.profiles = profiles;
  }

  @override
  Future<void> saveScheduleDateRuleLastAppliedSignature(String signature) async {
    saveSignatureCalls++;
    if (failSaveSignature) {
      throw StateError('signature disk down');
    }
  }

  @override
  void notifySyncDataChanged() => notifySyncCalls++;

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

/// 一条已经"到点"的规则：生效区间覆盖 2026-03-10。
ScheduleDateRule _dueRule({String schemeId = 's1', String id = 'r1'}) =>
    ScheduleDateRule(
      id: id,
      name: '春季作息',
      timeSchemeId: schemeId,
      startDate: '2026-03-01',
      endDate: '2026-04-30',
    );

TimeScheme _scheme(String id, {int sectionCount = 8}) => TimeScheme(
  id: id,
  name: '作息$id',
  sections: _sections(sectionCount),
  createdAt: DateTime(2026, 3),
  updatedAt: DateTime(2026, 3),
);

Course _course(String id, {int endSection = 2, String startTime = '07:30'}) =>
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

TimetableProfile _profile(String id, {required String schemeId}) =>
    TimetableProfile(
      id: id,
      name: '课表$id',
      courses: <Course>[_course('c_$id')],
      settings: TimetableSettings.defaults().copyWith(
        activeTimeSchemeId: 'old',
        sections: _sections(4),
      ),
      currentWeek: 1,
      createdAt: DateTime(2026, 3),
      lastUsedAt: DateTime(2026, 3),
    );

void main() {
  final now = DateTime(2026, 3, 10);

  test('没有到点的规则 → notDue，不动任何状态', () async {
    final port = _FakePort(
      rules: <ScheduleDateRule>[
        const ScheduleDateRule(
          id: 'r2',
          name: '暑期作息',
          timeSchemeId: 's1',
          startDate: '2026-06-01',
          endDate: '2026-07-31',
        ),
      ],
      schemes: <TimeScheme>[_scheme('s1')],
    );

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.notDue);
    expect(port.saveProfileCalls, 0);
    expect(port.notifyCalls, 0);
  });

  test('同一档期已经套过（签名相同）→ 不重复套', () async {
    final rule = _dueRule();
    final port = _FakePort(
      rules: <ScheduleDateRule>[rule],
      schemes: <TimeScheme>[_scheme('s1')],
      lastAppliedSignature: ScheduleDateRuleLogic.appliedSignature(rule),
    );

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.notDue);
    expect(port.saveProfileCalls, 0);
  });

  test('规则指向的作息不存在 → schemeMissing，不落盘', () async {
    final port = _FakePort(rules: <ScheduleDateRule>[_dueRule()]);

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.schemeMissing);
    expect(port.saveProfileCalls, 0);
    expect(port.notifyCalls, 0);
  });

  test('课程节次超出目标作息 → sectionOverflow 且带上两边的数', () async {
    final port = _FakePort(
      rules: <ScheduleDateRule>[_dueRule()],
      schemes: <TimeScheme>[_scheme('s1', sectionCount: 4)],
      courses: <Course>[_course('c1', endSection: 6)],
    );

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.sectionOverflow);
    expect(result.requiredMaxSection, 6);
    expect(result.schemeSectionCount, 4);
    expect(port.saveProfileCalls, 0);
  });

  test('套用成功：每个档案都换作息、活动课表跟着重排、签名最后落盘', () async {
    final rule = _dueRule();
    final port = _FakePort(
      rules: <ScheduleDateRule>[rule],
      schemes: <TimeScheme>[_scheme('s1')],
      profiles: <TimetableProfile>[
        _profile('p1', schemeId: 's1'),
        _profile('p2', schemeId: 's1'),
      ],
      courses: <Course>[_course('c1')],
      activeProfileIdValue: 'p1',
    );

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.applied);
    expect(
      port.profiles.map((profile) => profile.settings.activeTimeSchemeId),
      <String>['s1', 's1'],
    );
    expect(port.courses.single.startTime, '09:00');
    expect(port.saveProfileCalls, 1);
    expect(port.notifySyncCalls, 1);
    expect(port.notifyCalls, 1);
    expect(port.clearLiveCalls, 1);
    expect(port.saveSignatureCalls, 1);
    expect(
      port.scheduleDateRuleLastAppliedSignature,
      ScheduleDateRuleLogic.appliedSignature(rule),
    );
  });

  test('没有活动档案时：按规则里的作息直接改全局设置与当前课表', () async {
    final port = _FakePort(
      rules: <ScheduleDateRule>[_dueRule()],
      schemes: <TimeScheme>[_scheme('s1')],
      courses: <Course>[_course('c1')],
    );

    final result = await TimetableScheduleDateRuleService.applyDue(
      port,
      now: now,
    );

    expect(result.outcome, ScheduleDateRuleApplyOutcome.applied);
    expect(port.settings.activeTimeSchemeId, 's1');
    expect(port.courses.single.startTime, '09:00');
  });

  test('档案落盘失败：档案/设置/课程三份退回，签名不写、不通知', () async {
    final port = _FakePort(
      rules: <ScheduleDateRule>[_dueRule()],
      schemes: <TimeScheme>[_scheme('s1')],
      profiles: <TimetableProfile>[_profile('p1', schemeId: 's1')],
      courses: <Course>[_course('c1')],
      activeProfileIdValue: 'p1',
    );
    port.failSaveProfiles = true;

    await expectLater(
      TimetableScheduleDateRuleService.applyDue(port, now: now),
      throwsA(isA<StateError>()),
    );

    expect(
      port.profiles.single.settings.activeTimeSchemeId,
      'old',
      reason: '档案退回套用前',
    );
    expect(port.courses.single.startTime, '07:30');
    expect(port.notifyCalls, 0);
    expect(port.saveSignatureCalls, 0);
    expect(port.scheduleDateRuleLastAppliedSignature, isNull);
  });

  test('签名落盘失败：内存里的签名不写（否则重启后会漏套一次）', () async {
    final port = _FakePort(
      rules: <ScheduleDateRule>[_dueRule()],
      schemes: <TimeScheme>[_scheme('s1')],
      profiles: <TimetableProfile>[_profile('p1', schemeId: 's1')],
      activeProfileIdValue: 'p1',
    );
    port.failSaveSignature = true;

    await expectLater(
      TimetableScheduleDateRuleService.applyDue(port, now: now),
      throwsA(isA<StateError>()),
    );

    expect(
      port.scheduleDateRuleLastAppliedSignature,
      isNull,
      reason: '盘上没有这条标记，内存也不能记',
    );
    expect(
      port.notifyCalls,
      1,
      reason: '课表已经落盘成功，界面必须先看到新作息',
    );
  });
}
