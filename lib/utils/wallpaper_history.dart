import '../models/timetable_settings.dart';
import '../models/wallpaper_history.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import 'home_page_background.dart';
import 'managed_image_storage.dart';

/// 「最近使用」保留的壁纸条数上限。
const int kMaxWallpaperHistoryEntries = 10;

/// 自选壁纸的受管目录名与文件名前缀。
///
/// 设置页、恢复默认与历史淘汰清理共用同一对常量，避免各自手写字符串漂移
/// （[deleteManagedImage] 的双保险正是靠它们判定「这张图归我管」）。
const String kHomePageWallpaperDirectoryName = 'home_page_wallpaper';
const String kHomePageWallpaperFilePrefix = 'wallpaper';

/// 已下线的「内置壁纸」预设在历史里的键前缀（`builtin:<预设>`）。
///
/// 内置壁纸功能已整体移除（2026-09-13），但老用户的持久化历史里可能仍留着
/// 这类条目。它们没有磁盘文件，一律视为不可用：展示时过滤、淘汰清理时跳过，
/// 用户下次切换壁纸后自然被顶出历史。
const String kLegacyBuiltInWallpaperKeyPrefix = 'builtin:';

/// 条目是否来自已下线的内置壁纸（无文件、不可用）。
bool isLegacyBuiltInWallpaperEntry(WallpaperHistoryEntry entry) =>
    entry.key.startsWith(kLegacyBuiltInWallpaperKeyPrefix);

/// 一次历史写入的结果。
class WallpaperHistoryPushResult {
  const WallpaperHistoryPushResult({
    required this.history,
    required this.evictedPaths,
  });

  /// 去重置顶并按上限裁剪后的新历史（最新在前）。
  final List<WallpaperHistoryEntry> history;

  /// 被挤出上限、需要顺手删除文件的图片路径；遗留的内置壁纸条目无文件，不入表。
  final List<String> evictedPaths;
}

/// 记录一次壁纸使用：同一 key 去重后置顶，超出上限的旧条目挤出。
///
/// 返回新历史与需删除的淘汰文件路径，由调用方落盘并异步清理，函数本身
/// 不碰磁盘——这样它可以在 widget 回调里同步调用，也便于单测。
WallpaperHistoryPushResult pushWallpaperHistory({
  required List<WallpaperHistoryEntry> history,
  required String key,
  double alignX = 0,
  double alignY = 0,
  int? usedAt,
}) {
  final trimmedKey = key.trim();
  if (trimmedKey.isEmpty) {
    return WallpaperHistoryPushResult(
      history: List<WallpaperHistoryEntry>.of(history),
      evictedPaths: const [],
    );
  }

  final next = <WallpaperHistoryEntry>[
    WallpaperHistoryEntry(
      key: trimmedKey,
      alignX: alignX,
      alignY: alignY,
      usedAt: usedAt ?? DateTime.now().millisecondsSinceEpoch,
    ),
    for (final entry in history)
      if (entry.isValid && entry.key != trimmedKey) entry,
  ];

  final kept = next.take(kMaxWallpaperHistoryEntries).toList(growable: false);
  final evictedPaths = <String>[
    for (final entry in next.skip(kMaxWallpaperHistoryEntries))
      if (!isLegacyBuiltInWallpaperEntry(entry)) entry.key,
  ];
  return WallpaperHistoryPushResult(history: kept, evictedPaths: evictedPaths);
}

/// 条目当前是否可用：背景图片文件必须还在。
///
/// 图片存在性走 [homePageImageProvider]，与首页共用同一份按路径记忆的结果，
/// 因此每帧过滤整个历史也不会反复摸盘。
bool wallpaperHistoryEntryAvailable(WallpaperHistoryEntry entry) {
  if (isLegacyBuiltInWallpaperEntry(entry)) {
    return false;
  }
  return homePageImageProvider(entry.key) != null;
}

