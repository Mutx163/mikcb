import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  /// 清单超时：8 秒，与 `BingWallpaperService` 同档。
  ///
  /// ## 曾按「前台 / 后台」分成两档（8 秒 / 25 秒），现已合并回一档
  ///
  /// 拆开的理由是「前台是用户盯着等的界面，而这个源在大陆只是**慢**」——
  /// 慢的站点会给数据，不通的才一个字不说，所以多等一会儿是划算的。
  ///
  /// **那个理由是错的。** 2026-10-07 分段探测实测（见 `probeReachability` 的日志）：
  /// DNS 88ms 就返回了 `103.97.3.19` 与 `2a03:2880:…face:b00c…`，而
  /// Google DoH 给出的权威答案是 `104.26.11.35 / 172.67.74.111 / 104.26.10.35`
  /// （全 Cloudflare）。也就是说**域名在中国大陆被 DNS 污染**，请求压根发不到
  /// wallhaven 的服务器，而是发给了那台不相关的机器 —— TCP 握手必然超时。
  ///
  /// 于是「慢」与「被拦」必须分开对待：
  ///
  /// * **慢** → 多等一会儿划算，前台就该给更宽的预算；
  /// * **被拦** → 等多久都没用，用户白等 25 秒比白等 8 秒更糟。
  ///
  /// 本源是后者，所以回到 8 秒。**真要给某个源更宽的预算，判断依据只能是实测的
  /// 「慢」，不能是猜测** —— 而判断「慢 / 被拦」的唯一办法是
  /// [probeReachability]：DNS 返回的地址对不上权威答案，就是被拦。
  static const Duration listTimeout = Duration(seconds: 8);

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
  /// [timeout] 默认给 [listTimeout]；真要更宽的预算必须有「这个源确实慢」的实测
  /// 依据，理由见那个常量的注释。
  Future<List<WallhavenWallpaperItem>> fetchPortrait({
    WallhavenSort sort = WallhavenSort.toplist,
    int page = 1,
    Duration timeout = listTimeout,
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
      if (kDebugMode) {
        // 与主请求**并行**，不占用户等待时间；正式版不跑。
        unawaited(probeReachability());
      }
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
  /// 失败直接落到空列表** —— 用户对着空图库加一句「没能取到竖版高清图库」。
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
      items = await service.fetchPortrait();
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

  /// debug 专用：把「能不能连上」拆成 DNS / TCP / HTTP 三段分别计时。
  ///
  /// ## 为什么需要它
  ///
  /// 2026-10-07 实测：把前台超时从 8 秒放宽到 25 秒之后，请求**仍然**在 25 秒整超时、
  /// 一个字节没回来。这说明不是「慢」而是「不通」——但**卡在哪一步**看不出来：
  /// DNS 被拖住、TCP SYN 被丢进黑洞（于是永远连不上）、还是连上了不回话，
  /// 三种情况的修法完全不同。而 `package:http` 不暴露这些阶段，只能自己测。
  ///
  /// ## 三条纪律
  ///
  /// * **只在 debug 构建跑**（[kDebugMode]）：正式版没有这段探测，也没有它的日志；
  /// * **并行跑**（调用方 `unawaited`）：不占用户等待时间，主请求该超时还是超时；
  /// * **自己不抛**：探测失败本身就是它要报告的结论。
  ///
  /// ## 怎么读它的输出
  ///
  /// | DNS | TCP | 浏览器 UA 的 HTTPS | 结论 |
  /// |---|---|---|---|
  /// | 挂 | — | — | DNS/解析器问题，与图源无关 |
  /// | 过 | 挂 | — | 出口链路断了（运营商/黑洞），App 侧无解 |
  /// | 过 | 过 | 通，但本请求超时 | **我们的请求被区别对待**（UA 之类），可改 |
  /// | 过 | 过 | 也挂 | Cloudflare 对该来源整体不可达，App 侧无解 |
  ///
  /// 刻意**不加** `@visibleForTesting`：它由 [fetchPortrait] 在 `kDebugMode` 守卫下
  /// 调用，那是生产代码路径，标成仅测试可见会被分析器判成误用。
  static Future<void> probeReachability() async {
    final host = Uri.parse(_searchEndpoint).host;
    final sw = Stopwatch()..start();

    // ① DNS 解析
    final List<InternetAddress> addresses;
    try {
      addresses = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 6),
      );
    } on Object catch (error) {
      appDebugLog(
        _tag,
        'probe dns FAIL after ${sw.elapsedMilliseconds}ms: $error',
      );
      return;
    }
    if (addresses.isEmpty) {
      appDebugLog(_tag, 'probe dns ok but returned 0 address');
      return;
    }
    appDebugLog(
      _tag,
      'probe dns ok in ${sw.elapsedMilliseconds}ms -> '
      '${addresses.map((a) => '${a.address}/${a.type.name}').join(' ')}',
    );

    // ② TCP 握手。**只试第一个地址**：连不上就是真不通，不必挨个试完再报。
    final first = addresses.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );
    sw.reset();
    try {
      final socket = await Socket.connect(
        first.address,
        443,
        timeout: const Duration(seconds: 8),
      );
      socket.destroy();
      appDebugLog(_tag, 'probe tcp ok in ${sw.elapsedMilliseconds}ms');
    } on Object catch (error) {
      appDebugLog(
        _tag,
        'probe tcp FAIL after ${sw.elapsedMilliseconds}ms: $error',
      );
      return;
    }

    // ③ 同一个地址，用**浏览器身份**发一次 HTTPS。
    //
    // 这一段是整个探测的**关键**：它把「网络不通」和「我们的请求被区别对待」切开 ——
    // 用户反馈中国人能在浏览器里打开 wallhaven.cc，而浏览器与本 App 的差别不只在
    // 传输层，还在请求头（UA 尤其明显）。这一步通、而正文那种请求超时，就说明
    // 病根在我们发出的东西，那是能改的。
    sw.reset();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri.parse('$_searchEndpoint?page=1'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('User-Agent', _browserLikeUserAgent);
      req.headers.set('Accept', 'application/json');
      // 超时挂在 close() 的 Future 上，不是挂在 HttpClientRequest 上——后者
      // 没有 timeout 方法（编译期就会报 undefined）。
      final res = await req.close().timeout(const Duration(seconds: 10));
      final ms = sw.elapsedMilliseconds;
      appDebugLog(_tag, 'probe http(browserUA) ${res.statusCode} in ${ms}ms');
      // 必须把响应体读完：不读会让连接悬着，而 HttpClient.close() 只是不等它。
      await res.drain<void>().timeout(const Duration(seconds: 5));
    } on Object catch (error) {
      final ms = sw.elapsedMilliseconds;
      appDebugLog(_tag, 'probe http(browserUA) FAIL after ${ms}ms: $error');
    } finally {
      client.close(force: true);
    }
  }

  /// 探测第三段用的「像浏览器」UA。
  ///
  /// 刻意给一个**普通桌面浏览器**的 UA，而不是 `mikcb-wallpaper`：这一段的意义就是
  /// 「让服务端把我们当成浏览器对待」，那样才能看出差别到底出在请求头上。
  static const String _browserLikeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

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