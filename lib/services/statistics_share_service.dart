import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../logging/app_debug_log.dart';
import '../l10n/service_message_localizer.dart';
import '../models/statistics_export_options.dart';
import '../models/statistics_models.dart';
import '../utils/app_toast.dart';
import '../widgets/statistics/statistics_export_document.dart';

/// Captures course statistics as a long PNG and opens the share sheet.
class StatisticsShareService {
  StatisticsShareService._();

  /// Target capture density for share-quality long images.
  static const double _preferredPixelRatio = 3.0;

  /// Stay under common Android GPU max texture sizes when capturing one slice.
  static const double _maxTextureEdge = 8192;

  static const int _settleFrameCount = 5;
  static const double _maxExportLogicalHeight = 30000;

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
    final theme = Theme.of(context);
    final textDirection = Directionality.of(context);

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
      theme: theme,
      textDirection: textDirection,
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
          'ratio=$pixelRatio pxH≈${fullPixelHeight.round()}',
    );

    // Short enough: single high-DPI capture.
    if (fullPixelHeight <= maxSlicePixelHeight) {
      return _captureSingleShot(
        overlayState: overlayState,
        exportWidth: exportWidth,
        mediaQuery: mediaQuery,
        theme: theme,
        textDirection: textDirection,
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
        theme: theme,
        textDirection: textDirection,
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
    // Transparent fill; each slice already has the full background painted.
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    var offsetY = 0;
    for (final slice in decodedSlices) {
      img.compositeImage(canvas, slice, dstY: offsetY);
      offsetY += slice.height;
    }

    return Uint8List.fromList(img.encodePng(canvas, level: 6));
  }

  static Future<Size?> _measureExportDocument({
    required OverlayState overlayState,
    required double exportWidth,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required TextDirection textDirection,
    required Widget document,
  }) {
    final measureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _OffscreenExportHost(
          exportWidth: exportWidth,
          mediaQuery: mediaQuery,
          theme: theme,
          textDirection: textDirection,
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
    required TextDirection textDirection,
    required Widget document,
    required double pixelRatio,
  }) async {
    final captureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _OffscreenExportHost(
          exportWidth: exportWidth,
          mediaQuery: mediaQuery,
          theme: theme,
          textDirection: textDirection,
          maxHeight: _maxExportLogicalHeight,
          child: RepaintBoundary(key: captureKey, child: document),
        );
      },
    );

    overlayState.insert(entry);
    try {
      await _settleFrames();
      return _rasterizeKey(captureKey, pixelRatio);
    } finally {
      entry.remove();
    }
  }

  static Future<Uint8List?> _captureVerticalSlice({
    required OverlayState overlayState,
    required double exportWidth,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required TextDirection textDirection,
    required Widget document,
    required double sliceTop,
    required double sliceHeight,
    required double pixelRatio,
  }) async {
    final captureKey = GlobalKey();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: -(exportWidth + 64),
          top: 0,
          width: exportWidth,
          height: sliceHeight,
          child: IgnorePointer(
            child: MediaQuery(
              data: mediaQuery.copyWith(
                size: Size(exportWidth, sliceHeight),
                textScaler: mediaQuery.textScaler,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: Theme(
                data: theme,
                child: Directionality(
                  textDirection: textDirection,
                  child: Material(
                    type: MaterialType.transparency,
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
        );
      },
    );

    overlayState.insert(entry);
    try {
      await _settleFrames();
      return _rasterizeKey(captureKey, pixelRatio);
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

  static Future<Uint8List?> _rasterizeKey(
    GlobalKey key,
    double pixelRatio,
  ) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Off-screen host with finite Stack constraints and tall OverflowBox content.
class _OffscreenExportHost extends StatelessWidget {
  const _OffscreenExportHost({
    required this.exportWidth,
    required this.mediaQuery,
    required this.theme,
    required this.textDirection,
    required this.maxHeight,
    required this.child,
  });

  final double exportWidth;
  final MediaQueryData mediaQuery;
  final ThemeData theme;
  final TextDirection textDirection;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -(exportWidth + 64),
      top: 0,
      width: exportWidth,
      height: mediaQuery.size.height,
      child: IgnorePointer(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: exportWidth,
          maxWidth: exportWidth,
          minHeight: 0,
          maxHeight: maxHeight,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(exportWidth, mediaQuery.size.height),
              textScaler: mediaQuery.textScaler,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: Theme(
              data: theme,
              child: Directionality(
                textDirection: textDirection,
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(width: exportWidth, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
