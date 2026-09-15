import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper_history.dart';
import '../utils/wallpaper_history.dart';

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
