import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_debug_log.dart';
import '../l10n/service_message_localizer.dart';
import '../models/timetable_settings.dart';
import '../utils/async_utils.dart';
import 'app_http_client.dart';

/// A single log entry from the update process.
class UpdateLogEntry {
  final DateTime timestamp;
  final String message;

  const UpdateLogEntry(this.timestamp, this.message);

  String get timeString {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class AppReleaseInfo {
  final String version;
  final String title;
  final String body;
  final String releaseUrl;
  final String? downloadUrl;
  final String? pgyerDownloadUrl; // 蒲公英下载页面（来自蒲公英 API 时有值）
  final DateTime? updatedAt;
  final bool isPrerelease;

  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.body,
    required this.releaseUrl,
    required this.downloadUrl,
    this.pgyerDownloadUrl,
    required this.updatedAt,
    required this.isPrerelease,
  });
}

class AppUpdateCheckResult {
  final bool hasRelease;
  final bool hasUpdate;
  final String currentVersion;
  final AppReleaseInfo? latestRelease;
  final String? message;

  const AppUpdateCheckResult({
    required this.hasRelease,
    required this.hasUpdate,
    required this.currentVersion,
    this.latestRelease,
    this.message,
  });
}

class AppUpdateDownloadController {
  bool _isCancelled = false;
  void Function()? _cancelHandler;

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final handler = _cancelHandler;
    _cancelHandler = null;
    handler?.call();
  }

  void _setCancelHandler(void Function()? handler) {
    _cancelHandler = handler;
    if (_isCancelled && handler != null) {
      _cancelHandler = null;
      handler();
    }
  }
}

typedef AppUpdateTempDirectoryProvider = Future<Directory> Function();
typedef AppUpdateOpenInstaller = Future<OpenResult> Function(String path);

class AppUpdateDownloadProbeResult {
  final bool isSuccess;
  final Duration elapsed;
  final int? statusCode;
  final String? message;

  const AppUpdateDownloadProbeResult({
    required this.isSuccess,
    required this.elapsed,
    this.statusCode,
    this.message,
  });
}

class _AppUpdateFetchOutcome {
  final AppReleaseInfo? release;
  final bool saw404;
  final int? statusCode;
  final bool hadRetryableFailure;

  const _AppUpdateFetchOutcome({
    this.release,
    this.saw404 = false,
    this.statusCode,
    this.hadRetryableFailure = false,
  });
}

class AppUpdateService {
  static const String repositoryUrl = 'https://github.com/Mutx163/mikcb';

  /// Update process logs (most recent first, capped at 50).
  final List<UpdateLogEntry> logs = [];

  void _log(String message) {
    final now = DateTime.now();
    final entry = UpdateLogEntry(now, message);
    logs.insert(0, entry);
    if (logs.length > 50) logs.removeLast();
    appDebugLog('AppUpdateService', '${formatLogTimestamp(now)} $message');
  }

  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases/latest';
  static const String releasesApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases';
  static const String releasesPageUrl = '$repositoryUrl/releases';
  static const String defaultMirrorUrlPrefix = defaultAppUpdateMirrorUrlPrefix;
  static const String downloadCancelledMessage = 'download_cancelled';
  static const Duration _releaseRequestTimeout = Duration(seconds: 4);
  static const Duration _releasesPageRequestTimeout = Duration(seconds: 6);

  static final RegExp _releaseSectionPattern = RegExp(
    r'<section\b[^>]*>(.*?)</section>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _releaseTagPattern = RegExp(
    r'href="/Mutx163/mikcb/releases/tag/([^"#?]+)"',
    caseSensitive: false,
  );
  static final RegExp _releaseTitlePattern = RegExp(
    r'<a[^>]*href="/Mutx163/mikcb/releases/tag/[^"]+"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _releaseBodyPattern = RegExp(
    r'<div[^>]*data-test-selector="body-content"[^>]*>(.*?)</div>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _releaseUpdatedAtPattern = RegExp(
    r'<relative-time[^>]*datetime="([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _expandedAssetsPattern = RegExp(
    r'src="([^"]+/releases/expanded_assets/[^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _apkDownloadPattern = RegExp(
    r'href="(/Mutx163/mikcb/releases/download/[^"]+?\.apk)"',
    caseSensitive: false,
  );

