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


  static const _warmUpPaths = <String>[wechatPayQr, alipayQr];

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
