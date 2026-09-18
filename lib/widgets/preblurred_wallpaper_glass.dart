import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/home_page_background.dart';
import 'course_glass_shader.dart';

/// Identity of a cached pre-blurred wallpaper.
///
/// [devicePixelRatio] participates because [logicalSigma] is converted into
/// image pixel space using it — two densities need two different bitmaps.
@immutable
class _PreblurRequest {
  const _PreblurRequest({
    required this.path,
    required this.logicalSigma,
    required this.devicePixelRatio,
  });

  final String path;
  final double logicalSigma;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PreblurRequest &&
          other.path == path &&
          other.logicalSigma == logicalSigma &&
          other.devicePixelRatio == devicePixelRatio;

  @override
  int get hashCode => Object.hash(path, logicalSigma, devicePixelRatio);
}

double _screenPhysicalWidth() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) {
    return 0;
  }
  return views.first.physicalSize.width;
}

/// Builds and caches a **pre-blurred** full-screen wallpaper for dense glass cards.
///
/// Why: a live [BackdropFilter] / FakeGlass on 20–50 course cards re-samples the
/// backdrop every frame while the week pager moves — measured ~14 FPS on
/// mid-range MediaTek. Sampling one cached blurred bitmap is cheap and keeps
/// frost **identical while scrolling** (no quality flip).
///
/// The blurred result is kept as a [ui.Image] and painted directly. Encoding it
/// to PNG and re-decoding through an [ImageProvider] would cost a synchronous
/// encode plus a third copy of the wallpaper in memory.
class PreblurredWallpaperCache {
  PreblurredWallpaperCache._();
  static final PreblurredWallpaperCache instance = PreblurredWallpaperCache._();

  _PreblurRequest? _key;
  ui.Image? _image;

  /// In-flight builds. The future deliberately carries **no** [ui.Image]
  /// handle: it only signals 'the cache has (or has not) published this
  /// request'. Every caller clones [_image] for itself afterwards, so N
  /// concurrent waiters can never end up sharing one disposable handle.
  final Map<_PreblurRequest, Future<void>> _inFlight = {};

  /// Bumped by [evict] so a build that is already running cannot publish a
  /// stale bitmap afterwards.
  int _generation = 0;

  /// Blurred wallpaper for the last satisfied request, if any.
  ui.Image? get image => _image;

  /// Half-resolution decode of the wallpaper, Gaussian-blurred once.
  ///
  /// [logicalSigma] is the blur radius as it should appear **on screen**, in
  /// logical pixels, so it matches the chrome band's [BackdropFilter] sigma.
  Future<ui.Image?> obtain({
    required String? path,
    required double logicalSigma,
    required double devicePixelRatio,
  }) {
    if (path == null ||
        path.isEmpty ||
        logicalSigma <= 0 ||
        devicePixelRatio <= 0) {
      return Future<ui.Image?>.value();
    }
    final request = _PreblurRequest(
      path: path,
      logicalSigma: logicalSigma,
      devicePixelRatio: devicePixelRatio,
    );
    if (_key == request && _image != null) {
      // Hand out a clone: the caller owns its handle, so a later evict() can
      // dispose the cache's copy without invalidating a widget that is still
      // painting. `clone()` is refcounted and shares the same GPU buffer.
      return Future<ui.Image?>.value(_image!.clone());
    }
    final pending = _inFlight[request];
    Future<void> settled;
    if (pending != null) {
      settled = pending;
    } else {
      final built = _build(request);
      _inFlight[request] = built;
      settled = built.whenComplete(() {
        if (_inFlight[request] == built) {
          _inFlight.remove(request);
        }
      });
    }
    // Hand out a fresh clone of the cache-owned bitmap to *every* caller.
    // A Dart future broadcasts the SAME instance to all listeners; handing
    // that one instance to callers who each believe they exclusively own it
    // (the startup primer disposes its copy, a page scope swaps and disposes
    // its copy on the next sync) released the texture under another painter's
    // feet — the debug crash `Canvas.drawImageRect:
    // assert(!image.debugDisposed)` on glass card fills.
    return settled.then((_) {
      final image = _image;
      return (_key == request && image != null) ? image.clone() : null;
    });
  }

