import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../logging/app_debug_log.dart';

/// 把一棵 widget 树离屏光栅化成 PNG 的通用机制。
///
/// 原本长在「课程统计导出」里，课表图片分享要复用同一套坑位处理，因此抽成
/// 中性件：调用方只提供文档 widget 与宽度，其余（挂载宿主、量高、切片、
/// 拼接、后台编码）都由这里负责。
///
/// 几条不可省的约束，改这里前先读：
/// * **宽度必须给死**。宿主用 `OverflowBox` 固定宽度，文档里的
///   `LayoutBuilder` 才拿得到有限宽度；给无限宽会让按宽度均分的网格
///   （如课表日列宽）算出 `Infinity` 直接崩。
/// * **`RepaintBoundary` 必须在 `OverflowBox` 里面**，否则它的尺寸等于宿主
///   视口（一屏）而不是文档本身的固有高度，长图导出静默失效。
/// * **必须合成到不透明底色上**，否则文档里的透明区域分享出去是黑块。
/// * 宿主用 `Opacity(0.02)` 而不是 0 —— 0 会跳过绘制，捕获到空图。
/// * **光栅化前会等文档里的图片解码完**（见 [precacheDocumentImages]）：
///   `Image` 异步解析，固定帧数等不到它，拍出来就是空白。但这一步只能等
///   **已经在树上的 `Image`** —— 会先渲染占位盒的懒加载控件（如没预热过的
///   `BundledAssetImage`）首帧根本不在树里，等也等不到。文档用的图必须建树
///   首帧就可解析：预热进 `BundledAssets`，或直接 `Image.memory`。
/// * 这个宿主**采不到实时底面**：`BackdropFilter` / 液态折射在离屏
///   opacity 层下拿不到背后内容，只会塌成一层裸 tint。因此进这里的文档
///   不要保留实时玻璃，卡片材质请走实底。
abstract final class ImageExportCapture {
  /// 分享密度：在清晰度与主线程绘制成本之间取平衡。
  static const double preferredPixelRatio = 2.5;

  /// 保守的 GPU 纹理边长上限，避免中端安卓机型纹理过大。
  static const double maxTextureEdge = 4096;

  /// 布局稳定所需的帧数（不用 sleep —— sleep 体感像卡死）。
  static const int settleFrameCount = 2;

  /// 等文档内图片解码的上限。超时只放弃这几张图，不中断整次导出。
  static const Duration _imagePrecacheTimeout = Duration(seconds: 5);

  /// 文档逻辑高度上限，超过即切片。
  static const double maxExportLogicalHeight = 30000;

  /// 离屏量高/光栅化期间的转圈遮罩。
  static const Color _barrierScrimColor = Color(0x61000000);
  static const Color _barrierShellColor = Color(0xF5FFFFFF);

