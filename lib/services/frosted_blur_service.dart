import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../utils/timed_method_channel.dart';

/// Android-native RGBA blur (RenderEffect API 31+) with Dart Gaussian fallback.
abstract final class FrostedBlurService {
  static const _channel = TimedMethodChannel('com.mutx163.qingyu/frosted_blur');

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

  /// Blurs [source] and returns a new [ui.Image].
  ///
  /// When [disposeSource] is true (default), [source] is disposed after the
  /// pixels are read. CFH passes false while the source may still be painted.
  static Future<ui.Image?> blurImage(
    ui.Image source, {
    double sigmaPx = 8,
    bool disposeSource = true,
  }) async {
    final width = source.width;
    final height = source.height;
    final radiusPx = sigmaPx.clamp(0.5, 64.0);

    if (Platform.isAndroid &&
        (_nativeSupportedCache ?? false) &&
        !_nativeBlurUnavailable) {
      final rgba = await source.toByteData();
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
            if (disposeSource) {
              source.dispose();
            }
            _setBlurEngine('native');
            return _imageFromRgba(result, width, height);
          }
        } on PlatformException {
          _nativeBlurUnavailable = true;
        }
      }
    }

    _setBlurEngine('dart');
    return _blurInDart(source, radiusPx, disposeSource: disposeSource);
  }

  static void _setBlurEngine(String engine) {
    lastBlurEngine = engine;
  }

  static Future<ui.Image?> _imageFromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) async {
    // 三件套都必须手动释放，否则每次调用在 native 侧漏一份像素缓冲：
    // - [ui.ImmutableBuffer]：持有一份 RGBA 拷贝；
    // - [ui.ImageDescriptor]：描述符本体；
    // - [ui.Codec]：编解码器（拿到帧之后即可释放，帧的 [ui.Image] 独立持有）。
    // 释放顺序与创建相反；中途抛错也要走到（try/finally 兜底）。
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<ui.Image?> _blurInDart(
    ui.Image source,
    double sigmaPx, {
    required bool disposeSource,
  }) async {
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
    final picture = recorder.endRecording();
    final blurred = await picture.toImage(width, height);
    picture.dispose();
    if (disposeSource) {
      source.dispose();
    }
    return blurred;
  }
}
