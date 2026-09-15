import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log_messages.dart';
import '../models/timetable_profile.dart';
import '../models/wallpaper_history.dart';
import '../utils/wallpaper_history.dart';
import 'app_log_service.dart';

/// 首页壁纸「最近使用」历史的**全局**存储。
///
/// 历史是设备级的：所有课表 profile 共用同一条。真机反馈（2026-09-15）：
/// 历史原本只存在 `TimetableSettings.wallpaperHistory` 里，而 settings 是按
/// profile 拆开的（`TimetableProfile.settings`），于是切课表历史跟着换。
///
/// **真源只有这里一处。** `TimetableSettings.wallpaperHistory` 降级成「只写不读的
/// 镜像」：备份 / 云同步 / 局域网传输的 payload 只序列化 `profiles`
/// （`app_sync_snapshot_service.dart` 的 `snapshotToJson`），往 settings 里继续写一份
/// 镜像，历史才继续随备份走；读取一律走本 service。
///
/// 坏数据（手改备份、旧版本、字符串数字）逐条丢弃，绝不因为一条坏值丢掉整条历史
/// —— 与 `WallpaperHistoryEntry.listFromJson` 同一口径。
class WallpaperHistoryService {
  WallpaperHistoryService._();

  /// 全局历史的 prefs 键。
  static const String preferenceKey = 'wallpaper_history_v1';

  /// 「把各 profile 的历史并进全局」只做一次的标记。
  ///
  /// 放在本 service 自己的键空间里（而不是 `StorageService` 的迁移 flag 体系）：
  /// 标记与数据同生共死最省事，将来清数据也一起清掉。
  static const String migratedKey = 'wallpaper_history_v1_migrated';

  /// 进程内缓存 + 通知：设置页进页面读一次，之后靠它刷新（列表是本页唯一的读者）。
  static final ValueNotifier<List<WallpaperHistoryEntry>> notifier =
      ValueNotifier<List<WallpaperHistoryEntry>>(const []);

  /// 读全局历史（顺带把 [notifier] 同步成同一份）。
  static Future<List<WallpaperHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = _decode(preferences.getString(preferenceKey));
    if (!listEquals(notifier.value, entries)) {
      notifier.value = entries;
    }
    return entries;
  }

  /// 覆盖写全局历史（自动截断到 [kMaxWallpaperHistoryEntries]）并刷新 [notifier]。
  static Future<void> save(List<WallpaperHistoryEntry> entries) async {
    final bounded = entries
        .where((entry) => entry.isValid)
        .take(kMaxWallpaperHistoryEntries)
        .toList(growable: false);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      preferenceKey,
      jsonEncode([for (final entry in bounded) entry.toJson()]),
    );
    if (!listEquals(notifier.value, bounded)) {
      notifier.value = bounded;
    }
  }

  /// 把若干份历史并进全局历史（幂等）：读 → [mergeWallpaperHistories] → 写。
  ///
  /// [histories] 按「由旧到新」给。主要用于两件事：把各 profile 各自的历史汇成
  /// 全局那一份（只做一次，见 [markMigrated]），以及从备份导入之后把备份里的历史
  /// 并回来。
  static Future<List<WallpaperHistoryEntry>> mergeAndSave(
    Iterable<List<WallpaperHistoryEntry>> histories,
  ) async {
    final current = await load();
    final merged = mergeWallpaperHistories([current, ...histories]);
    await save(merged);
    return merged;
  }

  /// 「各 profile 的历史已并进全局」是否已做过。
  static Future<bool> isMigrated() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(migratedKey) ?? false;
  }

  static Future<void> markMigrated() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(migratedKey, true);
  }

  /// 把各课表 profile 各自的历史并进全局历史；**只做一次**。
  ///
  /// 带完成标记，不做二次合并：用户清空「最近使用」之后，残留在各 profile 镜像
  /// 里的旧条目不能被复活。逻辑收在本 service 里（Provider 只留一行调用入口）：
  /// 那边是 god class，行数棘轮只减不增。
  static Future<void> migrateProfilesOnce(Iterable<TimetableProfile> profiles) async {
    try {
      if (await isMigrated()) {
        return;
      }
      await mergeAndSave(_historiesOf(profiles));
      await markMigrated();
    } catch (error, stackTrace) {
      // 迁移失败不能拖垮启动：标记还没置位，下次载入会再试一次。
      await AppLogService.instance.error(
        'wallpaper_history_global_migration_failed',
        AppLogMessages.wallpaperHistoryGlobalMigrationFailed,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 外部快照导入（云同步 / 备份 / 局域网）之后，把导入进来的历史并回全局历史。
  ///
  /// 与 [migrateProfilesOnce] 的区别：这里**每次导入都要跑**，不受一次性标记约束
  /// —— 备份里带的是各 profile 的镜像，恢复之后就靠这次并集把「最近使用」找回来。
  /// 并集幂等，重复跑不会重复堆条目。
  static Future<void> mergeImportedProfiles(
    Iterable<TimetableProfile> profiles,
  ) async {
    try {
      await mergeAndSave(_historiesOf(profiles));
    } catch (error, stackTrace) {
      await AppLogService.instance.error(
        'wallpaper_history_import_merge_failed',
        AppLogMessages.wallpaperHistoryImportMergeFailed,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 各 profile 镜像里的历史，按 profile 顺序（由旧到新交给并集去判新旧）。
  static List<List<WallpaperHistoryEntry>> _historiesOf(
    Iterable<TimetableProfile> profiles,
  ) => <List<WallpaperHistoryEntry>>[
    for (final profile in profiles) profile.settings.wallpaperHistory,
  ];

  static List<WallpaperHistoryEntry> _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      return WallpaperHistoryEntry.listFromJson(jsonDecode(raw));
    } catch (_) {
      // 整串 JSON 都坏了：当空历史，不让它冒到调用方。
      return const [];
    }
  }
}