  /// Decodes + blurs [request] and publishes the result as the cache-owned
  /// canonical bitmap in [_image].
  ///
  /// The future resolves with no payload: callers get their own handle by
  /// cloning [_image] inside [obtain], so this future is safe to share across
  /// any number of waiters and never leaks or double-disposes a texture.
  Future<void> _build(_PreblurRequest request) async {
    final generation = _generation;
    ui.Image? source;
    ui.Image? blurred;
    try {
      final decodeWidth = (homePageBackdropDecodeWidth() * 0.55).round().clamp(
        480,
        1440,
      );
      source = await _decode(request.path, decodeWidth);
      if (source == null) {
        return;
      }
      // The blur runs in the decoded bitmap's pixel space, which is smaller
      // than the screen and then upscaled back to full size. Convert the
      // desired on-screen sigma into that space so the perceived frost
      // strength remains stable across screen densities.
      final physicalWidth = _screenPhysicalWidth();
      final downscale = physicalWidth <= 0 ? 1.0 : source.width / physicalWidth;
      final imageSigma =
          (request.logicalSigma * request.devicePixelRatio * downscale).clamp(
            0.5,
            40.0,
          );

      blurred = await _blur(source, imageSigma);
      if (blurred == null) {
        return;
      }

      if (generation != _generation) {
        // Evicted while we were building; finally disposes [blurred].
        return;
      }
      if (_key == request && _image != null) {
        // An identical request won the race; finally disposes [blurred].
        return;
      }

      _image?.dispose();
      _image = blurred;
      _key = request;
      blurred = null; // Ownership moved to the cache.
    } catch (error, stackTrace) {
      debugPrint('PreblurredWallpaperCache failed: $error\n$stackTrace');
    } finally {
      source?.dispose();
      blurred?.dispose();
    }
  }

  /// 背景图路径 → 解码用位图提供者；文件不存在时返回 null。
  ///
  /// 内置壁纸（代码渲染、无磁盘文件）已于 2026-09-13 随该功能整体移除，
  /// 这里只剩图片壁纸一条解码路径。
  ImageProvider? _providerFor(String key, int decodeWidth) {
    if (!File(key).existsSync()) {
      return null;
    }
    return ResizeImage(FileImage(File(key)), width: decodeWidth);
  }

  Future<ui.Image?> _decode(String path, int decodeWidth) async {
    final provider = _providerFor(path, decodeWidth);
    if (provider == null) {
      return null;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    var listenerAttached = false;

    void removeListener() {
      if (!listenerAttached) {
        return;
      }
      stream.removeListener(listener);
      listenerAttached = false;
    }

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image.clone());
        }
        removeListener();
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        removeListener();
      },
    );
    listenerAttached = true;
    try {
      stream.addListener(listener);
      return await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      removeListener();
    }
  }

  Future<ui.Image?> _blur(ui.Image source, double sigma) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      );
    canvas.drawImage(source, Offset.zero, paint);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
    }
  }

  void evict([String? path]) {
    if (path != null && path.isNotEmpty && _key?.path != path) {
      return;
    }
    _generation++;
    _image?.dispose();
    _image = null;
    _key = null;
    _inFlight.clear();
  }
}

/// Resolves the sigma the shared pre-blur wallpaper bitmap is built with,
/// from pure settings inputs (no [BuildContext]).
///
/// Single source of truth for 'which [PreblurredWallpaperCache] entry will the
/// home page actually request', so the cold-start primer can warm the exact
/// same bitmap ahead of the first frame. Mirrors the in-build resolution in
/// timetable_screen's homePreblurSigma closure: gaussian course cards define
/// the sigma first, then the liquid-glass chrome tuning (clamped to the same
/// 2-24 range), otherwise the frosted sheet sigma.
double resolveHomePreblurSigma({
  required bool gaussianCardsDrive,
  required bool liquidGlassChrome,
  required double sheetBlurSigma,
  required double? liquidGlassTunedBlur,
}) {
  if (gaussianCardsDrive) {
    return sheetBlurSigma;
  }
  if (liquidGlassChrome && liquidGlassTunedBlur != null) {
    return liquidGlassTunedBlur.clamp(2.0, 24.0).toDouble();
  }
  return sheetBlurSigma;
}

/// Pre-blurred wallpaper handed to course-card glass fills.
@immutable
class PreblurredWallpaperData {
  const PreblurredWallpaperData({
    required this.image,
    required this.pageController,
    required this.followsPager,
    this.repaint,
    this.revision = 0,
  });

  final ui.Image image;

  /// Active horizontal pager driving card motion over the wallpaper.
  ///
  /// On the home week grid this is the week [PageController]; in day view it is
  /// the day agenda pager. When [followsPager] is false the fill listens to
  /// this controller so a screen-fixed wallpaper is re-sampled every frame.
  final PageController? pageController;

