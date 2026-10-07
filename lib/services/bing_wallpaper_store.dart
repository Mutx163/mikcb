import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bing_wallpaper.dart';
import '../models/wallpaper_daily_source.dart';
import '../utils/home_page_background.dart';

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

  /// 每日壁纸**图源**的偏好键（2026-10-07 新增）。
  static const String sourceKey = 'wallpaper_daily_source_v1';

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

  /// 每日壁纸用哪个图源。
  ///
  /// ## 默认仍是 Bing，不是 Wallhaven
  ///
  /// 理由是「每天真的换一张」：Bing 是**日历驱动**的，同一天 worldwide 一张、内容
  /// 当天固定；Wallhaven 没有每日端点（`random`/`featured` 实测 404），「每天一张」
  /// 只能靠翻页偏移去凑，一旦用户装了 App 之后没几天、或他手动翻过图库，「今天那张」
  /// 就可能与昨天重复。**先能用上竖图**的价值高于「每天一定换新的」。
  ///
  /// 用户可在设置里切过去；切过去之后「每天自动更换」走 [WallhavenWallpaperService]。
  WallpaperDailySource get dailySource =>
      _sourceOverride ?? _sourceCache ?? WallpaperDailySource.bing;

  WallpaperDailySource? _sourceOverride;
  WallpaperDailySource? _sourceCache;

  Future<void> setDailySource(WallpaperDailySource value) async {
    // 真切换才自增世代号（重复设同一个值不算切换）：判据见 [sourceEpoch]。
    if ((_sourceOverride ?? _sourceCache ?? WallpaperDailySource.bing) !=
        value) {
      _sourceEpochOverride = sourceEpoch + 1;
    }
    _sourceOverride = value;
    notifier.value++;
    await _persistString(sourceKey, value.storageKey);
    await _persistInt(epochKey, sourceEpoch);
  }

  /// 图源世代号的存档键。
  static const String epochKey = 'wallpaper_daily_source_epoch_v1';

  /// 「最近一次自动换成功时的图源世代号」的存档键。
  static const String autoAppliedEpochKey = 'wallpaper_auto_applied_epoch_v1';

  /// 换源行为的存档键。
  static const String sourceFallbackKey = 'wallpaper_source_fallback_v1';

  /// 「Bing 失败时要不要换源」（见 [WallpaperSourceFallback]）。
  WallpaperSourceFallback get sourceFallback =>
      _sourceFallbackOverride ??
      _sourceFallbackCache ??
      WallpaperSourceFallback.onAutoApplyOnly;

  WallpaperSourceFallback? _sourceFallbackOverride;
  WallpaperSourceFallback? _sourceFallbackCache;

  Future<void> setSourceFallback(WallpaperSourceFallback value) async {
    _sourceFallbackOverride = value;
    notifier.value++;
    await _persistString(sourceFallbackKey, value.storageKey);
  }

  /// 图源切换的**世代号**：每次真切换（不是每次调用）自增 1。
  ///
  /// ## 为什么需要它
  ///
  /// [lastAutoAppliedDate] 是「今天已经换过了」的**唯一**判据，而它的键只由
  /// `dateKey + 档位 + 尺寸` 构成。于是用户上午用 Bing 自动换过、下午切到 Wallhaven，
  /// 那天会被判成「已换过」而**静默跳过** —— 看起来就是「我切了图源但什么都没发生」。
  ///
  /// 不删台账（删了会让已下的图被当成没下过、白重下一次，5–11 MB 的竖图代价太大），
  /// 改成在判据里再加一维：`lastAutoAppliedSourceEpoch == sourceEpoch` 才算「今天
  /// 换过」。切源让两者不等 → 当天立刻可以再换一次，且换完记下新的 epoch。
  int get sourceEpoch => _sourceEpochOverride ?? _sourceEpochCache ?? 0;

  int? _sourceEpochOverride;
  int? _sourceEpochCache;

  /// 最近一次自动换成功时的图源世代号；没换过为 null。
  int? get lastAutoAppliedSourceEpoch => _lastAutoAppliedSourceEpochOverride;

  int? _lastAutoAppliedSourceEpochOverride;

  /// 记下「最近一次自动换成功时图源世代号」。判据见 [sourceEpoch]。
  Future<void> recordAutoAppliedEpoch(int epoch) async {
    _lastAutoAppliedSourceEpochOverride = epoch;
    notifier.value++;
    await _persistInt(autoAppliedEpochKey, epoch);
  }

  /// 记一条 Wallhaven 台账（键 `wh:<id>`）。
  ///
  /// 尺寸记**这张图自己的**尺寸（而不是「按屏幕要的尺寸」）：台账键含尺寸，而这里的
  /// 作用是「这张图下过了没有」，必须是能唯一认出这张图的那一组。
  ///
  /// ## ⚠️ 一律 `autoApplied: false`（不是漏写，是刻意的）
  ///
  /// [lastAutoAppliedDate] 只认台账里 `autoApplied` 的那一条，而它是 **Bing 的按天
  /// 判据**。Wallhaven 若在这里也留一条 `autoApplied: true`，那个 getter 就会返回
  /// `wh:w53vkq` 这种值 —— 于是**切回 Bing 之后**「今天已换过」永远判不成立
  /// （Bing 的 `dateKey` 是 `20261007` 那种 8 位数，与 `wh:…` 永不相等），表现是
  /// 「切回 Bing 之后它每天都在重新下载同一天那张」。
  ///
  /// Wallhaven 的按天判据走另一条路：`lastAutoAppliedItemId` + 图源世代号
  /// （见 `WallhavenWallpaperService.maybeApplyDaily`）。
  Future<List<String>> recordWallhaven({
    required String id,
    required WallpaperTargetSize sourceSize,
    required String path,
  }) => recordApplied(
    // 前缀**写进 dateKey 本身**（不是只在算键时临时加）：台账条目的 [key] 是
    // `dateKey@档位@尺寸` 拼出来的，而 [findExistingWallhaven] 要用同一个字符串去
    // 比对，所以它必须存在条目里。只在算键时加前缀的话，两边算出来的键不一致，
    // 复用永远命中不了（症状：同一天反复下同一张 5–11 MB 的图）。
    dateKey: 'wh:$id',
    resolution: BingWallpaperResolution.standard,
    path: path,
    autoApplied: false,
    targetSize: sourceSize,
  );

  /// Wallhaven 那边的「今天该换的那张」是否已经换过。
  ///
  /// ## 与台账键的关系
  ///
  /// 这里存的是**裸 id**（`w53vkq`），而台账里存的是带前缀的 `wh:w53vkq`
  /// （见 [recordWallhaven]）。两处刻意不同：这里要比的是「哪一张」，前缀只是台账里
  /// 避免与 Bing 的 `dateKey` 撞键的手段。
  ///
  /// ## 为什么这里要比 **id** 而不是日期
  ///
  /// Bing 的「今天」是它自己的日历（`dateKey` 天然就是那天的图），所以比日期。
  /// Wallhaven **没有**每日端点，「今天该换哪张」是**我们**按 `dailyIndex(now)`
  /// 算出来的（见 `WallhavenWallpaperService.dailyIndex`）—— 那个映射是确定的，
  /// 于是同一天算出的 id 相同、隔天不同，所以比 id 就等于比「哪一天」。
  ///
  /// 只对 [WallpaperDailySource.wallhaven] 有意义；切到 Bing 时这个字段不参与判据。
  String? get lastAutoAppliedItemId =>
      _lastAutoAppliedItemIdOverride ?? _lastAutoAppliedItemIdCache;

  String? _lastAutoAppliedItemIdOverride;
  String? _lastAutoAppliedItemIdCache;

  /// 记下「最近一次 Wallhaven 自动换用掉的 id」。
  Future<void> recordAutoAppliedItem(String? id) async {
    _lastAutoAppliedItemIdOverride = id;
    notifier.value++;
    if (id == null) {
      await _persistStringRemove(autoAppliedItemKey);
    } else {
      await _persistString(autoAppliedItemKey, id);
    }
  }

  /// Wallhaven 自动换 id 的存档键。
  static const String autoAppliedItemKey = 'wallhaven_auto_applied_id_v1';

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
      _sourceCache = WallpaperDailySource.fromStorageKey(
        _prefs!.getString(sourceKey),
      );
      _sourceEpochCache = _prefs!.getInt(epochKey);
      _sourceFallbackCache = WallpaperSourceFallback.fromStorageKey(
        _prefs!.getString(sourceFallbackKey),
      );
      _lastAutoAppliedItemIdCache = _prefs!.getString(autoAppliedItemKey);
      _lastAutoAppliedSourceEpochOverride = _prefs!.getInt(
        autoAppliedEpochKey,
      );
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

  /// 记一次「这张 / 这个档位（/ 这个实际尺寸）已经下到 [path]」，并返回应当删除的溢出路径。
  ///
  /// 同键去重后置顶（最新在前），超出 [kMaxDownloadedEntries] 的返回给调用方去真删。
  /// **只记账，不碰磁盘** —— 与 `pushWallpaperHistory` 同一分工：调用方知道「还有谁在用
  /// 这张图」（别的课表可能正拿它当壁纸），所以删除必须走
  /// `deleteEvictedWallpaperFiles` 的白名单。
  ///
  /// [targetSize] 必须**跟着 [path] 一起记**：2026-10-07 起实际下载尺寸随设备变化，
  /// 而台账键原本只由 `dateKey + 档位` 组成 —— 于是「按 1080×1920 下过的那张」会被
  /// 误判成「按 1206×2622 也下过了」，`findExisting` 直接复用旧尺寸，那份本该去掉的
  /// 二次放大就又回来了（症状：换了设备仍是糊的，且没有任何报错）。
  Future<List<String>> recordApplied({
    required String dateKey,
    required BingWallpaperResolution resolution,
    required String path,
    bool autoApplied = true,
    WallpaperTargetSize? targetSize,
  }) async {
    final size = targetSize ?? resolution.downloadTargetSize;
    final key = _DownloadedEntry.makeKey(dateKey, resolution, size);
    final next = <_DownloadedEntry>[
      _DownloadedEntry(
        dateKey: dateKey,
        resolution: resolution,
        targetSize: size,
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

  /// 找一张已下过的 **Wallhaven** 图（按它的 id），文件仍在就返回其路径。
  ///
  /// ## 为什么单独一条而不用 [findExisting]
  ///
  /// Wallhaven 那边的「档位」是占位的（取图不看档位，见
  /// `WallhavenWallpaperItem` 的注释），尺寸也是**那张图自己的**尺寸而不是「按屏幕要的
  /// 尺寸」。所以调用方传的语义与 Bing 那条不同（`id` vs `dateKey` + 档位 + 目标尺寸），
  /// 硬套进同一个方法只会让两边各自带一段 if。
  ///
  /// 键用 `wh:<id>`：Bing 的 `dateKey` 是 8 位数字（`20261005`），不可能与 `wh:xxx`
  /// 撞上，于是两边共用同一张表而互不顶替。
  Future<String?> findExistingWallhaven(String id) async {
    // ⚠️ 比对的是**前缀** `wh:<id>@` 而不是整个键：台账键是
    // `dateKey@档位@尺寸`（`makeKey`），而尺寸是**那张图自己的**尺寸、调用方未必
    // 手里有。所以按前缀找，命中任一即算「这张下过了」。
    //
    // 早先拿 `'wh:$id'` 去**整键**比对，永远命中不了 —— 症状是同一天反复下载同一张
    // 5–11 MB 的图，而台账里明明记着它。
    final prefix = 'wh:$id@';
    for (final entry in _downloaded) {
      if (!entry.key.startsWith(prefix)) {
        continue;
      }
      if (File(entry.path).existsSync()) {
        return entry.path;
      }
    }
    return null;
  }

  /// 找一张已下过的图（同一张 + 同一档位 + 同一实际尺寸），文件仍在就返回其路径。
  ///
  /// 避免同一天反复点同一张时重复下载。文件可能已被历史淘汰删掉，所以查存在性。
  ///
  /// [targetSize] 要与当初下载时**一致**（见 [recordApplied]）：尺寸对不上就该重下，
  /// 不能拿旧尺寸那张糊的顶替。
  Future<String?> findExisting(
    String dateKey,
    BingWallpaperResolution resolution, {
    WallpaperTargetSize? targetSize,
  }) async {
    final size = targetSize ?? resolution.downloadTargetSize;
    final key = _DownloadedEntry.makeKey(dateKey, resolution, size);
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

  Future<void> _persistStringRemove(String key) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.remove(key);
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

/// 台账里的一条：`dateKey@档位@尺寸` → 本地路径。
///
/// 键**不含图源**：Bing 与 Wallhaven 走同一张表，于是「同一张图两个源」会互相顶掉
/// —— 而那正是我们要的（Bing 那张与 Wallhaven 那张尺寸与构图都不同，但**同一天同一档**
/// 只会留一份文件，留最新的即可）。图源只影响文件名（`wallpaper_bing_…` /
/// `wallpaper_wh_…`），所以顶替是安全的。
@immutable
class _DownloadedEntry {
  const _DownloadedEntry({
    required this.dateKey,
    required this.resolution,
    required this.targetSize,
    required this.path,
    required this.autoApplied,
  });

  final String dateKey;

  /// 档位。
  ///
  /// Wallhaven 那边的图**没有档位概念**（原图就是原生竖图，直接下），但仍要占一个位置：
  /// 存 [BingWallpaperResolution.standard] 即可 —— 取图时不看这个字段（URL 由
  /// `WallhavenWallpaperItem` 自己带），它只参与键的去重与封顶。
  final BingWallpaperResolution resolution;

  /// 实际下载时用的像素尺寸（2026-10-07 起进键，见 [recordApplied]）。
  ///
  /// **旧存档没有这个字段**：那些条目是「按写死档位尺寸下的」，语义等价于
  /// 「尺寸 = 该档默认尺寸」，所以反序列化时回退到
  /// `WallpaperTargetSize(resolution.width, resolution.height)` 而不是当前屏幕 ——
  /// 否则同一条目每次启动键都不一样，台账去重与封顶清理全失效。
  final WallpaperTargetSize targetSize;

  final String path;

  /// 是不是「自动换」写下的。
  ///
  /// [BingWallpaperStore.lastAutoAppliedDate] 只认自动换来的那一条：用户**手动**从图库
  /// 挑一张也算用上了今天那张，若把它算进「今天已换过」，自动换就会误以为已完成而跳过。
  final bool autoApplied;

  static String makeKey(
    String dateKey,
    BingWallpaperResolution resolution,
    WallpaperTargetSize size,
  ) => '$dateKey@${resolution.storageKey}@${size.width}x${size.height}';

  String get key => makeKey(dateKey, resolution, targetSize);

  Map<String, Object?> toJson() => <String, Object?>{
    'dateKey': dateKey,
    'resolution': resolution.storageKey,
    'targetWidth': targetSize.width,
    'targetHeight': targetSize.height,
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
    final resolutionKey = raw['resolution'];
    final resolution = BingWallpaperResolution.fromStorageKey(
      resolutionKey is String ? resolutionKey : null,
    );
    // 旧存档没有尺寸字段 → 回退到**该档默认尺寸**（见 [targetSize] 的说明），
    // 绝不回退到当前屏幕：那条目是按写死尺寸下的，用屏幕尺寸去找它必然找不到，
    // 一次白下不说，还会让台账里留两条指向同一张图的不同尺寸记录。
    final defaultSize = WallpaperTargetSize(resolution.width, resolution.height);
    final tw = raw['targetWidth'];
    final th = raw['targetHeight'];
    final hasSize = tw is int && th is int && tw > 0 && th > 0;
    return _DownloadedEntry(
      dateKey: dateKey.trim(),
      // 未知档位回退默认：宁可用错档位复用一张图，也不要因为存档里一个陌生字符串
      // 而把已下的图当成没下过、白白重下一遍。
      resolution: resolution,
      targetSize: hasSize ? WallpaperTargetSize(tw, th) : defaultSize,
      path: path.trim(),
      autoApplied: raw['autoApplied'] is bool
          ? raw['autoApplied']! as bool
          : true,
    );
  }
}