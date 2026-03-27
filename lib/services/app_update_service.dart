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

class AppUpdateService {
  static const String repositoryUrl = 'https://github.com/Mutx163/mikcb';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases/latest';
  static const String releasesApiUrl =
      'https://api.github.com/repos/Mutx163/mikcb/releases';
  static const String defaultMirrorUrlPrefix = 'https://ghfast.top/';

  final http.Client _client;

  AppUpdateService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<AppUpdateCheckResult> checkForUpdates({
    required String currentVersion,
    bool includePrerelease = false,
  }) async {
    try {
      final apiUrl = includePrerelease ? releasesApiUrl : latestReleaseApiUrl;
      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'mikcb-app',
        },
      );

      if (response.statusCode == 404) {
        return AppUpdateCheckResult(
          hasRelease: false,
          hasUpdate: false,
          currentVersion: currentVersion,
          message: '仓库还没有发布 Release。',
        );
      }

      if (response.statusCode != 200) {
        return AppUpdateCheckResult(
          hasRelease: false,
          hasUpdate: false,
          currentVersion: currentVersion,
          message: '检查更新失败（HTTP ${response.statusCode}）。',
        );
      }

      final releaseJson = includePrerelease
          ? _pickLatestEligibleRelease(
              jsonDecode(response.body) as List<dynamic>,
              includePrerelease: true,
            )
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (releaseJson == null) {
        return AppUpdateCheckResult(
          hasRelease: false,
          hasUpdate: false,
          currentVersion: currentVersion,
          message: includePrerelease ? '还没有可用的正式版或预发布版本。' : '仓库还没有发布 Release。',
        );
      }

      final latestVersion = _normalizeVersion(
        (releaseJson['tag_name'] as String?) ??
            (releaseJson['name'] as String?) ??
            '',
      );
      final release = AppReleaseInfo(
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

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
      return AppUpdateCheckResult(
        hasRelease: true,
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestRelease: release,
        message: hasUpdate
            ? (release.isPrerelease ? '发现新的预发布版本' : '发现新版本')
            : '当前已经是最新版本',
      );
    } catch (_) {
      return AppUpdateCheckResult(
        hasRelease: false,
        hasUpdate: false,
        currentVersion: currentVersion,
        message: '网络异常，暂时无法检查更新。',
      );
    }
  }

  Future<String?> downloadAndInstallUpdate(
    String url,
    void Function(int downloadedBytes, int? totalBytes) onProgress,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/mikcb_update.apk';

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return '下载失败（HTTP ${response.statusCode}）';
      }

      final total = response.contentLength;
      int downloaded = 0;
      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded, total <= 0 ? null : total);
      }

      await sink.close();
      client.close();

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        return '打开安装包失败: ${result.message}';
      }
      return null;
    } catch (e) {
      return '下载或安装过程中出现错误: $e';
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

  String _normalizeVersion(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  int _compareVersions(String left, String right) {
    final leftVersion = _parseVersion(left);
    final rightVersion = _parseVersion(right);
    final maxLength = leftVersion.mainParts.length > rightVersion.mainParts.length
        ? leftVersion.mainParts.length
        : rightVersion.mainParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue =
          index < leftVersion.mainParts.length ? leftVersion.mainParts[index] : 0;
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
    final main = dashIndex == -1 ? normalized : normalized.substring(0, dashIndex);
    final prerelease =
        dashIndex == -1 ? null : normalized.substring(dashIndex + 1).trim();
    return _ParsedVersion(
      mainParts: main
        .split('.')
        .map(
            (item) => int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList(),
      prerelease: prerelease == null || prerelease.isEmpty ? null : prerelease,
    );
  }

  int _comparePrerelease(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    final maxLength =
        leftParts.length > rightParts.length ? leftParts.length : rightParts.length;

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
      final version = _normalizeVersion(
        (release['tag_name'] as String?) ?? (release['name'] as String?) ?? '',
      );
      if (version.isEmpty) {
        continue;
      }

      if (bestRelease == null || bestVersion == null) {
        bestRelease = release;
        bestVersion = version;
        continue;
      }

      final compare = _compareVersions(version, bestVersion);
      if (compare > 0) {
        bestRelease = release;
        bestVersion = version;
        continue;
      }
      if (compare < 0) {
        continue;
      }

      final bestUpdatedAt = DateTime.tryParse(
        (bestRelease['updated_at'] as String?) ??
            (bestRelease['published_at'] as String?) ??
            '',
      );
      final currentUpdatedAt = DateTime.tryParse(
        (release['updated_at'] as String?) ??
            (release['published_at'] as String?) ??
            '',
      );
      if ((currentUpdatedAt?.millisecondsSinceEpoch ?? 0) >
          (bestUpdatedAt?.millisecondsSinceEpoch ?? 0)) {
        bestRelease = release;
        bestVersion = version;
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