  /// Whether the wallpaper itself slides with [pageController].
  ///
  /// When true the wallpaper and the cards move together (home week + "背景随
  /// 周次滑动"), so a card's sample is constant during a slide. When false the
  /// wallpaper is screen-fixed and the sample has to be recomputed as cards
  /// move — including day-view swipes, where the week pager is locked.
  final bool followsPager;

  /// Extra per-frame repaint driver for card motion the pager cannot see.
  ///
  /// The fill re-reads its screen position only when told to repaint. The
  /// day-view open/close ramp moves cards via ancestor Align/Transform — no
  /// scroll happens, so without this the frost texture is carried along with
  /// the card instead of staying locked to the wallpaper.
  final Listenable? repaint;

  final int revision;
}

/// Provides a pre-blurred wallpaper to course-card glass fills.
class PreblurredWallpaperScope extends StatefulWidget {
  const PreblurredWallpaperScope({
    required this.wallpaperPath,
    required this.blurSigma,
    required this.child,
    this.pageController,
    this.followsPager = false,
    this.repaint,
    this.enabled = true,
    super.key,
  });

  final String? wallpaperPath;

  /// Desired on-screen blur radius in logical pixels.
  final double blurSigma;

  final PageController? pageController;
  final bool followsPager;

  /// See [PreblurredWallpaperData.repaint].
  final Listenable? repaint;
  final bool enabled;
  final Widget child;

  static PreblurredWallpaperData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PreblurredWallpaperInherited>()
        ?.data;
  }

  /// Whether [context] sits under a scope whose bitmap is still being built.
  ///
  /// Unlike [maybeOf] this does not register a dependency; it only answers the
  /// 'scope exists but data is still pending' question, so callers can avoid
  /// falling back to expensive live backdrop sampling during the few frames
  /// before the pre-blurred bitmap arrives. Live sampling over a backdrop that
  /// has not finished decoding both triggers a first-use shader compile storm
  /// and produces dirty colors from an empty buffer.
  static bool isWaitingForBitmap(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_PreblurredWallpaperInherited>();
    if (element == null) {
      return false;
    }
    final inherited = element.widget as _PreblurredWallpaperInherited;
    return inherited.data == null;
  }

  @override
  State<PreblurredWallpaperScope> createState() =>
      _PreblurredWallpaperScopeState();
}

class _PreblurredWallpaperScopeState extends State<PreblurredWallpaperScope> {
  ui.Image? _image;
  int _revision = 0;

  /// Replaced handles awaiting end-of-frame disposal. See [_replaceImage].
  final List<ui.Image> _retiredImages = <ui.Image>[];
  Object? _pending;
  String? _loadedPath;
  double? _loadedSigma;
  double? _loadedDevicePixelRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRequest();
  }

  @override
  void didUpdateWidget(covariant PreblurredWallpaperScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaperPath != widget.wallpaperPath ||
        oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.enabled != widget.enabled) {
      _syncRequest();
    }
  }

  void _syncRequest() {
    final path = widget.enabled ? widget.wallpaperPath : null;
    final sigma = widget.blurSigma;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    if (path == null || path.isEmpty || sigma <= 0) {
      _pending = null;
      _loadedPath = null;
      _loadedSigma = null;
      _loadedDevicePixelRatio = null;
      // A build always follows didChangeDependencies / didUpdateWidget, so the
      // field assignment is enough — setState here would be called during build.
      _replaceImage(null);
      return;
    }
    if (_loadedPath == path &&
        _loadedSigma == sigma &&
        _loadedDevicePixelRatio == devicePixelRatio) {
      return;
    }
    _loadedPath = path;
    _loadedSigma = sigma;
    _loadedDevicePixelRatio = devicePixelRatio;

    final token = Object();
    _pending = token;
    unawaited(() async {
      final image = await PreblurredWallpaperCache.instance.obtain(
        path: path,
        logicalSigma: sigma,
        devicePixelRatio: devicePixelRatio,
      );
      if (!mounted || _pending != token) {
        // Superseded or unmounted: nobody will own this clone, so release it.
        image?.dispose();
        return;
      }
      setState(() {
        _replaceImage(image);
        _revision++;
      });
    }());
  }

  /// Swaps the owned image handle, retiring the previous clone for disposal
  /// once the current frame has finished painting.
  ///
  /// The cache hands out `clone()`s, so this state owns what it holds and must
  /// release it — otherwise every wallpaper / sigma change leaks a full-screen
  /// bitmap handle. Disposal is deferred because render objects that still
  /// hold the previous handle may repaint one last time in this very frame
  /// (listener-driven `markNeedsPaint` can land between this swap and the
  /// dependent rebuild); painting a disposed texture crashes in
  /// [Canvas.drawImageRect].
  void _replaceImage(ui.Image? next) {
    final previous = _image;
    if (identical(previous, next)) {
      return;
    }
    _image = next;
    if (previous != null) {
      _retiredImages.add(previous);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _disposeRetiredImages(),
      );
    }
  }

  void _disposeRetiredImages() {
    if (_retiredImages.isEmpty) {
      return;
    }
    final retired = List<ui.Image>.of(_retiredImages);
    _retiredImages.clear();
    for (final image in retired) {
      image.dispose();
    }
  }

  @override
  void dispose() {
    _pending = null;
    _replaceImage(null);
    // This subtree is being torn down and will never paint again, so the
    // retired handles (including the one just queued) can go right away —
    // no need to wait for a frame that may never be scheduled (app paused).
    _disposeRetiredImages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return _PreblurredWallpaperInherited(
      data: image == null
          ? null
          : PreblurredWallpaperData(
              image: image,
              pageController: widget.pageController,
              followsPager: widget.followsPager,
              repaint: widget.repaint,
              revision: _revision,
            ),
      child: widget.child,
    );
  }
}

