import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// In-memory cache for bundled raster assets used across the app.
///
/// Warm up during startup so pages can render images synchronously via
/// [BundledAssetImage] without async [Image.asset] resolution races.
class BundledAssets {
  BundledAssets._();

  static const launcherIcon = 'assets/branding/launcher_icon.png';
  static const wechatPayQr = 'assets/donate/wechatpay.png';
  static const alipayQr = 'assets/donate/alipay.png';

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
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      if (bytes.isEmpty) {
        _logMissing(assetPath, 'asset has empty data');
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
    debugPrint(
      '[BundledAssets] Failed to preload $assetPath: $error. '
      'Stop the app and run a full restart (not hot reload) after '
      '`flutter pub get`.',
    );
  }
}
