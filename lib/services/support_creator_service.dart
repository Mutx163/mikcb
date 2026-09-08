import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import 'app_update_service.dart';
import '../utils/async_utils.dart';
import 'app_http_client.dart';

class SupportDonorEntry {
  final String name;
  final String? amount;
  final String? date;
  final String? message;

  const SupportDonorEntry({
    required this.name,
    this.amount,
    this.date,
    this.message,
  });

  factory SupportDonorEntry.fromJson(Map<String, dynamic> json) {
    return SupportDonorEntry(
      name: (json['name'] as String? ?? '').trim(),
      amount: (json['amount'] as String?)?.trim(),
      date: (json['date'] as String?)?.trim(),
      message: (json['message'] as String?)?.trim(),
    );
  }
}

class SupportDonorData {
  final String? title;
  final String? subtitle;

  /// 留言格式说明，独立于 [subtitle] 展示为提示条；旧 JSON 无此字段时为 null。
  final String? subtitleNote;
  final String? updatedAt;
  final List<SupportDonorEntry> donors;

  const SupportDonorData({
    this.title,
    this.subtitle,
    this.subtitleNote,
    this.updatedAt,
    required this.donors,
  });

  factory SupportDonorData.fromJson(Map<String, dynamic> json) {
    final donorItems = (json['donors'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SupportDonorEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.name.isNotEmpty)
        .toList();

    donorItems.sort(_compareDonorDateDesc);

    return SupportDonorData(
      title: (json['title'] as String?)?.trim(),
      subtitle: (json['subtitle'] as String?)?.trim(),
      subtitleNote: (json['subtitleNote'] as String?)?.trim(),
      updatedAt: (json['updatedAt'] as String?)?.trim(),
      donors: donorItems,
    );
  }

  static int _compareDonorDateDesc(SupportDonorEntry a, SupportDonorEntry b) {
    final dateA = _parseDonorDate(a.date);
    final dateB = _parseDonorDate(b.date);
    if (dateA != null && dateB != null) {
      final cmp = dateB.compareTo(dateA);
      if (cmp != 0) return cmp;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    } else {
      final rawA = a.date?.trim() ?? '';
      final rawB = b.date?.trim() ?? '';
      if (rawA.isNotEmpty && rawB.isNotEmpty) {
        final cmp = rawB.compareTo(rawA);
        if (cmp != 0) return cmp;
      } else if (rawA.isNotEmpty) {
        return -1;
      } else if (rawB.isNotEmpty) {
        return 1;
      }
    }
    return 0;
  }

  static DateTime? _parseDonorDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
}

enum SystemDownloadStatus {
  pending,
  running,
  paused,
  successful,
  failed,
  unknown,
}

class SystemDownloadProgress {
  final SystemDownloadStatus status;
  final int downloadedBytes;
  final int? totalBytes;
  final int? reason;

  const SystemDownloadProgress({
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.reason,
  });

