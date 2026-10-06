import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import '../models/bing_wallpaper.dart';
// 只为 `parseBingWallpaperDateKey`（判「这条 dateKey 是不是今天」）引这一条。
// 它住在显示用的工具文件里，但**不含任何 l10n 调用**，纯字符串解析；搬去 model 会
// 牵动一处已通过的测试与笔记里的路径引用，为一个纯函数不值得。若日后那边真的开始
// 依赖 l10n，正确做法是把这个解析函数搬进 `bing_wallpaper.dart`（model 自己解析
// 自己的字段），而不是让 service 反向依赖界面层。
import '../utils/bing_wallpaper_date_label.dart';
import '../utils/managed_image_storage.dart';
import '../utils/wallpaper_history.dart';
import 'app_http_client.dart';
import 'app_log_service.dart';
import 'bing_wallpaper_store.dart';

/// 一次下载的**结果**：成功给 [path]，失败给 [failure] / [statusCode]。
///
/// [resolution] 只在成功时有意义，且是**实际**档位而不是用户选的那档 —— 中间档偶尔缺
/// （见 [BingWallpaperResolution.fallbackResolution]），这时它是退回的
/// [BingWallpaperResolution.standard]。[downgraded] 是给界面提示用的那个信号。
///
/// 刻意做成**非空**（成功失败都是它）而不是「失败返回 null」：2026-10-06 用户报
/// 「点大图下载失败」却查不出原因，根因就是 null 把「Bing 说这张没有」(404) 与
/// 「断网了」压成了同一个值。失败原因要能一路送到用户眼前与日志里。
class BingWallpaperDownload {
  const BingWallpaperDownload._({
    required this.path,
    required this.resolution,
    required this.downgraded,
    this.failure,
    this.statusCode,
    this.contentType,
    this.detail,
  });

  const BingWallpaperDownload.success({
    required String path,
    required BingWallpaperResolution resolution,
    required bool downgraded,
  }) : this._(
         path: path,
         resolution: resolution,
         downgraded: downgraded,
       );

  /// 由一次底层尝试的结果构造（失败时把**原因**一并带走）。
  ///
  /// 必须是 `factory` 而不是 const 转发构造：转发构造器里读参数上的字段是非法的
  /// （`attempt.statusCode` 不是编译期常量）。
  factory BingWallpaperDownload.fromAttempt(ManagedImageDownloadResult attempt) =>
      BingWallpaperDownload._(
        path: attempt.path,
        resolution: null,
        downgraded: false,
        failure: attempt.failure,
        statusCode: attempt.statusCode,
        contentType: attempt.contentType,
        detail: attempt.detail,
      );

  /// 退档后拿到的那一档（`downgraded` 恒为 true）。
  factory BingWallpaperDownload.successWithFallback({
    required String path,
    required BingWallpaperResolution resolution,
  }) => BingWallpaperDownload._(
    path: path,
    resolution: resolution,
    downgraded: true,
  );

  final String? path;

  /// 真正下到手的那一档（台账要记它，不是用户选的那档 —— 否则同一个文件名会被
  /// 两档共记，去重与封顶清理都跟着算错）。
  final BingWallpaperResolution? resolution;

  /// 是否因所选档位缺失而退了档。
  final bool downgraded;

  /// 两档都没拿到时的原因；成功为 null。
  final ManagedImageDownloadFailure? failure;

  /// 拿得到响应时的 HTTP 状态码（用来区分「Bing 没这张图」与「断网」）。
  final int? statusCode;

  final String? contentType;

  /// 失败现场原文（异常类型 + message 之类），见 [ManagedImageDownloadResult.detail]。
  final String? detail;

  bool get succeeded => path != null;

  /// 一行可直接进日志的描述。
  String describe() => succeeded
      ? 'ok tier=${resolution?.name} downgraded=$downgraded path=$path'
      : 'failed=$failure status=$statusCode contentType=$contentType '
            'detail=$detail';
}

