// ignore_for_file: depend_on_referenced_packages

// 回归：回滚基准必须取自「导入写盘之前」，否则回滚中崩溃会把失败导入当结果恢复。
//
// 背景（2026-10-20 复审第 1 条）：`runSettingsMirrorTransaction` 自己抓的 before
// 是「此刻盘上的值」。备份 / 云快照导入是**先写目标、失败后再开事务回滚**，于是
// 恢复记录指向失败导入的半成品；回滚中途进程被杀，下一次启动恢复出来的正是那次
// 失败导入的内容，用户导入前的课表永久丢失。
//
// 本文件只覆盖存储层：抓基准 → 模拟失败导入写盘 → 回滚写一半失败 → 重启恢复。
// provider 级接线（回滚事务真的把这份基准写进 journal）见
// `test/services/full_backup_rollback_baseline_test.dart`。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 可控的 prefs 平台：让指定 key 的写入 / 删除像满磁盘或不可靠 `commit()`
/// 那样失败，用来把事务停在「恢复记录还在盘上」的状态。
class _ControllablePreferencesStore extends SharedPreferencesStorePlatform {
  _ControllablePreferencesStore(this.values);

  final Map<String, Object> values;

  /// 写入这个 key 时返回 false（值不落盘）。
  String? failSetKey;

  /// 删除这个 key 时返回 false（值不删除）。
  String? failRemoveKey;

  @override
  bool get isMock => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$failSetKey') {
      return false;
    }
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

  test('回滚中崩溃后，启动恢复的是导入前数据而不是失败导入的半成品', () async {
    const oldProfiles = '[{"id":"old-profile"}]';
    const importProfiles = '[{"id":"import-profile"}]';
    final store = _ControllablePreferencesStore(<String, Object>{
      'flutter.app_global_settings_v1': 'old-global',
      'flutter.timetable_profiles': oldProfiles,
      'flutter.active_timetable_profile_id': 'old-profile',
      'flutter.timetable_profiles_schema_version': 1,
    });
    SharedPreferencesStorePlatform.instance = store;
    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();

    // 修复后的调用姿势：导入写下第一个 key 之前先抓回滚基准。
    final baseline = storage.captureSettingsMirrorSnapshot();
    expect((baseline['profiles'] as Map)['value'], oldProfiles);
    expect((baseline['activeProfileId'] as Map)['value'], 'old-profile');
    expect((baseline['profilesSchemaVersion'] as Map)['value'], 1);

    // 失败的导入已经把半成品写进盘（import 里这几条都是事务之外的裸写）。
    await preferences.setString('timetable_profiles', importProfiles);
    await preferences.setString(
      'active_timetable_profile_id',
      'import-profile',
    );
    await preferences.setString('app_global_settings_v1', 'import-global');
    await preferences.setInt('timetable_profiles_schema_version', 2);

    // 回滚事务：目标写入直接失败；恢复阶段 schema 与 activeId 写回去了，
    // profiles 这条写不进去 —— 等价于「回滚写到一半进程被杀」，恢复记录留在盘上。
    store.failSetKey = 'timetable_profiles';
    await expectLater(
      storage.runSettingsMirrorTransaction<void>(
        () async => throw StateError('simulated_rollback_failure'),
        beforeOverride: baseline,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNotNull,
      reason: '恢复失败时不能删掉最后的恢复依据',
    );
    expect(preferences.getString('timetable_profiles'), importProfiles);

    // 模拟重启：新进程只读盘，走 init 里的恢复分支。
    store.failSetKey = null;
    SharedPreferences.resetStatic();
    StorageService().resetForTesting();
    final restarted = StorageService.forTesting();
    await restarted.init();
    final restored = await SharedPreferences.getInstance();

    expect(
      restored.getString('timetable_profiles'),
      oldProfiles,
      reason: '把失败导入当恢复结果写回 = 导入前的课表永久丢失',
    );
    expect(restored.getString('active_timetable_profile_id'), 'old-profile');
    expect(restored.getString('app_global_settings_v1'), 'old-global');
    expect(restored.getInt('timetable_profiles_schema_version'), 1);
    expect(
      restored.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
  });
}
