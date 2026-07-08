import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import 'app_update_service.dart';
import '../utils/async_utils.dart';

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
  final String? updatedAt;
  final List<SupportDonorEntry> donors;

  const SupportDonorData({
    this.title,
    this.subtitle,
    this.updatedAt,
    required this.donors,
  });

  factory SupportDonorData.fromJson(Map<String, dynamic> json) {
    final donorItems = (json['donors'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => SupportDonorEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.name.isNotEmpty)
        .toList();
    return SupportDonorData(
      title: (json['title'] as String?)?.trim(),
      subtitle: (json['subtitle'] as String?)?.trim(),
      updatedAt: (json['updatedAt'] as String?)?.trim(),
      donors: donorItems,
    );
  }
}

class SupportCreatorService {
  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/support',
  );
  static const String _donorsUrl =
      'https://raw.githubusercontent.com/Mutx163/mikcb/main/docs/donors.json';

  final http.Client _client;

  SupportCreatorService({http.Client? client})
    : _client = client ?? http.Client();

  Future<SupportDonorData> fetchDonors({String? mirrorUrlPrefix}) async {
    final normalizedMirrorPrefix = _normalizeMirrorUrlPrefix(mirrorUrlPrefix);
    final candidateUrls = buildMirrorCandidateUrls(
      _donorsUrl,
      selectedMirrorPrefix: normalizedMirrorPrefix,
    );

    final sw = Stopwatch()..start();
    appDebugLog(
      'SupportCreator',
      'fetchDonors 开始，候选 ${candidateUrls.length} 个',
    );
    for (var i = 0; i < candidateUrls.length; i++) {
      appDebugLog('SupportCreator', '候选 $i：${candidateUrls[i]}');
    }

    final result = await raceFutures<http.Response, SupportDonorData>(
      candidateUrls.map((candidateUrl) {
        return _client
            .get(
              Uri.parse(candidateUrl),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'mikcb-app',
              },
            )
            .timeout(const Duration(seconds: 6));
      }).toList(),
      (response) {
        appDebugLog(
          'SupportCreator',
          '收到响应 ${response.statusCode}，耗时 ${sw.elapsedMilliseconds}ms',
        );
        if (response.statusCode != 200) return null;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) {
          appDebugLog('SupportCreator', '响应不是 Map 格式');
          return null;
        }
        final data = SupportDonorData.fromJson(
          Map<String, dynamic>.from(decoded),
        );
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
      encodeServiceMessage(
        'support_donors_load_failed',
        {'detail': '$lastError'},
      ),
    );
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
