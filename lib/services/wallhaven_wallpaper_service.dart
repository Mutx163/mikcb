import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import '../models/wallhaven_wallpaper.dart';
import '../utils/home_page_background.dart';
import '../utils/managed_image_storage.dart';
import '../utils/wallpaper_history.dart';
import 'app_http_client.dart';
import 'app_log_service.dart';
import 'bing_wallpaper_store.dart';
import 'wallpaper_history_service.dart';

/// 一次 Wallhaven 下载的结果；语义与 `BingWallpaperDownload` 对齐。
///
/// 刻意不做「退档」：Wallhaven 的图是原图直出，没有「这个尺寸 Bing 没生成」那类失败，
/// 失败就是失败（见 [WallhavenDownloadFailure] 的分类）。
@immutable
class WallhavenDownload {
  const WallhavenDownload.success(this.path) : failure = null;

  const WallhavenDownload.failed(this.failure) : path = null;

  final String? path;
  final WallhavenDownloadFailure? failure;

  bool get succeeded => path != null;
}

/// Wallhaven 下载失败的分类。
///
/// 分类不是为了好看：`WallhavenWallpaperService` 挂在启动路径上，失败必须能一路送到
/// 日志与用户可见的提示里，否则又是一次「点了没反应且无从查起」（2026-10-06 那次的
/// 根因就是失败原因被压成 null）。
enum WallhavenDownloadFailure {
  /// 拉清单失败（断网 / 超时 / 非 2xx / 格式变了）。
  list,

  /// 图片下载失败（网络 / 非 2xx / 空体 / 不是图片 / 写不进）。
  download,
}

/// 「今天自动换」这一次尝试的结局。
///
/// 与 `BingAutoApplyOutcome` **刻意做成同一组语义**（`disabled` / `alreadyApplied` /
/// `appliedToday` / `failed`），这样设置页与启动路径的那一串 `switch` 不必分叉 ——
/// 两个源换成功了都是「今天换好了」，对用户是同一件事。
///
/// 没有 `appliedStale`：Wallhaven 不存在「今天那张还没放出来」这回事（见
/// `WallpaperDailySource` 的注释）。
enum WallhavenAutoApplyOutcome {
  /// 功能没开。
  disabled,

  /// 今天已经换过了（判据：图源世代号 + 今天算出的那张 id）。
  alreadyApplied,

  /// 换上了今天该换的那张。
  appliedToday,

  /// 拉不到清单，或图没下下来。
  failed,
}

class WallhavenAutoApplyResult {
  const WallhavenAutoApplyResult(this.outcome, [this.path, this.itemId]);

  final WallhavenAutoApplyOutcome outcome;
  final String? path;

  /// 换上去那张的 Wallhaven id。
  final String? itemId;

  bool get succeeded => path != null;
}

/// Wallhaven 竖版壁纸的拉取与下载。
///
/// ## 为什么它是「更清晰但不是每天必换」的那一个
///
/// 见 `WallpaperDailySource` 的类注释。一句话：它的竖图是原生供给（实测 2250×4000
/// 起，放大 1.0），但接口没有每日端点，「每天一张」靠页码偏移凑。
///
/// ## 与 Bing 那条链路共用的东西（刻意复用，别另起一套）
///
/// * 落盘目录 / 前缀 / `downloadToManagedImage`（所以清理逻辑零改动）；
/// * [BingWallpaperStore] 的台账（所以封顶清理与「别重复下载」都免费得到）；
/// * [WallpaperHistoryService] 的「最近使用」当删文件白名单。
///
/// ## 不依赖 [TimetableProvider]
///
/// 与 `BingWallpaperService` 同一理由：守住那个 god class 的扇入棘轮。
class WallhavenWallpaperService {
  WallhavenWallpaperService({http.Client? client})
    : this._internal(client ?? createAppHttpClient(), client == null);

  WallhavenWallpaperService._internal(this._client, bool ownsCandidate)
    : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  /// ⚠️ `_ownsClient` 的算法**不能**写错，否则会把**全进程共享**的 client 关掉。
  ///
  /// 逐字照抄 `BingWallpaperService` 的同款写法（`client == null &&
  /// !isSharedAppHttpClient(_client)`）—— 那里曾写成 `||`，两个错叠加成恒 `true`，
  /// 于是打开一次图库就把天气 / 节假日 / 版本检查的 client 全关了（2026-10-06）。
  static const String _tag = 'WallhavenWallpaper';

  static const String _searchEndpoint = 'https://wallhaven.cc/api/v1/search';