/// 过滤掉文件已丢失 / 预设已下线的条目，保持原有先后顺序。
///
/// 只用于展示：不动持久化数据，文件恢复后条目会自己回来。
List<WallpaperHistoryEntry> availableWallpaperHistory(
  List<WallpaperHistoryEntry> history,
) => <WallpaperHistoryEntry>[
  for (final entry in history)
    if (wallpaperHistoryEntryAvailable(entry)) entry,
];

/// 把历史条目套用到设置上；条目不可用时返回 null（调用方按无效处理）。
///
/// 恢复该图被选用时的裁剪对齐值。不修改历史本身，置顶由
/// [pushWallpaperHistory] 负责。
TimetableSettings? settingsWithWallpaperHistoryEntry(
  TimetableSettings settings,
  WallpaperHistoryEntry entry,
) {
  if (isLegacyBuiltInWallpaperEntry(entry)) {
    return null;
  }
  if (homePageImageProvider(entry.key) == null) {
    return null;
  }
  return settings.copyWith(
    homePageWallpaperPath: entry.key,
    clearHomePageBackgroundImagePath: true,
    homePageWallpaperAlignX: entry.alignX,
    homePageWallpaperAlignY: entry.alignY,
    // 缩放是"当时那个取景"的一部分：只还原位置不还原缩放等于取景被改了一半。
    homePageWallpaperScale: entry.scale,
  );
}

/// 批量记录：把 [entries] 按「旧 → 新」顺序依次 [pushWallpaperHistory]，
/// 返回最终历史与累计的待删文件路径。
///
/// 切换背景时往往要同时补记「被换下的那一张」和「新选中的那一张」，
/// 逐条调用会分散淘汰信息，这里一次算完，调用方一次落盘、一次清理。
WallpaperHistoryPushResult rememberWallpaperHistoryBatch({
  required List<WallpaperHistoryEntry> history,
  required List<WallpaperHistoryEntry> entries,
}) {
  var current = history;
  final evicted = <String>[];
  for (final entry in entries) {
    if (!entry.isValid) {
      continue;
    }
    final result = pushWallpaperHistory(
      history: current,
      key: entry.key,
      alignX: entry.alignX,
      alignY: entry.alignY,
      usedAt: entry.usedAt == 0 ? null : entry.usedAt,
    );
    current = result.history;
    evicted.addAll(result.evictedPaths);
  }
  // 淘汰清单必须按**最终历史**再过滤一遍。
  //
  // 同一批里后一条可能把前一条挤出的那张图重新加回队首（典型：历史已满，
  // 用户点「最近使用」里最旧的一条 —— 调用方传 [被换下的, 新选中的]，第一条
  // 把最旧的 entry 挤出并列入待删，第二条又把它补回队首）。此时它仍在
  // history 里、`settings.homePageWallpaperPath` 也刚指向它，但 evicted 里还
  // 留着它 —— 照单删除就会删掉**正在使用的壁纸文件**。
  final keptKeys = <String>{for (final entry in current) entry.key};
  return WallpaperHistoryPushResult(
    history: current,
    evictedPaths: <String>[
      for (final path in evicted)
        if (!keptKeys.contains(path)) path,
    ],
  );
}

