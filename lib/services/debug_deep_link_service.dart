import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Debug-only deep-link bridge for adb / Android CLI automation.
///
/// Supported URIs (scheme `mikcb-debug`):
/// - `mikcb-debug://home`
/// - `mikcb-debug://settings`
/// - `mikcb-debug://settings/live`
/// - `mikcb-debug://settings/live/testing`
/// - `mikcb-debug://settings/live/keep-alive`
/// - `mikcb-debug://settings/couple`
/// - `mikcb-debug://settings/lan-edit`
/// - `mikcb-debug://courses/import`
/// - `mikcb-debug://action/resume`
/// - `mikcb-debug://action/seed-soon?minutes=15`
/// - `mikcb-debug://action/dump-live-status`
class DebugDeepLinkService {
  DebugDeepLinkService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mutx163.qingyu/miui_live',
  );

  static final StreamController<DebugDeepLinkCommand> _commandsController =
      StreamController<DebugDeepLinkCommand>.broadcast();

  static Stream<DebugDeepLinkCommand> get commands =>
      _commandsController.stream;

  /// Drain any route that arrived before Flutter was ready.
  ///
  /// Native push notifications use [onNativeRouteReceived]; do not call
  /// [MethodChannel.setMethodCallHandler] here — that channel is owned by
  /// [AppEntryScreen] for external-import callbacks as well.
  static Future<void> drainPending() async {
    if (kReleaseMode) {
      return;
    }
    try {
      final payload = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPendingDebugRoute',
      );
      final command = DebugDeepLinkCommand.tryParse(payload);
      if (command != null) {
        _commandsController.add(command);
      }
    } catch (_) {
      // Non-critical debug helper.
    }
  }

  /// Called from the shared MethodChannel handler when native pushes a route.
  static Future<void> onNativeRouteReceived() => drainPending();
}

class DebugDeepLinkCommand {
  final String path;
  final Map<String, String> query;

  const DebugDeepLinkCommand({required this.path, this.query = const {}});

  static DebugDeepLinkCommand? tryParse(Map<Object?, Object?>? payload) {
    if (payload == null) {
      return null;
    }
    final rawPath = (payload['path'] as String?)?.trim() ?? '';
    if (rawPath.isEmpty) {
      return null;
    }
    final normalizedPath = rawPath.startsWith('/')
        ? rawPath.substring(1)
        : rawPath;
    final rawQuery = payload['query'];
    final query = <String, String>{};
    if (rawQuery is Map) {
      rawQuery.forEach((key, value) {
        if (key == null || value == null) {
          return;
        }
        query[key.toString()] = value.toString();
      });
    }
    return DebugDeepLinkCommand(path: normalizedPath, query: query);
  }

  int? queryInt(String key) => int.tryParse(query[key] ?? '');

  @override
  String toString() => 'DebugDeepLinkCommand(path: $path, query: $query)';
}