class _PreblurredWallpaperInherited extends InheritedWidget {
  const _PreblurredWallpaperInherited({
    required this.data,
    required super.child,
  });

  final PreblurredWallpaperData? data;

  @override
  bool updateShouldNotify(covariant _PreblurredWallpaperInherited oldWidget) {
    return data?.revision != oldWidget.data?.revision ||
        data?.image != oldWidget.data?.image ||
        data?.followsPager != oldWidget.data?.followsPager ||
        data?.repaint != oldWidget.data?.repaint ||
        data?.pageController != oldWidget.data?.pageController;
  }
}

/// Marks a week page so glass fills inside it can align to the wallpaper
/// instance that slides with that page.
class PreblurredWallpaperPage extends InheritedWidget {
  const PreblurredWallpaperPage({
    required this.pageIndex,
    required super.child,
    super.key,
  });

  final int pageIndex;

  static int? maybeIndexOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PreblurredWallpaperPage>()
        ?.pageIndex;
  }

  @override
  bool updateShouldNotify(covariant PreblurredWallpaperPage oldWidget) {
    return pageIndex != oldWidget.pageIndex;
  }
}

/// Cover-fitted destination rect of the pre-blurred wallpaper in screen space.
///
/// Left edge is [wallpaperOriginX] (0 when screen-fixed; page origin when the
/// wallpaper slides with the week pager). Glass fills paint this full dest and
/// rely on their [ClipRRect] as a moving window — never a per-card source crop
/// that clamps at the bitmap edge (that freezes frost under near-full-width
/// day-view cards after a few pixels of drag).
///
/// Returns [Rect.zero] when the inputs cannot produce a sample.
@visibleForTesting
Rect preblurredWallpaperCoverDestRect({
  required Size imageSize,
  required Size screenSize,
  required double wallpaperOriginX,
}) {
  if (imageSize.isEmpty || screenSize.isEmpty) {
    return Rect.zero;
  }
  final scale = math.max(
    screenSize.width / imageSize.width,
    screenSize.height / imageSize.height,
  );
  if (scale <= 0 || !scale.isFinite) {
    return Rect.zero;
  }
  final destLeft =
      wallpaperOriginX + (screenSize.width - imageSize.width * scale) / 2;
  final destTop = (screenSize.height - imageSize.height * scale) / 2;
  return Rect.fromLTWH(
    destLeft,
    destTop,
    imageSize.width * scale,
    imageSize.height * scale,
  );
}

/// Legacy helper: image-pixel slice under a box for unit tests.
///
/// Prefer [preblurredWallpaperCoverDestRect] + clip for painting. This mapping
/// is unclamped so tests can assert continuous parallax as cards slide.
@visibleForTesting
Rect preblurredWallpaperSourceRect({
  required Size imageSize,
  required Size screenSize,
  required Size boxSize,
  required Offset globalOffset,
  required double wallpaperOriginX,
}) {
  final dest = preblurredWallpaperCoverDestRect(
    imageSize: imageSize,
    screenSize: screenSize,
    wallpaperOriginX: wallpaperOriginX,
  );
  if (dest.isEmpty || boxSize.isEmpty) {
    return Rect.zero;
  }
  final scale = dest.width / imageSize.width;
  if (scale <= 0 || !scale.isFinite) {
    return Rect.zero;
  }
  return Rect.fromLTWH(
    (globalOffset.dx - dest.left) / scale,
    (globalOffset.dy - dest.top) / scale,
    boxSize.width / scale,
    boxSize.height / scale,
  );
}

