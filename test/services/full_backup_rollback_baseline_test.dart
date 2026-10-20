// ignore_for_file: depend_on_referenced_packages

// 回归：完整备份导入失败后的回滚事务，写进恢复记录的 before 必须是**导入前**
// 的盘上值，而不是导入写下的半成品。
//
// 背景（2026-10-20 复审第 1 条）：`_timetableImportFullAppDataBackup` 会先把导入
// 数据裸写进 profiles / activeProfileId / 全局设置键，失败后才开事务回滚。事务
// 若自己去读「此刻盘上值」，恢复记录就指向那次失败导入；回滚中途被杀，下次启动
// 恢复出来的正是失败导入，导入前的课表永久丢失。
//
// 存储层的崩溃恢复路径见 `settings_mirror_rollback_baseline_test.dart`。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';

class _ControllablePreferencesStore extends SharedPreferencesStorePlatform {
  _ControllablePreferencesStore(this.values);

  final Map<String, Object> values;
  String? failRemoveKey;

  @override
  bool get isMock => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (key == 'flutter.$failRemoveKey') {
      return false;
    }
    values.remove(key);
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async =>
      Map<String, Object>.from(values);

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}

/// 让「写完 profiles 之后」的那一步 activeProfileId 失败一次，把完整备份导入
/// 推进回滚分支；回滚本身继续正常写盘。
class _FailOnActiveProfileIdStorage extends StorageService {
  _FailOnActiveProfileIdStorage() : super.forTesting();

  bool failNextActiveProfileIdWrite = false;

  @override
  Future<void> setActiveProfileId(String profileId) {
    if (failNextActiveProfileIdWrite) {
      failNextActiveProfileIdWrite = false;
      return Future<void>.error(
        StateError('test_active_profile_id_write_failed'),
      );
    }
    return super.setActiveProfileId(profileId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();
  });

  test('失败导入的回滚事务用导入前的盘上基准写 journal', () async {
    // 源：一份可识别的完整备份（档案 id 与本机不同）。
    SharedPreferences.setMockInitialValues(<String, Object>{
      'did_migrate_app_logs_default': true,
      'did_migrate_live_hide_prefix_default': true,
    });
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();
    final source = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await source.initialize();
    final sourceProfileId = source.profiles.first.id;
    final content = source.dataTransferService.buildFullBackupJson(
      profiles: source.profiles,
      activeProfileId: source.activeProfileId,
      timeSchemes: source.timeSchemes,
      scheduleDateRules: source.scheduleDateRules,
      locationTimeGroups: source.locationTimeGroups,
    );
    source.dispose();

    // 目标：本机已有自己的课表，且 prefs 允许注入失败。
    final localProfile = TimetableProfile(
      id: 'local-profile',
      name: '本机课表',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: DateTime(2026, 9, 2),
      lastUsedAt: DateTime(2026, 9, 2),
    );
    SharedPreferences.resetStatic();
    final store = _ControllablePreferencesStore(<String, Object>{
      'flutter.did_migrate_app_logs_default': true,
      'flutter.did_migrate_live_hide_prefix_default': true,
      'flutter.timetable_profiles': jsonEncode([localProfile.toJson()]),
      'flutter.active_timetable_profile_id': 'local-profile',
      'flutter.timetable_profiles_schema_version': 1,
      'flutter.time_schemes': '[]',
      'flutter.app_global_settings_v1': jsonEncode(<String, dynamic>{
        'homeTitleStyle': HomeTitleStyle.brand.value,
      }),
    });
    SharedPreferencesStorePlatform.instance = store;
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();

    final storage = _FailOnActiveProfileIdStorage();
    final target = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await target.initialize();
    final preferences = await SharedPreferences.getInstance();
    expect(target.activeProfileId, 'local-profile');
    expect(
      preferences.getString('timetable_profiles'),
      contains('local-profile'),
    );

    // 导入在写完 profiles 之后失败（activeProfileId 这一步），触发自动回滚；
    // 让删除恢复记录也失败，好直接检查回滚事务写进去的 before。
    storage.failNextActiveProfileIdWrite = true;
    store.failRemoveKey = StorageService.settingsMirrorTransactionKey;
    expect(
      await target.importFullAppDataBackup(content),
      'import_file_unrecognized',
    );

    final journalRaw = preferences.getString(
      StorageService.settingsMirrorTransactionKey,
    );
    expect(journalRaw, isNotNull, reason: 'remove 失败时恢复记录应留在盘上');
    final journal = jsonDecode(journalRaw!) as Map<String, dynamic>;
    expect(journal['state'], 'committed');
    final before = journal['before'] as Map<String, dynamic>;
    final baselineProfiles = (before['profiles'] as Map)['value'] as String;
    expect(
      baselineProfiles,
      contains('local-profile'),
      reason: '回滚基准必须是导入前的本机档案',
    );
    expect(
      baselineProfiles,
      isNot(contains(sourceProfileId)),
      reason: 'before 指向导入半成品，正是回滚崩溃后丢数据的根因',
    );
    expect((before['activeProfileId'] as Map)['value'], 'local-profile');
    expect((before['profilesSchemaVersion'] as Map)['value'], 1);

    // 回滚本身把本机数据写回去了，导入的档案没有留在盘上。
    expect(
      preferences.getString('timetable_profiles'),
      isNot(contains(sourceProfileId)),
    );
    target.dispose();
  });
}
