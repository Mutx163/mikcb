import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/data/timetable_repository.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/timetable_import_export_service.dart';
import 'package:university_timetable/services/timetable_live_activity_service.dart';

/// 导入导出服务（F8 从 provider 的分片整体搬出）的两条承诺：
///
/// 1. **导入扩容**：节数够就不动；不够就按现作息的时长/课间补，补不满必须
///    如实报错（不许拿短表继续导入，否则越界课次在时间轴里静默没时间）；
///    多张课表共用一套作息时新建「（导入补齐）」副本，而不是改用户原来那套。
/// 2. **整包导入失败回滚**：先把内存退回导入前的快照，再逐键把旧值写回盘；
///    单个 key 写失败不遮住其余 key，失败项如实收集（非空 = 回滚不完整）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('快照抓住导入前的内存状态并能整体写回', () async {
    final port = _FakePort(
      settings: const TimetableSettings(
        sections: _twoSections,
        activeTimeSchemeId: 'scheme-before',
        semesterWeekCount: 18,
      ),
      timeSchemes: <TimeScheme>[
        _buildScheme('scheme-before', '导入前作息', _twoSections),
      ],
      profiles: <TimetableProfile>[
        _buildProfile(id: 'p-before', name: '导入前课表', schemeId: 'scheme-before'),
      ],
    );
    await port.storage.init();
    port.currentWeek = 7;
    port.currentDateWeek = 9;
    port.currentCalendarWeek = 11;
    port.currentDayOfWeek = 3;
    port.activeProfileId = 'p-before';
    port.scheduleDateRuleLastAppliedSignature = 'sig-before';
    port.liveRuntime.lastLiveSnapshotSignature = 'live-before';
    port.liveRuntime.lastHomeWidgetSnapshotSignature = 'widget-before';

    final snapshot = FullBackupRestoreSnapshot(
      port,
      repository: port.repository,
      storage: port.storage,
    );
    expect(
      snapshot.mirrorBaseline.keys,
      containsAll(<String>[
        'globalSettings',
        'profiles',
        'activeProfileId',
        'profilesSchemaVersion',
      ]),
    );

    // 失败的导入把内存改成了半成品。
    port.timeSchemes = <TimeScheme>[];
    port.profiles = <TimetableProfile>[];
    port.settings = const TimetableSettings(
      sections: _twoSections,
      semesterWeekCount: 25,
    );
    port.currentWeek = 1;
    port.currentDateWeek = 1;
    port.currentCalendarWeek = 1;
    port.currentDayOfWeek = 1;
    port.activeProfileId = null;
    port.scheduleDateRuleLastAppliedSignature = null;
    port.liveRuntime.lastLiveSnapshotSignature = 'live-after';
    port.liveRuntime.lastHomeWidgetSnapshotSignature = 'widget-after';

    snapshot.restoreMemory(port);

    expect(port.timeSchemes.single.name, '导入前作息');
    expect(port.profiles.single.id, 'p-before');
    expect(port.settings.semesterWeekCount, 18);
    expect(port.settings.activeTimeSchemeId, 'scheme-before');
    expect(port.currentWeek, 7);
    expect(port.currentDateWeek, 9);
    expect(port.currentCalendarWeek, 11);
    expect(port.currentDayOfWeek, 3);
    expect(port.activeProfileId, 'p-before');
    expect(port.scheduleDateRuleLastAppliedSignature, 'sig-before');
    // 去重签名必须一起清掉：不清的话下一次心跳会以为「内容没变」而不推，
    // 界面停在失败导入那一版的选课上。
    expect(port.liveRuntime.lastLiveSnapshotSignature, isNull);
    expect(port.liveRuntime.lastHomeWidgetSnapshotSignature, isNull);
    expect(port.clearLiveCourseIdCount, 1);
  });

  test('所需节次不超过当前作息时不动任何状态', () async {
    final port = _FakePort(settings: const TimetableSettings(sections: _twoSections));
    await port.storage.init();

    final message = await TimetableImportExportService.ensureSectionCapacityForImport(
      port,
      2,
    );

    expect(message, isNull);
    expect(port.persistActiveProfileStateCount, 0);
    expect(port.persistTimeSchemesCount, 0);
    expect(port.updateTimeSchemeCalls, isEmpty);
    expect(port.addedTimeSchemes, isEmpty);
    expect(port.settings.sectionCount, 2);
  });

  test('只有一张课表共用作息时就地扩节', () async {
    final port = _FakePort(
      settings: const TimetableSettings(
        sections: _twoSections,
        activeTimeSchemeId: 'scheme-a',
      ),
      timeSchemes: <TimeScheme>[_buildScheme('scheme-a', '我的作息', _twoSections)],
      profiles: <TimetableProfile>[
        _buildProfile(id: 'p1', name: '我的课表', schemeId: 'scheme-a'),
      ],
    );
    await port.storage.init();

    final message = await TimetableImportExportService.ensureSectionCapacityForImport(
      port,
      4,
    );

    expect(message, isNull);
    expect(port.updateTimeSchemeCalls.single.schemeId, 'scheme-a');
    expect(port.updateTimeSchemeCalls.single.name, '我的作息');
    expect(port.updateTimeSchemeCalls.single.sections.length, 4);
    // 就地扩：不新建副本，原作息 id 不变。
    expect(port.addedTimeSchemes, isEmpty);
    expect(port.timeSchemes.single.id, 'scheme-a');
    expect(port.settings.sectionCount, 4);
  });

  test('扩不满节数时返回提示且不写任何状态', () async {
    const packedSections = <SectionTime>[
      SectionTime(startTime: '23:00', endTime: '23:40'),
    ];
    final port = _FakePort(
      settings: const TimetableSettings(
        sections: packedSections,
        activeTimeSchemeId: 'scheme-a',
      ),
      timeSchemes: <TimeScheme>[
        _buildScheme('scheme-a', '晚课作息', packedSections),
      ],
      profiles: <TimetableProfile>[
        _buildProfile(
          id: 'p1',
          name: '晚课课表',
          schemeId: 'scheme-a',
          sections: packedSections,
        ),
      ],
    );
    await port.storage.init();

    final message = await TimetableImportExportService.ensureSectionCapacityForImport(
      port,
      3,
    );

    expect(message, 'section_count_below_usage|requiredMaxSection=3');
    expect(port.updateTimeSchemeCalls, isEmpty);
    expect(port.addedTimeSchemes, isEmpty);
    expect(port.persistActiveProfileStateCount, 0);
    expect(port.persistTimeSchemesCount, 0);
    expect(port.settings.sectionCount, 1);
  });

  test('多张课表共用作息时新建「导入补齐」副本', () async {
    final port = _FakePort(
      settings: const TimetableSettings(
        sections: _twoSections,
        activeTimeSchemeId: 'scheme-a',
      ),
      timeSchemes: <TimeScheme>[_buildScheme('scheme-a', '我的作息', _twoSections)],
      profiles: <TimetableProfile>[
        _buildProfile(id: 'p1', name: '课表一', schemeId: 'scheme-a'),
        _buildProfile(id: 'p2', name: '课表二', schemeId: 'scheme-a'),
      ],
    );
    await port.storage.init();

    final message = await TimetableImportExportService.ensureSectionCapacityForImport(
      port,
      4,
    );

    expect(message, isNull);
    expect(port.timeSchemes.length, 2);
    final duplicated = port.timeSchemes.last;
    expect(duplicated.name, '我的作息$importSupplementNameSuffix');
    expect(duplicated.id, isNot('scheme-a'));
    expect(duplicated.sections.length, 4);
    // 原作息不动，当前课表切到副本上。
    expect(port.timeSchemes.first.sections.length, 2);
    expect(port.settings.activeTimeSchemeId, duplicated.id);
    expect(port.settings.sectionCount, 4);
    expect(port.persistTimeSchemesCount, 1);
    expect(port.clearLiveCourseIdCount, 1);
  });

  test('回滚先把内存恢复，单键写失败不遮住其余键', () async {
    final port = _FakePort(
      settings: const TimetableSettings(
        sections: _twoSections,
        activeTimeSchemeId: 'scheme-before',
        semesterWeekCount: 18,
      ),
      timeSchemes: <TimeScheme>[
        _buildScheme('scheme-before', '导入前作息', _twoSections),
      ],
      profiles: <TimetableProfile>[
        _buildProfile(id: 'p-before', name: '导入前课表', schemeId: 'scheme-before'),
      ],
    );
    await port.storage.init();
    port.activeProfileId = 'p-before';
    port.currentWeek = 7;
    port.scheduleDateRuleLastAppliedSignature = 'sig-before';
    final snapshot = FullBackupRestoreSnapshot(
      port,
      repository: port.repository,
      storage: port.storage,
    );

    // 失败导入留下的半成品 + 模拟 saveProfiles 写盘失败。
    port.timeSchemes = <TimeScheme>[];
    port.profiles = <TimetableProfile>[];
    port.settings = const TimetableSettings(
      sections: _twoSections,
      semesterWeekCount: 25,
    );
    port.currentWeek = 1;
    port.activeProfileId = null;
    port.scheduleDateRuleLastAppliedSignature = null;
    port.repository.throwOnSaveProfiles = true;

    final failures =
        await TimetableImportExportService.restoreAfterFullBackupFailure(
          port,
          snapshot,
        );

    expect(failures.map((failure) => failure.name).toList(), <String>['profiles']);
    // 内存已先退回导入前。
    expect(port.timeSchemes.single.name, '导入前作息');
    expect(port.profiles.single.id, 'p-before');
    expect(port.settings.semesterWeekCount, 18);
    expect(port.currentWeek, 7);
    expect(port.activeProfileId, 'p-before');
    // profiles 写失败之后，剩下的键照样写（部分成功好过一条都不写）。
    expect(
      port.repository.calls,
      containsAllInOrder(<String>[
        'saveTimeSchemes',
        'saveProfiles',
        'setActiveProfileId',
        'savePartnerTimetableBinding',
      ]),
    );
    expect(port.notifyCount, 1);
    expect(port.updateLiveActivityCount, 1);
    expect(port.clearLiveCourseIdCount, 2);
  });

  test('实时活动刷新失败记为 live_surface 失败项', () async {
    final port = _FakePort(settings: const TimetableSettings(sections: _twoSections));
    await port.storage.init();
    final snapshot = FullBackupRestoreSnapshot(
      port,
      repository: port.repository,
      storage: port.storage,
    );
    port.throwOnUpdateLiveActivity = true;

    final failures =
        await TimetableImportExportService.restoreAfterFullBackupFailure(
          port,
          snapshot,
        );

    expect(
      failures.map((failure) => failure.name).toList(),
      <String>['live_surface'],
    );
    expect(port.notifyCount, 1);
  });

  test('没有快照时回滚直接返回空列表', () async {
    final port = _FakePort(settings: const TimetableSettings(sections: _twoSections));
    await port.storage.init();

    final failures =
        await TimetableImportExportService.restoreAfterFullBackupFailure(
          port,
          null,
        );

    expect(failures, isEmpty);
    expect(port.repository.calls, isEmpty);
    expect(port.notifyCount, 0);
    expect(port.clearLiveCourseIdCount, 0);
  });
}

