import '../models/timetable_settings.dart';
import '../models/wallpaper_history.dart';
import '../ui/background/builtin_wallpaper.dart';
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

/// 条目是否是内置壁纸（背景身份键以 builtin: 开头）。
bool isBuiltInWallpaperHistoryEntry(WallpaperHistoryEntry entry) =>
    entry.key.startsWith(kBuiltInWallpaperKeyPrefix);

/// 一次历史写入的结果。
class WallpaperHistoryPushResult {
  const WallpaperHistoryPushResult({
    required this.history,
    required this.evictedPaths,
  });

  /// 去重置顶并按上限裁剪后的新历史（最新在前）。
  final List<WallpaperHistoryEntry> history;

  /// 被挤出上限、需要顺手删除文件的图片路径；内置壁纸无文件，不入表。
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
      if (!isBuiltInWallpaperHistoryEntry(entry)) entry.key,
  ];
  return WallpaperHistoryPushResult(history: kept, evictedPaths: evictedPaths);
}

/// 条目当前是否可用：内置预设必须仍是合法预设，图片文件必须还在。
///
/// 图片存在性走 [homePageImageProvider]，与首页共用同一份按路径记忆的结果，
/// 因此每帧过滤整个历史也不会反复摸盘。
bool wallpaperHistoryEntryAvailable(WallpaperHistoryEntry entry) {
  if (isBuiltInWallpaperHistoryEntry(entry)) {
    return builtInWallpaperOfHistoryEntry(entry) != null;
  }
  return homePageImageProvider(entry.key) != null;
}

/// 把内置壁纸条目还原成预设枚举；图片条目或非法预设返回 null。
BuiltInWallpaper? builtInWallpaperOfHistoryEntry(WallpaperHistoryEntry entry) {
  if (!isBuiltInWallpaperHistoryEntry(entry)) {
    return null;
  }
  return BuiltInWallpaper.fromValue(
    entry.key.substring(kBuiltInWallpaperKeyPrefix.length),
  );
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
/// - 内置条目：与点击内置预设卡完全同款——清掉图片路径（图片优先级更高，
///   不清就永远看不到内置底图），对齐归零。
/// - 图片条目：恢复当时的对齐值；**不清**内置壁纸，保留「清除图片后回退到
///   内置预设」这一既有语义。
/// 不修改历史本身，置顶由 [pushWallpaperHistory] 负责。
TimetableSettings? settingsWithWallpaperHistoryEntry(
  TimetableSettings settings,
  WallpaperHistoryEntry entry,
) {
  if (isBuiltInWallpaperHistoryEntry(entry)) {
    final wallpaper = builtInWallpaperOfHistoryEntry(entry);
    if (wallpaper == null) {
      return null;
    }
    return settings.copyWith(
      homePageBuiltInWallpaper: wallpaper.value,
      clearHomePageWallpaperPath: true,
      clearHomePageBackgroundImagePath: true,
      homePageWallpaperAlignX: 0,
      homePageWallpaperAlignY: 0,
    );
  }
  if (homePageImageProvider(entry.key) == null) {
    return null;
  }
  return settings.copyWith(
    homePageWallpaperPath: entry.key,
    clearHomePageBackgroundImagePath: true,
    homePageWallpaperAlignX: entry.alignX,
    homePageWallpaperAlignY: entry.alignY,
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
  return WallpaperHistoryPushResult(history: current, evictedPaths: evicted);
}

/// 删除被历史淘汰的图片壁纸文件。
///
/// 内置条目的 key 不是文件路径，直接跳过；[deleteManagedImage] 自身也带
/// 「必须在本目录且前缀匹配」的双保险，越界路径静默忽略。
Future<void> deleteEvictedWallpaperFiles(Iterable<String> paths) async {
  for (final path in paths) {
    if (path.isEmpty || path.startsWith(kBuiltInWallpaperKeyPrefix)) {
      continue;
    }
    await deleteManagedImage(
      path,
      directoryName: kHomePageWallpaperDirectoryName,
      filePrefix: kHomePageWallpaperFilePrefix,
    );
    invalidateHomePageBackdropFileExists(path);
  }
}
