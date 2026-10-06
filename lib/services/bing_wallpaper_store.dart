import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bing_wallpaper.dart';

/// Bing 每日壁纸的**设备级**存储：画质档位、自动换开关与按天判据、已下文件的台账。
///
/// ## 为什么是设备级，而不是进 `TimetableSettings`
///
/// 壁纸本身仍是「每个课表各自一张」（`homePageWallpaperPath` 在 settings 里），但这三样
/// 都不是壁纸的属性，而是**这个 App 在这台设备上怎么取图**的偏好：
/// * 「自动换」问的是 App 的行为，不是「这份课表长什么样」；
/// * 画质档位与课表无关，且两个课表若各存一份，用户在 A 课表选 4K、切到 B 课表又被
///   悄悄按 1080 下载，是纯粹的困惑。
///
/// 放进 `TimetableSettings` 还会牵进那个 god class 的行数棘轮
/// （`test/architecture/dependency_guards_test.dart`），而设备级语义本就该跟已有的
/// `WallpaperHistoryService` 同一口径。
///
/// ## 为什么不随备份/云同步走
///
/// 这些值描述的是**本机的网络与磁盘现状**（今天下过哪几张、这张档位多大）。备份到另一台
/// 设备时，那个路径不在、图片也不在，带过去只是让自动换白跑一次。设备级即天然不参与。
class BingWallpaperStore {
  BingWallpaperStore._();

  static BingWallpaperStore? _instance;

  /// 单例（prefs 读写是异步的，构造器里没法加载）。
  static BingWallpaperStore get instance => _instance ??= BingWallpaperStore._();

  static const String _preferenceKey = 'bing_wallpaper_v1';

  /// 画质档位的偏好键。
  static const String resolutionKey = 'bing_wallpaper_resolution_v1';

  /// 自动换开关的偏好键。
  static const String autoApplyKey = 'bing_wallpaper_auto_apply_v1';

  /// 台账（= 图库下载缓存）保留的条数。
  ///
  /// 取 12 的理由（2026-10-06 用户问「看过的图重新打开要重新下载吗」才定的）：
  /// **图库一次只展示 8 天**，而缓存只留 4 条时，用户从第 5 张往回翻就必然重新下载 ——
  /// 缓存等于没起到作用。12 条能盖住「当前 8 天 + 最近挑过几张」。
  ///
  /// 上限存在的**唯一**理由是磁盘：每天自动换一年就是 365 个文件，不封顶会攒到
  /// 100 MB 以上（自动换不进「最近使用」，那条 10 条上限的清理路径管不到它）。
  /// 竖屏三档最大 764 KB（`high` 1440×3200），12 × 764 KB ≈ 9 MB，可以忽略。
  ///
  /// 早先是 4 条 —— 那是横屏档还在时定的（当时最大档 4K 有 3.5 MB，4 × 3.5 = 14 MB）。
  /// 横屏档删掉后按体积算就完全不紧了，于是从「条数」跟着上调。
  static const int kMaxDownloadedEntries = 12;

  /// 台账里记着的本地文件路径（最新在前）。
  ///
  /// 供「清理没人引用的壁纸文件」那条路径用：图库里下过、但用户没确认应用的图
  /// **不该当垃圾删掉** —— 它在台账里（= 缓存），删了下次打开就得重新下载一遍。
  List<String> get downloadedPaths =>
      <String>[for (final entry in _downloaded) entry.path];

  List<BingWallpaperItem>? _cachedItems;
  DateTime? _cachedItemsFetchedAt;
  BingWallpaperResolution? _resolutionOverride;
  bool? _autoApplyOverride;
  List<_DownloadedEntry>? _downloadedOverride;

  /// 已下文件的台账条目：`dateKey@档位` → 本地路径。
  List<_DownloadedEntry> get _downloaded {
    final override = _downloadedOverride;
    if (override != null) {
      return override;
    }
    final raw = _prefsString(_preferenceKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return <_DownloadedEntry>[
        for (final item in decoded)
          if (_DownloadedEntry.fromJson(item) case final _DownloadedEntry entry)
            entry,
      ];
    } on Object {
      // 整串坏掉：当作没有台账。台账只用于「别重复下载」与「封顶清理」，
      // 丢了最坏后果是多下一次图，绝不能因此抛错打断设置页。
      return const [];
    }
  }

  String? _prefsString(String key) => _prefs?.getString(key);

  SharedPreferences? _prefs;

