import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

class _FailOnceTimeSchemeStorage extends StorageService {
  _FailOnceTimeSchemeStorage() : super.forTesting();

  bool failNextSave = false;
  int profileFailuresRemaining = 0;
  bool activeProfileIdWriteObserved = false;

  /// 只让「日期规则上次套用签名」落盘失败：该键只有启动期批量套用会写，
  /// 导入路径不碰它。用它把启动链尾的后台写入停在失败态，又不会干扰导入
  /// 自己的写盘——这样断言「导入不受启动期失败牵连」才没有竞态。
  bool failRuleSignatureWrites = false;

  @override
  Future<void> saveTimeSchemes(List<TimeScheme> schemes) {
    if (failNextSave) {
      failNextSave = false;
      return Future<void>.error(
        StateError('test_time_scheme_write_failed'),
      );
    }
    return super.saveTimeSchemes(schemes);
  }

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    if (profileFailuresRemaining > 0) {
      profileFailuresRemaining--;
      return Future<void>.error(StateError('test_profile_write_failed'));
    }
    return super.saveProfiles(profiles);
  }

  @override
  Future<void> setActiveProfileId(String profileId) {
    activeProfileIdWriteObserved = true;
    return super.setActiveProfileId(profileId);
  }

  @override
  Future<void> saveScheduleDateRuleLastAppliedSignature(String? signature) {
    if (failRuleSignatureWrites) {
      return Future<void>.error(
        StateError('test_rule_signature_write_failed'),
      );
    }
    return super.saveScheduleDateRuleLastAppliedSignature(signature);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  test('single-profile backup restores recurring schedule metadata', () async {
    final provider = await createProvider();
    final schedule = ScheduleItem(
      id: 'backup-schedule',
      title: '固定自习',
      startDate: DateTime(2026, 4, 6),
      endDate: DateTime(2026, 5, 4),
      startTime: '19:00',
      endTime: '20:00',
      recurrence: ScheduleRecurrence.weekly,
      exceptionDates: [DateTime(2026, 4, 13)],
      reminderMinutesBefore: 15,
      enabled: false,
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );
    await provider.addScheduleItem(schedule);

    final content = provider.dataTransferService.buildBackupJson(
      profileName: provider.activeProfile?.name,
      courses: provider.courses,
      tasks: provider.tasks,
      scheduleItems: provider.scheduleItems,
      exams: provider.exams,
      settings: provider.settings,
      currentWeek: provider.currentWeek,
    );

    final restored = await createProvider();
    expect(await restored.importAppDataBackup(content), isNull);

    final restoredSchedule = restored.scheduleItems.single;
    expect(restoredSchedule.recurrence, ScheduleRecurrence.weekly);
    expect(restoredSchedule.exceptionDates, [DateTime(2026, 4, 13)]);
    expect(restoredSchedule.reminderMinutesBefore, 15);
    expect(restoredSchedule.enabled, isFalse);
  });

  test('full backup restore applies date rules and location groups', () async {
    final source = await createProvider();
    final scheme = await source.createTimeScheme(
      name: '备份作息',
      sections: const [SectionTime(startTime: '10:00', endTime: '10:45')],
    );
    final group = await source.createLocationTimeGroup(
      name: '备份教学楼',
      timeSchemeId: scheme.id,
      keywords: const [LocationKeyword(pattern: 'B')],
    );
    final ruleResult = await source.createScheduleDateRule(
      name: '备份日期规则',
      timeSchemeId: scheme.id,
      startDate: '2026-09-01',
      endDate: '2026-09-07',
    );
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );

    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
    final restored = await createProvider();
    expect(await restored.importFullAppDataBackup(content), isNull);

    expect(restored.scheduleDateRules.single.id, ruleResult.rule.id);
    expect(
      restored.scheduleDateRules.single.timeSchemeId,
      ruleResult.rule.timeSchemeId,
    );
    expect(restored.locationTimeGroups.single.id, group.id);
    expect(restored.locationTimeGroups.single.timeSchemeId, group.timeSchemeId);
    expect(restored.timeSchemes.any((item) => item.id == scheme.id), isTrue);

    final reloaded = await createProvider();
    expect(reloaded.scheduleDateRules.single.id, ruleResult.rule.id);
    expect(reloaded.locationTimeGroups.single.id, group.id);
  });

  test('startup migration write failure does not abort provider init', () async {
    final storage = _FailOnceTimeSchemeStorage()..failNextSave = true;
    final provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );

    await provider.initialize();

    expect(provider.profiles, isNotEmpty);
  });

  test('startup background write failure does not poison later imports', () async {
    final source = await createProvider();
    final scheme = await source.createTimeScheme(
      name: '启动失败回归作息',
      sections: const [SectionTime(startTime: '10:00', endTime: '10:45')],
    );
    final today = ScheduleDateRuleLogic.formatIsoDate(DateTime.now());
    await source.createScheduleDateRule(
      name: '今日生效规则',
      timeSchemeId: scheme.id,
      startDate: today,
      endDate: today,
    );
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );

    // 上面建规则时已经把「上次套用签名」写进去了，清掉它，target 启动才会
    // 真的走到批量套用并落盘——启动链尾的这次写盘失败正是要构造的前提。
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('schedule_date_rule_last_applied_signature');

    final storage = _FailOnceTimeSchemeStorage()
      ..failRuleSignatureWrites = true;
    final target = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await target.initialize();

    // 导入只该等启动写入收尾，不该把那次与导入毫无关系的异常原样抛出来。
    expect(await target.importFullAppDataBackup(content), isNull);
  });

  test('full backup write failure restores the previous in-memory state', () async {
    final source = await createProvider();
    await source.updateTimetableSettings(
      source.settings.copyWith(semesterWeekCount: 21),
    );
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );

    final targetStorage = _FailOnceTimeSchemeStorage();
    final target = TimetableProvider(
      storageService: targetStorage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await target.initialize();
    final beforeProfileId = target.activeProfileId;
    final beforeWeekCount = target.settings.semesterWeekCount;
    final beforeTimeSchemeIds = target.timeSchemes.map((item) => item.id).toSet();

    targetStorage.failNextSave = true;
    expect(
      await target.importFullAppDataBackup(content),
      'import_file_unrecognized',
    );
    expect(target.activeProfileId, beforeProfileId);
    expect(target.settings.semesterWeekCount, beforeWeekCount);
    expect(
      target.timeSchemes.map((item) => item.id).toSet(),
      beforeTimeSchemeIds,
    );

    final reloadedStorage = _FailOnceTimeSchemeStorage();
    final reloaded = TimetableProvider(
      storageService: reloadedStorage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await reloaded.initialize();
    expect(reloaded.activeProfileId, beforeProfileId);
    expect(reloaded.settings.semesterWeekCount, beforeWeekCount);
  });

  test('rollback continues after a later storage key fails', () async {
    final source = await createProvider();
    await source.updateTimetableSettings(
      source.settings.copyWith(semesterWeekCount: 22),
    );
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );

    final targetStorage = _FailOnceTimeSchemeStorage();
    final target = TimetableProvider(
      storageService: targetStorage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await target.initialize();
    targetStorage.activeProfileIdWriteObserved = false;
    final beforeProfileId = target.activeProfileId;

    targetStorage.failNextSave = true;
    targetStorage.profileFailuresRemaining = 1;
    expect(
      await target.importFullAppDataBackup(content),
      'import_rollback_incomplete',
    );
    expect(targetStorage.activeProfileIdWriteObserved, isTrue);
    expect(target.activeProfileId, beforeProfileId);
  });
}
