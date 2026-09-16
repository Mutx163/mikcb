import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 截屏检测（Android 14+ 官方 `Activity.ScreenCaptureCallback`）。
///
/// 系统只告知「用户刚截了一张」，**不提供截图内容**，也不需要任何运行时
/// 权限 —— Manifest 里的 `DETECT_SCREEN_CAPTURE` 是普通权限，安装即授予。
/// 因此这里既没有读图、也没有监听截图文件夹。
///
/// Android 14 以下没有该回调，[isSupported] 为 false；调用方据此隐藏相关
/// 设置项，手动分享入口不受影响。
abstract final class ScreenCaptureService {
  static const _channel = MethodChannel('com.mutx163.qingyu/screen_capture');

  static final _controller = StreamController<void>.broadcast();

  static bool? _supported;
  static bool _handlerAttached = false;

  /// 想监听的调用方数量（引用计数）。
  ///
  /// 监听是**进程级**的，但发起方是页面：重建期间新旧 State 会短暂重叠，
  /// 若「谁走谁注销」，后走的那个会把新来者的监听一起关掉，表现为截屏提示
  /// 莫名失效且不再恢复。所以由最后一个离开的负责注销。
  static int _activeListeners = 0;

  /// 用户截屏事件。只在平台支持且已 [start] 后才会发事件。
  static Stream<void> get onScreenshot => _controller.stream;

  /// 本平台是否支持截屏检测（需先 [ensureSupported]）。
  static bool get isSupported => _supported ?? false;

  /// 探测平台能力，结果缓存（不可能在运行中变化）。
  ///
  /// 判定走 [defaultTargetPlatform] 而不是 `Platform.isAndroid`：前者在
  /// 测试里可用 `debugDefaultTargetPlatformOverride` 覆盖，后者不能。
  static Future<bool> ensureSupported() async {
    final cached = _supported;
    if (cached != null) {
      return cached;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _supported = false;
    }
    try {
      return _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return _supported = false;
    } on MissingPluginException {
      return _supported = false;
    }
  }

  /// 开始监听。可重复调用，内部按引用计数只在第一个调用方到位时注册。
  static Future<void> start() async {
    _activeListeners++;
    if (_activeListeners > 1) {
      return;
    }
    if (!await ensureSupported()) {
      return;
    }
    _attachHandler();
    try {
      await _channel.invokeMethod<bool>('start');
    } on PlatformException {
      // 原生侧拒绝（异常 ROM）时静默降级：手动分享入口不受影响。
    } on MissingPluginException {
      // 平台没有这个通道。
    }
  }

  /// 停止监听。最后一个调用方离开时才真的注销原生回调。
  static Future<void> stop() async {
    if (_activeListeners == 0) {
      return;
    }
    _activeListeners--;
    if (_activeListeners > 0) {
      return;
    }
    // 顺手摘掉 Dart 侧的回调：契约是「没在听就不发事件」。原生侧本就会
    // 停止上报，这里是防止它万一漏发一次时把事件漏给已下线的订阅者。
    _channel.setMethodCallHandler(null);
    _handlerAttached = false;
    try {
      await _channel.invokeMethod<bool>('stop');
    } on PlatformException {
      // 原生侧可能已随 Activity 销毁（进程留在后台被回收），忽略。
    } on MissingPluginException {
      // 平台不支持时本来就没注册过。
    }
  }

  static void _attachHandler() {
    if (_handlerAttached) {
      return;
    }
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshot' && !_controller.isClosed) {
        _controller.add(null);
      }
      return null;
    });
  }

  @visibleForTesting
  static void resetForTesting() {
    _supported = null;
    _activeListeners = 0;
    _handlerAttached = false;
    _channel.setMethodCallHandler(null);
  }
}
