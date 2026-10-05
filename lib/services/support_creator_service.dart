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

  /// 「这条记录不会再有进展」—— 成功、失败，以及 unknown。
  ///
  /// unknown 只有一个来源：原生侧**查不到这条下载**。`MainActivity.kt:1724-1731` 在
  /// cursor 为空时返回 `{status:"unknown", downloadedBytes:0, totalBytes:-1}`（不是 null），
  /// 而 DownloadManager 的五个真实状态都已映射，`else -> unknown` 实际走不到。
  /// 典型触发是用户把这条下载从系统「下载管理」里删掉，或行被系统清理。
  ///
  /// 这个判断必须轮询侧、组件的"进行中"判定、控制器重开弹窗时的清理三处共用：
  /// 历史上三处各不相同（轮询与组件当它"还在跑"、控制器当它"已结束"），后果是
  /// `watchSystemDownloadProgress` 每 350 毫秒查一次平台通道、**永不停止**（唯一订阅方
  /// 在首页，`if (!mounted) return` 要等整页销毁，而首页活满整个会话），弹窗进度条
  /// 同时永远停在 0%「下载中」。
  bool get isSettled =>
      isFinished || status == SystemDownloadStatus.unknown;
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
  /// 下载渠道选国内源（GitCode/蒲公英）时作为主候选先行，成功即用、不再
  /// 请求 GitHub 候选；失败时才回退 GitHub raw 与镜像前缀竞速池。
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
    final sw = Stopwatch()..start();

    // 与教务适配仓同一规则：下载渠道选国内源（GitCode/蒲公英）时，GitCode
    // 主候选先行——成功直接采用、不再请求 GitHub 候选；仅失败才回退
    // GitHub raw 与镜像竞速池，避免「优先国内」被更快的 GitHub 镜像截胡。
    if (preferGitCode) {
      try {
        final data = await _fetchDonorData(_gitcodeDonorsUrl);
        appDebugLog(
          'SupportCreator',
          'GitCode primary candidate hit in ${sw.elapsedMilliseconds}ms',
        );
        return data;
      } catch (error) {
        appDebugLog(
          'SupportCreator',
          'GitCode primary candidate failed, '
              'falling back to GitHub raw and mirror pool: $error',
        );
      }
    }

    final candidateUrls = buildMirrorCandidateUrls(
      _donorsUrl,
      selectedMirrorPrefix: normalizedMirrorPrefix,
    );

    appDebugLog(
      'SupportCreator',
      'fetchDonors 开始，候选 ${candidateUrls.length} 个，'
      'preferGitCode=$preferGitCode',
    );
    for (var i = 0; i < candidateUrls.length; i++) {
      appDebugLog('SupportCreator', '候选 $i：${candidateUrls[i]}');
    }

    final result = await raceFutures<SupportDonorData, SupportDonorData>(
      candidateUrls.map((candidateUrl) async {
        final data = await _fetchDonorData(candidateUrl);
        appDebugLog(
          'SupportCreator',
          '候选命中（$candidateUrl），耗时 ${sw.elapsedMilliseconds}ms',
        );
        return data;
      }).toList(growable: false),
      (data) => data,
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

  /// 从单个候选地址拉取并解析名单（GitCode v5 contents 走 base64 解码），
  /// 失败抛错由调用方决定是否回退。
  Future<SupportDonorData> _fetchDonorData(String candidateUrl) async {
    final response = await _client
        .get(
          Uri.parse(candidateUrl),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'mikcb-app',
          },
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw StateError('http_${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw StateError('donors_payload_not_map');
    }
    final rawMap = _isGitCodeContentsUrl(candidateUrl)
        ? _decodeGitCodeContentsPayload(decoded)
        : Map<String, dynamic>.from(decoded);
    if (rawMap == null) {
      throw StateError('gitcode_contents_decode_failed');
    }
    final data = SupportDonorData.fromJson(rawMap);
    appDebugLog('SupportCreator', '解析成功，${data.donors.length} 位捐赠者');
    return data;
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

  /// 轮询系统下载器的进度，直到这条记录"settled"（成功 / 失败 / unknown）。
  ///
  /// 两条停止条件都是这一族唯一的口径（[SystemDownloadProgress.isSettled]）：
  ///  - unknown 表示原生已经查不到这条下载（用户在系统「下载管理」里删掉、或行被清理），
  ///    它不会再变成 pending/running；原先只认 [isFinished]，于是这条流每
  ///    `interval` 毫秒问一次平台通道、**永不停止**（唯一订阅方在首页，只有整页销毁
  ///    才会 `return`，而首页活满整个会话），组件同时按"进行中"渲染，进度条卡在 0%。
  ///  - 查询抛错时先重试 [maxTransientFailures] 次再放弃：订阅方的注释一直写着
  ///    "下载行在 provider 接手前会短暂查不到……让下一次观察恢复"，但旧实现第一次抛错
  ///    就把流结束掉，没有任何"下一次"，进度从此冻在最后一个值上。
  /// [reader] 是可注入的进度读取口，默认走平台通道（[querySystemDownloadProgress]）；
  /// [SystemDownloadProgressReader] 这个 typedef 在本仓声明多年却没人用，这次把它接到
  /// 实处 —— "什么时候该停止轮询"这条规则必须有办法被单测钉住。
  Stream<SystemDownloadProgress> watchSystemDownloadProgress(
    int downloadId, {
    Duration interval = const Duration(milliseconds: 350),
    int maxTransientFailures = 3,
    SystemDownloadProgressReader? reader,
  }) async* {
    final read = reader ?? querySystemDownloadProgress;
    var consecutiveFailures = 0;
    while (true) {
      final SystemDownloadProgress? progress;
      try {
        progress = await read(downloadId);
        consecutiveFailures = 0;
      } catch (_) {
        consecutiveFailures++;
        if (consecutiveFailures >= maxTransientFailures) {
          rethrow;
        }
        await Future<void>.delayed(interval);
        continue;
      }
      if (progress == null) {
        return;
      }
      yield progress;
      if (progress.isSettled) {
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
