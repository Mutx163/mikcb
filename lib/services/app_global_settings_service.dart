import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log_messages.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'app_log_service.dart';

/// 「应用级偏好」的**全局**存储。
///
/// 导航形态、材质档位、主题外观、通用里的语言与交互开关，描述的是「软件长什么样、
/// 怎么用」，与某张课表无关 —— 但它们的字段全都长在 [TimetableSettings] 上，而
/// `TimetableSettings` 是 `TimetableProfile.settings`（按课表一份），于是切课表
/// 这些东西跟着换。用户口径（2026-09-22）：
///
/// > 软件导航设置，材质设置等等信息设置，比如是选择实体或者玻璃，这种信息，
/// > 应该独立处理，成为全局信息，而不是跟随课表
///
/// 做法与壁纸「最近使用」历史同源（见 `lib/services/wallpaper_history_service.dart`）：
/// **真源只有这里一处**，`TimetableSettings` 里那份降级成「只写不读的镜像」——
/// 备份 / 云同步 / 局域网传输的 payload 只序列化 `profiles`
/// （`app_sync_snapshot_service.dart` 的 `_buildPayloadMap`），往 settings 里继续写
/// 一份镜像，这些偏好才继续随备份走；读取一律走本 service（[overlay] 在载入 /
/// 切课表时把全局值盖上去）。
///
/// ## 为什么用 toJson/fromJson 的键名，而不是新写一个 44 字段的值对象
///
/// [extract] / [overlay] 因此各自只有几行，不必给 44 个字段各写一遍 `copyWith`
/// 参数，也天然绕开 `copyWith` 对可空字段「传 null = 不改」的坑 —— `clearLiquidGlassTuning`
/// 那一族标记就是为了绕它才存在的（`timetable_settings.dart`）。代价是键名是字符串，
/// 可能拼错/漏映射，用 `test/services/app_global_settings_service_test.dart` 逐键锁死。
///
/// ## 清单里为什么没有那两个「首页顶栏 / 星期栏模糊开关」
///
/// `homePageHeaderBlurEnabled` / `homePageWeekdayBarBlurEnabled` 是已下线的僵尸字段：
/// [TimetableSettings.fromJson] 里被无条件写死 `true`，内存里永远不可能是别的值。
/// 放进清单既无意义，也会让「覆盖后读数必须变化」那条测试永远红。
class AppGlobalSettingsService {
  AppGlobalSettingsService._();

  /// 全局那份的 prefs 键。
  static const String preferenceKey = 'app_global_settings_v1';

  /// 「把激活课表那一组字段搬成全局初始值」只做一次的标记。
  ///
  /// 与 [WallpaperHistoryService.migratedKey] 同口径：标记与数据同生共死，
  /// 将来清数据也一起清掉。
  static const String migratedKey = 'app_global_settings_v1_migrated';

  /// 全局字段清单（按 [TimetableSettings.toJson] 的键名）。
  ///
  /// 分组对应设置页里那个「应用」组 —— `settings_home_navigation.dart`（导航）、
  /// 外观编辑的材质面板与「外观」页（材质 / 主题）、`settings_general.dart`（通用）。
  /// 组件化改动时**这个列表就是契约**：往里加一个键，那项偏好立刻变成全局的，
  /// 不需要动 provider。
  static const List<String> keys = <String>[
    // —— 首页与导航（「首页与导航」页）——
    'homeNavigationForm',
    'glassDockActions',
    'glassDockShowAddButton',
    'glassDockButtonEntryId',
    'glassDockButtonIconName',
    'homeTitleStyle',
    'homeMenuStyle',
    'homeGridMenuActions',
    // 三个模块 Tab 开关的 UI 已删除（被 glassDockActions 取代），字段仍在模型里
    // 被序列化。一并归全局只是为了「导航类字段口径一致」，行为上无差别。
    'glassDockShowDayTab',
    'glassDockShowWeekTab',
    'glassDockShowSettingsTab',
    // —— 材质（外观编辑 → 材质面板）——
    'frostedGlassMode',
    'frostedBlurEnabled',
    'frostedSheetBlurSigma',
    'frostedSheetTintAlpha',
    'frostedSheetBarrierAlpha',
    'liquidGlassPreset',
    'liquidGlassTuning',
    'liquidGlassTuningDark',
    'linkLiquidGlassTuning',
    'darkGlassBoostEnabled',
    'liquidGlassDockEnabled',
    'courseCardSurfaceStyle',
    'courseCardGlassTuning',
    'homeBandGlassMaterial',
    'homePageTimeColumnBlurEnabled',
    // —— 主题与外观（「外观」页）——
    'appThemeMode',
    'appFontMode',
    'appFontWeight',
    'appTextScale',
    'themeSeedColor',
    'foruiTheme',
    'savedThemes',
    'themeCheckpointName',
    'themeCheckpointConfig',
    // —— 通用（「通用」页）——
    'appLocaleTag',
    'pageTransitionSpeed',
    'enableHaptics',
    'homePullQuickImportEnabled',
  ];

  /// 进程内缓存。`_applyProfileState` 是同步方法，覆盖时读这里，不再等 I/O。
  static Map<String, dynamic> _cache = const <String, dynamic>{};

  /// 当前全局那份（只读；测试与诊断用）。
  static Map<String, dynamic> get current => _cache;