/// Bing 每日壁纸的拉取与下载。
///
/// 一次列表请求就能拿到最近 [kBingWallpaperDays] 天（实测 `n=8` 返回 5.2 KB），
/// 所以「浏览图库」与「每天自动换」共用同一条链路，差别只在于要不要落盘。
///
/// ## 三条口径
///
/// * **浏览不下载**：图库页面只用 [BingWallpaperItem.thumbnailUrl] 的 480×854 小图
///   （约 105 KB/张，8 张约 840 KB）。只有用户点某一张才下原图。
/// * **失败一律静默**：本类挂在启动路径上（自动换），任何异常都自己吞掉并记一笔日志，
///   返回 null 表示「今天没有可换的图」。绝不把错误抛给调用方。
/// * **不依赖 [TimetableProvider]**：只负责「算出该用哪个本地文件」，写设置那一步在
///   `main.dart`。这是为了守住 `timetable_provider.dart` 的扇入棘轮
///   （见 `test/architecture/dependency_guards_test.dart`）。
class BingWallpaperService {
  /// ⚠️ `_ownsClient` 的算法**不能**写错，否则会把**全进程共享**的 client 关掉。
///
/// [createAppHttpClient] 在 debug/profile 下返回的是 BlackBox 那个**共享** client；
/// 关掉它之后，同进程内所有走它创建 client 的服务（天气、节假日同步、版本检查…）
/// 随后的请求全部抛异常。所以按 `WeatherService` / `HolidayService` 的同款写法：
/// `client == null && !isSharedAppHttpClient(_client)` —— **自己 new 出来的**
/// 才归自己关。
///
/// （2026-10-06 实踩：这里曾写成 `client == null || !isSharedAppHttpClient(client)`
/// —— 两个错叠加成恒 `true`，于是图库页 `loadItems()` 一 `dispose()` 就把共享 client
/// 关了，用户紧接着点任何一张图都 `failed=network`。表现是「列表能出、图下不来」，
/// 根因却在离下载三行远的地方。）
BingWallpaperService({http.Client? client})
    : this._internal(client ?? createAppHttpClient(), client == null);

BingWallpaperService._internal(this._client, bool ownsCandidate)
    : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  /// `appDebugLog` 的 tag。grep 这个串就能拿到本功能的全部排障轨迹。
  static const String _tag = 'BingWallpaper';

  /// 一次拉几天的图。Bing 在 `n=8` 上给满，再多不保证。
  static const int kBingWallpaperDays = 8;

  /// 列表请求地址模板。
  ///
  /// `mkt=zh-CN` 让版权说明变成中文（实测返回「阿德利企鹅，南极洲 (? …)」，
  /// 响应是合法 UTF-8）。Bing 对 `mkt` 无鉴权要求。
  static const String _listEndpoint =
      'https://www.bing.com/HPImageArchive.aspx'
      '?format=js&idx=0&n=$kBingWallpaperDays&mkt=zh-CN';

  /// 列表请求超时。给 8 秒，与 `holiday_service` 同档：这是个「锦上添花」的请求，
  /// 卡住比失败更糟。
  static const Duration _listTimeout = Duration(seconds: 8);

  final http.Client _client;
  final bool _ownsClient;

  /// 只给测试用的构造钩子：把 `maybeApplyDaily` / `loadItems` 内部**自建**的
  /// service 指向一个 `MockClient`。
  ///
  /// ## 为什么需要这个钩子
  ///
  /// 那两个入口刻意自己 `BingWallpaperService()` 再 `dispose()`：自动换挂在
  /// `main.dart` 的启动流程上，没有调用方持有 client 可传，于是不能在测试里注入。
  /// 与其在生产代码里为测试开一个长期口子，不如留一个**只在测试里赋值**的钩子。
  @visibleForTesting
  static http.Client Function()? testClientFactory;

  /// 自建一个 service；测试钩子在场时用它提供的 client。
  static BingWallpaperService _createInternal() =>
      BingWallpaperService(client: testClientFactory?.call());