  /// **后台**（每天自动换）用的清单超时：8 秒，与 `BingWallpaperService` 同档。
  ///
  /// 那是挂在启动路径上的锦上添花请求，宁可失败也不该让 App 启动变慢。
  static const Duration backgroundListTimeout = Duration(seconds: 8);

  /// **前台**（图库页）用的清单超时：25 秒。
  ///
  /// ## ⚠️ 这两个预算不能取同一个值
  ///
  /// 8 秒对 Bing 成立（微软国内有节点），对 Wallhaven **不成立** —— 它挂在 Cloudflare
  /// 后面，而 Cloudflare 在大陆是「**降级**」而不是「不通」：线路差的手机上光是
  /// TLS 握手就要好几秒。实测 2026-10-07 有用户的两次图库拉取都在第 8 秒整被判失败
  /// （日志 `TimeoutException after 0:00:08`），而**同一台手机同一次会话里 Bing
  /// 拉取成功** —— 所以那不是断网，是这一个源慢。
  ///
  /// 而图库页是**用户正盯着等**的界面：他多等十几秒还会回来接着用，弹一句
  /// 「没能取到」他只会以为 App 坏了（2026-10-07 实测）。
  static const Duration foregroundListTimeout = Duration(seconds: 25);

  final http.Client _client;
  final bool _ownsClient;

  @visibleForTesting
  static http.Client Function()? testClientFactory;

  static WallhavenWallpaperService _createInternal() =>
      WallhavenWallpaperService(client: testClientFactory?.call());

  static WallhavenWallpaperService createTransient() => _createInternal();

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// 比例筛选值（像素尺寸写法，见 [WallhavenQuery] 的⚠️）。
  ///
  /// 取三个常见竖屏比例的**并集**：只要其中之一命中即可，不必命中全部。
  static const List<String> kPortraitRatios = <String>[
    '1080x1920',
    '1440x2560',
    '1200x2400',
  ];

  /// 尺寸下限：至少要比**最窄**的那台常见机（1080×1920）大，否则屏大一点就得放大。
  ///
  /// 用 1080×1920 而不是当前屏幕分辨率，是为了让**清单**在设备间稳定（同一份清单
  /// 在任何设备上一样）。真正下多大的图由 [WallhavenDownload] 按当前屏幕决定。
  static const WallpaperTargetSize kMinimumSourceSize = WallpaperTargetSize(
    1080,
    1920,
  );

