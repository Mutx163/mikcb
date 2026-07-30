import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../ui/hyperos/hyperos.dart';

import '../logging/app_debug_log.dart';
import '../l10n/service_message_localizer.dart';
import '../models/statistics_export_options.dart';
import '../models/statistics_models.dart';
import '../ui/hyperos/hyperos_tokens.dart';
import '../utils/app_toast.dart';
import '../widgets/statistics/statistics_export_document.dart';

/// Captures course statistics as a long PNG and opens the share sheet.
class StatisticsShareService {
  StatisticsShareService._();

  /// Share density: 2.5 balances sharpness vs main-thread paint cost.
  static const double _preferredPixelRatio = 2.5;

  /// Conservative GPU texture edge so OPPO / mid-range Android stays safe.
  static const double _maxTextureEdge = 4096;

  /// Layout settle frames (no artificial sleeps — those feel like freezes).
  static const int _settleFrameCount = 2;
  static const double _maxExportLogicalHeight = 30000;

  /// Share images always use light scaffold so transparent holes never look black.
  static const Color _exportScaffoldColor = HyperosTokens.background;

  static Future<void> exportAndShare({
    required BuildContext context,
    required StatisticsExportOptions options,
    required SemesterStats semesterStats,
    required List<Achievement> achievements,
    required List<DataStory> stories,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!options.hasModules) {
      if (context.mounted) {
        showAppToast(
          context,
          message: l10n.statisticsExportSelectModuleHint,
          kind: AppToastKind.warning,
        );
      }
      return;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      appDebugLog('StatisticsShare', 'Overlay not found for export capture');
      if (context.mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(
            l10n,
            encodeServiceMessage('statistics_share_failed', {
              'detail': 'overlay_missing',
            }),
          ),
          kind: AppToastKind.error,
        );
      }
      return;
    }

