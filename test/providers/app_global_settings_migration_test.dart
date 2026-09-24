import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

/// 应用级偏好（导航 / 材质 / 主题外观 / 通用）改成全局之后，从**用户看得见的行为**
/// 这一层锁住：切课表不再换材质与导航形态、新建课表继承当前那套、备份恢复能把它们
/// 带回来，而真正属于某张课表的字段（壁纸、隐藏周末……）照旧跟着课表走。
///
/// 真源机制本身（extract / overlay / 迁移选谁）在
/// `test/services/app_global_settings_service_test.dart` 里单测。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // StorageService 的这两个键是私有的，这里按同一个字面量播种。
  const String profilesKey = 'timetable_profiles';
  const String activeProfileKey = 'active_timetable_profile_id';

  Map<String, Object?> profileJson({
    required String id,
    required TimetableSettings settings,
  }) => TimetableProfile(
    id: id,
    name: id,
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: DateTime(2026, 9),
    lastUsedAt: DateTime(2026, 9),
  ).toJson();

  Future<TimetableProvider> bootProvider({StorageService? storage}) async {
    final provider = TimetableProvider(
      storageService: storage ?? StorageService.forTesting(),
      liveActivitiesService: TestMiuiLiveActivitiesService(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    // 首帧之后还有 unawaited 的后台加载，排空掉再断言。
    await pumpEventQueue();
    return provider;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppGlobalSettingsService.resetCacheForTest();
  });

  test('首次载入：全局那份取激活课表的值，切课表不再跟着换', () async {
    SharedPreferences.setMockInitialValues({
      profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          settings: TimetableSettings.defaults().copyWith(
            homeBandGlassMaterial: 'liquid',
            appLocaleTag: 'en',
            frostedGlassMode: FrostedGlassMode.gaussian,
          ),
        ),
        profileJson(
          id: 'b',
          settings: TimetableSettings.defaults().copyWith(
            homeBandGlassMaterial: 'solid',
            appLocaleTag: 'ja',
            frostedGlassMode: FrostedGlassMode.liquidGlass,
          ),
        ),
      ]),
      activeProfileKey: 'b',
    });

    final provider = await bootProvider();

    expect(provider.activeProfileId, 'b');
    expect(provider.settings.homeBandGlassMaterial, 'solid');
    expect(provider.settings.appLocaleTag, 'ja');

    // 切到 A：A 自己那份是 liquid / en，但全局那份该盖过来。
    await provider.switchProfile('a');

    expect(provider.activeProfileId, 'a');
    expect(
      provider.settings.homeBandGlassMaterial,
      'solid',
      reason: '材质是设备级的，不许跟着课表换成 A 的旧值',
    );
    expect(provider.settings.appLocaleTag, 'ja');
    expect(
      provider.settings.frostedGlassMode,
      FrostedGlassMode.liquidGlass,
      reason: '整体材质档同样不许跟着换',
    );
  });

  test('改一次之后切课表仍然生效，新建的课表也继承', () async {
    final provider = await bootProvider();
    final firstId = provider.activeProfileId!;

    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeBandGlassMaterial: 'solid',
        appLocaleTag: 'ja',
      ),
    );

    final second = await provider.createProfile(name: '第二张');
    await provider.switchProfile(second.id);

    expect(provider.settings.homeBandGlassMaterial, 'solid');
    expect(provider.settings.appLocaleTag, 'ja');

    await provider.switchProfile(firstId);
    expect(provider.settings.homeBandGlassMaterial, 'solid');
  });

  test('真正属于某张课表的字段照旧跟着课表走', () async {
    SharedPreferences.setMockInitialValues({
      profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          settings: TimetableSettings.defaults().copyWith(
            timetableHideWeekends: true,
            courseCardShowTeacher: false,
          ),
        ),
        profileJson(
          id: 'b',
          settings: TimetableSettings.defaults().copyWith(
            timetableHideWeekends: false,
            courseCardShowTeacher: true,
          ),
        ),
      ]),
      activeProfileKey: 'a',
    });

    final provider = await bootProvider();
    expect(provider.settings.timetableHideWeekends, isTrue);

    await provider.switchProfile('b');

    expect(
      provider.settings.timetableHideWeekends,
      isFalse,
      reason: '隐藏周末是课表页的设置，仍按课表记',
    );
    expect(provider.settings.courseCardShowTeacher, isTrue);
  });

  test('全局那份落盘了，重启（新进程）之后还在；课表里也留了镜像给备份带走', () async {
    final provider = await bootProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeBandGlassMaterial: 'solid',
        appLocaleTag: 'ja',
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    final storedGlobal =
        jsonDecode(
              preferences.getString(AppGlobalSettingsService.preferenceKey)!,
            )
            as Map<String, dynamic>;
    expect(storedGlobal['homeBandGlassMaterial'], 'solid');

    // 镜像：备份 / 云同步的 payload 只序列化 profiles，靠它才能把这些偏好带走。
    final storedProfiles =
        jsonDecode(preferences.getString(profilesKey)!) as List<dynamic>;
    final activeSettings =
        (storedProfiles.first as Map<String, dynamic>)['settings']
            as Map<String, dynamic>;
    expect(activeSettings['homeBandGlassMaterial'], 'solid');

    // 模拟重启：缓存丢掉，重新读盘。
    AppGlobalSettingsService.resetCacheForTest();
    final rebooted = await bootProvider();

    expect(rebooted.settings.homeBandGlassMaterial, 'solid');
    expect(rebooted.settings.appLocaleTag, 'ja');
  });

  test('完整备份导入会从导入课表刷新全局设置', () async {
    final provider = await bootProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        appLocaleTag: 'en',
        homeBandGlassMaterial: 'solid',
      ),
    );

    final imported = provider.profiles.first.copyWith(
      id: 'imported',
      name: '导入的课表',
      settings: provider.profiles.first.settings.copyWith(
        appLocaleTag: 'ja',
        homeBandGlassMaterial: 'liquid',
      ),
    );
    final backupJson = DataTransferService().buildFullBackupJson(
      profiles: [imported],
      activeProfileId: imported.id,
      timeSchemes: provider.timeSchemes,
    );

    expect(await provider.importFullAppDataBackup(backupJson), isNull);
    expect(provider.settings.appLocaleTag, 'ja');
    expect(provider.settings.homeBandGlassMaterial, 'liquid');
    expect(AppGlobalSettingsService.current['appLocaleTag'], 'ja');
  });

  test('删除当前课表后把全局设置写回备用课表镜像', () async {
    SharedPreferences.setMockInitialValues({
      profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          settings: TimetableSettings.defaults().copyWith(appLocaleTag: 'en'),
        ),
        profileJson(
          id: 'b',
          settings: TimetableSettings.defaults().copyWith(appLocaleTag: 'zh'),
        ),
      ]),
      activeProfileKey: 'a',
    });

    final provider = await bootProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(appLocaleTag: 'ja'),
    );

    expect(await provider.deleteProfile('a'), isTrue);
    expect(provider.settings.appLocaleTag, 'ja');
    expect(provider.profiles.single.settings.appLocaleTag, 'ja');
  });

  test('删除当前课表后修改作息模板不会恢复旧镜像', () async {
    SharedPreferences.setMockInitialValues({
      profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          settings: TimetableSettings.defaults().copyWith(appLocaleTag: 'en'),
        ),
        profileJson(
          id: 'b',
          settings: TimetableSettings.defaults().copyWith(appLocaleTag: 'zh'),
        ),
      ]),
      activeProfileKey: 'a',
    });

    final provider = await bootProvider();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(appLocaleTag: 'ja'),
    );
    expect(await provider.deleteProfile('a'), isTrue);

    final scheme = provider.timeSchemes.first;
    expect(
      await provider.updateTimeScheme(
        schemeId: scheme.id,
        name: scheme.name,
        sections: scheme.sections,
      ),
      isNull,
    );
    expect(provider.settings.appLocaleTag, 'ja');
  });

  test('主题撤销会把全局字段一起退回去', () async {
    final provider = await bootProvider();
    final beforeSeed = provider.settings.themeSeedColor;

    await provider.applyThemeWithUndo(
      const ThemeConfig(
        seedColor: '#010203',
      ).applyToSettings(provider.settings),
      themeName: '测试主题',
    );
    expect(provider.settings.themeSeedColor, '#010203');

    await provider.undoThemeChange();

    expect(provider.settings.themeSeedColor, beforeSeed);
    final preferences = await SharedPreferences.getInstance();
    final storedGlobal =
        jsonDecode(
              preferences.getString(AppGlobalSettingsService.preferenceKey)!,
            )
            as Map<String, dynamic>;
    expect(
      storedGlobal['themeSeedColor'],
      beforeSeed,
      reason: '撤销也要回落到全局那份，不能只改内存',
    );
  });

  test('导入快照之后全局那份来自导入的激活课表', () async {
    final storage = StorageService.forTesting();
    final provider = await bootProvider(storage: storage);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeBandGlassMaterial: 'liquid',
        appLocaleTag: 'en',
      ),
    );

    // 模拟外部快照落盘：真实导入也走同一份存储层，缓存与盘保持一致。
    await storage.saveProfiles([
      TimetableProfile(
        id: 'imported',
        name: '导入的课表',
        courses: const [],
        settings: TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: 'solid',
          appLocaleTag: 'ja',
        ),
        currentWeek: 1,
        createdAt: DateTime(2026, 9),
        lastUsedAt: DateTime(2026, 9),
      ),
    ]);
    await storage.setActiveProfileId('imported');

    await provider.reloadFromStorageAfterExternalApply();

    expect(provider.settings.homeBandGlassMaterial, 'solid');
    expect(provider.settings.appLocaleTag, 'ja');
    expect(
      AppGlobalSettingsService.current['appLocaleTag'],
      'ja',
      reason: '全局那份也要跟着导入重推，不能只在内存里盖一下',
    );
  });
}
