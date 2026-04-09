import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/timetable_settings.dart';

class AppReleaseInfo {
  final String version;
  final String title;
  final String body;
  final String releaseUrl;
  final String? downloadUrl;
  final DateTime? updatedAt;
  final bool isPrerelease;

  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.body,
    required this.releaseUrl,
    required this.downloadUrl,
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

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
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

  const _AppUpdateFetchOutcome({
    this.release,
    this.saw404 = false,
    this.statusCode,
  });
}

class AppUpdateService {
  static const String repositoryUrl = 'https://github.com/Mutx163/mikcb';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases/latest';
  static const String releasesApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases';
  static const String docsReleaseManifestUrl =
      'https://mutx.ccwu.cc/releases/latest.json';
  static const String rawReleaseManifestUrl =
      'https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/releases/latest.json';
  static const String defaultMirrorUrlPrefix = defaultAppUpdateMirrorUrlPrefix;
  static const String downloadCancelledMessage = '下载已取消';

  static const Map<String, String> _releaseHeaders = {
    'Accept': 'application/vnd.github+json, application/json;q=0.9',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'mikcb-app',
  };

  final http.Client _client;
  final AppUpdateTempDirectoryProvider _temporaryDirectoryProvider;
  final AppUpdateOpenInstaller _openInstaller;

  AppUpdateService({
    http.Client? client,
    AppUpdateTempDirectoryProvider? temporaryDirectoryProvider,
    AppUpdateOpenInstaller? openInstaller,
  })  : _client = client ?? http.Client(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _openInstaller = openInstaller ?? OpenFilex.open;

  Future<AppUpdateCheckResult> checkForUpdates({
    required String currentVersion,
    bool includePrerelease = false,
    AppUpdateDownloadSource preferredSource = AppUpdateDownloadSource.original,
    String? mirrorUrlPrefix,
  }) async {
    final manifestCandidates = _buildReleaseManifestCandidates(
      preferredSource: preferredSource,
      mirrorUrlPrefix: mirrorUrlPrefix,
    );

    var saw404 = false;
    int? lastStatusCode;

    try {
      for (final candidate in manifestCandidates) {
        final outcome = await _fetchFromManifest(
          candidate,
          includePrerelease: includePrerelease,
        );
        if (outcome.release != null) {
          return _buildCheckResult(
            currentVersion: currentVersion,
            release: outcome.release!,
          );
        }
        saw404 = saw404 || outcome.saw404;
        lastStatusCode = outcome.statusCode ?? lastStatusCode;
      }

      final apiOutcome = await _fetchFromGitHubApi(
        includePrerelease: includePrerelease,
        preferredSource: preferredSource,
        mirrorUrlPrefix: mirrorUrlPrefix,
      );
      if (apiOutcome.release != null) {
        return _buildCheckResult(
          currentVersion: currentVersion,
          release: apiOutcome.release!,
        );
      }
      saw404 = saw404 || apiOutcome.saw404;
      lastStatusCode = apiOutcome.statusCode ?? lastStatusCode;
    } catch (_) {
      // Fall through to the result builders below.
    }

    if (saw404) {
      return AppUpdateCheckResult(
        hasRelease: false,
        hasUpdate: false,
        currentVersion: currentVersion,
        message: includePrerelease ? '还没有可用的正式版或预发布版本。' : '仓库还没有发布 Release。',
      );
    }

    if (lastStatusCode != null) {
      return AppUpdateCheckResult(
        hasRelease: false,
        hasUpdate: false,
        currentVersion: currentVersion,
        message: '检查更新失败（HTTP $lastStatusCode）。',
      );
    }

    return AppUpdateCheckResult(
      hasRelease: false,
      hasUpdate: false,
      currentVersion: currentVersion,
      message: '网络异常，暂时无法检查更新。',
    );
  }

  Future<String?> downloadAndInstallUpdate(
    String url,
    void Function(int downloadedBytes, int? totalBytes) onProgress,
    AppUpdateDownloadController? controller,
  ) async {
    HttpClient? client;
    IOSink? sink;
    File? file;
    try {
      final tempDir = await _temporaryDirectoryProvider();
      final savePath = '${tempDir.path}/mikcb_update.apk';
      file = File(savePath);

      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return '下载失败（HTTP ${response.statusCode}）';
      }

      final total = response.contentLength;
      int downloaded = 0;
      sink = file.openWrite();

      await for (final chunk in response) {
        if (controller?.isCancelled == true) {
          return downloadCancelledMessage;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded, total <= 0 ? null : total);
      }

      await sink.close();
      sink = null;

      if (controller?.isCancelled == true) {
        return downloadCancelledMessage;
      }

      final result = await _openInstaller(savePath);
      if (result.type != ResultType.done) {
        return '打开安装包失败: ${result.message}';
      }
      return null;
    } catch (e) {
      if (controller?.isCancelled == true) {
        return downloadCancelledMessage;
      }
      return '下载或安装过程中出现错误: $e';
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client?.close(force: true);
      if (controller?.isCancelled == true && file != null) {
        await _deleteFileIfExists(file);
      }
    }
  }

