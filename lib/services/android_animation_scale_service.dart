import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import '../utils/timed_method_channel.dart';

/// Reads Android developer-option animation scales for Flutter transitions.
abstract final class AndroidAnimationScaleService {
  static const _channel = TimedMethodChannel('com.mutx163.qingyu/system_ui');

  static double _transitionScale = 1;
  static double _userTransitionSpeed = 1;
  static double _displayCornerRadiusDp =
      HyperosMiuixNavigation.pageCornerRadiusFallback;
  static bool _initialized = false;

  static double get transitionScale => _transitionScale;

  /// App-level page transition speed multiplier (1.0 = default).
  ///
  /// Higher values shorten push/pop durations; lower values lengthen them.
  static double get userTransitionSpeed => _userTransitionSpeed;

  static void setUserTransitionSpeed(double speed) {
    _userTransitionSpeed = speed.clamp(0.5, 2.5);
  }

  /// Top-left display corner radius in logical pixels (matches screen corners).
  static double get displayCornerRadiusDp => _displayCornerRadiusDp;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  static Future<void> refresh() async {
    if (kIsWeb || !Platform.isAndroid) {
      _transitionScale = 1.0;
      _displayCornerRadiusDp = HyperosMiuixNavigation.pageCornerRadiusFallback;
      return;
    }
    try {
      final value = await _channel.invokeMethod<num>(
        'getTransitionAnimationScale',
      );
      _transitionScale = (value ?? 1.0).toDouble().clamp(0.0, 3.0);
    } on PlatformException {
      _transitionScale = 1.0;
    } on MissingPluginException {
      _transitionScale = 1.0;
    }
    try {
      final radius = await _channel.invokeMethod<num>(
        'getDisplayCornerRadiusDp',
      );
      // 2026-10-18：平台返回 0 = 这台机器没有可对齐的屏幕圆角（或上下角
      // 半径不一致到取不出公共值）。此时**不能用 28dp 假装**：假半径会把
      // 转场的前缘缺口画到机身圆角之外，停稳时就露出来（用户口径「圆角
      // 闪现消失」）。归零 = 整条转场不做前缘裁切，退回普通直角滑入。
      _displayCornerRadiusDp = (radius != null && radius > 0)
          ? radius.toDouble()
          : 0;
    } on PlatformException {
      // 读失败保留上一次的值（初次 = 历史回退值），下次 resume 还会再读。
    } on MissingPluginException {
      // 同上：保留上一次的值。
    }
  }

  static Duration scaledDuration(int baseMilliseconds) {
    final speed = _userTransitionSpeed <= 0 ? 1.0 : _userTransitionSpeed;
    final scale = _transitionScale / speed;
    if (scale <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (baseMilliseconds * scale).round());
  }
}