    try {
      final pngBytes = await _captureExportDocumentPng(
        overlayState: overlayState,
        context: context,
        options: options,
        semesterStats: semesterStats,
        achievements: achievements,
        stories: stories,
      );
      if (pngBytes == null) {
        appDebugLog('StatisticsShare', 'Export capture returned empty bytes');
        if (context.mounted) {
          showAppToast(
            context,
            message: localizeServiceMessage(
              l10n,
              encodeServiceMessage('statistics_share_failed', {
                'detail': 'capture_empty',
              }),
            ),
            kind: AppToastKind.error,
          );
        }
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = File(
        '${tempDirectory.path}/statistics_export_$timestamp.png',
      );
      await outputFile.writeAsBytes(pngBytes, flush: true);

      if (!context.mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outputFile.path, mimeType: 'image/png')],
          subject: l10n.statisticsShareTitle,
          text: l10n.statisticsShareText,
        ),
      );
    } catch (error, stackTrace) {
      appDebugLog('StatisticsShare', 'Export failed: $error\n$stackTrace');
      if (context.mounted) {
        showAppToast(
          context,
          message: localizeServiceMessage(
            AppLocalizations.of(context)!,
            encodeServiceMessage('statistics_share_failed', {
              'detail': '$error',
            }),
          ),
          kind: AppToastKind.error,
        );
      }
    }
  }

  static Future<Uint8List?> _captureExportDocumentPng({
    required OverlayState overlayState,
    required BuildContext context,
    required StatisticsExportOptions options,
    required SemesterStats semesterStats,
    required List<Achievement> achievements,
    required List<DataStory> stories,
  }) async {
    final mediaQuery = MediaQuery.of(context);
    final exportWidth = mediaQuery.size.width.clamp(320.0, 420.0);
    final textDirection = Directionality.of(context);
    final exportTheme = _exportLightTheme(context);
    const scaffoldColor = _exportScaffoldColor;

    final document = StatisticsExportDocument(
      options: options,
      semesterStats: semesterStats,
      achievements: achievements,
      stories: stories,
    );

    final session = _ExportCaptureSession(
      exportWidth: exportWidth,
      mediaQuery: mediaQuery,
      theme: exportTheme,
      textDirection: textDirection,
      scaffoldColor: scaffoldColor,
      document: document,
    );

    late OverlayEntry captureEntry;
    captureEntry = OverlayEntry(builder: (_) => session.build());
    // Capture first, then barrier on top — user only sees the spinner.
    overlayState.insert(captureEntry);

    final barrierEntry = OverlayEntry(
      builder: (_) {
        return const Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              color: Color(0x61000000),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xF5FFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(barrierEntry);
    // Paint the spinner once before heavy capture work so the UI doesn't feel frozen.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      // Pass 1: measure full logical size (one host, no tear-down mid-session).
      session.configureFullDocument();
      captureEntry.markNeedsBuild();
      final measuredSize = await _waitAndReadSize(session.boundaryKey);
      if (measuredSize == null ||
          measuredSize.width <= 0 ||
          measuredSize.height <= 0) {
        appDebugLog('StatisticsShare', 'Failed to measure export document');
        return null;
      }

      const pixelRatio = _preferredPixelRatio;
      final fullPixelHeight = measuredSize.height * pixelRatio;
      final maxSlicePixelHeight = _maxTextureEdge - 16;

      appDebugLog(
        'StatisticsShare',
        'Export measure '
            '${measuredSize.width.toStringAsFixed(1)}x'
            '${measuredSize.height.toStringAsFixed(1)} '
            'ratio=$pixelRatio pxH≈${fullPixelHeight.round()}',
      );

      if (fullPixelHeight <= maxSlicePixelHeight) {
        final rgbaImage = await _rasterizeKeyToRgba(
          session.boundaryKey,
          pixelRatio,
          opaqueFill: scaffoldColor,
        );
        if (rgbaImage == null) {
          return null;
        }
        return _encodePngOffMainThread(rgbaImage);
      }

      // Tall content: reuse one host, only change slice window.
      final sliceLogicalHeight = maxSlicePixelHeight / pixelRatio;
      final sliceCount = (measuredSize.height / sliceLogicalHeight).ceil();
      appDebugLog(
        'StatisticsShare',
        'Tall export slices=$sliceCount sliceH=${sliceLogicalHeight.toStringAsFixed(1)}',
      );

      final decodedSlices = <img.Image>[];
      for (var sliceIndex = 0; sliceIndex < sliceCount; sliceIndex++) {
        final sliceTop = sliceIndex * sliceLogicalHeight;
        final remaining = measuredSize.height - sliceTop;
        if (remaining <= 0.5) {
          break;
        }
        final thisSliceHeight = math.min(sliceLogicalHeight, remaining);
        session.configureSlice(
          sliceTop: sliceTop,
          sliceHeight: thisSliceHeight,
        );
        captureEntry.markNeedsBuild();
        // Yield so the barrier spinner can paint between heavy frames.
        await Future<void>.delayed(Duration.zero);
        await _settleFrames();

        final sliceImage = await _rasterizeKeyToRgba(
          session.boundaryKey,
          pixelRatio,
          opaqueFill: scaffoldColor,
        );
        if (sliceImage == null) {
          appDebugLog('StatisticsShare', 'Slice $sliceIndex capture failed');
          return null;
        }
        decodedSlices.add(sliceImage);
      }

      if (decodedSlices.isEmpty) {
        return null;
      }

      // Stitch on the main isolate (img.Image is not reliably isolate-sendable),
      // then encode PNG off the UI thread.
      final stitched = _stitchRgbaSlices(
        slices: decodedSlices,
        fillColor: scaffoldColor,
      );
      return _encodePngOffMainThread(stitched);
    } finally {
      barrierEntry.remove();
      captureEntry.remove();
    }
  }

  /// Force light Material theme so share cards stay readable in WeChat etc.
  static ThemeData _exportLightTheme(BuildContext context) {
    final current = Theme.of(context);
    if (current.brightness == Brightness.light) {
      return current;
    }
    final fontFamily = current.textTheme.bodyMedium?.fontFamily;
    final fontFamilyFallback = current.textTheme.bodyMedium?.fontFamilyFallback;
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: current.useMaterial3,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  static Future<void> _settleFrames() async {
    for (var frameIndex = 0; frameIndex < _settleFrameCount; frameIndex++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  static Future<Size?> _waitAndReadSize(GlobalKey key) async {
    await _settleFrames();
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.size;
  }

  /// Rasterize [RepaintBoundary] → opaque RGBA [img.Image] (no PNG round-trip).
  static Future<img.Image?> _rasterizeKeyToRgba(
    GlobalKey key,
    double pixelRatio, {
    required Color opaqueFill,
  }) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    // Never read [RenderObject.debugNeedsPaint] in release (throws LateError).
    final snapshot = await renderObject.toImage(pixelRatio: pixelRatio);
    ui.Image? composited;
    try {
      composited = await _compositeOntoOpaque(snapshot, opaqueFill);
      final byteData = await composited.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return null;
      }
      return img.Image.fromBytes(
        width: composited.width,
        height: composited.height,
        bytes: byteData.buffer,
        bytesOffset: byteData.offsetInBytes,
        order: img.ChannelOrder.rgba,
      );
    } finally {
      snapshot.dispose();
      composited?.dispose();
    }
  }

  static Future<ui.Image> _compositeOntoOpaque(
    ui.Image source,
    Color fillColor,
  ) async {
    final width = source.width;
    final height = source.height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawRect(bounds, ui.Paint()..color = fillColor);
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  static Future<Uint8List> _encodePngOffMainThread(img.Image image) {
    final width = image.width;
    final height = image.height;
    final rgbaBytes = Uint8List.fromList(
      image.getBytes(order: img.ChannelOrder.rgba),
    );
    return Isolate.run(() {
      final copy = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        order: img.ChannelOrder.rgba,
      );
      return Uint8List.fromList(img.encodePng(copy, level: 6));
    });
  }

  static img.Image _stitchRgbaSlices({
    required List<img.Image> slices,
    required Color fillColor,
  }) {
    final stitchedWidth = slices.map((slice) => slice.width).reduce(math.max);
    final stitchedHeight = slices.fold<int>(
      0,
      (sum, slice) => sum + slice.height,
    );
    final canvas = img.Image(width: stitchedWidth, height: stitchedHeight);
    img.fill(canvas, color: _toRgba8(fillColor));
    var offsetY = 0;
    for (final slice in slices) {
      img.compositeImage(canvas, slice, dstY: offsetY);
      offsetY += slice.height;
    }
    return canvas;
  }

  static img.ColorRgba8 _toRgba8(Color color) {
    return img.ColorRgba8(
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
      (color.a * 255.0).round().clamp(0, 255),
    );
  }
}

enum _ExportCaptureMode { fullDocument, slice }

/// Mutable capture host config shared by one OverlayEntry for the whole export.
class _ExportCaptureSession {
  _ExportCaptureSession({
    required this.exportWidth,
    required this.mediaQuery,
    required this.theme,
    required this.textDirection,
    required this.scaffoldColor,
    required this.document,
  });

  final double exportWidth;
  final MediaQueryData mediaQuery;
  final ThemeData theme;
  final TextDirection textDirection;
  final Color scaffoldColor;
  final Widget document;

  final GlobalKey boundaryKey = GlobalKey();

  _ExportCaptureMode mode = _ExportCaptureMode.fullDocument;
  double sliceTop = 0;
  double sliceHeight = 0;

  void configureFullDocument() {
    mode = _ExportCaptureMode.fullDocument;
    sliceTop = 0;
    sliceHeight = 0;
  }

  void configureSlice({required double sliceTop, required double sliceHeight}) {
    mode = _ExportCaptureMode.slice;
    this.sliceTop = sliceTop;
    this.sliceHeight = sliceHeight;
  }

  Widget build() {
    // Host viewport may be only one screen tall; the document itself must be
    // measured/captured from *inside* OverflowBox. Putting [RepaintBoundary]
    // outside OverflowBox makes size == hostHeight (one screen) and kills
    // long-image export.
    final hostHeight = mode == _ExportCaptureMode.slice
        ? sliceHeight
        : mediaQuery.size.height;

    final Widget themedBody;
    if (mode == _ExportCaptureMode.slice) {
      // Viewport-sized boundary: only the visible slice is rasterized.
      themedBody = ClipRect(
        child: RepaintBoundary(
          key: boundaryKey,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: exportWidth,
            maxWidth: exportWidth,
            minHeight: 0,
            maxHeight: StatisticsShareService._maxExportLogicalHeight,
            child: Transform.translate(
              offset: Offset(0, -sliceTop),
              child: SizedBox(width: exportWidth, child: document),
            ),
          ),
        ),
      );
    } else {
      // Full document boundary lives under OverflowBox so its height is the
      // intrinsic document height, not the screen height.
      themedBody = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: exportWidth,
        maxWidth: exportWidth,
        minHeight: 0,
        maxHeight: StatisticsShareService._maxExportLogicalHeight,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(width: exportWidth, child: document),
        ),
      );
    }

    return Positioned(
      left: 0,
      top: 0,
      width: exportWidth,
      height: hostHeight,
      child: IgnorePointer(
        child: ExcludeSemantics(
          // Non-zero opacity so the subtree still paints (0 skips paint).
          // Barrier above hides this from the user.
          child: Opacity(
            opacity: 0.02,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(exportWidth, hostHeight),
                textScaler: mediaQuery.textScaler,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                platformBrightness: Brightness.light,
              ),
              child: Theme(
                data: theme,
                child: Directionality(
                  textDirection: textDirection,
                  child: Material(color: scaffoldColor, child: themedBody),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