/// Paints the pre-blurred wallpaper aligned to the wallpaper the user sees.
///
/// Must sit inside a clip (e.g. [ClipRRect]) so only the card region shows.
/// The alignment is read from the render transform at paint time, so the frost
/// never lags a frame behind the card and no rebuilds happen while paging.
///
/// [glass] 非 null 时走「液态玻璃」：同一份共享预模糊位图先过一遍折射着色器
/// 再上屏（边缘按圆角 SDF 把采样点朝外推开 + 叠染色 + 叠受光边缘高光）。
/// 着色器没就绪（后端不支持 / 资产缺失 / 测试环境）时自动回落成直接贴图 +
/// 一层染色 —— 也就是「高斯磨砂」的外观，不会破相。
class PreblurredWallpaperAlignedFill extends LeafRenderObjectWidget {
  const PreblurredWallpaperAlignedFill({this.glass, super.key});

  /// 液态玻璃参数；null = 原行为（直接贴图，即高斯模糊档）。
  final CourseGlassStyle? glass;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final data = PreblurredWallpaperScope.maybeOf(context);
    return _RenderPreblurredFill(
      image: data?.image,
      screenSize: MediaQuery.sizeOf(context),
      pageController: data?.pageController,
      followsPager: data?.followsPager ?? false,
      repaint: data?.repaint,
      pageIndex: PreblurredWallpaperPage.maybeIndexOf(context),
      verticalScrollPosition: Scrollable.maybeOf(
        context,
        axis: Axis.vertical,
      )?.position,
      glass: glass,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final data = PreblurredWallpaperScope.maybeOf(context);
    (renderObject as _RenderPreblurredFill)
      ..image = data?.image
      ..screenSize = MediaQuery.sizeOf(context)
      ..followsPager = data?.followsPager ?? false
      ..pageIndex = PreblurredWallpaperPage.maybeIndexOf(context)
      ..pageController = data?.pageController
      ..repaint = data?.repaint
      ..verticalScrollPosition = Scrollable.maybeOf(
        context,
        axis: Axis.vertical,
      )?.position
      ..glass = glass;
  }
}

class _RenderPreblurredFill extends RenderBox {
  _RenderPreblurredFill({
    required this._image,
    required this._screenSize,
    required this._pageController,
    required this._followsPager,
    required this._pageIndex,
    this._repaint,
    this._verticalScrollPosition,
    CourseGlassStyle? glass,
  }) {
    // 构造期直接落字段、不走 setter：setter 里的 _syncShader 要 attached 才
    // 建着色器，此刻还没 attach，交给 attach() 统一处理。
    _glass = glass;
  }

  ui.Image? _image;
  set image(ui.Image? value) {
    if (_image == value) {
      return;
    }
    _image = value;
    markNeedsPaint();
  }

