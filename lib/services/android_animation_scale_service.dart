import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';

/// Reads Android developer-option animation scales for Flutter transitions.
abstract final class AndroidAnimationScaleService {
  static const _channel = MethodChannel('com.mutx163.qingyu/system_ui');

  static double _transitionScale = 1.0;
  static double _userTransitionSpeed = 1.0;
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
      if (radius != null && radius > 0) {
        _displayCornerRadiusDp = radius.toDouble();
      } else {
        _displayCornerRadiusDp =
            HyperosMiuixNavigation.pageCornerRadiusFallback;
      }
    } on PlatformException {
      _displayCornerRadiusDp = HyperosMiuixNavigation.pageCornerRadiusFallback;
    } on MissingPluginException {
      _displayCornerRadiusDp = HyperosMiuixNavigation.pageCornerRadiusFallback;
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
