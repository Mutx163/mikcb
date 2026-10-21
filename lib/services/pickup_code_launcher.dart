import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/timed_method_channel.dart';

/// 一次原生调用的结果：成功与否 + 失败原因码（用于界面文案与日志）。
class PickupCodeCallResult {
  const PickupCodeCallResult({required this.ok, this.reason});

  const PickupCodeCallResult.success() : ok = true, reason = null;

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
abstract interface class PickupCodePlatform {
  /// 当前平台能不能做外部跳转（Android 才接通道）。
  bool get supported;

  /// ACTION_VIEW 打开 [uri]，可选限定目标包名。
  Future<PickupCodeCallResult> launchUri({
    required String uri,
    String? package,
    bool clearTask = false,
  });

  /// 只拉起 [package] 的应用主界面（没有公开直达链接时的降级）。
  Future<PickupCodeCallResult> launchApp({
    required String package,
    bool clearTask = false,
  });

  /// [uri] 在当前设备上有没有 App 能接（Android 11+ 需 manifest `<queries>`）。
  Future<bool> canResolve({required String uri, String? package});

  /// 批量查询包名是否已安装。
  Future<Set<String>> installedPackages(List<String> packages);
}

/// 真机实现：`com.mutx163.qingyu/pickup_code` 通道（Kotlin 侧
/// `PickupCodeLauncher`）。
///
/// 用 [TimedMethodChannel]：原生主线程被占用时 `await` 会永远不返回，没有
/// 超时就没有恢复路径（全仓口径，见 timed_method_channel.dart 的说明）。
final class PickupCodeNativeChannel implements PickupCodePlatform {
  const PickupCodeNativeChannel();

  static const String channelName = 'com.mutx163.qingyu/pickup_code';

  static const TimedMethodChannel _channel = TimedMethodChannel(channelName);

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PickupCodeCallResult> launchUri({
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
  Future<PickupCodeCallResult> launchApp({
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
      _warnMissingHandler('canResolve');
      return false;
    }
  }

  /// 批量查「装没装」。
  ///
  /// **失败一律抛出，不要吞成空集合。** 空集合在这里的含义是「查过了，一个都没
  /// 装」——页面会据此把每一条入口都降成「未安装」的灰态、执行器也会跳过所有
  /// App 兜底；而「查不到」（通道没注册、原生报错）完全不是这个意思，它应该让
  /// 调用方退回「不知道装没装，那就逐条试」。区分方式就是抛异常：
  /// `PickupCodeRunner.installedPackages` 用 `catch (_) => null` 把异常翻译成
  /// 「未知」。把异常吞成空集合，等于把「不知道」谎报成「一个都没装」。
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
        throw PlatformException(
          code: 'no_result',
          message: 'installedPackages 没有回包',
        );
      }
      return <String>{
        for (final entry in result.entries)
          if (entry.value == true) entry.key,
      };
    } on MissingPluginException {
      _warnMissingHandler('installedPackages');
      rethrow;
    }
  }

  Future<PickupCodeCallResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    if (!supported) {
      return const PickupCodeCallResult(ok: false, reason: 'unsupported');
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      if (result == null) {
        return const PickupCodeCallResult(ok: false, reason: 'no_result');
      }
      final ok = result['ok'] == true;
      final reason = result['reason'];
      return PickupCodeCallResult(
        ok: ok,
        reason: reason is String && reason.isNotEmpty ? reason : null,
      );
    } on PlatformException catch (error) {
      // 超时与「原生明确报错」在调用方看来是同一件事：没拿到可用结果。
      return PickupCodeCallResult(
        ok: false,
        reason: error.code == kPlatformChannelTimeoutCode ? 'timeout' : error.code,
      );
    } on MissingPluginException {
      _warnMissingHandler(method);
      return const PickupCodeCallResult(ok: false, reason: 'unsupported');
    }
  }

  /// 通道「根本没被注册」时喊一声，别让它伪装成「这台设备不支持」。
  ///
  /// 为什么值得专门喊：`MissingPluginException` 的语义是**原生侧没有这条通道**，
  /// 也就是两侧通道名写岔了、或者 Kotlin 里漏注册了——都是本仓的 bug，不是用户
  /// 设备的能力问题。但调用方只能从 [PickupCodeCallResult.reason] 拿到
  /// `unsupported`，界面就显示「当前平台不支持跳到其它应用」，看到的人只会以为
  /// 这功能在别的系统上才可用。2026-10-20 改名时 Dart 侧改成 `pickup_code`、
  /// Kotlin 侧还留着 `campus_tools`，整页 7 条入口全挂在这条误报上。
  ///
  /// 只 `debugPrint`（release 构建里它不输出）：这是给改代码的人看的提示，
  /// 不该出现在用户面前；界面上仍然沿用原来的 `unsupported` 文案。
  void _warnMissingHandler(String method) {
    debugPrint(
      '[pickup_code] 原生通道 $channelName 未注册（$method 收到 '
      'MissingPluginException）：Dart 侧与 Kotlin 侧通道名不一致，或 '
      'MainActivity 漏注册了这条通道 —— 这不是「当前平台不支持」。',
    );
  }
}