  static const Map<String, String> _releaseHeaders = {
    'Accept': 'application/vnd.github+json, application/json;q=0.9',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'mikcb-app',
  };
  static const Map<String, String> _releasePageHeaders = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'User-Agent': 'mikcb-app',
  };

  final http.Client _client;
  final AppUpdateTempDirectoryProvider _temporaryDirectoryProvider;
  final AppUpdateOpenInstaller _openInstaller;
  final Duration _releaseApiRequestTimeout;

  AppUpdateService({
    http.Client? client,
    AppUpdateTempDirectoryProvider? temporaryDirectoryProvider,
    AppUpdateOpenInstaller? openInstaller,
    this._releaseApiRequestTimeout = _releaseRequestTimeout,
  }) : _client = client ?? createAppHttpClient(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _openInstaller = openInstaller ?? OpenFilex.open;

  Future<AppUpdateCheckResult> checkForUpdates({
    required String currentVersion,
    bool includePrerelease = false,
    AppUpdateDownloadSource preferredSource = AppUpdateDownloadSource.original,
    String? mirrorUrlPrefix,
  }) async {
    _log('开始检查更新（当前版本 $currentVersion，含预发布: $includePrerelease）');

    // 两个策略并行竞争，谁先有结果用谁
    _AppUpdateFetchOutcome? apiOutcome;
    _AppUpdateFetchOutcome? pageOutcome;

    final result = await raceFutures<_AppUpdateFetchOutcome, _AppUpdateFetchOutcome>([
      _fetchFromGitHubApi(
        includePrerelease: includePrerelease,
        preferredSource: preferredSource,
        mirrorUrlPrefix: mirrorUrlPrefix,
      ).then((outcome) {
        apiOutcome = outcome;
        _log(
          'GitHub API 完成，有结果: ${outcome.release != null}，状态码: ${outcome.statusCode}',
        );
        return outcome;
      }),
      _fetchFromReleasesPage(
        includePrerelease: includePrerelease,
        mirrorUrlPrefix: mirrorUrlPrefix,
      ).then((outcome) {
        pageOutcome = outcome;
        _log(
          'Release 页面 完成，有结果: ${outcome.release != null}，状态码: ${outcome.statusCode}',
        );
        return outcome;
      }),
    ], (outcome) => outcome.release != null ? outcome : null);

    final winner = result.winner;

    if (winner != null) {
      _log('竞争胜出，版本 ${winner.release!.version}');
      return _buildCheckResult(
        currentVersion: currentVersion,
        release: winner.release!,
      );
    }

    // 两个策略都没有结果，汇总错误信息
    final saw404 =
        (apiOutcome?.saw404 ?? false) || (pageOutcome?.saw404 ?? false);
    final hadRetryableFailure =
        (apiOutcome?.hadRetryableFailure ?? false) ||
        (pageOutcome?.hadRetryableFailure ?? false);
    final lastStatusCode = _pickLastNon404StatusCode(
      apiOutcome?.statusCode,
      pageOutcome?.statusCode,
    );

    if (saw404 && !hadRetryableFailure && lastStatusCode == null) {
      _log('所有策略均未获取到版本');
      return AppUpdateCheckResult(
        hasRelease: false,
        hasUpdate: false,
        currentVersion: currentVersion,
        message: includePrerelease
            ? 'no_release_with_prerelease'
            : 'no_release_available',
      );
    }

    if (lastStatusCode != null) {
      _log('检查更新失败，最后 HTTP 状态码: $lastStatusCode');
      return AppUpdateCheckResult(
        hasRelease: false,
        hasUpdate: false,
        currentVersion: currentVersion,
        message: encodeServiceMessage('update_check_http_failed', {
          'statusCode': lastStatusCode,
        }),
      );
    }

    _log('网络异常，所有策略均失败');
    return AppUpdateCheckResult(
      hasRelease: false,
      hasUpdate: false,
      currentVersion: currentVersion,
      message: 'update_check_network_failed',
    );
  }

  static int? _pickLastNon404StatusCode(int? a, int? b) {
    if (a != null && a != 404) return a;
    if (b != null && b != 404) return b;
    return null;
  }

  Future<String?> downloadAndInstallUpdate(
    String url,
    void Function(int downloadedBytes, int? totalBytes) onProgress,
    AppUpdateDownloadController? controller, {
    String? mirrorUrlPrefix,
  }) async {
    if (!isTrustedApkDownloadUrl(url, mirrorUrlPrefix: mirrorUrlPrefix)) {
      _log('拒绝不受信任的更新下载地址：$url');
      return 'update_download_url_untrusted';
    }
    _log('开始下载更新：$url');
    HttpClient? client;
    IOSink? sink;
    File? file;
    try {
      final tempDir = await _temporaryDirectoryProvider();
      await _cleanupManagedInstallerFiles(tempDir);
      final savePath = '${tempDir.path}/mikcb_update.apk';
      file = File(savePath);
      await _deleteFileIfExists(file);

      client = HttpClient();
      controller?._setCancelHandler(() => client?.close(force: true));
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        _log('下载失败，HTTP ${response.statusCode}');
        return encodeServiceMessage('update_download_http_failed', {
          'statusCode': response.statusCode,
        });
      }

      final total = response.contentLength;
      _log(
        '下载响应 OK，文件大小: ${total > 0 ? '${(total / 1024 / 1024).toStringAsFixed(1)} MB' : '未知'}',
      );
      int downloaded = 0;
      sink = file.openWrite();

      await for (final chunk in response) {
        if (controller?.isCancelled == true) {
          _log('下载被用户取消');
          return downloadCancelledMessage;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded, total <= 0 ? null : total);
      }

      await sink.close();
      sink = null;

      if (controller?.isCancelled == true) {
        _log('下载被用户取消');
        return downloadCancelledMessage;
      }

      _log('下载完成，${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB，正在打开安装…');
      final result = await _openInstaller(savePath);
      if (result.type != ResultType.done) {
        _log('打开安装包失败: ${result.message}');
        return encodeServiceMessage('update_open_installer_failed', {
          'detail': result.message,
        });
      }
      _log('安装包已打开');
      return null;
    } catch (e) {
      if (controller?.isCancelled == true) {
        _log('下载被用户取消');
        return downloadCancelledMessage;
      }
      _log('下载或安装异常：$e');
      return encodeServiceMessage('update_download_install_error', {
        'detail': '$e',
      });
    } finally {
      controller?._setCancelHandler(null);
      try {
        await sink?.close();
      } catch (_) {}
      client?.close(force: true);
      if (controller?.isCancelled == true && file != null) {
        await _deleteFileIfExists(file);
      }
    }
  }

  Future<void> _cleanupManagedInstallerFiles(Directory tempDir) async {
    if (!tempDir.existsSync()) {
      return;
    }
    await for (final entity in tempDir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      final normalized = name.toLowerCase();
      if (!normalized.startsWith('mikcb_update') ||
          !normalized.endsWith('.apk')) {
        continue;
      }
      await _deleteFileIfExists(entity);
    }
  }

  Future<AppUpdateDownloadProbeResult> probeDownloadUrl(
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _log('测速失败：地址无效 $url');
      return const AppUpdateDownloadProbeResult(
        isSuccess: false,
        elapsed: Duration.zero,
        message: 'invalid_url',
      );
    }

    _log('测速 $url …');
    final stopwatch = Stopwatch()..start();
    try {
      var response = await _client
          .head(uri, headers: const {'User-Agent': 'mikcb-app'})
          .timeout(timeout);

      if (response.statusCode == 405 || response.statusCode == 403) {
        response = http.Response(
          '',
          await _probeRangeRequestStatusCode(uri, timeout: timeout),
        );
      }

      stopwatch.stop();
      final isSuccess = response.statusCode >= 200 && response.statusCode < 400;
      _log(
        '测速结果：${isSuccess ? '成功' : '失败'} HTTP ${response.statusCode}，耗时 ${stopwatch.elapsedMilliseconds} ms',
      );
      return AppUpdateDownloadProbeResult(
        isSuccess: isSuccess,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        message: isSuccess ? null : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      stopwatch.stop();
      _log('测速异常：$error，耗时 ${stopwatch.elapsedMilliseconds} ms');
      return AppUpdateDownloadProbeResult(
        isSuccess: false,
        elapsed: stopwatch.elapsed,
        message: error.runtimeType.toString(),
      );
    }
  }

  Future<int> _probeRangeRequestStatusCode(
    Uri uri, {
    required Duration timeout,
  }) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(const {'User-Agent': 'mikcb-app', 'Range': 'bytes=0-0'});
    final response = await _client.send(request).timeout(timeout);
    final subscription = response.stream.listen(null);
    try {
      return response.statusCode;
    } finally {
      await subscription.cancel();
    }
  }

  String buildDownloadUrl({
    required String originalUrl,
    required AppUpdateDownloadSource source,
    required String mirrorUrlPrefix,
  }) {
    if (source != AppUpdateDownloadSource.mirror) {
      return originalUrl;
    }

    final normalizedPrefix = mirrorUrlPrefix.trim();
    if (normalizedPrefix.isEmpty) {
      return originalUrl;
    }

    final separator = normalizedPrefix.endsWith('/') ? '' : '/';
    return '$normalizedPrefix$separator$originalUrl';
  }

  /// 获取下载链接（根据下载渠道）
  String? getEffectiveDownloadUrl({
    required AppReleaseInfo? release,
    required AppUpdateDownloadChannel channel,
    required AppUpdateDownloadSource source,
    required String mirrorUrlPrefix,
  }) {
    if (channel == AppUpdateDownloadChannel.pgyer) {
      // 蒲公英渠道：优先返回蒲公英下载页面，兜底用固定地址
      return release?.pgyerDownloadUrl ?? 'https://www.pgyer.com/qingyu';
    } else {
      // GitHub 渠道：返回 GitHub 下载链接（可能经过镜像加速）
      final originalUrl = release?.downloadUrl;
      if (originalUrl == null) return null;
      return buildDownloadUrl(
        originalUrl: originalUrl,
        source: source,
        mirrorUrlPrefix: mirrorUrlPrefix,
      );
    }
  }

  Future<_AppUpdateFetchOutcome> _fetchFromReleasesPage({
    required bool includePrerelease,
    required String? mirrorUrlPrefix,
  }) async {
    final pageCandidates = buildMirrorCandidateUrls(
      releasesPageUrl,
      selectedMirrorPrefix: mirrorUrlPrefix,
    );
    _log('Release 页面候选地址 ${pageCandidates.length} 个，并行竞争');

    final outcomes = <_AppUpdateFetchOutcome>[];
    final result =
        await raceFutures<_AppUpdateFetchOutcome, _AppUpdateFetchOutcome>(
          pageCandidates.map((candidate) {
            return _fetchReleasesPageCandidate(
              candidate,
              includePrerelease: includePrerelease,
              mirrorUrlPrefix: mirrorUrlPrefix,
            ).then((outcome) {
              outcomes.add(outcome);
              return outcome;
            });
          }).toList(),
          (outcome) => outcome.release != null ? outcome : null,
        );

    if (result.winner != null) {
      return result.winner!;
    }

    var saw404 = false;
    var hadRetryableFailure = false;
    int? lastStatusCode;
    for (final outcome in outcomes) {
      saw404 = saw404 || outcome.saw404;
      hadRetryableFailure = hadRetryableFailure || outcome.hadRetryableFailure;
      lastStatusCode = outcome.statusCode ?? lastStatusCode;
    }
    for (final error in result.errors) {
      hadRetryableFailure = true;
      _log('页面候选异常：$error');
    }

    return _AppUpdateFetchOutcome(
      saw404: saw404,
      statusCode: lastStatusCode,
      hadRetryableFailure: hadRetryableFailure,
    );
  }

  Future<_AppUpdateFetchOutcome> _fetchReleasesPageCandidate(
    String candidate, {
    required bool includePrerelease,
    required String? mirrorUrlPrefix,
  }) async {
    try {
      _log('请求 $candidate');
      final response = await _client
          .get(Uri.parse(candidate), headers: _releasePageHeaders)
          .timeout(_releasesPageRequestTimeout);
      if (response.statusCode == 404) {
        _log('页面响应 404');
        return const _AppUpdateFetchOutcome(saw404: true, statusCode: 404);
      }
      if (response.statusCode != 200) {
        _log('页面响应 ${response.statusCode}，跳过');
        return _AppUpdateFetchOutcome(
          statusCode: response.statusCode,
          hadRetryableFailure: true,
        );
      }

      final html = utf8.decode(response.bodyBytes);
      final release = await _pickLatestEligibleReleaseFromPage(
        html,
        includePrerelease: includePrerelease,
        mirrorUrlPrefix: mirrorUrlPrefix,
      );
      if (release != null) {
        return _AppUpdateFetchOutcome(release: release);
      }

      return const _AppUpdateFetchOutcome(saw404: true, statusCode: 404);
    } on TimeoutException {
      return const _AppUpdateFetchOutcome(hadRetryableFailure: true);
    } catch (_) {
      return const _AppUpdateFetchOutcome(hadRetryableFailure: true);
    }
  }

  Future<_AppUpdateFetchOutcome> _fetchFromGitHubApi({
    required bool includePrerelease,
    required AppUpdateDownloadSource preferredSource,
    String? mirrorUrlPrefix,
  }) async {
    final candidates = _buildGitHubApiCandidates(
      releasesApiUrl,
      preferredSource: preferredSource,
      mirrorUrlPrefix: mirrorUrlPrefix,
    );
    _log('GitHub API 候选地址 ${candidates.length} 个，并行竞争');

    // 所有镜像并行竞争，谁先有结果用谁
    final outcomes = <_AppUpdateFetchOutcome>[];
    final result =
        await raceFutures<_AppUpdateFetchOutcome, _AppUpdateFetchOutcome>(
          candidates.map((candidate) {
            return _fetchGitHubApiCandidate(
              candidate,
              includePrerelease: includePrerelease,
            ).then((outcome) {
              outcomes.add(outcome);
              return outcome;
            });
          }).toList(),
          (outcome) => outcome.release != null ? outcome : null,
        );

    if (result.winner != null) {
      return result.winner!;
    }

    // 所有候选均无结果，汇总错误信息
    var saw404 = false;
    var hadRetryableFailure = false;
    int? lastStatusCode;
    for (final outcome in outcomes) {
      saw404 = saw404 || outcome.saw404;
      hadRetryableFailure = hadRetryableFailure || outcome.hadRetryableFailure;
      lastStatusCode = outcome.statusCode ?? lastStatusCode;
    }
    for (final error in result.errors) {
      hadRetryableFailure = true;
      _log('候选异常：$error');
    }

    return _AppUpdateFetchOutcome(
      saw404: saw404,
      statusCode: lastStatusCode,
      hadRetryableFailure: hadRetryableFailure,
    );
  }

  Future<_AppUpdateFetchOutcome> _fetchGitHubApiCandidate(
    String candidate, {
    required bool includePrerelease,
  }) async {
    try {
      _log('请求 $candidate');
      final response = await _client
          .get(Uri.parse(candidate), headers: _releaseHeaders)
          .timeout(_releaseApiRequestTimeout);
      if (response.statusCode == 404) {
        _log('API 响应 404');
        return const _AppUpdateFetchOutcome(saw404: true, statusCode: 404);
      }
      if (response.statusCode != 200) {
        _log('API 响应 ${response.statusCode}，跳过');
        return _AppUpdateFetchOutcome(
          statusCode: response.statusCode,
          hadRetryableFailure: true,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return const _AppUpdateFetchOutcome();
      }

      final releaseJson = _pickLatestEligibleRelease(
        decoded,
        includePrerelease: includePrerelease,
      );
      if (releaseJson == null) {
        return const _AppUpdateFetchOutcome();
      }

      return _AppUpdateFetchOutcome(
        release: _releaseFromGitHubJson(releaseJson),
      );
    } on TimeoutException {
      return const _AppUpdateFetchOutcome(hadRetryableFailure: true);
    } on FormatException {
      return const _AppUpdateFetchOutcome(hadRetryableFailure: true);
    } catch (_) {
      return const _AppUpdateFetchOutcome(hadRetryableFailure: true);
    }
  }

  List<String> _buildGitHubApiCandidates(
    String apiUrl, {
    required AppUpdateDownloadSource preferredSource,
    String? mirrorUrlPrefix,
  }) {
    final normalizedSelectedMirror = _normalizeMirrorUrlPrefix(mirrorUrlPrefix);
    final mirrorCandidates = buildMirrorCandidateUrls(
      apiUrl,
      selectedMirrorPrefix: normalizedSelectedMirror,
    );

    // 按 preferredSource 决定顺序
    if (preferredSource == AppUpdateDownloadSource.mirror) {
      return mirrorCandidates;
    } else {
      // 直连优先，镜像兜底
      final direct = mirrorCandidates.last; // 原始 URL 在最后
      final mirrors = mirrorCandidates.sublist(0, mirrorCandidates.length - 1);
      return [direct, ...mirrors];
    }
  }

  AppUpdateCheckResult _buildCheckResult({
    required String currentVersion,
    required AppReleaseInfo release,
  }) {
    final hasUpdate = _compareVersions(release.version, currentVersion) > 0;
    _log(
      '版本比较：最新 ${release.version} vs 当前 $currentVersion → ${hasUpdate ? '有更新' : '已是最新'}',
    );
    return AppUpdateCheckResult(
      hasRelease: true,
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestRelease: release,
      message: hasUpdate
          ? (release.isPrerelease
                ? 'update_available_prerelease'
                : 'update_available')
          : 'already_latest',
    );
  }

  AppReleaseInfo _releaseFromGitHubJson(Map<String, dynamic> releaseJson) {
    final latestVersion = _normalizeVersion(
      (releaseJson['tag_name'] as String?) ??
          (releaseJson['name'] as String?) ??
          '',
    );
    return AppReleaseInfo(
      version: latestVersion,
      title: (releaseJson['name'] as String?)?.trim().isNotEmpty == true
          ? (releaseJson['name'] as String).trim()
          : latestVersion,
      body: (releaseJson['body'] as String?)?.trim() ?? '',
      releaseUrl: (releaseJson['html_url'] as String?) ?? repositoryUrl,
      downloadUrl: _pickDownloadUrl(
        releaseJson['assets'] as List<dynamic>? ?? const [],
      ),
      updatedAt: DateTime.tryParse(
        (releaseJson['updated_at'] as String?) ??
            (releaseJson['published_at'] as String?) ??
            '',
      )?.toLocal(),
      isPrerelease: releaseJson['prerelease'] as bool? ?? false,
    );
  }

  String? _normalizeMirrorUrlPrefix(String? prefix) {
    final candidate = prefix?.trim() ?? '';
    if (candidate.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return candidate;
  }

  String? _pickDownloadUrl(List<dynamic> assets) {
    final normalizedAssets = assets
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();

    for (final asset in normalizedAssets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith('.apk') && !name.contains('debug')) {
        return asset['browser_download_url'] as String?;
      }
    }

    for (final asset in normalizedAssets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String?;
      }
    }

    final firstAsset = normalizedAssets.isEmpty ? null : normalizedAssets.first;
    return firstAsset?['browser_download_url'] as String?;
  }

  bool _hasUsableDownloadUrl(Map<String, dynamic> releaseJson) {
    return _pickDownloadUrl(
          releaseJson['assets'] as List<dynamic>? ?? const [],
        ) !=
        null;
  }

  Future<AppReleaseInfo?> _pickLatestEligibleReleaseFromPage(
    String html, {
    required bool includePrerelease,
    required String? mirrorUrlPrefix,
  }) async {
    for (final match in _releaseSectionPattern.allMatches(html)) {
      final block = match.group(1);
      if (block == null || block.isEmpty) {
        continue;
      }
      final tagMatch = _releaseTagPattern.firstMatch(block);
      final rawTag = tagMatch?.group(1);
      if (rawTag == null || rawTag.isEmpty) {
        continue;
      }

      final isPrerelease = block.contains('Pre-release');
      if (!includePrerelease && isPrerelease) {
        continue;
      }

      // 优先从 tag 直接构造下载链接（APK 命名规律：mikcb-{version}-arm64-v8a.apk）
      // 避免每次都发起 expanded_assets 子请求，国内用户常因该子请求超时/403 导致选错版本
      final version = _normalizeVersion(rawTag);
      final constructedUrl = _constructApkDownloadUrl(rawTag, version);
      final downloadUrl =
          constructedUrl ??
          await _fetchApkDownloadUrlFromExpandedAssets(
            _extractExpandedAssetsUrl(block, rawTag),
            mirrorUrlPrefix: mirrorUrlPrefix,
          );
      if (downloadUrl == null) {
        continue;
      }

      final title = _extractReleaseTitle(block) ?? version;
      return AppReleaseInfo(
        version: version,
        title: title,
        body: _extractReleaseBody(block),
        releaseUrl: _resolveGitHubUrl('/Mutx163/mikcb/releases/tag/$rawTag'),
        downloadUrl: downloadUrl,
        updatedAt: _extractReleaseUpdatedAt(block),
        isPrerelease: isPrerelease,
      );
    }

    return null;
  }

  /// 根据 tag 和版本号构造 APK 下载链接。
  ///
  /// 本仓库所有历史 release 的 APK 命名遵循固定模式：
  /// `mikcb-{version}-arm64-v8a.apk`，下载路径为
  /// `https://github.com/Mutx163/mikcb/releases/download/{tag}/mikcb-{version}-arm64-v8a.apk`。
  /// 只有极早期 v1.0.1 是 `mikcb-1.0.1.apk`（无 ABI 后缀），不在此构造路径覆盖范围。
  /// 对于不匹配命名规律的 tag，返回 null，交由 expanded_assets 兜底。
  String? _constructApkDownloadUrl(String rawTag, String version) {
    final tagWithoutPrefix = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
    if (tagWithoutPrefix.isEmpty) {
      return null;
    }
    final fileName = 'mikcb-$version-arm64-v8a.apk';
    final encodedTag = Uri.encodeComponent(rawTag);
    return '$repositoryUrl/releases/download/$encodedTag/$fileName';
  }

  String _extractExpandedAssetsUrl(String block, String tag) {
    final match = _expandedAssetsPattern.firstMatch(block);
    final expandedAssetsUrl = match?.group(1);
    if (expandedAssetsUrl != null && expandedAssetsUrl.isNotEmpty) {
      return expandedAssetsUrl;
    }
    final encodedTag = Uri.encodeComponent(tag);
    return '$repositoryUrl/releases/expanded_assets/$encodedTag';
  }

  Future<String?> _fetchApkDownloadUrlFromExpandedAssets(
    String url, {
    String? mirrorUrlPrefix,
  }) async {
    final candidates = buildMirrorCandidateUrls(
      url,
      selectedMirrorPrefix: mirrorUrlPrefix,
    );
    for (final candidate in candidates) {
      try {
        final response = await _client
            .get(Uri.parse(candidate), headers: _releasePageHeaders)
            .timeout(_releasesPageRequestTimeout);
        if (response.statusCode != 200) {
          continue;
        }
        final html = utf8.decode(response.bodyBytes);
        final match = _apkDownloadPattern.firstMatch(html);
        final assetPath = match?.group(1);
        if (assetPath == null || assetPath.isEmpty) {
          continue;
        }
        return _resolveGitHubUrl(assetPath);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String? _extractReleaseTitle(String block) {
    final match = _releaseTitlePattern.firstMatch(block);
    final rawTitle = match?.group(1);
    if (rawTitle == null || rawTitle.isEmpty) {
      return null;
    }
    final title = _htmlToPlainText(rawTitle).trim();
    return title.isEmpty ? null : title;
  }

  String _extractReleaseBody(String block) {
    final match = _releaseBodyPattern.firstMatch(block);
    final rawBody = match?.group(1);
    if (rawBody == null || rawBody.isEmpty) {
      return '';
    }
    return _htmlToPlainText(rawBody).trim();
  }

  DateTime? _extractReleaseUpdatedAt(String block) {
    final match = _releaseUpdatedAtPattern.firstMatch(block);
    final rawUpdatedAt = match?.group(1);
    return rawUpdatedAt == null
        ? null
        : DateTime.tryParse(rawUpdatedAt)?.toLocal();
  }

  String _resolveGitHubUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    return 'https://github.com$pathOrUrl';
  }

  String _htmlToPlainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }

  String _normalizeVersion(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  int _compareVersions(String left, String right) {
    final leftVersion = _parseVersion(left);
    final rightVersion = _parseVersion(right);
    final maxLength =
        leftVersion.mainParts.length > rightVersion.mainParts.length
        ? leftVersion.mainParts.length
        : rightVersion.mainParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftVersion.mainParts.length
          ? leftVersion.mainParts[index]
          : 0;
      final rightValue = index < rightVersion.mainParts.length
          ? rightVersion.mainParts[index]
          : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    final leftPre = leftVersion.prerelease;
    final rightPre = rightVersion.prerelease;
    if (leftPre == null && rightPre == null) {
      return 0;
    }
    if (leftPre == null) {
      return 1;
    }
    if (rightPre == null) {
      return -1;
    }
    return _comparePrerelease(leftPre, rightPre);
  }

  _ParsedVersion _parseVersion(String version) {
    final normalized = _normalizeVersion(version).split('+').first;
    final dashIndex = normalized.indexOf('-');
    final hasExplicitPrerelease = dashIndex != -1;
    final base = hasExplicitPrerelease
        ? normalized.substring(0, dashIndex)
        : normalized;
    final explicitPrerelease = hasExplicitPrerelease
        ? normalized.substring(dashIndex + 1).trim()
        : null;
    final baseParts = base.split('.');
    final numericExplicitPrereleaseParts = explicitPrerelease == null
        ? null
        : _parseNumericParts(explicitPrerelease);
    if (numericExplicitPrereleaseParts != null &&
        numericExplicitPrereleaseParts.isNotEmpty) {
      return _ParsedVersion(
        mainParts: [
          ...baseParts.map(
            (item) => int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          ),
          ...numericExplicitPrereleaseParts,
        ],
        prerelease: null,
      );
    }
    // 处理 "1.2.0-29-debug" 这类含数字前缀的预发布：
    // 提取 "29" 作为构建号，剩余 "debug" 作为预发布标识
    if (explicitPrerelease != null) {
      final numericPrefix = _extractNumericPrefixParts(explicitPrerelease);
      if (numericPrefix != null && numericPrefix.isNotEmpty) {
        // "29-debug" -> mainParts append 29, prerelease null
        return _ParsedVersion(
          mainParts: [
            ...baseParts.map(
              (item) =>
                  int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
            ),
            ...numericPrefix,
          ],
          prerelease: null,
        );
      }
    }

    final numericDottedSuffixParts =
        !hasExplicitPrerelease && baseParts.length > 3
        ? _parseNumericParts(baseParts.skip(3).join('.'))
        : null;
    if (numericDottedSuffixParts != null &&
        numericDottedSuffixParts.isNotEmpty) {
      return _ParsedVersion(
        mainParts: [
          ...baseParts
              .take(3)
              .map(
                (item) =>
                    int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
              ),
          ...numericDottedSuffixParts,
        ],
        prerelease: null,
      );
    }

    final hasDottedPrerelease = !hasExplicitPrerelease && baseParts.length > 3;
    final main = hasDottedPrerelease ? baseParts.take(3).join('.') : base;
    final prerelease = hasExplicitPrerelease
        ? explicitPrerelease
        : hasDottedPrerelease
        ? baseParts.skip(3).join('.')
        : null;
    return _ParsedVersion(
      mainParts: main
          .split('.')
          .map(
            (item) => int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          )
          .toList(),
      prerelease: prerelease == null || prerelease.isEmpty ? null : prerelease,
    );
  }

  List<int>? _parseNumericParts(String raw) {
    final parts = raw
        .split('.')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    final values = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null) {
        return null;
      }
      values.add(value);
    }
    return values;
  }

  /// 提取 "29-debug" 中的数字前缀部分 [29]，
  /// 或 "1.2.3-xxx" 中的 [1, 2, 3]。
  List<int>? _extractNumericPrefixParts(String raw) {
    final parts = raw.split('.');
    final values = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value != null) {
        values.add(value);
        continue;
      }
      // 尝试提取段内的数字前缀，如 "29-debug" → 29
      final match = RegExp(r'^\d+').firstMatch(part);
      if (match != null) {
        final prefixValue = int.tryParse(match.group(0)!);
        if (prefixValue != null) {
          values.add(prefixValue);
        }
      }
      break; // 遇到非纯数字段就停止
    }
    return values.isEmpty ? null : values;
  }

  int _comparePrerelease(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : '';
      final rightValue = index < rightParts.length ? rightParts[index] : '';
      if (leftValue == rightValue) {
        continue;
      }
      final leftNumber = int.tryParse(leftValue);
      final rightNumber = int.tryParse(rightValue);
      if (leftNumber != null && rightNumber != null) {
        return leftNumber.compareTo(rightNumber);
      }
      // 提取数字前缀处理 "29" vs "29-debug" 这类情况
      final leftPrefix = leftNumber ?? _extractNumericPrefix(leftValue);
      final rightPrefix = rightNumber ?? _extractNumericPrefix(rightValue);
      if (leftPrefix != null && rightPrefix != null) {
        if (leftPrefix != rightPrefix) {
          return leftPrefix.compareTo(rightPrefix);
        }
        // 数字前缀相同，继续比较下一段
        continue;
      }
      if (leftNumber != null) {
        return -1;
      }
      if (rightNumber != null) {
        return 1;
      }
      return leftValue.compareTo(rightValue);
    }

    return 0;
  }

  static int? _extractNumericPrefix(String value) {
    final match = RegExp(r'^\d+').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  Map<String, dynamic>? _pickLatestEligibleRelease(
    List<dynamic> rawList, {
    required bool includePrerelease,
  }) {
    Map<String, dynamic>? bestRelease;
    String? bestVersion;

    for (final item in rawList) {
      if (item is! Map) {
        continue;
      }
      final release = Map<String, dynamic>.from(item);
      if (release['draft'] == true) {
        continue;
      }
      if (!includePrerelease && release['prerelease'] == true) {
        continue;
      }
      if (!_hasUsableDownloadUrl(release)) {
        continue;
      }

      final candidateVersion = _normalizeVersion(
        (release['tag_name'] as String?) ?? (release['name'] as String?) ?? '',
      );
      if (candidateVersion.isEmpty) {
        continue;
      }

      if (bestRelease == null ||
          bestVersion == null ||
          _compareVersions(candidateVersion, bestVersion) > 0) {
        bestRelease = release;
        bestVersion = candidateVersion;
      }
    }

    return bestRelease;
  }
}

class _ParsedVersion {
  final List<int> mainParts;
  final String? prerelease;

  const _ParsedVersion({required this.mainParts, required this.prerelease});
}
