import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 蒲公英 API 配置
class PgyerApiConfig {
  final String apiKey;
  final String appKey;

  const PgyerApiConfig({
    required this.apiKey,
    required this.appKey,
  });

  bool get isValid => apiKey.isNotEmpty && appKey.isNotEmpty;
}

/// 蒲公英 API 服务
class PgyerApiService {
  static const String _baseUrl = 'https://www.pgyer.com/apiv2';
  static const Duration _timeout = Duration(seconds: 3);

  final http.Client _client;
  final PgyerApiConfig? _config;

  PgyerApiService({
    http.Client? client,
    PgyerApiConfig? config,
  })  : _client = client ?? http.Client(),
        _config = config;

  /// 检测应用更新
  /// 返回 null 表示调用失败或未配置，应降级到 GitHub API
  Future<PgyerAppInfo?> checkForUpdate() async {
    final config = _config;
    if (config == null || !config.isValid) {
      debugPrint('[PgyerApi] 未配置 API Key，跳过');
      return null;
    }

    try {
      debugPrint('[PgyerApi] 开始检测更新...');
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/app/check'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              '_api_key': config.apiKey,
              'appKey': config.appKey,
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[PgyerApi] 请求失败: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json['code'] != 0) {
        debugPrint('[PgyerApi] API 错误: ${json['message']}');
        return null;
      }

      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('[PgyerApi] 返回数据为空');
        return null;
      }

      debugPrint('[PgyerApi] 检测成功: ${data['buildVersion']}');
      return PgyerAppInfo.fromMap(data);
    } on TimeoutException {
      debugPrint('[PgyerApi] 请求超时');
      return null;
    } catch (e) {
      debugPrint('[PgyerApi] 异常: $e');
      return null;
    }
  }

  /// 获取应用下载页面链接（不消耗额度）
  String getDownloadPageUrl(String buildShortcutUrl) {
    return 'https://www.pgyer.com/$buildShortcutUrl';
  }

  void dispose() {
    _client.close();
  }
}

/// 蒲公英应用信息
class PgyerAppInfo {
  final String buildKey;
  final String buildVersion;
  final String buildVersionNo;
  final String buildUpdateDescription;
  final String buildCreated;
  final String buildFileSize;
  final String buildShortcutUrl;
  final String buildName;
  final String buildIcon;

  const PgyerAppInfo({
    required this.buildKey,
    required this.buildVersion,
    required this.buildVersionNo,
    required this.buildUpdateDescription,
    required this.buildCreated,
    required this.buildFileSize,
    required this.buildShortcutUrl,
    required this.buildName,
    required this.buildIcon,
  });

  factory PgyerAppInfo.fromMap(Map<String, dynamic> map) {
    return PgyerAppInfo(
      buildKey: map['buildKey']?.toString() ?? '',
      buildVersion: map['buildVersion']?.toString() ?? '',
      buildVersionNo: map['buildVersionNo']?.toString() ?? '',
      buildUpdateDescription: map['buildUpdateDescription']?.toString() ?? '',
      buildCreated: map['buildCreated']?.toString() ?? '',
      buildFileSize: map['buildFileSize']?.toString() ?? '',
      buildShortcutUrl: map['buildShortcutUrl']?.toString() ?? '',
      buildName: map['buildName']?.toString() ?? '',
      buildIcon: map['buildIcon']?.toString() ?? '',
    );
  }

  /// 获取下载页面链接
  String get downloadPageUrl => 'https://www.pgyer.com/$buildShortcutUrl';

  /// 获取文件大小（MB）
  double get fileSizeMB {
    final bytes = int.tryParse(buildFileSize) ?? 0;
    return bytes / 1024 / 1024;
  }

  /// 格式化的文件大小
  String get formattedFileSize {
    final mb = fileSizeMB;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb * 1024).toStringAsFixed(0)} KB';
  }

  /// 格式化的更新时间
  String get formattedUpdateTime {
    try {
      final date = DateTime.parse(buildCreated);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return buildCreated;
    }
  }
}