const List<SectionTime> _twoSections = <SectionTime>[
  SectionTime(startTime: '08:00', endTime: '08:45'),
  SectionTime(startTime: '08:55', endTime: '09:40'),
];

TimeScheme _buildScheme(
  String id,
  String name,
  List<SectionTime> sections,
) {
  return TimeScheme(
    id: id,
    name: name,
    sections: sections,
    createdAt: DateTime(2026, 3, 2, 9),
    updatedAt: DateTime(2026, 3, 2, 9),
  );
}

TimetableProfile _buildProfile({
  required String id,
  required String name,
  String? schemeId,
  List<SectionTime> sections = _twoSections,
}) {
  return TimetableProfile(
    id: id,
    name: name,
    courses: const <Course>[],
    settings: TimetableSettings(
      sections: sections,
      activeTimeSchemeId: schemeId,
    ),
    currentWeek: 3,
    createdAt: DateTime(2026, 3, 2, 9),
    lastUsedAt: DateTime(2026, 3, 2, 9),
  );
}

/// 记录每个 key 的落盘顺序，用来验证「单键失败后继续写剩余键」。
class _RecordingRepository extends TimetableRepository {
  _RecordingRepository(super.storage);

  final List<String> calls = <String>[];
  bool throwOnSaveProfiles = false;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    calls.add('saveProfiles');
    if (throwOnSaveProfiles) {
      throw StateError('disk full');
    }
    return super.saveProfiles(profiles);
  }

  @override
  Future<void> saveTimeSchemes(List<TimeScheme> schemes) {
    calls.add('saveTimeSchemes');
    return super.saveTimeSchemes(schemes);
  }

  @override
  Future<void> saveLocationTimeGroups(List<LocationTimeGroup> groups) {
    calls.add('saveLocationTimeGroups');
    return super.saveLocationTimeGroups(groups);
  }

  @override
  Future<void> saveScheduleDateRules(List<ScheduleDateRule> rules) {
    calls.add('saveScheduleDateRules');
    return super.saveScheduleDateRules(rules);
  }

  @override
  Future<void> setActiveProfileId(String profileId) {
    calls.add('setActiveProfileId');
    return super.setActiveProfileId(profileId);
  }

  @override
  Future<void> clearActiveProfileId() {
    calls.add('clearActiveProfileId');
    return super.clearActiveProfileId();
  }

  @override
  Future<void> saveScheduleDateRuleLastAppliedSignature(String? signature) {
    calls.add('saveScheduleDateRuleLastAppliedSignature');
    return super.saveScheduleDateRuleLastAppliedSignature(signature);
  }

  @override
  Future<void> savePartnerTimetableBinding(PartnerTimetableBinding? binding) {
    calls.add('savePartnerTimetableBinding');
    return super.savePartnerTimetableBinding(binding);
  }
}