  Size _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) {
      return;
    }
    _screenSize = value;
    markNeedsPaint();
  }

  bool _followsPager;
  set followsPager(bool value) {
    if (_followsPager == value) {
      return;
    }
    _followsPager = value;
    _syncPagerListener();
    markNeedsPaint();
  }

  int? _pageIndex;
  set pageIndex(int? value) {
    if (_pageIndex == value) {
      return;
    }
    _pageIndex = value;
    markNeedsPaint();
  }

  PageController? _pageController;
  set pageController(PageController? value) {
    if (_pageController == value) {
      return;
    }
    if (_listening) {
      _pageController?.removeListener(markNeedsPaint);
      _listening = false;
    }
    _pageController = value;
    _syncPagerListener();
    markNeedsPaint();
  }

  /// Whether [markNeedsPaint] is currently registered on [_pageController].
  bool _listening = false;

  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (_repaint == value) {
      return;
    }
    if (_listeningRepaint) {
      _repaint?.removeListener(markNeedsPaint);
      _listeningRepaint = false;
    }
    _repaint = value;
    _syncRepaintListener();
    markNeedsPaint();
  }

  /// Whether [markNeedsPaint] is currently registered on [_repaint].
  bool _listeningRepaint = false;

  ScrollPosition? _verticalScrollPosition;
  set verticalScrollPosition(ScrollPosition? value) {
    if (_verticalScrollPosition == value) {
      return;
    }
    if (_listeningVertical) {
      _verticalScrollPosition?.removeListener(markNeedsPaint);
      _listeningVertical = false;
    }
    _verticalScrollPosition = value;
    _syncVerticalScrollListener();
    markNeedsPaint();
  }

  /// Whether [markNeedsPaint] is registered on [_verticalScrollPosition].
  bool _listeningVertical = false;

  /// 液态玻璃参数。null = 直接贴图（高斯磨砂档）。
  CourseGlassStyle? _glass;
  set glass(CourseGlassStyle? value) {
    if (_glass == value) {
      return;
    }
    _glass = value;
    _syncShader();
    markNeedsPaint();
  }

  /// 本绘制对象独占的着色器实例。
  ///
  /// 由本对象创建、本对象释放。这是**所有权**上的选择（attach 建、detach 释放），
  /// 不是正确性要求：引擎把着色器交给渲染列表前会复制一份 uniform
  /// （`lib/ui/painting/fragment_shader.cc` 的 `ReusableFragmentShader::shader`），
  /// 所以只要「设 uniform → 立刻绘制」不被打断，多张卡共用一个实例也不会互相踩。
  /// 一张卡一个实例换来的好处是生命周期不用再找中央持有者，代价只是每卡一个
  /// Float32List 与一次 `fragmentShader()`。
  ui.FragmentShader? _shader;

  /// 绑定在 [_shader] 上的 uniform 槽位，跟着着色器实例一起换。
  _CourseGlassUniforms? _uniforms;

  /// 是否已把 [_onShaderReady] 挂到全局加载器上。
  bool _listeningShader = false;

  /// 期望用着色器时确保实例在手：程序已加载就立刻建，没加载就订阅加载器，
  /// 等它就绪后补一次重绘（不重建整棵树）。
  void _syncShader() {
    final wantsShader = _glass != null && attached;
    if (wantsShader) {
      if (_shader == null) {
        final loader = CourseCardGlassShader.instance;
        _shader = loader.newShader();
        if (_shader == null && !_listeningShader) {
          loader.addListener(_onShaderReady);
          _listeningShader = true;
          unawaited(loader.ensureLoaded());
        }
      }
    } else if (_shader != null) {
      _removeShaderListener();
      _shader!.dispose();
      _shader = null;
      _uniforms = null;
    }
  }

  void _onShaderReady() {
    if (!attached || _glass == null || _shader != null) {
      return;
    }
    final shader = CourseCardGlassShader.instance.newShader();
    if (shader == null) {
      return;
    }
    _removeShaderListener();
    _shader = shader;
    _uniforms = null;
    markNeedsPaint();
  }

  void _removeShaderListener() {
    if (!_listeningShader) {
      return;
    }
    CourseCardGlassShader.instance.removeListener(_onShaderReady);
    _listeningShader = false;
  }

  /// A screen-fixed wallpaper needs a fresh sample every frame while pages
  /// slide. Without this, a parent [RepaintBoundary] (or similar layer cache)
  /// can translate a stale frost texture. A wallpaper that slides *with* the
  /// pager does not need the listener: the card and the wallpaper move
  /// together, so the sample stays constant.
  void _syncPagerListener() {
    final controller = _pageController;
    final shouldListen = attached && !_followsPager && controller != null;
    if (shouldListen == _listening) {
      return;
    }
    try {
      if (shouldListen) {
        // 防御：controller 可能已在上一帧被 dispose（例如日视图控制器
        // 延迟回收与 PreblurredWallpaperScope 挂载竞态）。addListener 对
        // 已释放的 ChangeNotifier 会在 debug 下抛
        // "A PageController was used after being disposed"，这里兜底跳过。
        controller.addListener(markNeedsPaint);
      } else {
        controller?.removeListener(markNeedsPaint);
      }
    } catch (_) {
      // 已释放的控制器：放弃监听，让预模糊壁纸按静态采样绘制。
    }
    _listening = shouldListen;
  }

  /// Non-scroll card motion (day-view open/close ramp) also invalidates the
  /// sample: the fill sits in its own [RepaintBoundary], which would otherwise
  /// just translate the stale frost texture along with the moving card.
  void _syncRepaintListener() {
    final repaint = _repaint;
    final shouldListen = attached && repaint != null;
    if (shouldListen == _listeningRepaint) {
      return;
    }
    if (shouldListen) {
      repaint.addListener(markNeedsPaint);
    } else {
      repaint?.removeListener(markNeedsPaint);
    }
    _listeningRepaint = shouldListen;
  }

  /// Vertical scrolls move cards over a wallpaper that never scrolls
  /// vertically, so the sample always has to be recomputed — and this fill
  /// paints inside its own [RepaintBoundary], which would otherwise translate
  /// a stale frost texture with the card (day agenda list, week grid scroll).
  void _syncVerticalScrollListener() {
    final position = _verticalScrollPosition;
    final shouldListen = attached && position != null;
    if (shouldListen == _listeningVertical) {
      return;
    }
    if (shouldListen) {
      position.addListener(markNeedsPaint);
    } else {
      position?.removeListener(markNeedsPaint);
    }
    _listeningVertical = shouldListen;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncPagerListener();
    _syncRepaintListener();
    _syncVerticalScrollListener();
    _syncShader();
  }

  @override
  void detach() {
    // After super.detach() `attached` is false, so the sync unregisters.
    super.detach();
    _syncPagerListener();
    _syncRepaintListener();
    _syncVerticalScrollListener();
    _syncShader();
  }

  @override
  void dispose() {
    if (_listening) {
      _pageController?.removeListener(markNeedsPaint);
      _listening = false;
    }
    if (_listeningRepaint) {
      _repaint?.removeListener(markNeedsPaint);
      _listeningRepaint = false;
    }
    if (_listeningVertical) {
      _verticalScrollPosition?.removeListener(markNeedsPaint);
      _listeningVertical = false;
    }
    _removeShaderListener();
    _shader?.dispose();
    _shader = null;
    _uniforms = null;
    super.dispose();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  /// Horizontal origin of the wallpaper instance sitting behind this box.
  ///
  /// Screen-fixed wallpaper (and day view) → 0. Pager-following week wallpaper
  /// → the left edge of this card's own page, mirroring
  /// [HomePageSlidingBackdropLayer].
  double _wallpaperOriginX() {
    if (!_followsPager) {
      return 0;
    }
    final controller = _pageController;
    final index = _pageIndex;
    if (controller == null || index == null) {
      return 0;
    }
    final page =
        controllerPageOrNull(controller) ?? controller.initialPage.toDouble();
    return (index - page) * _screenSize.width;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _image;
    if (image == null || size.isEmpty) {
      return;
    }
    // Safety net: a bitmap swapped out by the scope can still be referenced
    // for the tail of one frame before updateRenderObject delivers its
    // replacement. Drawing a released native handle hits
    // `Canvas.drawImageRect`'s `assert(!image.debugDisposed)` in debug builds
    // — skip this frame instead; the next sync repaints with the new handle.
    if (kDebugMode && image.debugDisposed) {
      return;
    }
    final screen = _screenSize;
    if (screen.width <= 0 ||
        screen.height <= 0 ||
        image.width <= 0 ||
        image.height <= 0) {
      return;
    }

    // Paint the full cover-fitted wallpaper in screen space, then let the
    // parent ClipRRect act as a moving window. Reading localToGlobal each
    // paint keeps frost locked with no one-frame lag. Do **not** crop+clamp a
    // per-card source rect: near-full-width day cards pin at the bitmap edge
    // after a few pixels of drag and the frost freezes onto the card.
    final globalTopLeft = localToGlobal(Offset.zero);
    final dest = preblurredWallpaperCoverDestRect(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      screenSize: screen,
      wallpaperOriginX: _wallpaperOriginX(),
    );
    if (dest.isEmpty) {
      return;
    }

    // dest is in global/screen coords; paint is in this box's parent coords.
    final paintDest = dest.shift(offset - globalTopLeft);

    final glass = _glass;
    final shader = _shader;
    if (glass != null && shader != null) {
      _paintRefraction(context.canvas, offset, shader, glass, paintDest);
      return;
    }

    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      paintDest,
      Paint()..filterQuality = FilterQuality.low,
    );
    // 折射档但着色器还没就绪：补一层染色，外观与「高斯模糊」档一致。
    // 染色在着色器路径里是着色器自己做的，所以这里不能无条件画。
    if (glass != null) {
      context.canvas.drawRect(offset & size, Paint()..color = glass.tint);
    }
  }

  /// 液态玻璃路径：同一份共享预模糊位图，按卡片圆角做边缘折射 + 染色 + 高光。
  ///
  /// 全程只有一次 `drawRect`，没有离屏目标、没有 GPU 回读 —— 这正是「卡片数量
  /// 翻倍不改变 GPU 工作量级」的来源（对比每卡一次实时 BackdropFilter）。
  void _paintRefraction(
    Canvas canvas,
    Offset offset,
    ui.FragmentShader shader,
    CourseGlassStyle glass,
    Rect paintDest,
  ) {
    final image = _image;
    if (image == null) {
      return;
    }
    final uniforms = _uniforms ??= _CourseGlassUniforms(shader);
    final tint = glass.tint;
    final rim = glass.rimColor;
    final light = glass.lightDirection;

    // 纹理左上角在**本 box 局部坐标**里的位置：着色器按局部坐标算 uv，
    // 而 paintDest 是在父坐标系里。
    final texOrigin = paintDest.topLeft - offset;

    uniforms.size.set(size.width, size.height);
    uniforms.texOrigin.set(texOrigin.dx, texOrigin.dy);
    uniforms.texDestSize.set(paintDest.width, paintDest.height);
    uniforms.radius.set(glass.borderRadius);
    uniforms.tint.set(tint.r, tint.g, tint.b, tint.a);
    uniforms.refract.set(glass.refraction);
    uniforms.band.set(glass.refractionBand);
    uniforms.edgePow.set(glass.refractionEdgePow);
    uniforms.rimColor.set(rim.r, rim.g, rim.b);
    uniforms.rim.set(glass.rimStrength);
    uniforms.rimWidth.set(glass.rimWidth);
    uniforms.lightDir.set(light.dx, light.dy);

    shader.setImageSampler(0, image);

    // FlutterFragCoord() 取的是 drawRect 的局部坐标（Impeller 的顶点着色器直接
    // 把顶点 position 传下来），所以必须先平移到卡片原点、再从 (0,0) 画，
    // 否则坐标从 offset 起算，SDF 与圆角会整体偏移。
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    canvas.restore();
  }
}