  /// 画质档位；未设置时默认 [BingWallpaperResolution.standard]。
  ///
  /// 默认**竖屏 1080×1920**：用户 2026-10-06 明确「我们软件都是竖图」「不需要横屏的
  /// 显示」—— 横图铺到竖屏上会被 cover 裁掉七成横向。横屏档已从枚举里删掉。
  ///
  /// 同步读（不 await）：UI 拿它渲染档位胶囊。首帧读不到就落回默认档，等
  /// [load] 完成后 [notifier] 触发一次重建 —— 与「最近使用」那条历史
  /// 先空后填的口径一致。
  ///
  /// ⚠️ [load] 必须由启动流程调一次（`main.dart` 的 `_handleStartupFlows`）：它是
  /// **唯一**给 `_prefs` 赋值的地方，不调则本 getter 在冷启动后恒为默认档。
  BingWallpaperResolution get resolution =>
      _resolutionOverride ??
      _resolutionCache ??
      BingWallpaperResolution.standard;

  BingWallpaperResolution? _resolutionCache;

  /// 自动换开关。**默认关**：新功能不该在用户没选择时就联网换壁纸。
  bool get autoApplyEnabled => _autoApplyOverride ?? _autoApplyCache ?? false;

  bool? _autoApplyCache;

  /// 最近一次自动换用掉的那天的 `dateKey`；没换过为 null。
  String? get lastAutoAppliedDate {
    for (final entry in _downloaded) {
      if (entry.autoApplied) {
        return entry.dateKey;
      }
    }
    return null;
  }

  /// 已下文件的缓存清单（图库页用）。
  List<BingWallpaperItem> get cachedItems => _cachedItems ?? const [];

  /// 清单最后一次成功拉取的时间。
  DateTime? get cachedItemsFetchedAt => _cachedItemsFetchedAt;

  /// 进程内变更通知：设置页与图库页靠它刷新。
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// 从 prefs 载入全部字段并广播一次。
  ///
  /// 幂等、可重复调用。失败（prefs 不可用）时保持默认值，不抛错。
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _resolutionCache = BingWallpaperResolution.fromStorageKey(
        _prefs!.getString(resolutionKey),
      );
      _autoApplyCache = _prefs!.getBool(autoApplyKey) ?? false;
      _cachedItemsFetchedAt = _fromEpoch(_prefs!.getInt(_cachedAtKey));
      final raw = _prefs!.getString(_cachedItemsKey);
      if (raw != null && raw.isNotEmpty) {
        _cachedItems = BingWallpaperItem.listFromJson(jsonDecode(raw));
      } else {
        _cachedItems = const [];
      }
      notifier.value++;
    } on Object {
      // 读失败保持默认值：功能降级为「档位默认、自动换关」，比抛错安全。
    }
  }

  static const String _cachedItemsKey = 'bing_wallpaper_items_v1';
  static const String _cachedAtKey = 'bing_wallpaper_items_at_v1';

  static DateTime? _fromEpoch(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);

  Future<void> setResolution(BingWallpaperResolution value) async {
    _resolutionOverride = value;
    notifier.value++;
    await _persistString(resolutionKey, value.storageKey);
  }

  Future<void> setAutoApplyEnabled(bool value) async {
    _autoApplyOverride = value;
    notifier.value++;
    await _persistBool(autoApplyKey, value);
  }

  /// 缓存图库清单（只在拉成功时调用）。
  Future<void> saveCachedItems(List<BingWallpaperItem> items) async {
    _cachedItems = items;
    _cachedItemsFetchedAt = DateTime.now();
    notifier.value++;
    await _persistString(
      _cachedItemsKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
    await _persistInt(_cachedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 记一次「这张 / 这个档位已经下到 [path]」，并返回应当删除的溢出路径。
  ///
  /// 同键去重后置顶（最新在前），超出 [kMaxDownloadedEntries] 的返回给调用方去真删。
  /// **只记账，不碰磁盘** —— 与 `pushWallpaperHistory` 同一分工：调用方知道「还有谁在用
  /// 这张图」（别的课表可能正拿它当壁纸），所以删除必须走
  /// `deleteEvictedWallpaperFiles` 的白名单。
  Future<List<String>> recordApplied({
    required String dateKey,
    required BingWallpaperResolution resolution,
    required String path,
    bool autoApplied = true,
  }) async {
    final key = _DownloadedEntry.makeKey(dateKey, resolution);
    final next = <_DownloadedEntry>[
      _DownloadedEntry(
        dateKey: dateKey,
        resolution: resolution,
        path: path,
        autoApplied: autoApplied,
      ),
      for (final entry in _downloaded)
        if (entry.key != key) entry,
    ];
    final kept = next.take(kMaxDownloadedEntries).toList(growable: false);
    final evicted = <String>[
      for (final entry in next.skip(kMaxDownloadedEntries)) entry.path,
    ];
    _downloadedOverride = kept;
    notifier.value++;
    await _persistString(
      _preferenceKey,
      jsonEncode([for (final entry in kept) entry.toJson()]),
    );
    return evicted;
  }

  /// 撤回 [dateKey] 那一天的「今天已自动换过」标记，**保留**下载台账。
  ///
  /// ## 为什么需要它
  ///
  /// `maybeApplyDaily` 在**下载成功之后**就写下了 `autoApplied`，而真正把壁纸落到
  /// 设置里还差一步用户确认（设置页那条路径要过「调整位置」页，用户可能点「退出」）。
  /// 用户一旦退出，那一天就被判成「已换过」，当天剩下的启动/回前台全部被跳过 ——
  /// 表现是「我明明开了自动换，什么都没发生」，而且要等到第二天才恢复。
  ///
  /// 只翻标记、**不删台账条目**：文件已经下好了，保留它才能让用户再点一次时直接复用
  /// （[findExisting] 命中，不重新下），也仍在封顶清理的白名单里（不会被当垃圾删掉）。
  ///
  /// 幂等：当天没有自动换记录时什么都不做。
  Future<void> releaseAutoApplyClaim(String dateKey) async {
    final current = _downloaded;
    if (!current.any(
      (entry) => entry.dateKey == dateKey && entry.autoApplied,
    )) {
      return;
    }
    final next = <_DownloadedEntry>[
      for (final entry in current)
        if (entry.dateKey == dateKey && entry.autoApplied)
          _DownloadedEntry(
            dateKey: entry.dateKey,
            resolution: entry.resolution,
            path: entry.path,
            autoApplied: false,
          )
        else
          entry,
    ];
    _downloadedOverride = next;
    notifier.value++;
    await _persistString(
      _preferenceKey,
      jsonEncode([for (final entry in next) entry.toJson()]),
    );
  }

  /// 找一张已下过的图（同一张 + 同一档位），文件仍在就返回其路径。
  ///
  /// 避免同一天反复点同一张时重复下载。文件可能已被历史淘汰删掉，所以查存在性。
  Future<String?> findExisting(
    String dateKey,
    BingWallpaperResolution resolution,
  ) async {
    final key = _DownloadedEntry.makeKey(dateKey, resolution);
    for (final entry in _downloaded) {
      if (entry.key != key) {
        continue;
      }
      // 同步 `exists()`：这是台账查重，逐条 await 会让「连点 8 张」串成 8 次事件循环往返。
      if (File(entry.path).existsSync()) {
        return entry.path;
      }
    }
    return null;
  }

  Future<void> _persistString(String key, String value) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } on Object {
      // 持久化失败只让下次启动丢一份缓存，不影响本次功能。
    }
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Object {
      // 同上。
    }
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } on Object {
      // 同上。
    }
  }

  /// 单测用的重置：丢掉缓存的单例（**不清**持久化数据，prefs 由测试自己 mock）。
  @visibleForTesting
  static void debugResetForTesting() {
    _instance = null;
    notifier.value++;
  }
}