/// 把多份历史并成一份：按 key 去重、同 key 取「更新」的那条，最新在前，按上限截断。
///
/// [histories] 必须按「由旧到新」给：两条都缺 `usedAt`（老数据回退 0）时，取后看到
/// 的那条，顺序才符合直觉。用于两处：
/// - 把各 profile 各自的历史并成一条**全局**历史（历史已改成设备级共享）；
/// - 从备份导入之后，把备份里的历史并回全局历史。
List<WallpaperHistoryEntry> mergeWallpaperHistories(
  Iterable<List<WallpaperHistoryEntry>> histories,
) {
  final merged = <String, WallpaperHistoryEntry>{};
  final seenOrder = <String, int>{};
  var sequence = 0;
  for (final history in histories) {
    for (final entry in history) {
      sequence++;
      if (!entry.isValid) {
        continue;
      }
      final current = merged[entry.key];
      if (current == null) {
        merged[entry.key] = entry;
        seenOrder[entry.key] = sequence;
        continue;
      }
      final newer = entry.usedAt != current.usedAt
          ? entry.usedAt > current.usedAt
          : sequence > (seenOrder[entry.key] ?? 0);
      if (newer) {
        merged[entry.key] = entry;
        seenOrder[entry.key] = sequence;
      }
    }
  }
  final ordered = merged.values.toList()
    ..sort((a, b) {
      if (a.usedAt != b.usedAt) {
        return b.usedAt.compareTo(a.usedAt);
      }
      return (seenOrder[b.key] ?? 0).compareTo(seenOrder[a.key] ?? 0);
    });
  return ordered.take(kMaxWallpaperHistoryEntries).toList(growable: false);
}

/// 一批课表设置里**当前在用**的壁纸文件路径集合（含已下线的 legacy 字段）。
///
/// 壁纸「最近使用」历史是设备级共享的，而壁纸仍每个课表各自一张，于是"被历史
/// 淘汰 / 被恢复默认清掉"不再等于"没人用" —— 删文件前必须拿这份集合当白名单
/// （见 [deleteEvictedWallpaperFiles] 的 `inUsePaths`）。纯函数，便于单测。
Set<String> inUseWallpaperPaths(Iterable<TimetableSettings> settingsList) => {
  for (final settings in settingsList) ?resolveHomePageBackdropImagePath(settings),
};

/// 从「待删清单」里筛掉**不该删**的路径，返回真正可以删的那些。
///
/// 三条豁免：空串、遗留的内置壁纸键（不是文件路径）、以及 [inUsePaths]（正要被
/// 删、但还有人在用的图 —— 全局历史下别的课表可能正拿它当壁纸）。纯函数，便于单测。
List<String> deletableWallpaperPaths(
  Iterable<String> paths, {
  Set<String> inUsePaths = const <String>{},
}) => <String>[
  for (final path in paths)
    if (path.isNotEmpty &&
        !path.startsWith(kLegacyBuiltInWallpaperKeyPrefix) &&
        !inUsePaths.contains(path))
      path,
];

/// 删除被历史淘汰的图片壁纸文件。
///
/// 遗留的「内置壁纸」键不是文件路径，直接跳过；[deleteManagedImage] 自身
/// 也带「必须在本目录且前缀匹配」的双保险，越界路径静默忽略。
///
/// ⚠️ [inUsePaths] 是**全局历史下新增的安全阀**：历史是设备级共享的，而壁纸仍
/// 每个课表各自一张，于是"被历史淘汰"不再等于"没人用" —— 别的课表可能正拿这张图
/// 当壁纸。调用方必须把**所有 profile 的当前壁纸路径**传进来（见
/// `TimetableProvider.allProfilesWallpaperPaths`），在用的一律不删。
Future<void> deleteEvictedWallpaperFiles(
  Iterable<String> paths, {
  Set<String> inUsePaths = const <String>{},
}) async {
  for (final path in deletableWallpaperPaths(paths, inUsePaths: inUsePaths)) {
    // 两处按路径缓存的渲染产物要先失效、再删文件：
    // - 预模糊位图（首页玻璃卡片用）；
    // - 图片缓存（`evictHomePageImageCache` 内部先失效"文件存在"memo，**文件没了
    //   它会提前返回**，所以顺序不能反）。
    // 少了这一步，删掉的那张图会继续以旧位图渲染，重启才露馅。
    PreblurredWallpaperCache.instance.evict(path);
    evictHomePageImageCache(path);
    await deleteManagedImage(
      path,
      directoryName: kHomePageWallpaperDirectoryName,
      filePrefix: kHomePageWallpaperFilePrefix,
    );
    // 删完再失效一次：上一步的缓存失效会把"文件存在"memo 重新填成 true。
    invalidateHomePageBackdropFileExists(path);
  }
}