  Future<AppUpdateDownloadProbeResult> probeDownloadUrl(
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const AppUpdateDownloadProbeResult(
        isSuccess: false,
        elapsed: Duration.zero,
        message: '地址无效',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      var response = await _client.head(
        uri,
        headers: const {
          'User-Agent': 'mikcb-app',
        },
      ).timeout(timeout);

      if (response.statusCode == 405 || response.statusCode == 403) {
        response = http.Response(
          '',
          await _probeRangeRequestStatusCode(uri, timeout: timeout),
        );
      }

      stopwatch.stop();
      final isSuccess = response.statusCode >= 200 && response.statusCode < 400;
      return AppUpdateDownloadProbeResult(
        isSuccess: isSuccess,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        message: isSuccess ? null : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      stopwatch.stop();
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
      ..headers.addAll(const {
        'User-Agent': 'mikcb-app',
        'Range': 'bytes=0-0',
      });
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

  List<String> _buildReleaseManifestCandidates({
    required AppUpdateDownloadSource preferredSource,
    String? mirrorUrlPrefix,
  }) {
    final normalizedSelectedMirror = _normalizeMirrorUrlPrefix(mirrorUrlPrefix);
    final fallbackMirrorUrls = <String?>[
      _normalizeMirrorUrlPrefix(defaultAppUpdateMirrorUrlPrefix),
      _normalizeMirrorUrlPrefix(ghproxyCnMirrorUrlPrefix),
      _normalizeMirrorUrlPrefix(ghLlkkMirrorUrlPrefix),
    ];

    final originalCandidates = <String>[
      docsReleaseManifestUrl,
      rawReleaseManifestUrl,
    ];
    final mirrorCandidates = <String>[
      if (normalizedSelectedMirror != null)
        buildDownloadUrl(
          originalUrl: rawReleaseManifestUrl,
          source: AppUpdateDownloadSource.mirror,
          mirrorUrlPrefix: normalizedSelectedMirror,
        ),
      ...fallbackMirrorUrls.whereType<String>().map(
            (prefix) => buildDownloadUrl(
              originalUrl: rawReleaseManifestUrl,
              source: AppUpdateDownloadSource.mirror,
              mirrorUrlPrefix: prefix,
            ),
          ),
    ];

    final ordered = <String>[
      if (preferredSource == AppUpdateDownloadSource.mirror) ...[
        ...mirrorCandidates,
        ...originalCandidates,
      ] else ...[
        ...originalCandidates,
        ...mirrorCandidates,
      ],
    ];

    final seen = <String>{};
    return ordered.where((candidate) {
      final normalized = candidate.trim();
      return normalized.isNotEmpty && seen.add(normalized);
    }).toList(growable: false);
  }

  Future<_AppUpdateFetchOutcome> _fetchFromManifest(
    String url, {
    required bool includePrerelease,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: _releaseHeaders,
      );
      if (response.statusCode == 404) {
        return const _AppUpdateFetchOutcome(saw404: true, statusCode: 404);
      }
      if (response.statusCode != 200) {
        return _AppUpdateFetchOutcome(statusCode: response.statusCode);
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return const _AppUpdateFetchOutcome();
      }

      final manifest = Map<String, dynamic>.from(decoded);
      final release = _pickReleaseFromManifest(
        manifest,
        includePrerelease: includePrerelease,
      );
      return _AppUpdateFetchOutcome(release: release);
    } on FormatException {
      return const _AppUpdateFetchOutcome();
    } catch (_) {
      return const _AppUpdateFetchOutcome();
    }
  }

  Future<_AppUpdateFetchOutcome> _fetchFromGitHubApi({
    required bool includePrerelease,
    required AppUpdateDownloadSource preferredSource,
    String? mirrorUrlPrefix,
  }) async {
    final apiUrl = includePrerelease ? releasesApiUrl : latestReleaseApiUrl;

    for (final candidate in _buildGitHubApiCandidates(
      apiUrl,
      preferredSource: preferredSource,
      mirrorUrlPrefix: mirrorUrlPrefix,
    )) {
      try {
        final response = await _client.get(
          Uri.parse(candidate),
          headers: _releaseHeaders,
        );
        if (response.statusCode == 404) {
          return const _AppUpdateFetchOutcome(saw404: true, statusCode: 404);
        }
        if (response.statusCode != 200) {
          continue;
        }

        final releaseJson = includePrerelease
            ? _pickLatestEligibleRelease(
                jsonDecode(response.body) as List<dynamic>,
                includePrerelease: true,
              )
            : jsonDecode(response.body) as Map<String, dynamic>;
        if (releaseJson == null) {
          return const _AppUpdateFetchOutcome();
        }

        return _AppUpdateFetchOutcome(
          release: _releaseFromGitHubJson(releaseJson),
        );
      } on FormatException {
        continue;
      } catch (_) {
        continue;
      }
    }

    return const _AppUpdateFetchOutcome();
  }

  List<String> _buildGitHubApiCandidates(
    String apiUrl, {
    required AppUpdateDownloadSource preferredSource,
    String? mirrorUrlPrefix,
  }) {
    final normalizedSelectedMirror = _normalizeMirrorUrlPrefix(mirrorUrlPrefix);
    final fallbackMirrorUrls = <String?>[
      _normalizeMirrorUrlPrefix(defaultAppUpdateMirrorUrlPrefix),
      _normalizeMirrorUrlPrefix(ghproxyCnMirrorUrlPrefix),
      _normalizeMirrorUrlPrefix(ghLlkkMirrorUrlPrefix),
    ];

    final originalCandidates = <String>[apiUrl];
    final mirrorCandidates = <String>[
      if (normalizedSelectedMirror != null)
        buildDownloadUrl(
          originalUrl: apiUrl,
          source: AppUpdateDownloadSource.mirror,
          mirrorUrlPrefix: normalizedSelectedMirror,
        ),
      ...fallbackMirrorUrls.whereType<String>().map(
            (prefix) => buildDownloadUrl(
              originalUrl: apiUrl,
              source: AppUpdateDownloadSource.mirror,
              mirrorUrlPrefix: prefix,
            ),
          ),
    ];

    final ordered = <String>[
      if (preferredSource == AppUpdateDownloadSource.mirror) ...[
        ...mirrorCandidates,
        ...originalCandidates,
      ] else ...[
        ...originalCandidates,
        ...mirrorCandidates,
      ],
    ];

    final seen = <String>{};
    return ordered.where((candidate) {
      final normalized = candidate.trim();
      return normalized.isNotEmpty && seen.add(normalized);
    }).toList(growable: false);
  }

  AppUpdateCheckResult _buildCheckResult({
    required String currentVersion,
    required AppReleaseInfo release,
  }) {
    final hasUpdate = _compareVersions(release.version, currentVersion) > 0;
    return AppUpdateCheckResult(
      hasRelease: true,
      hasUpdate: hasUpdate,
      currentVersion: currentVersion,
      latestRelease: release,
      message: hasUpdate
          ? (release.isPrerelease ? '发现新的预发布版本' : '发现新版本')
          : '当前已经是最新版本',
    );
  }

  AppReleaseInfo? _pickReleaseFromManifest(
    Map<String, dynamic> manifest, {
    required bool includePrerelease,
  }) {
    final stable = _releaseFromManifestEntry(manifest['stable']);
    final prerelease = _releaseFromManifestEntry(manifest['prerelease']);

    if (!includePrerelease) {
      return stable;
    }
    if (stable == null) {
      return prerelease;
    }
    if (prerelease == null) {
      return stable;
    }
    return _compareVersions(prerelease.version, stable.version) > 0
        ? prerelease
        : stable;
  }

  AppReleaseInfo? _releaseFromManifestEntry(dynamic rawEntry) {
    if (rawEntry is! Map) {
      return null;
    }
    final entry = Map<String, dynamic>.from(rawEntry);
    final version = _normalizeVersion((entry['version'] as String?) ?? '');
    if (version.isEmpty) {
      return null;
    }
    final title = (entry['title'] as String?)?.trim();
    final releaseUrl = (entry['releaseUrl'] as String?)?.trim();
    final downloadUrl = (entry['downloadUrl'] as String?)?.trim();
    final body = (entry['body'] as String?)?.trim() ?? '';
    return AppReleaseInfo(
      version: version,
      title: title?.isNotEmpty == true ? title! : version,
      body: body,
      releaseUrl: releaseUrl?.isNotEmpty == true ? releaseUrl! : repositoryUrl,
      downloadUrl: downloadUrl?.isNotEmpty == true ? downloadUrl : null,
      updatedAt:
          DateTime.tryParse((entry['updatedAt'] as String?) ?? '')?.toLocal(),
      isPrerelease: entry['isPrerelease'] as bool? ?? false,
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
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
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

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
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
    final base =
        hasExplicitPrerelease ? normalized.substring(0, dashIndex) : normalized;
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

    final numericDottedSuffixParts =
        !hasExplicitPrerelease && baseParts.length > 3
            ? _parseNumericParts(baseParts.skip(3).join('.'))
            : null;
    if (numericDottedSuffixParts != null &&
        numericDottedSuffixParts.isNotEmpty) {
      return _ParsedVersion(
        mainParts: [
          ...baseParts.take(3).map(
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

  const _ParsedVersion({
    required this.mainParts,
    required this.prerelease,
  });
}
