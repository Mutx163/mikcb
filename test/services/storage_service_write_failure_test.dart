// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';

class _FailingPreferencesStore extends SharedPreferencesStorePlatform {
  _FailingPreferencesStore(this.values);

  final Map<String, Object> values;
  String? failKey;

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

  late _FailingPreferencesStore store;

  setUp(() {
    SharedPreferences.resetStatic();
    store = _FailingPreferencesStore(<String, Object>{
      'flutter.current_week': 3,
    });
    SharedPreferencesStorePlatform.instance = store;
    AppGlobalSettingsService.resetCacheForTest();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    AppGlobalSettingsService.resetCacheForTest();
  });

  test('storage write failure reloads the old process cache', () async {
    final storage = StorageService.forTesting();
    await storage.init();
    store.failKey = 'current_week';

    await expectLater(
      storage.setCurrentWeek(4),
      throwsA(isA<StateError>()),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('current_week'), 3);
  });

  test('global settings retry after a false platform write', () async {
    final settings = TimetableSettings.defaults().copyWith(appLocaleTag: 'ja');
    store.failKey = 'app_global_settings_v1';

    await expectLater(
      AppGlobalSettingsService.syncFrom(settings),
      throwsA(isA<StateError>()),
    );

    store.failKey = null;
    await AppGlobalSettingsService.syncFrom(settings);

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(AppGlobalSettingsService.preferenceKey);
    expect(raw, isNotNull);
    final stored = jsonDecode(raw!) as Map<String, dynamic>;
    expect(stored['appLocaleTag'], 'ja');
  });
}
