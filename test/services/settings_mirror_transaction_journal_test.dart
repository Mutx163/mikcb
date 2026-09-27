// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';

const _oldProfiles = '[{"id":"old-profile"}]';
const _newProfiles = '[{"id":"new-profile"}]';

Map<String, dynamic> _stringSnapshot(String? value) => <String, dynamic>{
      'present': value != null,
      'value': value,
    };

Map<String, dynamic> _intSnapshot(int? value) => <String, dynamic>{
      'present': value != null,
      'value': value,
    };

Map<String, dynamic> _beforeSnapshot({
  String? global = 'old-global',
  String? profiles = _oldProfiles,
  String? activeProfileId = 'old-profile',
  int? schemaVersion = 1,
}) =>
    <String, dynamic>{
      'globalSettings': _stringSnapshot(global),
      'profiles': _stringSnapshot(profiles),
      'activeProfileId': _stringSnapshot(activeProfileId),
      'profilesSchemaVersion': _intSnapshot(schemaVersion),
    };

Map<String, dynamic> _journal({
  String state = 'pending',
  Map<String, dynamic>? before,
}) =>
    <String, dynamic>{
      'version': 1,
      'transactionId': 'test-transaction',
      'state': state,
      'createdAtMillis': 1,
      'before': before ?? _beforeSnapshot(),
    };

class _FailingPreferencesStore extends SharedPreferencesStorePlatform {
  _FailingPreferencesStore(this.values);

  final Map<String, Object> values;
  String? failKey;

  /// When set, [remove] for this key reports failure **without** deleting it —
  /// what a full disk / an unreliable platform `commit()` actually does. The
  /// journal is then left on disk, which is the precondition the in-session
  /// recovery has to cope with.
  String? failRemoveKey;

  @override
  bool get isMock => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$failKey') {
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
  Future<Map<String, Object>> getAll() async => Map<String, Object>.from(values);

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