class _TimeSchemeUpdate {
  const _TimeSchemeUpdate(this.schemeId, this.name, this.sections);

  final String schemeId;
  final String name;
  final List<SectionTime> sections;
}

/// 只实现被测服务真正会碰的那些成员：其余一律 `UnimplementedError`，
/// 一旦服务悄悄扩了依赖面，测试立刻炸而不是静默通过。
class _FakePort implements TimetableImportExportPort {
  _FakePort({
    TimetableSettings? settings,
    List<TimeScheme>? timeSchemes,
    List<TimetableProfile>? profiles,
  }) : settings = settings ?? const TimetableSettings(sections: _twoSections),
       timeSchemes = timeSchemes ?? <TimeScheme>[],
       profiles = profiles ?? <TimetableProfile>[] {
    repository = _RecordingRepository(storage);
  }

  // `storage` / `repository` 2026-10-20 起退出端口（「注入依赖不进端口」）：
  // 不再是接口成员，所以都去掉 `@override`；`icsImporter` 干脆整条删掉。
  // 测试自己持有它们，构造快照 / 调服务入口时按具名参数直传——这正是收法
  // 要换来的形状：假端口不必再假装能提供仓储与解析器。
  final StorageService storage = StorageService.forTesting();
  late final _RecordingRepository repository;

