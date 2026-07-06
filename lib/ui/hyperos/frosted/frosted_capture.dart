import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a downsampled snapshot from a [RepaintBoundary].
abstract final class FrostedCapture {
  /// Capture scale for the header backdrop strip (higher = sharper frost).
  static const headerPixelRatio = 0.72;

  /// Extra logical px sampled below the header for blur kernel bleed.
  static const headerStripBleed = 36.0;

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
    double scrollOffsetLogical = 0,
    double pixelRatio = headerPixelRatio,
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
    final displayHeight = (visibleHeight * pixelRatio).ceil().clamp(
      1,
      cropHeight,
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
    canvas.drawImageRect(snapshot, src, dst, ui.Paint());

    final picture = recorder.endRecording();
    late final ui.Image strip;
    try {
      strip = await picture.toImage(cropWidth, cropHeight);
    } finally {
      picture.dispose();
    }

    if (displayHeight >= cropHeight) {
      return strip;
    }
    return _cropTop(strip, displayHeight, cropWidth);
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

    final strip = await cropHeaderStripFromSnapshot(
      snapshot,
      stripHeightLogical: stripHeightLogical,
      visibleHeightLogical: visibleHeightLogical,
      pixelRatio: pixelRatio,
    );
    snapshot.dispose();
    return strip;
  }

  static Future<ui.Image?> _cropTop(
    ui.Image source,
    int heightPx,
    int widthPx,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final src = ui.Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble());
    canvas.drawImageRect(source, src, src, ui.Paint());
    source.dispose();
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(widthPx, heightPx);
    } finally {
      picture.dispose();
    }
  }
}