  bool get isFinished =>
      status == SystemDownloadStatus.successful ||
      status == SystemDownloadStatus.failed;
}

typedef SystemDownloadProgressReader =
    Future<SystemDownloadProgress?> Function(int downloadId);

class SupportCreatorService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/support',
  );
  static const String _donorsUrl =
      'https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/donors.json';

  /// GitCode 国内直连镜像（v5 contents API，免令牌可读，返回 base64 JSON）：
  /// 下载渠道选 GitCode 时作为主候选，域名/命名空间与 GitHub 主仓一致
  /// （镜像与 main 全量同步）；失败时回退 GitHub raw 与镜像前缀候选。
  static const String _gitcodeDonorsUrl =
      'https://api.gitcode.com/api/v5/repos/mutx/qingyu/contents/docs/donors.json?ref=main';

  final http.Client _client;

  SupportCreatorService({http.Client? client})
    : _client = client ?? createAppHttpClient();

  Future<SupportDonorData> fetchDonors({
    String? mirrorUrlPrefix,
    bool preferGitCode = false,
  }) async {
    final normalizedMirrorPrefix = _normalizeMirrorUrlPrefix(mirrorUrlPrefix);
    final candidateUrls = <String>[
      // GitCode 国内直连（下载渠道选 GitCode 时纳入主候选）：v5 contents API
      // 免令牌、返回 base64 JSON，命中即胜出，无需绕道镜像前缀。
      if (preferGitCode) _gitcodeDonorsUrl,
      ...buildMirrorCandidateUrls(
        _donorsUrl,
        selectedMirrorPrefix: normalizedMirrorPrefix,
      ),
    ];

    final sw = Stopwatch()..start();
    appDebugLog(
      'SupportCreator',
      'fetchDonors 开始，候选 ${candidateUrls.length} 个，'
      'preferGitCode=$preferGitCode',
    );
    for (var i = 0; i < candidateUrls.length; i++) {
      appDebugLog('SupportCreator', '候选 $i：${candidateUrls[i]}');
    }

    final result = await raceFutures<(http.Response, String), SupportDonorData>(
      candidateUrls.map((candidateUrl) async {
        final response = await _client
            .get(
              Uri.parse(candidateUrl),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'mikcb-app',
              },
            )
            .timeout(const Duration(seconds: 6));
        return (response, candidateUrl);
      }).toList(growable: false),
      (entry) {
        final response = entry.$1;
        final candidateUrl = entry.$2;
        appDebugLog(
          'SupportCreator',
          '收到响应 ${response.statusCode}（$candidateUrl），'
          '耗时 ${sw.elapsedMilliseconds}ms',
        );
        if (response.statusCode != 200) {
          return null;
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) {
          appDebugLog('SupportCreator', '响应不是 Map 格式');
          return null;
        }
        final rawMap = _isGitCodeContentsUrl(candidateUrl)
            ? _decodeGitCodeContentsPayload(decoded)
            : Map<String, dynamic>.from(decoded);
        if (rawMap == null) {
          appDebugLog('SupportCreator', 'GitCode base64 内容解码失败');
          return null;
        }
        final data = SupportDonorData.fromJson(rawMap);
        appDebugLog('SupportCreator', '解析成功，${data.donors.length} 位捐赠者');
        return data;
      },
    );

    if (result.winner != null) {
      appDebugLog('SupportCreator', '竞争胜出，总耗时 ${sw.elapsedMilliseconds}ms');
      return result.winner!;
    }

    final lastError = result.errors.isNotEmpty ? result.errors.last : null;
    appDebugLog('SupportCreator', '全部失败，errors：${result.errors}');
    throw Exception(
      encodeServiceMessage('support_donors_load_failed', {
        'detail': '$lastError',
      }),
    );
  }

  /// 是否为 GitCode v5 contents API 候选（命中后需 base64 解码再解析 JSON）。
  static bool _isGitCodeContentsUrl(String url) =>
      Uri.tryParse(url)?.host == 'api.gitcode.com';

  /// GitCode contents API（Gitee 兼容）返回 base64 信封 `{content: '<base64>'}`。
  /// 取 content 解码回原始文件字节，按 UTF-8 还原文件文本后再解析 JSON，
  /// 语义与 GitHub raw 直读完全对齐；失败返回 null 让调用方回退其他候选。
  static Map<String, dynamic>? _decodeGitCodeContentsPayload(
    Map<dynamic, dynamic> decoded,
  ) {
    final base64Content = decoded['content'];
    if (base64Content is! String || base64Content.isEmpty) {
      return null;
    }
    final String innerJson;
    try {
      innerJson = utf8.decode(
        base64Decode(base64Content.replaceAll(RegExp(r'\s'), '')),
      );
    } catch (_) {
      return null;
    }
    final Object? inner = jsonDecode(innerJson);
    if (inner is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(inner);
  }

  Future<bool> saveAssetImageToGallery({
    required String assetPath,
    required String fileName,
  }) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = Uint8List.sublistView(byteData);
    final savedUri = await _channel.invokeMethod<String>('saveImageToGallery', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': 'image/png',
    });
    return savedUri != null && savedUri.isNotEmpty;
  }

  Future<int?> enqueueSystemDownload({
    required String url,
    String? fileName,
    String? title,
    String? description,
  }) {
    return _channel.invokeMethod<int>('enqueueSystemDownload', {
      'url': url,
      'fileName': fileName,
      'title': title,
      'description': description,
    });
  }

  Future<SystemDownloadProgress?> querySystemDownloadProgress(
    int downloadId,
  ) async {
    final payload = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getSystemDownloadProgress',
      {'downloadId': downloadId},
    );
    if (payload == null) {
      return null;
    }

    final status = switch (payload['status'] as String?) {
      'pending' => SystemDownloadStatus.pending,
      'running' => SystemDownloadStatus.running,
      'paused' => SystemDownloadStatus.paused,
      'successful' => SystemDownloadStatus.successful,
      'failed' => SystemDownloadStatus.failed,
      _ => SystemDownloadStatus.unknown,
    };
    final downloadedBytes = (payload['downloadedBytes'] as num?)?.toInt() ?? 0;
    final rawTotalBytes = (payload['totalBytes'] as num?)?.toInt() ?? -1;
    return SystemDownloadProgress(
      status: status,
      downloadedBytes: downloadedBytes,
      totalBytes: rawTotalBytes > 0 ? rawTotalBytes : null,
      reason: (payload['reason'] as num?)?.toInt(),
    );
  }

  Stream<SystemDownloadProgress> watchSystemDownloadProgress(
    int downloadId, {
    Duration interval = const Duration(milliseconds: 350),
  }) async* {
    while (true) {
      final progress = await querySystemDownloadProgress(downloadId);
      if (progress == null) {
        return;
      }
      yield progress;
      if (progress.isFinished) {
        return;
      }
      await Future<void>.delayed(interval);
    }
  }

  String? _normalizeMirrorUrlPrefix(String? prefix) {
    final candidate = (prefix ?? AppUpdateService.defaultMirrorUrlPrefix)
        .trim();
    if (candidate.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return candidate;
  }
}