/// 已解析的 uniform 槽位，绑在一个具体的 [ui.FragmentShader] 实例上。
///
/// 为什么不在每帧调 `shader.getUniformFloat('名字')`：那是一次引擎查询
/// （native 调用）。一屏 20~50 张卡、每帧十几处 uniform，累起来是实打实的
/// 开销；而名字只在拿到着色器实例时解析一次即可。槽位本身只是
/// 「着色器 + 下标」的轻量包装，`set` 直接写 float，没有名字查找。
///
/// 按名字取而不是硬编码 `setFloat(下标, …)`：uniform 的下标取决于
/// `course_card_glass.frag` 里的声明顺序，改一次着色器就要同步改一遍 Dart，
/// 漏改不报错、只会静默画错。名字写错会当场抛 ArgumentError。
class _CourseGlassUniforms {
  _CourseGlassUniforms(ui.FragmentShader shader)
    : size = shader.getUniformVec2('u_size'),
      texOrigin = shader.getUniformVec2('u_tex_origin'),
      texDestSize = shader.getUniformVec2('u_tex_dest_size'),
      radius = shader.getUniformFloat('u_radius'),
      tint = shader.getUniformVec4('u_tint'),
      refract = shader.getUniformFloat('u_refract'),
      band = shader.getUniformFloat('u_band'),
      edgePow = shader.getUniformFloat('u_edge_pow'),
      rimColor = shader.getUniformVec3('u_rim_color'),
      rim = shader.getUniformFloat('u_rim'),
      rimWidth = shader.getUniformFloat('u_rim_width'),
      lightDir = shader.getUniformVec2('u_light_dir');

  final ui.UniformVec2Slot size;
  final ui.UniformVec2Slot texOrigin;
  final ui.UniformVec2Slot texDestSize;
  final ui.UniformFloatSlot radius;
  final ui.UniformVec4Slot tint;
  final ui.UniformFloatSlot refract;
  final ui.UniformFloatSlot band;
  final ui.UniformFloatSlot edgePow;
  final ui.UniformVec3Slot rimColor;
  final ui.UniformFloatSlot rim;
  final ui.UniformFloatSlot rimWidth;
  final ui.UniformVec2Slot lightDir;
}

/// 校验着色器与 Dart 侧的 uniform 名字对得上，测试专用。
///
/// 名字写错时 [ui.FragmentShader.getUniformVec2] 等会当场抛 ArgumentError ——
/// 但那是**绘制期**才发生的事，一屏几十张卡一起炸在真机上才发现。这个入口让
/// 纯单元测试能在不画任何东西的前提下先把名字对一遍。
@visibleForTesting
void debugValidateCourseGlassUniforms(ui.FragmentShader shader) {
  _CourseGlassUniforms(shader);
}
