import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// Android-native RGBA blur (RenderEffect API 31+) with Dart Gaussian fallback.
abstract final class FrostedBlurService {
  static const _channel = MethodChannel('com.mutx163.qingyu/frosted_blur');

  static bool? _nativeSupportedCache;
  static bool _nativeBlurUnavailable = false;

  /// Last blur engine used (for diagnostics).
  static String lastBlurEngine = 'unknown';

  /// CFH live blur on Android API 31+; iOS and web use tint-only.
  static bool get isLiveBlurSupported {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    final cached = _nativeSupportedCache;
    if (cached != null) {
      return cached;
    }
    return false;
  }

  static Future<void> probeNativeSupport() async {
    if (kIsWeb || !Platform.isAndroid) {
      _nativeSupportedCache = false;
      return;
    }
    try {
      final supported =
          await _channel.invokeMethod<bool>('isSupported') ?? false;
      _nativeSupportedCache = supported;
    } on PlatformException {
      _nativeSupportedCache = false;
    }
  }

  /// Blurs [source] and returns a new [ui.Image]. Disposes [source].
  ///
  /// [sigmaPx] is the Gaussian sigma in **snapshot pixel** coordinates.
  static Future<ui.Image?> blurImage(
    ui.Image source, {
    double sigmaPx = 8,
  }) async {
    final width = source.width;
    final height = source.height;
    final radiusPx = sigmaPx.clamp(0.5, 64.0);

    if (Platform.isAndroid &&
        (_nativeSupportedCache ?? false) &&
        !_nativeBlurUnavailable) {
      final rgba = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba != null) {
        try {
          final result = await _channel.invokeMethod<Uint8List>('blurRgba', {
            'bytes': rgba.buffer.asUint8List(
              rgba.offsetInBytes,
              rgba.lengthInBytes,
            ),
            'width': width,
            'height': height,
            'radius': radiusPx,
          });
          if (result != null && result.length == width * height * 4) {
            source.dispose();
            _setBlurEngine('native');
            _logBlurPath('native-rgba', radiusPx);
            return _imageFromRgba(result, width, height);
          }
        } on PlatformException {
          _nativeBlurUnavailable = true;
        }
      }
    }

    _setBlurEngine('dart');
    _logBlurPath('dart', radiusPx);
    return _blurInDart(source, radiusPx);
  }

  static void _setBlurEngine(String engine) {
    lastBlurEngine = engine;
  }

  static void _logBlurPath(String path, double sigma) {
    if (kDebugMode) {
      debugPrint('[FrostedBlur] path=$path sigma=$sigma');
    }
  }

  static Future<ui.Image?> _imageFromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<ui.Image?> _blurInDart(ui.Image source, double sigmaPx) async {
    final width = source.width;
    final height = source.height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigmaPx,
        sigmaY: sigmaPx,
        tileMode: ui.TileMode.clamp,
      );
    canvas.drawImage(source, ui.Offset.zero, paint);
    source.dispose();
    final picture = recorder.endRecording();
    final blurred = await picture.toImage(width, height);
    picture.dispose();
    return blurred;
  }
}
