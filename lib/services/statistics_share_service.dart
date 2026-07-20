import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forui/forui.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

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

  /// Target capture density for share-quality long images.
  static const double _preferredPixelRatio = 3.0;

  /// Conservative GPU texture edge so OPPO / mid-range Android stays safe.
  static const double _maxTextureEdge = 4096;

  static const int _settleFrameCount = 5;
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

    try {
      final pngBytes = await _captureExportDocumentPng(
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
    required BuildContext context,
    required StatisticsExportOptions options,
    required SemesterStats semesterStats,
    required List<Achievement> achievements,
    required List<DataStory> stories,
  }) async {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      appDebugLog('StatisticsShare', 'Overlay not found for export capture');
      return null;
    }

    final mediaQuery = MediaQuery.of(context);
    final exportWidth = mediaQuery.size.width.clamp(320.0, 420.0);
    final textDirection = Directionality.of(context);
    final exportTheme = _exportLightTheme(context);
    final exportForuiTheme = _exportLightForuiTheme(context);
    const scaffoldColor = _exportScaffoldColor;

    Widget buildDocument() {
      return StatisticsExportDocument(
        options: options,
        semesterStats: semesterStats,
        achievements: achievements,
        stories: stories,
      );
    }

    // Pass 1: measure full logical size at layout-only density.
    final measuredSize = await _measureExportDocument(
      overlayState: overlayState,
      exportWidth: exportWidth,
      mediaQuery: mediaQuery,
      theme: exportTheme,
      foruiTheme: exportForuiTheme,
      textDirection: textDirection,
      scaffoldColor: scaffoldColor,
      document: buildDocument(),
    );
    if (measuredSize == null ||
        measuredSize.width <= 0 ||
        measuredSize.height <= 0) {
      appDebugLog('StatisticsShare', 'Failed to measure export document');
      return null;
    }

    final pixelRatio = _preferredPixelRatio;
    final fullPixelHeight = measuredSize.height * pixelRatio;
    final maxSlicePixelHeight = _maxTextureEdge - 16;

    appDebugLog(
      'StatisticsShare',
      'Export measure '
          '${measuredSize.width.toStringAsFixed(1)}x'
          '${measuredSize.height.toStringAsFixed(1)} '
          'ratio=$pixelRatio pxH≈${fullPixelHeight.round()} '
          'scaffold=#${scaffoldColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
    );

    // Short enough: single high-DPI capture.
    if (fullPixelHeight <= maxSlicePixelHeight) {
      return _captureSingleShot(
        overlayState: overlayState,
        exportWidth: exportWidth,
        mediaQuery: mediaQuery,
        theme: exportTheme,
        foruiTheme: exportForuiTheme,
        textDirection: textDirection,
        scaffoldColor: scaffoldColor,
        document: buildDocument(),
        pixelRatio: pixelRatio,
      );
    }

    // Tall content: capture vertical windows at full pixel ratio, then stitch.
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
      final slicePng = await _captureVerticalSlice(
        overlayState: overlayState,
        exportWidth: exportWidth,
        mediaQuery: mediaQuery,
        theme: exportTheme,
        foruiTheme: exportForuiTheme,
        textDirection: textDirection,
        scaffoldColor: scaffoldColor,
        document: buildDocument(),
        sliceTop: sliceTop,
        sliceHeight: thisSliceHeight,
        pixelRatio: pixelRatio,
      );
      if (slicePng == null) {
        appDebugLog('StatisticsShare', 'Slice $sliceIndex capture failed');
        return null;
      }
      final decoded = img.decodePng(slicePng);
      if (decoded == null) {
        appDebugLog('StatisticsShare', 'Slice $sliceIndex decode failed');
        return null;
      }
      decodedSlices.add(decoded);
    }

    if (decodedSlices.isEmpty) {
      return null;
    }

    final stitchedWidth = decodedSlices
        .map((slice) => slice.width)
        .reduce(math.max);
    final stitchedHeight = decodedSlices.fold<int>(
      0,
      (sum, slice) => sum + slice.height,
    );
    final canvas = img.Image(width: stitchedWidth, height: stitchedHeight);
    // Opaque scaffold fill: any unpainted slice edge stays light gray, not black.
    img.fill(canvas, color: _toRgba8(scaffoldColor));

    var offsetY = 0;
    for (final slice in decodedSlices) {
      img.compositeImage(canvas, slice, dstY: offsetY);
      offsetY += slice.height;
    }

    return Uint8List.fromList(img.encodePng(canvas, level: 6));
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

  /// Light Forui palette for export (Hyperos dark branches never run).
  static FThemeData _exportLightForuiTheme(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return context.theme;
    }
    return FThemes.neutral.light.touch;
  }

  static Future<Size?> _measureExportDocument({
    required OverlayState overlayState,
    required double exportWidth,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required FThemeData foruiTheme,
    required TextDirection textDirection,
    required Color scaffoldColor,
    required Widget document,
  }) {
    final measureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _ExportCaptureHost(
          exportWidth: exportWidth,
          hostHeight: mediaQuery.size.height,
          mediaQuery: mediaQuery,
          theme: theme,
          foruiTheme: foruiTheme,
          textDirection: textDirection,
          scaffoldColor: scaffoldColor,
          maxHeight: _maxExportLogicalHeight,
          child: RepaintBoundary(key: measureKey, child: document),
        );
      },
    );

    overlayState.insert(entry);
    return _waitAndReadSize(measureKey).whenComplete(entry.remove);
  }

  static Future<Uint8List?> _captureSingleShot({
    required OverlayState overlayState,
    required double exportWidth,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required FThemeData foruiTheme,
    required TextDirection textDirection,
    required Color scaffoldColor,
    required Widget document,
    required double pixelRatio,
  }) async {
    final captureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _ExportCaptureHost(
          exportWidth: exportWidth,
          hostHeight: mediaQuery.size.height,
          mediaQuery: mediaQuery,
          theme: theme,
          foruiTheme: foruiTheme,
          textDirection: textDirection,
          scaffoldColor: scaffoldColor,
          maxHeight: _maxExportLogicalHeight,
          child: RepaintBoundary(key: captureKey, child: document),
        );
      },
    );

    overlayState.insert(entry);
    try {
      await _settleFrames();
      return _rasterizeKey(captureKey, pixelRatio, opaqueFill: scaffoldColor);
    } finally {
      entry.remove();
    }
  }

  static Future<Uint8List?> _captureVerticalSlice({
    required OverlayState overlayState,
    required double exportWidth,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required FThemeData foruiTheme,
    required TextDirection textDirection,
    required Color scaffoldColor,
    required Widget document,
    required double sliceTop,
    required double sliceHeight,
    required double pixelRatio,
  }) async {
    final captureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        // Boundary must be constrained to [sliceHeight] so each capture is a
        // viewport window, not the full document (which would break stitching).
        return Positioned(
          left: 0,
          top: 0,
          width: exportWidth,
          height: sliceHeight,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                // Non-zero so the subtree still paints (0 skips paint entirely).
                opacity: 0.01,
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    size: Size(exportWidth, sliceHeight),
                    textScaler: mediaQuery.textScaler,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                    platformBrightness: Brightness.light,
                  ),
                  child: Theme(
                    data: theme,
                    child: FTheme(
                      data: foruiTheme,
                      child: Directionality(
                        textDirection: textDirection,
                        child: Material(
                          color: scaffoldColor,
                          child: ClipRect(
                            child: RepaintBoundary(
                              key: captureKey,
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: exportWidth,
                                maxWidth: exportWidth,
                                minHeight: 0,
                                maxHeight: _maxExportLogicalHeight,
                                child: Transform.translate(
                                  offset: Offset(0, -sliceTop),
                                  child: SizedBox(
                                    width: exportWidth,
                                    child: document,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(entry);
    try {
      await _settleFrames();
      return _rasterizeKey(captureKey, pixelRatio, opaqueFill: scaffoldColor);
    } finally {
      entry.remove();
    }
  }

  static Future<void> _settleFrames() async {
    for (var frameIndex = 0; frameIndex < _settleFrameCount; frameIndex++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 20));
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

  /// Rasterize [RepaintBoundary] then composite onto an opaque scaffold fill.
  ///
  /// Unpainted pixels from [toImage] are transparent black (0,0,0,0); without
  /// this step, share previews (OPPO / WeChat) show large pure-black holes.
  static Future<Uint8List?> _rasterizeKey(
    GlobalKey key,
    double pixelRatio, {
    required Color opaqueFill,
  }) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    // Do not read [RenderObject.debugNeedsPaint]: in release builds that
    // getter throws LateInitializationError (assert-only assignment).
    // Callers already settle frames before rasterizing.
    final snapshot = await renderObject.toImage(pixelRatio: pixelRatio);
    ui.Image? composited;
    try {
      composited = await _compositeOntoOpaque(snapshot, opaqueFill);
      final byteData = await composited.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
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

  static img.ColorRgba8 _toRgba8(Color color) {
    return img.ColorRgba8(
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
      (color.a * 255.0).round().clamp(0, 255),
    );
  }
}

/// On-screen (but invisible) host so Impeller still composites the layer.
///
/// Completely off-screen negative [Positioned.left] can skip rasterization on
/// some ColorOS / Android 16 devices; keep the host in the viewport and hide
/// it with near-zero [Opacity] instead.
///
/// Do not use [Opacity] of `0`: Flutter skips painting fully transparent
/// subtrees, which leaves [RepaintBoundary.toImage] empty. Parent opacity
/// does not multiply into a child boundary's [toImage] result.
class _ExportCaptureHost extends StatelessWidget {
  const _ExportCaptureHost({
    required this.exportWidth,
    required this.hostHeight,
    required this.mediaQuery,
    required this.theme,
    required this.foruiTheme,
    required this.textDirection,
    required this.scaffoldColor,
    required this.maxHeight,
    required this.child,
  });

  final double exportWidth;
  final double hostHeight;
  final MediaQueryData mediaQuery;
  final ThemeData theme;
  final FThemeData foruiTheme;
  final TextDirection textDirection;
  final Color scaffoldColor;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: exportWidth,
      height: hostHeight,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            // Non-zero so the subtree still paints (0 skips paint entirely).
            opacity: 0.01,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: exportWidth,
              maxWidth: exportWidth,
              minHeight: 0,
              maxHeight: maxHeight,
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
                  child: FTheme(
                    data: foruiTheme,
                    child: Directionality(
                      textDirection: textDirection,
                      child: Material(
                        color: scaffoldColor,
                        child: SizedBox(width: exportWidth, child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
