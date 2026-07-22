import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 公平运行内存 / 全应用内存监控（仅调试版、性能版入口使用）。
class MemoryStatsService {
  MemoryStatsService._();

  static final MemoryStatsService instance = MemoryStatsService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/memory_stats',
  );

  /// 与 Android productFlavor 一致：dev → `.debug`，perf → `.profile`。
  static bool isDiagnosticsPackageName(String packageName) {
    return packageName.endsWith('.debug') || packageName.endsWith('.profile');
  }

  static Future<bool> isDiagnosticsBuild() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return isDiagnosticsPackageName(packageInfo.packageName);
    } catch (_) {
      return false;
    }
  }

  /// 拉取原生全量快照，并合并 Dart / 图片缓存指标。
  Future<Map<String, dynamic>> fetchSnapshot() async {
    if (kIsWeb || !Platform.isAndroid) {
      return <String, dynamic>{'supported': false, 'error': '仅 Android 支持内存统计'};
    }

    Map<String, dynamic> native = <String, dynamic>{};
    try {
      final raw = await _channel.invokeMethod<dynamic>('getMemorySnapshot');
      if (raw is Map) {
        native = Map<String, dynamic>.from(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } on PlatformException catch (error) {
      native = <String, dynamic>{
        'supported': false,
        'error': error.message ?? error.code,
      };
    } catch (error) {
      native = <String, dynamic>{'supported': false, 'error': error.toString()};
    }

    final imageCache = PaintingBinding.instance.imageCache;
    final dartVm = <String, dynamic>{
      'currentRssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
    };
    final flutterImageCache = <String, dynamic>{
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
      'currentSize': imageCache.currentSize,
      'maximumSize': imageCache.maximumSize,
      'liveImageCount': imageCache.liveImageCount,
      'pendingImageCount': imageCache.pendingImageCount,
    };

    final analysis = asStringKeyMap(native['analysis']);
    final cleanable = asStringKeyMap(analysis['cleanableEstimate']);
    final imageCacheMb = imageCache.currentSizeBytes / (1024 * 1024);
    final mediumMb = (asInt(cleanable['mediumMb']) ?? 0) + imageCacheMb.round();
    final easyMb = imageCacheMb.round();
    final enrichedAnalysis = <String, dynamic>{
      ...analysis,
      'cleanableEstimate': <String, dynamic>{
        ...cleanable,
        'easyMb': easyMb,
        'mediumMb': mediumMb,
        'note': cleanable['note'] ?? 'easy≈图片缓存；medium≈图形/壁纸/模糊；hard≈引擎与系统分摊。',
      },
      if (analysis['bullets'] is List)
        'bullets': List<dynamic>.from(analysis['bullets'] as List),
    };

    return <String, dynamic>{
      ...native,
      'supported': native['error'] == null,
      'dartVm': dartVm,
      'flutterImageCache': flutterImageCache,
      'analysis': enrichedAnalysis,
      'mergedAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static int? asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static double? asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static Map<String, dynamic> asStringKeyMap(dynamic value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item.map((key, nested) => MapEntry(key.toString(), nested)),
          ),
        )
        .toList(growable: false);
  }

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) {
      return '—';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kilobytes = bytes / 1024.0;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }
    final megabytes = kilobytes / 1024.0;
    if (megabytes < 1024) {
      return '${megabytes.toStringAsFixed(2)} MB';
    }
    final gigabytes = megabytes / 1024.0;
    return '${gigabytes.toStringAsFixed(2)} GB';
  }

  static String formatKb(int? kilobytes) {
    if (kilobytes == null || kilobytes < 0) {
      return '—';
    }
    return formatBytes(kilobytes * 1024);
  }

  static String formatDuration(int? millis) {
    if (millis == null || millis < 0) {
      return '—';
    }
    final totalSeconds = millis ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  static String formatPercent(double? ratio) {
    if (ratio == null || ratio.isNaN) {
      return '—';
    }
    return '${(ratio * 100).toStringAsFixed(1)}%';
  }
}