  @override
  TimetableSettings settings;
  @override
  List<Course> courses = <Course>[];
  @override
  List<CourseTask> tasks = <CourseTask>[];
  @override
  List<ScheduleItem> scheduleItems = <ScheduleItem>[];
  @override
  List<Exam> exams = <Exam>[];
  @override
  List<TimetableProfile> profiles;
  @override
  List<TimeScheme> timeSchemes;
  @override
  List<LocationTimeGroup> locationTimeGroups = <LocationTimeGroup>[];
  @override
  List<ScheduleDateRule> scheduleDateRules = <ScheduleDateRule>[];
  @override
  PartnerTimetableBinding? partnerBinding;
  @override
  String? activeProfileId;
  @override
  String? scheduleDateRuleLastAppliedSignature;
  @override
  int currentWeek = 1;
  @override
  int currentDateWeek = 1;
  @override
  int currentCalendarWeek = 1;
  @override
  int currentDayOfWeek = 1;
  @override
  Map<String, int> lastImportDroppedCounts = <String, int>{};

  @override
  final LiveActivityRuntimeState liveRuntime = LiveActivityRuntimeState();

  String? currentLiveCourseId;
  int clearLiveCourseIdCount = 0;
  int notifyCount = 0;
  int persistActiveProfileStateCount = 0;
  int persistTimeSchemesCount = 0;
  int updateLiveActivityCount = 0;
  bool throwOnUpdateLiveActivity = false;
  final List<TimeScheme> addedTimeSchemes = <TimeScheme>[];
  final List<_TimeSchemeUpdate> updateTimeSchemeCalls = <_TimeSchemeUpdate>[];

