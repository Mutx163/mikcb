import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/timed_method_channel.dart';

/// 应用自行请求回到后台（等效按 Home 键）。
///
/// 走 `system_ui` 通道的 `moveTaskToBack`：调 `Activity.moveTaskToBack(true)`，
/// 不涉及任何设备控制（不是注入按键，是应用自己 task 的标准退后台 API），
/// 无需特殊权限。MIUI 等定制桌面上偶发返回 false（分屏/画中画等非常规
/// task 形态），调用方应自行兜底提示「请手动按 Home 查看」。
abstract final class AndroidMoveToBackService {
  static const _channel = TimedMethodChannel('com.mutx163.qingyu/system_ui');

  /// 尝试把应用退到后台。返回是否成功发起；桌面端 / iOS 一律 false。
  static Future<bool> moveTaskToBack() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('moveTaskToBack') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