  test('normal settings mirror transaction clears its journal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_global_settings_v1': 'old-global',
      'timetable_profiles': _oldProfiles,
      'active_timetable_profile_id': 'old-profile',
      'timetable_profiles_schema_version': 1,
    });
    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();
    var wroteTargets = false;

    await storage.runSettingsMirrorTransaction(() async {
      wroteTargets = true;
      await preferences.setString(
        AppGlobalSettingsService.preferenceKey,
        'new-global',
      );
      final timestamp = DateTime.now();
      await storage.saveProfiles([
        TimetableProfile(
          id: 'new-profile',
          name: '新课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 1,
          createdAt: timestamp,
          lastUsedAt: timestamp,
        ),
      ]);
      await storage.setActiveProfileId('new-profile');
    });

    expect(wroteTargets, isTrue);
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
    expect(
      preferences.getString(AppGlobalSettingsService.preferenceKey),
      'new-global',
    );
    expect(preferences.getString('active_timetable_profile_id'), 'new-profile');
  });

  test('a journal the platform refuses to delete does not block later saves',
      () async {
    // Regression: the journal is removed *after* the targets are written, and
    // both cleanup sites swallow a platform `remove` failure. Recovery only ran
    // from _doInit, so a record left behind (full disk / unreliable commit())
    // made every later settings save throw already_pending until the process
    // was killed. The guard now recovers in-session.
    final store = _FailingPreferencesStore(<String, Object>{
      'flutter.app_global_settings_v1': 'old-global',
      'flutter.timetable_profiles': _oldProfiles,
      'flutter.active_timetable_profile_id': 'old-profile',
      'flutter.timetable_profiles_schema_version': 1,
    });
    SharedPreferencesStorePlatform.instance = store;

    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();

    // The platform now refuses to delete the journal record.
    store.failRemoveKey = StorageService.settingsMirrorTransactionKey;
    await storage.runSettingsMirrorTransaction(() async {
      await preferences.setString(
        AppGlobalSettingsService.preferenceKey,
        'new-global',
      );
    });

    // Precondition: the committed record is still on disk.
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNotNull,
    );

    // The next save must recover in-session instead of throwing. The cap here is
    // 16 for the reader: on the old code this threw
    // StateError('settings_mirror_transaction_already_pending').
    store.failRemoveKey = null;
    await storage.runSettingsMirrorTransaction(() async {
      await preferences.setString(
        AppGlobalSettingsService.preferenceKey,
        'newer-global',
      );
    });

    expect(
      preferences.getString(AppGlobalSettingsService.preferenceKey),
      'newer-global',
    );
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
  });

  test('a rolled-back settings save keeps app-level preferences device-global',
      () async {
    // Regression: the rollback path used to blank the in-process global-settings
    // cache instead of re-reading it. `overlay` returns `base` unchanged when the
    // cache is empty, so "app-level preferences are device-global" silently
    // stopped being true for the rest of the session — and `hasPendingChanges`
    // then reports true forever, so the next save of anything promotes the
    // active timetable's stale mirror to the new global truth.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_global_settings_v1': jsonEncode(<String, dynamic>{
        'homeTitleStyle': HomeTitleStyle.brand.value,
      }),
      'app_global_settings_v1_migrated': true,
      'timetable_profiles': _oldProfiles,
      'active_timetable_profile_id': 'old-profile',
      'timetable_profiles_schema_version': 1,
    });
    final storage = StorageService.forTesting();
    await storage.init();

    // Populate the cache the way provider init does.
    await AppGlobalSettingsService.resolveInitial(
      profiles: const [],
      activeProfileId: null,
    );
    expect(
      AppGlobalSettingsService.current['homeTitleStyle'],
      HomeTitleStyle.brand.value,
    );

    // Any failing transaction goes through the same restore path a failed save
    // does.
    await expectLater(
      storage.runSettingsMirrorTransaction<void>(
        () async => throw StateError('simulated_failure'),
      ),
      throwsA(isA<StateError>()),
    );

    // The global value is still on disk...
    final preferences = await SharedPreferences.getInstance();
    final onDisk =
        jsonDecode(
              preferences.getString(AppGlobalSettingsService.preferenceKey)!,
            )
            as Map<String, dynamic>;
    expect(onDisk['homeTitleStyle'], HomeTitleStyle.brand.value);
    // ...and, the part that used to break, the in-process cache still carries it
    // so `overlay` keeps applying the global value.
    expect(
      AppGlobalSettingsService.current['homeTitleStyle'],
      HomeTitleStyle.brand.value,
      reason: 'recovery must re-read the global key, not blank the cache',
    );
    final base = TimetableSettings.defaults().copyWith(
      homeTitleStyle: HomeTitleStyle.classic,
    );
    expect(
      AppGlobalSettingsService.overlay(base).homeTitleStyle,
      HomeTitleStyle.brand,
    );
  });

  test('target failure restores the old raw values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_global_settings_v1': 'old-global',
      'timetable_profiles': _oldProfiles,
      'active_timetable_profile_id': 'old-profile',
      'timetable_profiles_schema_version': 1,
    });
    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();

    await expectLater(
      storage.runSettingsMirrorTransaction(() async {
        await preferences.setString(
          AppGlobalSettingsService.preferenceKey,
          'new-global',
        );
        await preferences.setString('timetable_profiles', _newProfiles);
        throw StateError('simulated_target_failure');
      }),
      throwsA(isA<StateError>()),
    );

    expect(
      preferences.getString(AppGlobalSettingsService.preferenceKey),
      'old-global',
    );
    expect(preferences.getString('timetable_profiles'), _oldProfiles);
    expect(preferences.getString('active_timetable_profile_id'), 'old-profile');
    expect(preferences.getInt('timetable_profiles_schema_version'), 1);
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
  });

  test('startup restores a pending journal before reading profiles', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_global_settings_v1': 'new-global',
      'timetable_profiles': _newProfiles,
      'active_timetable_profile_id': 'new-profile',
      'timetable_profiles_schema_version': 2,
      StorageService.settingsMirrorTransactionKey: jsonEncode(_journal()),
    });

    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getString(AppGlobalSettingsService.preferenceKey),
      'old-global',
    );
    expect(preferences.getString('timetable_profiles'), _oldProfiles);
    expect(preferences.getString('active_timetable_profile_id'), 'old-profile');
    expect(preferences.getInt('timetable_profiles_schema_version'), 1);
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
  });

  test('startup only cleans a committed journal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_global_settings_v1': 'new-global',
      'timetable_profiles': _newProfiles,
      'active_timetable_profile_id': 'new-profile',
      'timetable_profiles_schema_version': 2,
      StorageService.settingsMirrorTransactionKey: jsonEncode(
        _journal(state: 'committed'),
      ),
    });

    final storage = StorageService.forTesting();
    await storage.init();
    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getString(AppGlobalSettingsService.preferenceKey),
      'new-global',
    );
    expect(preferences.getString('timetable_profiles'), _newProfiles);
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
  });

  test('journal write failure stops before target writes', () async {
    final store = _FailingPreferencesStore(<String, Object>{
      'flutter.app_global_settings_v1': 'old-global',
      'flutter.timetable_profiles': _oldProfiles,
      'flutter.active_timetable_profile_id': 'old-profile',
      'flutter.timetable_profiles_schema_version': 1,
    });
    SharedPreferencesStorePlatform.instance = store;
    final storage = StorageService.forTesting();
    await storage.init();
    store.failKey = StorageService.settingsMirrorTransactionKey;
    var wroteTargets = false;

    await expectLater(
      storage.runSettingsMirrorTransaction(() async {
        wroteTargets = true;
      }),
      throwsA(isA<StateError>()),
    );

    expect(wroteTargets, isFalse);
    expect(store.values['flutter.app_global_settings_v1'], 'old-global');
    expect(store.values['flutter.timetable_profiles'], _oldProfiles);
  });

  test('provider settings save uses and clears the mirror journal', () async {
    final now = DateTime.now();
    final profile = TimetableProfile(
      id: 'profile-1',
      name: '默认课表',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: now,
      lastUsedAt: now,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'did_migrate_app_logs_default': true,
      'did_migrate_live_hide_prefix_default': true,
      'timetable_profiles': jsonEncode([profile.toJson()]),
      'active_timetable_profile_id': profile.id,
      'time_schemes': '[]',
    });
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await provider.updateTimetableSettings(
      provider.settings.copyWith(appLocaleTag: 'ja'),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      isNull,
    );
    final global = jsonDecode(
      preferences.getString(AppGlobalSettingsService.preferenceKey)!,
    ) as Map<String, dynamic>;
    expect(global['appLocaleTag'], 'ja');
    final profiles = jsonDecode(
      preferences.getString('timetable_profiles')!,
    ) as List<dynamic>;
    expect(
      ((profiles.single as Map<String, dynamic>)['settings']
          as Map<String, dynamic>)['appLocaleTag'],
      'ja',
    );
    provider.dispose();
  });

  test('unknown journal version is preserved and blocks startup', () async {
    final raw = jsonEncode(<String, dynamic>{
      'version': 99,
      'transactionId': 'future',
      'state': 'pending',
      'before': _beforeSnapshot(),
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      StorageService.settingsMirrorTransactionKey: raw,
    });

    final storage = StorageService.forTesting();
    await expectLater(storage.init(), throwsA(isA<StateError>()));
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(StorageService.settingsMirrorTransactionKey),
      raw,
    );
  });
}
