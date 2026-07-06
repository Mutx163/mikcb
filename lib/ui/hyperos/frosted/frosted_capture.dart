import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../hyperos_theme.dart';

/// Captures a downsampled snapshot from a [RepaintBoundary].
abstract final class FrostedCapture {
  /// Capture scale for the header backdrop strip (higher = sharper frost).
  static const headerPixelRatio = 0.72;

  /// Extra logical px sampled below the header for blur kernel bleed.
  static const headerStripBleed = 18.0;

  /// Visible header height (status bar + bar), without blur-kernel bleed.
  static double headerVisibleHeightLogical(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    const headerBody = 44.0;
    const headerPaddingBottom = 4.0;
    return safeTop + headerBody + headerPaddingBottom;
  }

  /// Logical height of the strip captured for CFH (visible header + bleed).
  static double headerStripHeightLogical(BuildContext context) {
    return headerVisibleHeightLogical(context) + headerStripBleed;
  }

  static Future<ui.Image?> fromBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = headerPixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    if (renderObject.debugNeedsPaint) {
      return null;
    }
    try {
      return renderObject.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      return null;
    }
  }

  /// Like [fromBoundary] but composites onto an opaque page background first.
  static Future<ui.Image?> fromBoundaryOpaque(
    GlobalKey boundaryKey, {
    double pixelRatio = headerPixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    final fillColor = context != null
        ? HyperosColors.scaffoldBackground(context)
        : null;
    final snapshot = await fromBoundary(boundaryKey, pixelRatio: pixelRatio);
    if (snapshot == null) {
      return null;
    }
    if (fillColor == null) {
      return snapshot;
    }

    final width = snapshot.width;
    final height = snapshot.height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawRect(bounds, ui.Paint()..color = fillColor);
    canvas.drawImage(snapshot, ui.Offset.zero, ui.Paint());
    snapshot.dispose();

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  /// Crops the header strip from [snapshot] taken at [captureScrollPixels].
  ///
  /// [scrollOffsetLogical] = currentScroll - captureScroll; shifts the crop
  /// down in the cached bitmap so the blur tracks scroll without re-capture.
  ///
  /// Returns null when the crop falls outside [snapshot] (caller should recapture).
  static Future<ui.Image?> cropHeaderStripFromSnapshot(
    ui.Image snapshot, {
    BuildContext? context,
    double? stripHeightLogical,
    double? visibleHeightLogical,
    Color? scaffoldBackground,
    double scrollOffsetLogical = 0,
    double pixelRatio = headerPixelRatio,
    bool paintBackground = true,
  }) async {
    final stripHeight =
        stripHeightLogical ??
        (context != null ? headerStripHeightLogical(context) : null);
    final visibleHeight =
        visibleHeightLogical ??
        (context != null ? headerVisibleHeightLogical(context) : null);
    if (stripHeight == null || visibleHeight == null) {
      return null;
    }

    final offsetYPx = (scrollOffsetLogical * pixelRatio).round().clamp(
      0,
      snapshot.height,
    );
    final cropHeight = (stripHeight * pixelRatio).ceil().clamp(
      1,
      snapshot.height,
    );
    final cropWidth = snapshot.width;

    if (offsetYPx + cropHeight > snapshot.height) {
      return null;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final src = ui.Rect.fromLTWH(
      0,
      offsetYPx.toDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );
    final dst = ui.Rect.fromLTWH(
      0,
      0,
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );
    // Opaque fill before compositing: transparent [toImage] pixels blur to black
    // halos and blow out light content when alpha is mishandled downstream.
    if (paintBackground) {
      final fillColor =
          scaffoldBackground ??
          (context != null
              ? HyperosColors.scaffoldBackground(context)
              : const Color(0xFFF5F5F5));
      canvas.drawRect(dst, ui.Paint()..color = fillColor);
    }
    canvas.drawImageRect(snapshot, src, dst, ui.Paint());

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(cropWidth, cropHeight);
    } finally {
      picture.dispose();
    }
  }

  /// Crops [source] to the visible header height (drops blur-kernel bleed below).
  ///
  /// When [disposeSource] is true, [source] is disposed after pixels are copied
  /// (only when a new image is created). Callers that still need [source] for
  /// blur must pass `disposeSource: false`.
  static Future<ui.Image?> cropTopToVisible(
    ui.Image source, {
    required double visibleHeightLogical,
    double pixelRatio = headerPixelRatio,
    bool disposeSource = false,
  }) async {
    final displayHeight = (visibleHeightLogical * pixelRatio).ceil().clamp(
      1,
      source.height,
    );
    if (displayHeight >= source.height) {
      return source;
    }
    return _cropTop(
      source,
      displayHeight,
      source.width,
      disposeSource: disposeSource,
    );
  }

  /// Captures viewport-top strip (fresh [toImage] + crop at offset 0).
  static Future<ui.Image?> headerStripFromBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = headerPixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      return null;
    }

    final stripHeightLogical = headerStripHeightLogical(context);
    final visibleHeightLogical = headerVisibleHeightLogical(context);

    final snapshot = await fromBoundary(boundaryKey, pixelRatio: pixelRatio);
    if (snapshot == null) {
      return null;
    }

    final stripWithBleed = await cropHeaderStripFromSnapshot(
      snapshot,
      stripHeightLogical: stripHeightLogical,
      visibleHeightLogical: visibleHeightLogical,
      pixelRatio: pixelRatio,
    );
    snapshot.dispose();
    if (stripWithBleed == null) {
      return null;
    }
    return cropTopToVisible(
      stripWithBleed,
      visibleHeightLogical: visibleHeightLogical,
      pixelRatio: pixelRatio,
      disposeSource: true,
    );
  }

  static Future<ui.Image?> _cropTop(
    ui.Image source,
    int heightPx,
    int widthPx, {
    bool disposeSource = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final src = ui.Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble());
    canvas.drawImageRect(source, src, src, ui.Paint());
    if (disposeSource) {
      source.dispose();
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(widthPx, heightPx);
    } finally {
      picture.dispose();
    }
  }
}