  /// 从一份设置里抽出全局字段。
  static Map<String, dynamic> extract(TimetableSettings settings) {
    final json = settings.toJson();
    return <String, dynamic>{
      for (final key in keys) key: json[key],
    };
  }

  /// 把全局那份盖到 [base] 上，返回该课表「应该看到」的设置。
  ///
  /// 走 `toJson → fromJson`：只改清单里的键，其余键原样带回。清单里的键**都会写**，
  /// 值为 null 也一样写（可空调参字段靠这条才能被真正清空，`copyWith` 做不到）。
  static TimetableSettings overlay(TimetableSettings base) {
    if (_cache.isEmpty) {
      return base;
    }
    final json = base.toJson();
    for (final key in keys) {
      json[key] = _cache[key];
    }
    return TimetableSettings.fromJson(json);
  }

  /// 首次载入：未迁移过就**以激活课表那份为初始值**，否则读盘。
  ///
  /// 扫描是标量（不是并集），多张课表各调过一套材质时只能选一份 —— 选「激活的那张」
  /// 是唯一有依据的答案（用户当下看到的就是它）。与壁纸历史不同，历史是列表，
  /// 并集有明确语义；标量没有，所以这里不做并集。
  ///
  /// 必须在 `_applyProfileState` 之前 `await` 完 —— 覆盖要读缓存。
  ///
  /// 标记已置位但**数据没了 / 坏了**（写数据与置位之间被打断、手改坏了）时按
  /// 「没迁移」重来一次：宁可拿激活课表那份重建，也不能变成「全局那份整个丢失、
  /// 于是悄悄退回跟随课表」。
  static Future<void> resolveInitial({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(migratedKey) ?? false) {
      final decoded = _tryDecode(preferences.getString(preferenceKey));
      if (decoded != null) {
        _cache = decoded;
        return;
      }
    }
    final source = _pickSourceProfile(profiles, activeProfileId);
    if (source == null) {
      // 一张课表都没有：没有可依据的初始值，标记先不置位，下次载入再试。
      _cache = const <String, dynamic>{};
      return;
    }
    _cache = extract(source.settings);
    try {
      await _write(preferences, _cache);
      await preferences.setBool(migratedKey, true);
    } catch (error, stackTrace) {
      // 迁移失败不能拖垮启动：标记还没置位，下次载入会再试一次。
      await AppLogService.instance.error(
        'app_global_settings_migration_failed',
        AppLogMessages.appGlobalSettingsMigrationFailed,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 从内存那份设置里抽出全局字段落盘（与缓存相同则直接返回，不写盘）。
  ///
  /// 挂在 `_persistActiveProfileState` 上，于是**所有**设置写路径（设置页、
  /// 主题应用与撤销、保存/改名/删除主题、按日期规则批量套用作息……）自动覆盖。
  /// 课程编辑这类与全局字段无关的落盘，因为内容没变，这里是一次内存比较。
  static Future<void> syncFrom(TimetableSettings settings) async {
    final next = extract(settings);
    if (_sameAsCache(next)) {
      return;
    }
    _cache = next;
    final preferences = await SharedPreferences.getInstance();
    await _write(preferences, next);
  }

  /// 外部快照导入（云同步 / 备份 / 局域网）之后，从导入进来的那份重新推导全局值。
  ///
  /// 没有时间戳可比，所以口径就是**导入的那份为准**（与「恢复备份会恢复当时的
  /// 样子」一致）。备份里各课表的镜像可能陈旧，但 payload 的 `activeProfileId`
  /// 指向的那份一定是最新的（每次设置变更都随该课表落盘），所以只认它。
  static Future<void> refreshFromImportedProfiles({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
  }) async {
    final source = _pickSourceProfile(profiles, activeProfileId);
    if (source == null) {
      return;
    }
    await syncFrom(source.settings);
  }

  /// 测试用：清掉进程内缓存（静态状态会跨用例残留）。
  @visibleForTesting
  static void resetCacheForTest() {
    _cache = const <String, dynamic>{};
  }

  static TimetableProfile? _pickSourceProfile(
    List<TimetableProfile> profiles,
    String? activeProfileId,
  ) {
    if (profiles.isEmpty) {
      return null;
    }
    for (final profile in profiles) {
      if (profile.id == activeProfileId) {
        return profile;
      }
    }
    return profiles.first;
  }

  /// 缓存比较不能靠 `mapEquals`（值里有嵌套 Map / List，那是身份比较，恒不相等）。
  /// 两侧都由本类按 [keys] 的固定顺序构造，所以编码结果可比。
  static bool _sameAsCache(Map<String, dynamic> next) =>
      jsonEncode(next) == jsonEncode(_cache);

  static Future<void> _write(
    SharedPreferences preferences,
    Map<String, dynamic> value,
  ) => preferences.setString(preferenceKey, jsonEncode(value));

  /// 解出全局那份；**坏数据与「没有数据」都返回 null**（交给调用方决定是重建还是当空）。
  ///
  /// 解出来的表**总是补齐 [keys] 全部键**：盘上没写的键一律当 null。
  /// 全局那份是唯一真源，缺键就该读作「这项回默认」，而不是「回头去读课表的镜像」——
  /// 后者会让「哪来的值」取决于文件写了多少，是那类很难查的混合状态。
  static Map<String, dynamic>? _tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      return <String, dynamic>{
        for (final key in keys) key: map[key],
      };
    } catch (_) {
      return null;
    }
  }
}
