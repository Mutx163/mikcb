import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _recoverySnapshotKey = 'fair_memory_recovery_snapshot_v1';

  bool _handlerAttached = false;
  final FairMemoryRouteObserver routeObserver = FairMemoryRouteObserver();
  Future<Map<String, Object?>> Function()? _snapshotProvider;

  /// Registers business state that is already safe to persist. The callback is
  /// awaited on KILL, so the Binder acknowledgement is not sent early.
  void registerSnapshotProvider(
    Future<Map<String, Object?>> Function() provider,
  ) {
    _snapshotProvider = provider;
  }

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
    await _persistRecoverySnapshot(payload);
    _clearVolatileImageCacheOnly();
    unawaitedLog(
      category: 'fair_memory_kill',
      message: AppLogMessages.fairMemoryKillHandled,
      extras: _safeExtras(payload),
    );
  }

  Future<void> _persistRecoverySnapshot(Map<String, dynamic> payload) async {
    final businessState = await _snapshotProvider?.call() ?? const {};
    final prefs = await SharedPreferences.getInstance();
    final snapshot = <String, Object?>{
      'version': 1,
      'savedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'action': payload['action']?.toString(),
      'notifyType': payload['notifyType'],
      'notifyId': payload['notifyId'],
      'reason': payload['reason']?.toString(),
      'routes': routeObserver.snapshot,
      'businessState': businessState,
    };
    final saved = await prefs.setString(
      _recoverySnapshotKey,
      jsonEncode(snapshot),
    );
    if (!saved) {
      throw StateError('fair-memory recovery snapshot was not persisted');
    }
  }

  @visibleForTesting
  Future<void> persistRecoverySnapshotForTesting(
    Map<String, dynamic> payload,
  ) => _persistRecoverySnapshot(payload);

  /// Returns and removes a recent KILL snapshot so startup restoration cannot
  /// loop if rebuilding a route fails.
  Future<FairMemoryRecoverySnapshot?> takePendingRecoverySnapshot({
    DateTime? now,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recoverySnapshotKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    await prefs.remove(_recoverySnapshotKey);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return null;
      }
      final savedAtMillis = decoded['savedAtMillis'];
      if (savedAtMillis is! int || savedAtMillis <= 0) {
        return null;
      }
      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMillis);
      final age = (now ?? DateTime.now()).difference(savedAt);
      if (age > maxAge) {
        return null;
      }
      final rawRoutes = decoded['routes'];
      final routes = (rawRoutes is List ? rawRoutes : const <dynamic>[])
          .map((route) => route.toString())
          .where((route) => route.isNotEmpty)
          .toList(growable: false);
      final rawBusinessState = decoded['businessState'];
      final businessState = rawBusinessState is Map
          ? <String, Object?>{
              for (final entry in rawBusinessState.entries)
                entry.key.toString(): entry.value,
            }
          : const <String, Object?>{};
      return FairMemoryRecoverySnapshot(
        savedAt: savedAt,
        routes: routes,
        businessState: businessState,
      );
    } catch (_) {
      return null;
    }
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

@immutable
class FairMemoryRecoverySnapshot {
  const FairMemoryRecoverySnapshot({
    required this.savedAt,
    required this.routes,
    required this.businessState,
  });

  final DateTime savedAt;
  final List<String> routes;
  final Map<String, Object?> businessState;

  String? get lastNamedRoute {
    for (final route in routes.reversed) {
      if (route.startsWith('/')) {
        return route;
      }
    }
    return null;
  }
}

/// Tracks active routes for the recovery snapshot. Named routes identify the
/// screen that should be resumed, while the actual business data remains in
/// the normal profile/preferences storage.
class FairMemoryRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  List<String> get snapshot =>
      List<String>.unmodifiable(_routes.map(_describe));

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _routes[index] = newRoute;
    } else if (oldRoute != null) {
      _routes.remove(oldRoute);
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  String _describe(Route<dynamic>? route) {
    if (route == null) {
      return '';
    }
    final name = route.settings.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return route.runtimeType.toString();
  }
}
