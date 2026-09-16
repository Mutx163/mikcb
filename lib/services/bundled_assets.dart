import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_debug_log.dart';

/// In-memory cache for bundled raster assets used across the app.
///
/// Warm up during startup so pages can render images synchronously via
/// [BundledAssetImage] without async [Image.asset] resolution races.
class BundledAssets {
  BundledAssets._();

  static const launcherIcon = 'assets/branding/launcher_icon.png';
  static const wechatPayQr = 'assets/donate/wechatpay.png';
  static const alipayQr = 'assets/donate/alipay.png';


  /// 启动后（首帧之后）预读的图。**App 图标必须在列**。
  ///
  /// 品牌条走 [BundledAssetImage]：字节没预热时它先渲染成一个占位盒
  /// （`Image` 根本没进树），等资源到位的 `setState` 要落在后面的帧上。而分享
  /// 课表图 / 统计长图的离屏快照只按固定帧数等待，等不到这个异步过程 ——
  /// 拍出来的图里 logo 就是空白（2026-09-16 用户报的就是这个）。
  ///
  /// 图标曾在 `7b49e35c` 被移出清单：当时它是为「启动品牌层」预读的，而那一层
  /// 被删了。品牌条同样需要它，故加回。
  static const _warmUpPaths = <String>[launcherIcon, wechatPayQr, alipayQr];

  static final Map<String, Uint8List> _bytesByPath = {};

  static Uint8List? bytesFor(String assetPath) => _bytesByPath[assetPath];

  static void remember(String assetPath, Uint8List bytes) {
    _bytesByPath[assetPath] = bytes;
  }


  /// Preloads common bitmaps. Failures are logged but never crash startup.
  static Future<void> warmUp() async {
    await Future.wait(_warmUpPaths.map(_loadIntoCache));
  }

  static Future<void> _loadIntoCache(String assetPath) async {
    if (_bytesByPath.containsKey(assetPath)) {
      return;
    }
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) {
        _logMissing(assetPath, '资源数据为空');
        return;
      }
      _bytesByPath[assetPath] = bytes;
    } catch (error, stackTrace) {
      _logMissing(assetPath, error);
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static void _logMissing(String assetPath, Object error) {
    appDebugLog(
      'BundledAssets',
      '预加载 $assetPath 失败：$error。请完全重启应用（非热重载）后再试 `flutter pub get`。',
    );
  }
}
