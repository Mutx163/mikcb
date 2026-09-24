import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course_glass_tuning.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

/// 应用级偏好（导航 / 材质 / 主题 / 通用）改全局之后，这份 service 是唯一真源。
/// 这里锁三件事：清单与模型对得上、覆盖真的生效且只动清单里的键、迁移选激活课表那份。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppGlobalSettingsService.resetCacheForTest();
  });

  /// 一份「清单里每个键都非 null」的应用级偏好：enum / bool / double / String /
  /// 可空 String / List&lt;String&gt; / 可空嵌套对象 / 对象列表都被覆盖到。
  ///
  /// 五个可空调参字段**必须都设**：`toJson` 对 null 是「不写这个键」，不设齐的话
  /// 「清单每个键都在 toJson 里」那条会把它们误判成拼错的键。
  TimetableSettings customized() => TimetableSettings.defaults().copyWith(
    // 导航
    homeNavigationForm: HomeNavigationForm.glassDock,
    homeTitleStyle: HomeTitleStyle.brand,
    homeMenuStyle: HomeMenuStyle.grid,
    homeGridMenuActions: const ['addCourse', 'settings'],
    glassDockActions: const ['day', 'settings'],
    glassDockShowAddButton: false,
    glassDockButtonEntryId: 'weather',
    glassDockButtonIconName: 'cloudFill',
    // 材质
    frostedGlassMode: FrostedGlassMode.liquidGlass,
    frostedBlurEnabled: false,
    liquidGlassPreset: LiquidGlassPreset.dense,
    liquidGlassTuning: LiquidGlassTuning.defaults,
    liquidGlassTuningDark: LiquidGlassTuning.defaults,
    courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
    courseCardGlassTuning: CourseGlassTuning.courseCard,
    homeBandGlassMaterial: 'solid',
    homePageTimeColumnBlurEnabled: true,
    // 主题外观
    appThemeMode: AppThemeMode.dark,
    appFontMode: AppFontMode.monospace,
    appFontWeight: 500,
    appTextScale: 1.2,
    themeSeedColor: '#010203',
    themeCheckpointName: '夜间',
    themeCheckpointConfig: const ThemeConfig(seedColor: '#010203'),
    savedThemes: [
      SavedTheme(
        id: 't1',
        name: '主题一',
        config: const ThemeConfig(seedColor: '#0a0b0c'),
        createdAt: DateTime(2026, 9, 22),
      ),
    ],
    // 通用
    appLocaleTag: 'en',
    pageTransitionSpeed: 0.6,
    enableHaptics: false,
    homePullQuickImportEnabled: true,
  );

  /// 把全局那份塞进缓存（走 [AppGlobalSettingsService.syncFrom] 的正式路径）。
  Future<void> seedGlobal(TimetableSettings source) =>
      AppGlobalSettingsService.syncFrom(source);

  test('清单里每个键都是 TimetableSettings.toJson 真的会写出来的键', () {
    // 用「每个键都非 null」那份来问：null 的字段 toJson 会整个不写这个键，
    // 拿默认值那份问会把五个可空调参字段误判成拼错的键。
    final json = customized().toJson();
    final missing = [
      for (final key in AppGlobalSettingsService.keys)
        if (!json.containsKey(key)) key,
    ];
    expect(missing, isEmpty, reason: '这些键在 toJson 里不存在（拼错或字段改名）：$missing');
  });

  test('extract 的键与清单严格一致', () {
    expect(
      AppGlobalSettingsService.extract(TimetableSettings.defaults()).keys,
      AppGlobalSettingsService.keys,
    );
  });

  test('overlay 把清单里的键全部换成全局那份，其它键原样不动', () async {
    final global = customized();
    await seedGlobal(global);

    // 换一份「别处都不同」的基座：全局字段回默认、非全局字段显式改掉。
    final base = TimetableSettings.defaults().copyWith(
      courseCardShowTeacher: false,
      timetableHideWeekends: true,
      homePageWallpaperPath: '/x/y.png',
    );
    final merged = AppGlobalSettingsService.overlay(base);

    expect(
      jsonEncode(AppGlobalSettingsService.extract(merged)),
      jsonEncode(AppGlobalSettingsService.extract(global)),
      reason: '清单里的每个键都应等于全局那份',
    );
    expect(merged.courseCardShowTeacher, isFalse, reason: '非全局字段不许被覆盖动过');
    expect(merged.timetableHideWeekends, isTrue);
    expect(merged.homePageWallpaperPath, '/x/y.png');
  });

  test('可空的调参字段能被全局那份真正清空', () async {
    await seedGlobal(TimetableSettings.defaults());
    // 基座带着一套参数，全局那份是 null（用户把调参关回预设档）。
    final base = TimetableSettings.defaults().copyWith(
      liquidGlassTuning: LiquidGlassTuning.defaults,
    );
    expect(base.liquidGlassTuning, isNotNull);

    expect(AppGlobalSettingsService.overlay(base).liquidGlassTuning, isNull);
  });

  test('没解析过全局那份时 overlay 原样返回（不白造对象）', () {
    final base = TimetableSettings.defaults();
    expect(identical(AppGlobalSettingsService.overlay(base), base), isTrue);
  });

  test('两个已下线的模糊开关不进清单：读写盘都会被写回 true', () {
    final json = TimetableSettings.defaults().toJson()
      ..['homePageHeaderBlurEnabled'] = false
      ..['homePageWeekdayBarBlurEnabled'] = false;
    final parsed = TimetableSettings.fromJson(json);
    expect(parsed.homePageHeaderBlurEnabled, isTrue);
    expect(parsed.homePageWeekdayBarBlurEnabled, isTrue);
    expect(
      AppGlobalSettingsService.keys,
      isNot(
        contains(anyOf('homePageHeaderBlurEnabled', 'homePageWeekdayBarBlurEnabled')),
      ),
    );
  });

  group('首次载入的迁移', () {
    TimetableProfile profile(String id, TimetableSettings settings) =>
        TimetableProfile(
          id: id,
          name: id,
          courses: const [],
          settings: settings,
          currentWeek: 1,
          createdAt: DateTime(2026, 9),
          lastUsedAt: DateTime(2026, 9),
        );

    test('以激活课表那份为初始值，而不是随便挑一张', () async {
      final a = profile('a', customized());
      final b = profile(
        'b',
        TimetableSettings.defaults().copyWith(homeTitleStyle: HomeTitleStyle.brand),
      );

      await AppGlobalSettingsService.resolveInitial(
        profiles: [a, b],
        activeProfileId: 'b',
      );

      expect(
        AppGlobalSettingsService.current['homeTitleStyle'],
        HomeTitleStyle.brand.value,
      );
      expect(
        AppGlobalSettingsService.current['homeMenuStyle'],
        HomeMenuStyle.list.value,
        reason: 'B 没改过菜单形态，全局也该是 B 的默认值',
      );
    });

    test('迁移会把结果落盘并置位标记', () async {
      await AppGlobalSettingsService.resolveInitial(
        profiles: [profile('a', customized())],
        activeProfileId: 'a',
      );

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(AppGlobalSettingsService.migratedKey), isTrue);
      final stored = jsonDecode(
        preferences.getString(AppGlobalSettingsService.preferenceKey)!,
      ) as Map<String, dynamic>;
      expect(stored['homeNavigationForm'], HomeNavigationForm.glassDock.value);
    });

    test('标记已置位后只读盘，不再看课表', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(AppGlobalSettingsService.migratedKey, true);
      await preferences.setString(
        AppGlobalSettingsService.preferenceKey,
        jsonEncode({'homeTitleStyle': HomeTitleStyle.brand.value}),
      );

      await AppGlobalSettingsService.resolveInitial(
        profiles: [profile('a', customized())],
        activeProfileId: 'a',
      );

      final merged = AppGlobalSettingsService.overlay(
        TimetableSettings.defaults(),
      );
      expect(merged.homeTitleStyle, HomeTitleStyle.brand);
      expect(
        merged.homeNavigationForm,
        HomeNavigationForm.classic,
        reason: '盘上没写的键当默认，不许回头去读课表里那份镜像',
      );
      expect(
        AppGlobalSettingsService.current.containsKey('homeNavigationForm'),
        isTrue,
        reason: '缓存那份也要补齐全部键（缺键当 null）',
      );
    });

    test('标记置位但数据丢了 / 坏了时按未迁移重建，不许静默退回跟随课表', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(AppGlobalSettingsService.migratedKey, true);
      await preferences.setString(
        AppGlobalSettingsService.preferenceKey,
        '{ 这不是 JSON',
      );

      await AppGlobalSettingsService.resolveInitial(
        profiles: [profile('a', customized())],
        activeProfileId: 'a',
      );

      expect(
        AppGlobalSettingsService.current['homeNavigationForm'],
        HomeNavigationForm.glassDock.value,
        reason: '拿激活课表那份重建，而不是当「没有全局覆盖」',
      );
      expect(
        jsonDecode(
          preferences.getString(AppGlobalSettingsService.preferenceKey)!,
        ),
        isA<Map<String, dynamic>>(),
        reason: '坏数据要被好数据盖掉',
      );
    });

    test('激活 id 匹配不上时退回第一张', () async {
      await AppGlobalSettingsService.resolveInitial(
        profiles: [profile('a', customized())],
        activeProfileId: 'zzz',
      );
      expect(AppGlobalSettingsService.current['appLocaleTag'], 'en');
    });

    test('一张课表都没有时不落盘、也不置位（下次载入再试）', () async {
      await AppGlobalSettingsService.resolveInitial(
        profiles: const [],
        activeProfileId: null,
      );

      expect(AppGlobalSettingsService.current, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(AppGlobalSettingsService.migratedKey),
        isNot(isTrue),
        reason: '没置位（键不存在时读数就是 null）',
      );
      expect(
        preferences.getString(AppGlobalSettingsService.preferenceKey),
        isNull,
      );
    });
  });

  test('syncFrom 内容没变时重复落盘结果一致（幂等）', () async {
    final global = customized();
    await seedGlobal(global);
    final first = (await SharedPreferences.getInstance())
        .getString(AppGlobalSettingsService.preferenceKey);

    await seedGlobal(global);
    await seedGlobal(global);

    expect(
      (await SharedPreferences.getInstance())
          .getString(AppGlobalSettingsService.preferenceKey),
      first,
    );
  });

  test('导入之后从导入的那份重新推导', () async {
    await seedGlobal(customized());

    await AppGlobalSettingsService.refreshFromImportedProfiles(
      profiles: [
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
      ],
      activeProfileId: 'imported',
    );

    expect(AppGlobalSettingsService.current['homeBandGlassMaterial'], 'solid');
    expect(AppGlobalSettingsService.current['appLocaleTag'], 'ja');
    expect(
      AppGlobalSettingsService.current['homeNavigationForm'],
      HomeNavigationForm.classic.value,
      reason: '导入那份覆盖全局，不是与旧的取并集',
    );
  });
}