/// 台账里的一条：`dateKey@档位` → 本地路径。
@immutable
class _DownloadedEntry {
  const _DownloadedEntry({
    required this.dateKey,
    required this.resolution,
    required this.path,
    required this.autoApplied,
  });

  final String dateKey;
  final BingWallpaperResolution resolution;
  final String path;

  /// 是不是「自动换」写下的。
  ///
  /// [BingWallpaperStore.lastAutoAppliedDate] 只认自动换来的那一条：用户**手动**从图库
  /// 挑一张也算用上了今天那张，若把它算进「今天已换过」，自动换就会误以为已完成而跳过。
  final bool autoApplied;

  static String makeKey(String dateKey, BingWallpaperResolution resolution) =>
      '$dateKey@${resolution.storageKey}';

  String get key => makeKey(dateKey, resolution);

  Map<String, Object?> toJson() => <String, Object?>{
    'dateKey': dateKey,
    'resolution': resolution.storageKey,
    'path': path,
    'autoApplied': autoApplied,
  };

  /// 脏条目逐条丢弃（与 `WallpaperHistoryEntry.listFromJson` 同一口径）。
  static _DownloadedEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final dateKey = raw['dateKey'];
    final path = raw['path'];
    if (dateKey is! String || path is! String) {
      return null;
    }
    if (dateKey.trim().isEmpty || path.trim().isEmpty) {
      return null;
    }
    final resolution = raw['resolution'];
    return _DownloadedEntry(
      dateKey: dateKey.trim(),
      // 未知档位回退默认：宁可用错档位复用一张图，也不要因为存档里一个陌生字符串
      // 而把已下的图当成没下过、白白重下一遍。
      resolution: BingWallpaperResolution.fromStorageKey(
        resolution is String ? resolution : null,
      ),
      path: path.trim(),
      autoApplied: raw['autoApplied'] is bool
          ? raw['autoApplied']! as bool
          : true,
    );
  }
}