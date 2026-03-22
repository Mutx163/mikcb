import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String version;
  final String title;
  final String body;
  final String releaseUrl;
  final String? downloadUrl;
  final DateTime? publishedAt;

  const AppReleaseInfo({
    required this.version,
    required this.title,
    required this.body,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.publishedAt,
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

  Future<AppUpdateCheckResult> checkForUpdates({
    required String currentVersion,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(latestReleaseApiUrl),
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

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = _normalizeVersion(
        (json['tag_name'] as String?) ?? (json['name'] as String?) ?? '',
      );
      final release = AppReleaseInfo(
        version: latestVersion,
        title: (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : latestVersion,
        body: (json['body'] as String?)?.trim() ?? '',
        releaseUrl: (json['html_url'] as String?) ?? repositoryUrl,
        downloadUrl: _pickDownloadUrl(
          json['assets'] as List<dynamic>? ?? const [],
        ),
        publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
      );

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
      return AppUpdateCheckResult(
        hasRelease: true,
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestRelease: release,
        message: hasUpdate ? '发现新版本' : '当前已经是最新版本',
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
    void Function(double) onProgress,
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
        if (total != -1) {
          onProgress(downloaded / total);
        }
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
    final leftParts = _parseVersionParts(left);
    final rightParts = _parseVersionParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  List<int> _parseVersionParts(String version) {
    final normalized = version.split('+').first.split('-').first;
    return normalized
        .split('.')
        .map(
            (item) => int.tryParse(item.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