  /// 拉竖版清单；失败返回空列表（**不抛**）。
  ///
  /// [timeout] 默认给 [backgroundListTimeout]（后台那条路径）。图库页要显式传
  /// [foregroundListTimeout] —— 理由见那两个常量的注释。
  Future<List<WallhavenWallpaperItem>> fetchPortrait({
    WallhavenSort sort = WallhavenSort.toplist,
    int page = 1,
    Duration timeout = backgroundListTimeout,
  }) async {
    final query = WallhavenQuery(
      ratios: kPortraitRatios,
      minimumSize: kMinimumSourceSize,
      sort: sort,
      page: page,
    );
    final uri = Uri.parse(
      '$_searchEndpoint?${query.toQueryParameters().entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&')}',
    );
    try {
      appDebugLog(_tag, 'list start page=$page sort=${sort.wire}');
      final response = await _client
          .get(uri, headers: const {'User-Agent': 'mikcb-wallpaper'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        appDebugLog(_tag, 'list failed status=${response.statusCode}');
        await _logWarn('wallhaven_wallpaper_list_failed', 'status=${response.statusCode}');
        return const [];
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        await _logWarn('wallhaven_wallpaper_list_failed', 'body is not a JSON object');
        return const [];
      }
      // ⚠️ 两道筛：解析器丢掉坏条目与 `anime`，这里再筛一次**确实是竖图**。
      // 后者不能省 —— 接口给的 `dimension_y > dimension_x` 与我们理解的「竖」是同一件事，
      // 但**接口不保证**（实测 `ratios` 参数写错就静默返回横图，见 [WallhavenQuery]）。
      // 宁可清单空掉，也不要拿一张横图去当竖屏壁纸（那正是用户 2026-10-06 拍板删掉
      // 横屏档位的理由：横图铺竖屏会被裁掉七成）。
      final items = <WallhavenWallpaperItem>[
        for (final item in WallhavenWallpaperItem.listFromJson(decoded['data']))
          if (item.isPortrait) item,
      ];
      appDebugLog(_tag, 'list ok count=${items.length}');
      if (items.isEmpty) {
        await _logWarn('wallhaven_wallpaper_list_empty', null);
      }
      return items;
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'list threw: $error');
      await _logWarn('wallhaven_wallpaper_list_failed', error, stackTrace);
      return const [];
    }
  }

  /// 图库清单缓存多久就重新拉（与 `BingWallpaperService` 同档）。
  static const Duration _listCacheTtl = Duration(hours: 3);

  /// 要展示的清单；**网络拿不到时回落到上次缓存**。
  ///
  /// ## 为什么不能只靠 TTL
  ///
  /// 只有「命中缓存就给缓存，否则拉网络，拉不到就返回空」的话，**缓存过期后的那一次
  /// 失败直接落到空列表** —— 用户对着空图库加一句「没能取到竖版高清图库」。而这个源
  /// 的失败不是偶发断网、是常态（Cloudflare 在大陆是降级不是不通，见
  /// [foregroundListTimeout]）：TTL 3 小时一过，下一次打开就可能整个空白。
  ///
  /// 所以是「宁可给旧的，不要给空」：有旧的就给旧的，图库页照常显示并提示「这是上次
  /// 的结果」；一次都没成功过才返回空 —— 那才是真失败。
  ///
  /// **空清单不写缓存**（见 [BingWallpaperStore.saveCachedWallhavenItems]）：否则一次
  /// 失败被缓存 3 小时。
  static Future<List<WallhavenWallpaperItem>> loadPortrait({
    bool forceRefresh = false,
  }) async {
    final store = BingWallpaperStore.instance;
    if (!forceRefresh) {
      final cached = store.cachedWallhavenItems;
      final cachedAt = store.cachedWallhavenItemsFetchedAt;
      final fresh = cachedAt != null &&
          DateTime.now().difference(cachedAt) < _listCacheTtl;
      if (cached.isNotEmpty && fresh) {
        return cached;
      }
    }
    final service = _createInternal();
    final List<WallhavenWallpaperItem> items;
    try {
      // 前台预算：这条**只有图库页会走**（自动换走 [maybeApplyDaily] 里的
      // [fetchPortrait] 默认档）。
      items = await service.fetchPortrait(timeout: foregroundListTimeout);
    } finally {
      service.dispose();
    }
    if (items.isNotEmpty) {
      await store.saveCachedWallhavenItems(items);
      return items;
    }
    final stale = store.cachedWallhavenItems;
    if (stale.isNotEmpty) {
      appDebugLog(_tag, 'list failed, serving ${stale.length} cached items');
    }
    return stale;
  }

  /// 下 [item] 的原图。
  ///
  /// ## 不按屏幕尺寸要图，也不退档
  ///
  /// * **不 resize**：Wallhaven 的竖图本来就大于屏幕，缩下来只会平白丢细节，
  ///   并让「原生竖图 = 放大 1.0」这个优势作废；
  /// * **不退档**：Bing 那边的退档解决的是「这个尺寸它没预生成」，这里不存在这个问题。
  ///   5–11 MB 的原图直下，是这张源换来清晰度的代价。
  Future<WallhavenDownload> download(WallhavenWallpaperItem item) async {
    final url = item.downloadUrl;
    appDebugLog(_tag, 'download start ${item.id} ${item.width}x${item.height} $url');
    try {
      final result = await downloadToManagedImage(
        url: Uri.parse(url),
        directoryName: kHomePageWallpaperDirectoryName,
        // ⭐ 前缀必须是 `wallpaper`：与 Bing 那条共用既有的删除守卫（见
        // `WallhavenWallpaperItem.fileName` 的注释）。
        fileName: item.fileName,
        client: _client,
      );
      appDebugLog(_tag, 'download result ${item.id} ${result.describe()}');
      if (!result.succeeded) {
        await _logWarn('wallhaven_wallpaper_download_failed', result.describe());
        return const WallhavenDownload.failed(
          WallhavenDownloadFailure.download,
        );
      }
      return WallhavenDownload.success(result.path);
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'download threw: $error');
      await _logWarn('wallhaven_wallpaper_download_failed', error, stackTrace);
      return const WallhavenDownload.failed(WallhavenDownloadFailure.download);
    }
  }

  /// 今天该换的那一张是清单里的**第几张**。
  ///
  /// ## 为什么用「按天算页码 + 按天算下标」而不是随机
  ///
  /// 接口没有每日端点（实测 `random` / `featured` 都 404），而 `sort=random` 每次调用
  /// 都给不同清单 —— 用它做「今天那张」会导致**同一天内两次拉取得到不同答案**，
  /// 于是「今天已换过」的判据（比 id）根本立不住，同一张图会被换两次。
  ///
  /// 所以走**确定性**映射：同一个 [now] 永远算出同一个答案。基数取得小一点，
  /// 是为了让相邻两天的偏移不同（否则每天很可能取到清单里同一格）。
  static int dailyIndex(DateTime now) =>
      now.year * 372 + now.month * 31 + now.day;

  /// 「今天自动换」的执行体。
  ///
  /// [now] 只给测试用（单测把「今天」钉在固定日期上，不必跟着运行时刻漂）。
  /// [inUsePaths] 是**所有课表**当前壁纸（见 `inUseWallpaperPaths`）：清理台账溢出
  /// 的文件时用它当白名单，本服务刻意不依赖 `TimetableProvider`。
  static Future<WallhavenAutoApplyResult> maybeApplyDaily({
    DateTime? now,
    Set<String> inUsePaths = const <String>{},
  }) async {
    final store = BingWallpaperStore.instance;
    if (!store.autoApplyEnabled) {
      return const WallhavenAutoApplyResult(
        WallhavenAutoApplyOutcome.disabled,
      );
    }
    final clock = now ?? DateTime.now();
    final service = _createInternal();
    final List<WallhavenWallpaperItem> items;
    try {
      items = await service.fetchPortrait();
    } finally {
      service.dispose();
    }
    if (items.isEmpty) {
      return const WallhavenAutoApplyResult(WallhavenAutoApplyOutcome.failed);
    }
    // 清单按天偏移取：同一张可能落在清单外，于是按 `id % len` 再取一次，
    // 保证「今天一定有一张」，且同一天永远同一张。
    final offset = dailyIndex(clock) % items.length;
    final today = items[offset];
    // 判据用 **id** 而不是日期：Wallhaven 没有「今天那张」这个概念，
    // 「今天该换的那张」是**我们**按 [dailyIndex] 定的，所以只能比 id。
    if (store.lastAutoAppliedItemId == today.id &&
        store.lastAutoAppliedSourceEpoch == store.sourceEpoch) {
      return const WallhavenAutoApplyResult(
        WallhavenAutoApplyOutcome.alreadyApplied,
      );
    }
    final downloader = _createInternal();
    final WallhavenDownload download;
    try {
      download = await downloader.download(today);
    } finally {
      downloader.dispose();
    }
    if (!download.succeeded) {
      return const WallhavenAutoApplyResult(WallhavenAutoApplyOutcome.failed);
    }
    // 走 `recordWallhaven`：键是 `wh:<id>`、且**不**留 `autoApplied` 标记
    // （否则会污染 Bing 的按天判据，理由见那个方法的注释）。
    final evicted = await store.recordWallhaven(
      id: today.id,
      sourceSize: WallpaperTargetSize(today.width, today.height),
      path: download.path!,
    );
    await store.recordAutoAppliedItem(today.id);
    await store.recordAutoAppliedEpoch(store.sourceEpoch);
    unawaited(_deleteEvictedWallpapers(evicted, inUsePaths: inUsePaths));
    appDebugLog(_tag, 'daily applied id=${today.id}');
    return WallhavenAutoApplyResult(
      WallhavenAutoApplyOutcome.appliedToday,
      download.path,
      today.id,
    );
  }

  /// 删掉台账挤出去的图，白名单口径与 Bing 那条**逐字一致**。
  static Future<void> _deleteEvictedWallpapers(
    List<String> paths, {
    required Set<String> inUsePaths,
  }) async {
    if (paths.isEmpty) {
      return;
    }
    try {
      final history = await WallpaperHistoryService.load();
      await deleteEvictedWallpaperFiles(
        paths,
        inUsePaths: <String>{
          ...inUsePaths,
          ...BingWallpaperStore.instance.downloadedPaths,
          for (final entry in history) entry.key,
        },
      );
    } on Object catch (error) {
      appDebugLog(_tag, 'daily evict failed: ${error.runtimeType}: $error');
    }
  }

  static Future<void> _logWarn(
    String category,
    Object? error, [
    StackTrace? stackTrace,
  ]) async {
    try {
      await AppLogService.instance.warn(
        category,
        AppLogMessages.wallhavenWallpaperRequestFailed,
        error: error,
        stackTrace: stackTrace,
      );
    } on Object {
      // 日志本身失败必须彻底静默 —— 这条路径的调用方在启动流程上。
    }
  }
}