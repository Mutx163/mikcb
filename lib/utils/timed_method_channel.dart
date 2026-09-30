import 'dart:async';

import 'package:flutter/services.dart';

/// 平台通道默认超时。
///
/// 10s 的取法：绝大多数调用是「读个系统开关 / 写个小组件 / 查个内存数」，
/// 真机上毫秒级到几百毫秒。留 10s 是为了让「原生侧真的卡了」与「设备正忙」
/// 分得开——低端机冷启动时主线程被占住几百毫秒是常事，几十毫秒的阈值会把
/// 正常调用误杀成超时。
const Duration kPlatformChannelTimeout = Duration(seconds: 10);

/// 超时时代替原生回包抛出的异常所用的 [code]。
///
/// 调用方若要区分「原生明确报错」与「原生没回话」，比对这个 code 即可。
const String kPlatformChannelTimeoutCode = 'TIMEOUT';

/// 给 [MethodChannel] 套一层默认超时的子类。
///
/// ## 为什么需要它
///
/// 平台通道的回包由**原生主线程**派发（官方口径：`setMethodCallHandler` 的
/// 回调跑在主线程）。主线程一卡——冷启动、GC、原生 handler 里跑重活——Dart 侧
/// 的 `await` 就**永远不完成，且没有任何恢复路径**：没有超时、没有取消、没有兜底。
///
/// 本仓曾有 71 处 `invokeMethod` / `invokeListMethod` / `invokeMapMethod` 全部裸调，
/// 一处超时都没有。改成逐个调用点补 `.timeout()` 需要改 71 处、diff 巨大且容易漏；
/// 而通道声明只有 21 处，所以超时做在**通道这一层**：换掉类型，全仓一次覆盖，
/// 以后新写的通道只要用这个类就自动带上限。
///
/// ## 为什么超时时抛 [PlatformException] 而不是 [TimeoutException]
///
/// 抛 `TimeoutException` 会让**只捕获 `PlatformException` 的调用点漏接**
/// （本仓实测 18 处），另有 13 处调用点就近没有 catch——这些地方会凭空多出
/// 新的未处理异步错误，把「安静卡住」换成「突然抛错」。而从 Dart 的视角看，
/// 超时和「原生调用失败」是同一件事：没拿到可用回包。抛 `PlatformException`
/// 让既有的 `on PlatformException` / `catch (e)` 逻辑原样生效，零改动适配。
class TimedMethodChannel extends MethodChannel {
  /// 构造一个带默认超时的通道。
  ///
  /// 位置参数与 [MethodChannel] 一致（通道名），其余改成命名——Dart 不允许一个
  /// 构造函数同时有可选位置参数和命名参数，而 `timeout` 用命名的可读性明显更好。
  /// 本仓 21 处通道声明都只传通道名，所以换签名不影响任何调用点。
  const TimedMethodChannel(
    String name, {
    MethodCodec codec = const StandardMethodCodec(),
    BinaryMessenger? binaryMessenger,
    this.timeout = kPlatformChannelTimeout,
  }) : super(name, codec, binaryMessenger);

  /// 本通道所有调用的超时上限。
  final Duration timeout;

  Never _onTimeout(String method) => throw PlatformException(
        code: kPlatformChannelTimeoutCode,
        message:
            '平台通道 $name 的 $method 调用超过 ${timeout.inMilliseconds}ms 未返回'
            '（原生主线程可能被占用），已放弃本次等待。',
      );

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) =>
      super
          .invokeMethod<T>(method, arguments)
          .timeout(timeout, onTimeout: () => _onTimeout(method));

  @override
  Future<List<T>?> invokeListMethod<T>(String method, [dynamic arguments]) =>
      super
          .invokeListMethod<T>(method, arguments)
          .timeout(timeout, onTimeout: () => _onTimeout(method));

  @override
  Future<Map<K, V>?> invokeMapMethod<K, V>(String method, [dynamic arguments]) =>
      super
          .invokeMapMethod<K, V>(method, arguments)
          .timeout(timeout, onTimeout: () => _onTimeout(method));
}
