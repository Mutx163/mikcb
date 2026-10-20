import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/timed_method_channel.dart';

/// 一次原生调用的结果：成功与否 + 失败原因码（用于界面文案与日志）。
class CampusToolCallResult {
  const CampusToolCallResult({required this.ok, this.reason});

  const CampusToolCallResult.success() : ok = true, reason = null;

  final bool ok;

  /// `no_activity` / `app_not_found` / `invalid_uri` / `invalid_package` /
  /// `timeout` / `unsupported` 等；成功时通常为 null。
  final String? reason;
}

/// 打开外部 App / 链接的平台端口。
///
/// 为什么要端口而不是直接调 MethodChannel：跳转顺序（先直达链接、再拉起
/// 应用、最后网页兜底）是**纯逻辑**，值得被单测钉死；把通道放在接口后面，
/// 测试注入一个假实现就能验证「第 2 条链接失败后才试第 3 条」「全失败才报错」，
/// 不需要真机。
abstract interface class CampusToolPlatform {
  /// 当前平台能不能做外部跳转（Android 才接通道）。
  bool get supported;

  /// ACTION_VIEW 打开 [uri]，可选限定目标包名。
  Future<CampusToolCallResult> launchUri({
    required String uri,
    String? package,
    bool clearTask = false,
  });

  /// 只拉起 [package] 的应用主界面（没有公开直达链接时的降级）。
  Future<CampusToolCallResult> launchApp({
    required String package,
    bool clearTask = false,
  });

  /// [uri] 在当前设备上有没有 App 能接（Android 11+ 需 manifest `<queries>`）。
  Future<bool> canResolve({required String uri, String? package});

  /// 批量查询包名是否已安装。
  Future<Set<String>> installedPackages(List<String> packages);
}

/// 真机实现：`com.mutx163.qingyu/campus_tools` 通道（Kotlin 侧
/// `CampusToolLauncher`）。
///
/// 用 [TimedMethodChannel]：原生主线程被占用时 `await` 会永远不返回，没有
/// 超时就没有恢复路径（全仓口径，见 timed_method_channel.dart 的说明）。
final class CampusToolNativeChannel implements CampusToolPlatform {
  const CampusToolNativeChannel();

  static const String channelName = 'com.mutx163.qingyu/campus_tools';

  static const TimedMethodChannel _channel = TimedMethodChannel(channelName);

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<CampusToolCallResult> launchUri({
    required String uri,
    String? package,
    bool clearTask = false,
  }) {
    return _invoke('launch', <String, Object?>{
      'uri': uri,
      if (package != null && package.isNotEmpty) 'package': package,
      'clearTask': clearTask,
    });
  }

  @override
  Future<CampusToolCallResult> launchApp({
    required String package,
    bool clearTask = false,
  }) {
    return _invoke('launchApp', <String, Object?>{
      'package': package,
      'clearTask': clearTask,
    });
  }

  @override
  Future<bool> canResolve({required String uri, String? package}) async {
    if (!supported) {
      return false;
    }
    try {
      final resolved = await _channel.invokeMethod<bool>('canResolve', <String, Object?>{
        'uri': uri,
        if (package != null && package.isNotEmpty) 'package': package,
      });
      return resolved ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Set<String>> installedPackages(List<String> packages) async {
    if (!supported || packages.isEmpty) {
      return const <String>{};
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'installedPackages',
        <String, Object?>{'packages': packages},
      );
      if (result == null) {
        return const <String>{};
      }
      return <String>{
        for (final entry in result.entries)
          if (entry.value == true) entry.key,
      };
    } on PlatformException {
      return const <String>{};
    } on MissingPluginException {
      return const <String>{};
    }
  }

  Future<CampusToolCallResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    if (!supported) {
      return const CampusToolCallResult(ok: false, reason: 'unsupported');
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (result == null) {
        return const CampusToolCallResult(ok: false, reason: 'no_result');
      }
      final ok = result['ok'] == true;
      final reason = result['reason'];
      return CampusToolCallResult(
        ok: ok,
        reason: reason is String && reason.isNotEmpty ? reason : null,
      );
    } on PlatformException catch (error) {
      // 超时与「原生明确报错」在调用方看来是同一件事：没拿到可用结果。
      return CampusToolCallResult(
        ok: false,
        reason: error.code == kPlatformChannelTimeoutCode ? 'timeout' : error.code,
      );
    } on MissingPluginException {
      return const CampusToolCallResult(ok: false, reason: 'unsupported');
    }
  }
}
