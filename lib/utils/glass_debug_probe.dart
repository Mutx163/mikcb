import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// [临时诊断] 液体玻璃回落实体卡片的调试探针。
///
/// 背景：用户反馈「手机截图时，液体玻璃效果会恢复成实体卡片」。玻璃表面
/// 统一由 `LiquidGlassDegradation.shouldDegradeFor`（MediaQuery 三个无障碍
/// 信号）加预模糊壁纸位图可用性决定，但截图（尤其 HyperOS 截图流程）究竟
/// 触发了哪条回落路径未知。本探针把所有可能翻转的输入都打上 `[GlassDbg]`
/// 前缀日志，复现后按时间轴对齐定位；定位完成后整体移除。
abstract final class GlassDebugProbe {
  static bool _installed = false;

  static void log(String message) {
    debugPrint('[GlassDbg] $message');
  }

  /// 一次性快照：玻璃降级闸门的全部 Flutter 侧输入 + 预模糊请求键输入。
  static void logPlatformSignals(String reason) {
    final dispatcher = PlatformDispatcher.instance;
    final accessibility = dispatcher.accessibilityFeatures;
    final view = dispatcher.views.isEmpty ? null : dispatcher.views.first;
    log(
      '$reason :: '
      'disableAnimations=${accessibility.disableAnimations} '
      'accessibleNavigation=${accessibility.accessibleNavigation} '
      'highContrast=${accessibility.highContrast} '
      'dpr=${view?.devicePixelRatio} '
      'physicalSize=${view?.physicalSize} '
      'textScale=${dispatcher.textScaleFactor} '
      'brightness=${dispatcher.platformBrightness.name}',
    );
  }

  /// 注册全局信号监听（main 启动早期调用一次）。
  static void install() {
    if (_installed) {
      return;
    }
    _installed = true;
    WidgetsBinding.instance.addObserver(_GlassDebugObserver());
    logPlatformSignals('probe.install');
  }
}

class _GlassDebugObserver extends WidgetsBindingObserver {
  @override
  void didChangeAccessibilityFeatures() {
    GlassDebugProbe.logPlatformSignals('a11y.CHANGED');
  }

  @override
  void didChangeMetrics() {
    GlassDebugProbe.logPlatformSignals('metrics.CHANGED');
  }

  @override
  void didChangeTextScaleFactor() {
    GlassDebugProbe.logPlatformSignals('textScale.CHANGED');
  }

  @override
  void didChangePlatformBrightness() {
    GlassDebugProbe.logPlatformSignals('brightness.CHANGED');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    GlassDebugProbe.log('lifecycle -> ${state.name}');
  }
}
