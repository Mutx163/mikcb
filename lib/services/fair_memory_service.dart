import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../logging/app_log_messages.dart';
import 'app_log_service.dart';

/// 金标联盟「公平运行内存」Flutter 侧钩子。
///
/// 安全边界：
/// - 只清理 [PaintingBinding] 内存图片缓存（纯 RAM）
/// - **不** 清理 SharedPreferences、课表文件、超级岛/小组件快照
/// - **不** 调用 stopLiveUpdate / clearSnapshot / 小组件 clear
class FairMemoryService {
  FairMemoryService._();

  static final FairMemoryService instance = FairMemoryService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/fair_memory',
  );

  bool _handlerAttached = false;

  /// 在 [main] 尽早调用；非 Android 为 no-op。
  void ensureInitialized() {
    if (_handlerAttached) {
      return;
    }
    if (kIsWeb || !Platform.isAndroid) {
      _handlerAttached = true;
      return;
    }
    _channel.setMethodCallHandler(_handleMethodCall);
    _handlerAttached = true;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final arguments = call.arguments;
    final payload = arguments is Map
        ? Map<String, dynamic>.from(
            arguments.map((key, value) => MapEntry(key.toString(), value)),
          )
        : <String, dynamic>{};

    switch (call.method) {
      case 'onTrim':
        await _onTrim(payload);
        return true;
      case 'onKill':
        await _onKill(payload);
        return true;
      default:
        return null;
    }
  }

  Future<void> _onTrim(Map<String, dynamic> payload) async {
    _clearVolatileImageCacheOnly();
    unawaitedLog(
      category: 'fair_memory_trim',
      message: AppLogMessages.fairMemoryTrimHandled,
      extras: _safeExtras(payload),
    );
  }

  Future<void> _onKill(Map<String, dynamic> payload) async {
    // 关键业务状态依赖日常写盘；此处不阻塞做重 I/O，只清 RAM 缓存。
    _clearVolatileImageCacheOnly();
    unawaitedLog(
      category: 'fair_memory_kill',
      message: AppLogMessages.fairMemoryKillHandled,
      extras: _safeExtras(payload),
    );
  }

  /// 仅清内存图片解码缓存；不触碰磁盘与业务持久化。
  void _clearVolatileImageCacheOnly() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();
    } catch (_) {
      // 引擎未就绪时忽略
    }
  }

  Map<String, Object?> _safeExtras(Map<String, dynamic> payload) {
    return <String, Object?>{
      'action': payload['action']?.toString(),
      'notifyType': payload['notifyType'],
      'notifyId': payload['notifyId'],
      'reason': payload['reason']?.toString(),
      'pss': payload['pss'],
      'pssLimit': payload['pssLimit'],
      'heapAlloc': payload['heapAlloc'],
      'heapCapacity': payload['heapCapacity'],
      'protectedLiveAndWidget': payload['protectedLiveAndWidget'] == true,
    };
  }

  void unawaitedLog({
    required String category,
    required String message,
    Map<String, Object?> extras = const {},
  }) {
    // 避免在 3s 回执路径上 await；日志异步写入即可。
    // ignore: unawaited_futures
    AppLogService.instance.info(category, message, extras: extras);
  }
}