  /// 把 [document] 渲染成 PNG 字节；失败返回 null（调用方负责提示）。
  ///
  /// [exportWidth] 是文档的逻辑宽度（图片像素宽 = 该值 × [preferredPixelRatio]）。
  /// [scaffoldColor] 同时作为主题底色与透明区域的不透明填充色，请传不透明色。
  static Future<Uint8List?> captureToPng({
    required OverlayState overlayState,
    required MediaQueryData mediaQuery,
    required ThemeData theme,
    required TextDirection textDirection,
    required double exportWidth,
    required Color scaffoldColor,
    required Widget document,
    String debugLabel = 'ImageExport',
  }) async {
    final session = _ExportCaptureSession(
      exportWidth: exportWidth,
      mediaQuery: mediaQuery,
      theme: theme,
      textDirection: textDirection,
      scaffoldColor: scaffoldColor,
      document: document,
    );

    late OverlayEntry captureEntry;
    captureEntry = OverlayEntry(builder: (_) => session.build());
    // 先插捕获宿主，再盖遮罩 —— 用户只会看到转圈。
    overlayState.insert(captureEntry);

    final barrierEntry = OverlayEntry(builder: _buildBarrier);
    overlayState.insert(barrierEntry);
    // 先让遮罩画一帧，重活开始后界面才不会像冻住。
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      // 图片必须先落地：`Image` 是异步解码的，文档首帧里它往往还是空盒子。
      await precacheDocumentImages(session.boundaryKey);

      // 第一趟：量文档的完整逻辑高度（同一个宿主，中途不拆装）。
      session.configureFullDocument();
      captureEntry.markNeedsBuild();
      final measuredSize = await _waitAndReadSize(session.boundaryKey);
      if (measuredSize == null ||
          measuredSize.width <= 0 ||
          measuredSize.height <= 0) {
        appDebugLog(debugLabel, 'Failed to measure export document');
        return null;
      }

      const pixelRatio = preferredPixelRatio;
      final fullPixelHeight = measuredSize.height * pixelRatio;
      const maxSlicePixelHeight = maxTextureEdge - 16;

      appDebugLog(
        debugLabel,
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

      // 超高内容：复用同一个宿主，只挪切片窗口。
      const sliceLogicalHeight = maxSlicePixelHeight / pixelRatio;
      final sliceCount = (measuredSize.height / sliceLogicalHeight).ceil();
      appDebugLog(
        debugLabel,
        'Tall export slices=$sliceCount '
            'sliceH=${sliceLogicalHeight.toStringAsFixed(1)}',
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
        // 让出帧，遮罩的转圈才能在两片重活之间动起来。
        await Future<void>.delayed(Duration.zero);
        await _settleFrames();

        final sliceImage = await _rasterizeKeyToRgba(
          session.boundaryKey,
          pixelRatio,
          opaqueFill: scaffoldColor,
        );
        if (sliceImage == null) {
          appDebugLog(debugLabel, 'Slice $sliceIndex capture failed');
          return null;
        }
        decodedSlices.add(sliceImage);
      }

      if (decodedSlices.isEmpty) {
        return null;
      }

      // 在主 isolate 上拼接（img.Image 不能可靠跨 isolate 传递），
      // 再拿到 UI 线程外编码 PNG。
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

  /// 分享图固定走亮色主题：暗色卡片发到微信等浅底场景会糊成一片。
  static ThemeData lightExportThemeOf(BuildContext context) {
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

  static Widget _buildBarrier(BuildContext context) {
    return const Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: _barrierScrimColor,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _barrierShellColor,
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
  }

  static Future<void> _settleFrames() async {
    for (var frameIndex = 0; frameIndex < settleFrameCount; frameIndex++) {
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

  /// 收集文档子树里所有 [Image] 的 provider（`RepaintBoundary` 之外的宿主
  /// 外壳不在遍历范围内）。
  static List<ImageProvider> _imageProvidersIn(BuildContext rootContext) {
    final providers = <ImageProvider>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Image) {
        providers.add(widget.image);
      }
      element.visitChildren(visit);
    }

    rootContext.visitChildElements(visit);
    return providers;
  }

  /// 等 [rootKey] 所指子树里的图片全部解码完。
  ///
  /// 取 key 而不是 [BuildContext]：调用点在 `await` 之后，直接把 context
  /// 递进去会触发 `use_build_context_synchronously`（context 只在这里取、
  /// 且取出后紧跟着用，天然没有跨异步间隙的问题）。
  ///
  /// 导出流程里由 [captureToPng] 调用；标 `@visibleForTesting` 是为了让测试
  /// 能绕开「离屏宿主 + 帧调度」单独验这条契约。
  ///
  /// [Image] 是异步解析的：文档首帧建好时它往往还只是个空盒子，解码结果要等
  /// 后续帧才回来。而本流程只按固定帧数等待（[settleFrameCount] + 量高那几
  /// 帧），量高与光栅化都可能赶在解码之前 —— 拍出来的图里那张图就是空白。
  /// 课表分享图底部的品牌 logo 就踩过这个坑（同一个 provider 已被图片缓存
  /// 认定为 in-flight，这里只是等它完成；落地后文档下一帧就能直接画出来）。
  ///
  /// 缺资源、解码失败、超时都只让这几张图空着，不中断整次导出：一张 logo
  /// 不该让整张图出不来。失败原因进日志。
  @visibleForTesting
  static Future<void> precacheDocumentImages(GlobalKey rootKey) async {
    final rootContext = rootKey.currentContext;
    if (rootContext == null) {
      return;
    }
    final providers = _imageProvidersIn(rootContext);
    if (providers.isEmpty) {
      return;
    }

    await Future.wait(
      providers.map(
        (provider) => precacheImage(
          provider,
          rootContext,
          onError: (error, stackTrace) {
            appDebugLog('ImageExport', 'Image precache failed: $error');
          },
        ),
      ),
    ).timeout(_imagePrecacheTimeout, onTimeout: () => const <void>[]);
  }

  /// `RepaintBoundary` → 不透明 RGBA [img.Image]（不做 PNG 中转）。
  static Future<img.Image?> _rasterizeKeyToRgba(
    GlobalKey key,
    double pixelRatio, {
    required Color opaqueFill,
  }) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    // release 下绝不能读 [RenderObject.debugNeedsPaint]（会抛 LateError）。
    final snapshot = await renderObject.toImage(pixelRatio: pixelRatio);
    ui.Image? composited;
    try {
      composited = await _compositeOntoOpaque(snapshot, opaqueFill);
      final byteData = await composited.toByteData();
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
      return Uint8List.fromList(img.encodePng(copy));
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

/// 一次导出共用的可变捕获宿主配置（整个导出只挂一个 OverlayEntry）。
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
    // 宿主视口可能只有一屏高；文档本身必须从 `OverflowBox` **里面**测量与
    // 捕获。把 [RepaintBoundary] 放到 `OverflowBox` 外面会让 size 等于宿主
    // 高度（一屏），长图导出直接失效。
    final hostHeight = mode == _ExportCaptureMode.slice
        ? sliceHeight
        : mediaQuery.size.height;

    final Widget themedBody;
    if (mode == _ExportCaptureMode.slice) {
      // 视口大小的边界：只光栅化可见的那一片。
      themedBody = ClipRect(
        child: RepaintBoundary(
          key: boundaryKey,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: exportWidth,
            maxWidth: exportWidth,
            minHeight: 0,
            maxHeight: ImageExportCapture.maxExportLogicalHeight,
            child: Transform.translate(
              offset: Offset(0, -sliceTop),
              child: SizedBox(width: exportWidth, child: document),
            ),
          ),
        ),
      );
    } else {
      // 完整文档的 boundary 放在 `OverflowBox` 下面，高度才取文档固有高度
      // 而不是屏幕高度。
      themedBody = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: exportWidth,
        maxWidth: exportWidth,
        minHeight: 0,
        maxHeight: ImageExportCapture.maxExportLogicalHeight,
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
          // 透明度非 0，子树才会继续绘制（0 会跳过绘制）。
          // 上面盖着遮罩，用户看不到它。
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