  /// 自建一个「用完即弃」的 service —— [loadItems] / [maybeApplyDaily] / 图库页
  /// **三处都要走这一条**，不要直接 `BingWallpaperService()`。
  ///
  /// 走 [_createInternal] 的理由：测试的 `testClientFactory` 钩子只挂在这一条路上。
  /// 早前图库页在 `_pick` 里直接 `BingWallpaperService()`，绕过了钩子，于是单测里那条
  /// 图片请求落到了 Flutter 测试自带的 HttpClient 上（恒回 400），表现为「点了图却
  /// 下载失败、回调也不触发」—— 看着像功能坏了，其实是测试没接上。
  static BingWallpaperService createTransient() => _createInternal();

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// 拉最近 [kBingWallpaperDays] 天的壁纸清单；失败返回空列表。
  ///
  /// 解析上的两个要点：
  /// * `format=js` 返回的是**标准 JSON**（不是某些接口那种 key 不带引号的伪 JS），
  ///   所以能直接 `jsonDecode`；
  /// * 逐条丢弃脏数据而不是整份作废（见 `BingWallpaperItem.listFromJson`）——
  ///   Bing 改字段时不该让整个图库空掉。
  Future<List<BingWallpaperItem>> fetchRecent() async {
    try {
      appDebugLog(_tag, 'list start');
      final response = await _client
          .get(
            Uri.parse(_listEndpoint),
            headers: const {'User-Agent': 'mikcb-wallpaper'},
          )
          .timeout(_listTimeout);
      if (response.statusCode != 200) {
        appDebugLog(_tag, 'list failed status=${response.statusCode}');
        await _logWarn('bing_wallpaper_list_status', null);
        return const [];
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        appDebugLog(_tag, 'list malformed: body is not a JSON object');
        await _logWarn('bing_wallpaper_list_malformed', null);
        return const [];
      }
      final items = BingWallpaperItem.listFromJson(decoded['images']);
      appDebugLog(
        _tag,
        'list ok count=${items.length} '
        'first=${items.isEmpty ? "-" : items.first.dateKey}',
      );
      if (items.isEmpty) {
        await _logWarn('bing_wallpaper_list_empty', null);
      }
      return items;
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'list threw: $error');
      await _logWarn('bing_wallpaper_list_failed', error, stackTrace);
      return const [];
    }
  }

  /// 把 [item] 下到本地壁纸目录。
  ///
  /// 所选档位拿不到时按 [BingWallpaperResolution.fallbackResolution] 退一档重试，
  /// 而不是直接失败 —— Bing 并非每天都预生成 1920×1200，实测 24 天里缺 1 天，
  /// 而那一张常常就在用户眼前的图库里。
  Future<BingWallpaperDownload> download(
    BingWallpaperItem item,
    BingWallpaperResolution resolution,
  ) async {
    final direct = await _downloadAt(item, resolution);
    if (direct.succeeded) {
      return BingWallpaperDownload.success(
        path: direct.path!,
        resolution: resolution,
        downgraded: false,
      );
    }
    final fallback = resolution.fallbackResolution;
    // ⚠️ 只在「Bing 说这张没有 / 给的不是图」时退档重试。断网、超时、磁盘写不进
    // 都**不是**缺档：换个尺寸重下同一张图照样会失败，而那意味着用户对着一个
    // 转圈的进度条白等两个 20 秒超时（2026-10-06 review 实测的口径）。
    // 换句话说：退档解决的是「这个尺寸不存在」，不是「网络坏了」。
    if (fallback == null || !_isMissingTier(direct.failure)) {
      return BingWallpaperDownload.fromAttempt(direct);
    }
    final retry = await _downloadAt(item, fallback);
    if (retry.succeeded) {
      return BingWallpaperDownload.successWithFallback(
        path: retry.path!,
        resolution: fallback,
      );
    }
    // 两档都失败：报**所选**那一档的失败原因（用户选的就是它，退档只是内部兜底）。
    return BingWallpaperDownload.fromAttempt(direct);
  }

  /// [failure] 是不是「这个尺寸 Bing 根本没给」那一类。
  ///
  /// 只有 [ManagedImageDownloadFailure.status]（多为 404）与
  /// [ManagedImageDownloadFailure.notImage]（Bing 对未知尺寸回 HTML 错误页，且状态码
  /// 偶尔仍是 200）才值得退档。`network` / `emptyBody` / `write` 与尺寸无关，重试只是
  /// 把一次失败拖成两次超时。
  static bool _isMissingTier(ManagedImageDownloadFailure? failure) =>
      failure == ManagedImageDownloadFailure.status ||
      failure == ManagedImageDownloadFailure.notImage;

  /// 只下一档，不做退档重试。失败时结果里带原因（不抛）。
  Future<ManagedImageDownloadResult> _downloadAt(
    BingWallpaperItem item,
    BingWallpaperResolution resolution,
  ) async {
    final url = item.fullUrl(resolution);
    appDebugLog(
      _tag,
      'download start date=${item.dateKey} tier=${resolution.name} $url',
    );
    try {
      final result = await downloadToManagedImage(
        url: Uri.parse(url),
        directoryName: kHomePageWallpaperDirectoryName,
        // ⭐ 前缀必须是 `wallpaper`：既有的 `deleteEvictedWallpaperFiles` 按这个前缀
        // 判定「这张图归我管」，改名成别的开头会导致它被挤出历史后删不掉（见
        // `BingWallpaperItem.fileName` 的注释）。
        fileName: item.fileName(resolution),
        client: _client,
      );
      // 每一次尝试都留一行 —— 2026-10-06 用户报「点大图下载失败」而四条分支全都只回
      // null、且日志写进了默认关闭的 AppLogService，于是无从查起（见笔记）。
      // `appDebugLog` 在 debug 下直接进 logcat，不需要用户先开「本地诊断」。
      appDebugLog(
        _tag,
        'download result tier=${resolution.name} ${result.describe()}',
      );
      if (!result.succeeded) {
        await _logWarn('bing_wallpaper_download_failed', result.describe());
      }
      return result;
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'download threw: $error');
      await _logWarn('bing_wallpaper_download_failed', error, stackTrace);
      return const ManagedImageDownloadResult.failed(
        ManagedImageDownloadFailure.network,
      );
    }
  }

  /// 清单缓存多久就重新拉。
  ///
  /// 取 3 小时：Bing 每天换一次，而「每天首次打开 App 自动换」这条主路径本来就带
  /// 独立的按天判据（[BingWallpaperStore.lastAutoAppliedDate]），这里的 TTL 只用来
  /// 防止用户反复进出设置页时反复请求。
  static const Duration _listCacheTtl = Duration(hours: 3);

  /// 要展示的清单：命中缓存就直接给，否则拉网络并顺手更新缓存。
  ///
  /// 缓存是**设备级全局**（存 `BingWallpaperStore`）而不是每个课表一份：图库内容与
  /// 用哪份课表无关。命中的判据是「缓存时间在 TTL 内且非空」—— 空列表也算未命中，
  /// 否则一次失败会被缓存 3 小时，用户当天再也看不到图库。
  static Future<List<BingWallpaperItem>> loadItems({
    bool forceRefresh = false,
  }) async {
    final store = BingWallpaperStore.instance;
    if (!forceRefresh) {
      final cached = store.cachedItems;
      final cachedAt = store.cachedItemsFetchedAt;
      final fresh = cachedAt != null &&
          DateTime.now().difference(cachedAt) < _listCacheTtl;
      if (cached.isNotEmpty && fresh) {
        return cached;
      }
    }
    final service = _createInternal();
    try {
      final items = await service.fetchRecent();
      if (items.isNotEmpty) {
        await store.saveCachedItems(items);
      }
      return items;
    } finally {
      service.dispose();
    }
  }

  /// 自动换的判据 + 下载，返回该用的本地路径。
  ///
  /// 返回 null 的每一种情况都意味着「别动用户的壁纸」：
  /// * 开关关着；
  /// * 今天已经换过（`lastAutoAppliedDate` 等于今天那天的 `dateKey`）；
  /// * 清单里**没有今天那张**（见 [_isToday]）；
  /// * 拉不到清单 / 下载失败。
  ///
  /// 成功时**只**记 [BingWallpaperStore.lastAutoAppliedDate] 与文件台账，
  /// **不碰「最近使用」历史**（理由见笔记「自动换不进历史」）。
  ///
  /// [now] 只给测试用：单测把「今天」钉在固定日期上，不必跟着测试运行时刻漂
  /// （与 `bingWallpaperDateLabel` 的 `now` 同一口径）。
  static Future<String?> maybeApplyDaily({DateTime? now}) async {
    final store = BingWallpaperStore.instance;
    if (!store.autoApplyEnabled) {
      return null;
    }
    final clock = now ?? DateTime.now();
    final items = await loadItems();
    if (items.isEmpty) {
      return null;
    }
    // 清单按新→旧排（Bing 的 `idx=0` 就是今天），首项即当天 —— 但**必须验**，见
    // [_isToday]：清单有 3 小时缓存而 Bing 按本地零点换图，跨零点后首项可能还是昨天。
    var today = items.first;
    if (!_isToday(today, clock)) {
      // 命中的多半是「跨了零点但仍在 TTL 内」的旧缓存：强制重拉一次再验。
      // 注意空清单**不写缓存**（见 [loadItems]），所以这里不会把一次失败缓存住。
      final refreshed = await loadItems(forceRefresh: true);
      if (refreshed.isEmpty || !_isToday(refreshed.first, clock)) {
        // 还是没有今天那张：宁可今天不换（下一次启动会再试），也不能替用户挂一张
        // 隔夜的图、还把昨天记成「今天已换过」——那会让今天真正的图当天再也上不来。
        appDebugLog(_tag, 'daily skipped: no entry for today');
        return null;
      }
      today = refreshed.first;
    }
    if (store.lastAutoAppliedDate == today.dateKey) {
      return null;
    }
    final resolution = store.resolution;
    final service = _createInternal();
    final BingWallpaperDownload result;
    try {
      result = await service.download(today, resolution);
    } finally {
      service.dispose();
    }
    if (!result.succeeded) {
      return null;
    }
    // 下载成功**之后**才记日期：记早了会在下载失败时把当天判成「已换过」，
    // 于是这一天再也不会重试（要等用户下次手动进设置页才可能补上）。
    //
    // 记的是**实际**那档（退档后就是 standard）：文件名与台账键都由它决定，
    // 记用户选的那档会让「同一张图两档」共用一个文件名并被去重掉一次。
    await store.recordApplied(
      dateKey: today.dateKey,
      resolution: result.resolution!,
      path: result.path!,
    );
    return result.path;
  }

  /// [item] 是不是**今天**（按本机日期）那一张。
  ///
  /// ## 为什么必须验，而不能信「首项即今天」
  ///
  /// 清单有 3 小时缓存（[_listCacheTtl]），Bing 却是按**本地零点**换图的。晚上 23:50
  /// 缓存下的清单，到 00:10 仍算「新鲜」，首项却已经是**昨天**那张。若直接拿它当今天
  /// 换上，顺带把昨天记成「今天已换过」，真正的今日壁纸当天就再也上不来了 ——
  /// 而且这个错**没有任何症状**：图库、日期标签、台账全都自洽，只有内容错了一天。
  ///
  /// 解析不了 `dateKey` 一律按「不是今天」处理：宁可今天不换，也不要在脏数据上赌。
  ///
  /// [now] 由 [maybeApplyDaily] 统一注入（生产取 `DateTime.now()`，测试取固定日期），
  /// 所以判据在单测里可复现。
  static bool _isToday(BingWallpaperItem item, DateTime now) {
    final parsed = parseBingWallpaperDateKey(item.dateKey);
    if (parsed == null) {
      return false;
    }
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  static Future<void> _logWarn(
    String category,
    Object? error, [
    StackTrace? stackTrace,
  ]) async {
    try {
      await AppLogService.instance.warn(
        category,
        AppLogMessages.bingWallpaperRequestFailed,
        error: error,
        stackTrace: stackTrace,
      );
    } on Object {
      // 日志本身失败必须彻底静默 —— 这条路径的调用方在启动流程上。
    }
  }

  }