  @override
  TimetableProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) {
        return profile;
      }
    }
    return null;
  }

  @override
  TimeScheme? get activeTimeScheme {
    final schemeId = settings.activeTimeSchemeId;
    if (schemeId == null) {
      return null;
    }
    for (final scheme in timeSchemes) {
      if (scheme.id == schemeId) {
        return scheme;
      }
    }
    return null;
  }

  @override
  DataTransferService get dataTransferService =>
      throw UnimplementedError('本测试不覆盖传输编码');

  @override
  Future<void> initialize() async {}

  @override
  Future<T> runMutation<T>(Future<T> Function() operation) {
    return operation();
  }

  @override
  void restoreImportedMemory(FullBackupRestoreSnapshot snapshot) {
    snapshot.restoreMemory(this);
  }

  @override
  void addTimeScheme(TimeScheme scheme) {
    addedTimeSchemes.add(scheme);
    timeSchemes = <TimeScheme>[...timeSchemes, scheme];
  }

  @override
  void addProfile(TimetableProfile profile) {
    profiles = <TimetableProfile>[...profiles, profile];
  }

  @override
  void clearCurrentLiveCourseId() {
    currentLiveCourseId = null;
    clearLiveCourseIdCount++;
  }

  @override
  Future<void> persistActiveProfileState({
    bool touchLastUsedAt = false,
    bool notifySync = true,
  }) async {
    persistActiveProfileStateCount++;
  }

  @override
  Future<void> persistTimeSchemes() async {
    persistTimeSchemesCount++;
  }

  @override
  Future<void> syncExamReminders() async {}

  @override
  Future<void> updateLiveActivity({bool syncScheduleSnapshot = true}) async {
    updateLiveActivityCount++;
    if (throwOnUpdateLiveActivity) {
      throw StateError('native surface unavailable');
    }
  }

  @override
  void notifyStateChanged() {
    notifyCount++;
  }

  @override
  void applyProfileState(TimetableProfile profile) {
    activeProfileId = profile.id;
  }

  @override
  TimetableSettings normalizeTimetableSettings(TimetableSettings settings) {
    return settings;
  }

  @override
  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  }) {
    return List<Course>.from(source);
  }

  @override
  Future<TimetableSettings> resolveSettingsAgainstTimeSchemes(
    TimetableSettings settings, {
    required String fallbackName,
  }) async {
    return settings;
  }

  @override
  int calculateWeekForDate(DateTime date, {int? fallbackWeek}) {
    return currentWeek;
  }

  @override
  int resolveCurrentDateWeek() {
    return currentDateWeek;
  }

  @override
  int previewImportedCourseRequiredSectionCount(
    List<Course> importedCourses, {
    required bool replaceExisting,
  }) {
    if (importedCourses.isEmpty) {
      return settings.sectionCount;
    }
    return importedCourses
        .map((course) => course.endSection)
        .reduce((left, right) => left > right ? left : right);
  }

  @override
  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  }) async {
    updateTimeSchemeCalls.add(_TimeSchemeUpdate(schemeId, name, sections));
    settings = settings.copyWith(activeTimeSchemeId: schemeId, sections: sections);
    timeSchemes = timeSchemes
        .map(
          (scheme) => scheme.id == schemeId
              ? scheme.copyWith(name: name, sections: sections)
              : scheme,
        )
        .toList();
    return null;
  }
}
