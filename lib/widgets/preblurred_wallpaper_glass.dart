import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Listenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/course_glass_tuning.dart';
import '../models/timetable_settings.dart';
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

  /// 缓存能同时持有的位图数：**首页那份**（页顶玻璃带 / 日视图摘要替身卡）与
  /// **课程卡片那份**。
  ///
  /// 为什么不是一份：课程卡片有自己一套磨砂量（`CourseGlassTuning.blurSigma`），
  /// 与首页那份可以不同。只留一份会让两个请求互相顶掉 —— 谁都命中不了快路径，
  /// 每次都要把整屏位图重烤一遍（解码 + 高斯 + 离屏渲染）。消费者就这两类，
  /// 所以上限压在 2 而不是无限：每份都是整屏 RGBA（1080 宽机约 3 MB、2160 宽屏约 12 MB）。
  static const int maxEntries = 2;

  /// 已发布位图。Dart 的 `Map` 迭代即插入序，所以 [keys] 的第一项就是最早那项。
  final Map<_PreblurRequest, ui.Image> _images = {};

  /// In-flight builds. The future deliberately carries **no** [ui.Image]
  /// handle: it only signals 'the cache has (or has not) published this
  /// request'. Every caller clones the published image for itself afterwards,
  /// so N concurrent waiters can never end up sharing one disposable handle.
  final Map<_PreblurRequest, Future<void>> _inFlight = {};

  /// Bumped by [evict] so a build that is already running cannot publish a
  /// stale bitmap afterwards.
  int _generation = 0;

  /// 「可采样的预糊位图变了」的通知出口（**发布**新图与**失效**都算）。
  ///
  /// 给「把整屏烤成一张图」的消费者用（`PreviewBakeBoundary.repaintSignal`）。
  /// 位图是**异步就绪**的（解码 → 高斯 → 离屏渲染），就绪那一刻没有任何 widget
  /// 会重建整个画面 —— 玻璃面只是在自己那个**重绘边界**里换成新图，外面看不出来。
  /// 于是预览会在换壁纸之后**一直停在旧画面上**，直到用户又碰了别的东西
  /// （真机反馈「换壁纸的时候，画面还是前帧」，2026-09-22）。订阅它就拿到了
  /// 「可以重新取景了」这个确切时刻。
  ///
  /// 单例、进程级存活：故意不提供 dispose（与 [instance] 同寿命）。
  ///
  /// 用「自增的计数」而不是 `ChangeNotifier`：`notifyListeners` 是 protected，
  /// 从外面喊不了；仓库里这类"手动喊一声"的口子一律走 `ValueNotifier` 自增
  /// （与编辑页的草稿版本号同一套）。
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);

  Listenable get changes => _changes;

  /// 已发布的位图张数（诊断与测试用）。
  @visibleForTesting
  int get entryCount => _images.length;

  /// Half-resolution decode of the wallpaper, Gaussian-blurred once.
  ///
  /// [logicalSigma] is the blur radius as it should appear **on screen**, in
  /// logical pixels, so it matches the chrome band's [BackdropFilter] sigma.
  ///
  /// **[logicalSigma] 为 0 = 「清」档**（用户口径 2026-09-22「让 0 真的清」）：
  /// 这一档不走「55% 解码 + 高斯」那条省钱路，直接出**按屏幕物理宽度解码的原图** ——
  /// 卡片把磨砂拖到 0 时，背景要的是与壁纸底图同等清晰，而不是一层极轻的糊。
  /// 与首页那张壁纸底图用同一个 provider 参数，所以通常直接命中 `ImageCache`，
  /// 不多解一次（见 [_build]）。负值非法：调用方一律过解析函数夹过。
  Future<ui.Image?> obtain({
    required String? path,
    required double logicalSigma,
    required double devicePixelRatio,
  }) {
    if (path == null ||
        path.isEmpty ||
        logicalSigma < 0 ||
        devicePixelRatio <= 0) {
      return Future<ui.Image?>.value();
    }
    final request = _PreblurRequest(
      path: path,
      logicalSigma: logicalSigma,
      devicePixelRatio: devicePixelRatio,
    );
    if (_images[request] case final cached?) {
      // Hand out a clone: the caller owns its handle, so a later evict() can
      // dispose the cache's copy without invalidating a widget that is still
      // painting. `clone()` is refcounted and shares the same GPU buffer.
      //
      // 命中时把它挪到插入序末尾，于是淘汰的总是"最久没用过"的那张 ——
      // 卡片档位在实体 / 液态之间来回切时，首页那份不会被反复踢掉。
      _images.remove(request);
      _images[request] = cached;
      return Future<ui.Image?>.value(cached.clone());
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
      final image = _images[request];
      return image?.clone();
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
    // 「清」档：不跑高斯，解码宽度也换成整屏物理宽度（理由见 [obtain]）。
    final sharp = request.logicalSigma <= 0;
    ui.Image? source;
    ui.Image? blurred;
    try {
      final decodeWidth = sharp
          ? homePageBackdropDecodeWidth()
          : (homePageBackdropDecodeWidth() * 0.55).round().clamp(480, 1440);
      source = await _decode(request.path, decodeWidth);
      if (source == null) {
        return;
      }
      if (sharp) {
        // 原图就是成品：不过高斯，也不过「55% 解码再放大」那一趟。
        // 本缓存留下的是 clone 句柄 —— 与首页壁纸底图那份解码结果共享同一份像素，
        // 所以这一档几乎不额外占显存（代价只在"多留一整个句柄"这件事上）。
        blurred = source;
        source = null;
      } else {
        // The blur runs in the decoded bitmap's pixel space, which is smaller
        // than the screen and then upscaled back to full size. Convert the
        // desired on-screen sigma into that space so the perceived frost
        // strength remains stable across screen densities.
        final physicalWidth = _screenPhysicalWidth();
        final downscale = physicalWidth <= 0
            ? 1.0
            : source.width / physicalWidth;
        final imageSigma =
            (request.logicalSigma * request.devicePixelRatio * downscale).clamp(
              0.5,
              40.0,
            );

        blurred = await _blur(source, imageSigma);
      }
      if (blurred == null) {
        return;
      }

      if (generation != _generation) {
        // Evicted while we were building; finally disposes [blurred].
        return;
      }
      if (_images[request] != null) {
        // An identical request won the race; finally disposes [blurred].
        return;
      }

      // 只顶掉**同一个请求**的旧项：别的请求（另一张图）不归这次发布管。
      _images.remove(request)?.dispose();
      _images[request] = blurred;
      blurred = null; // Ownership moved to the cache.

      // 超出上限就淘汰最早那项（只可能是另一个请求）。
      while (_images.length > maxEntries) {
        final oldest = _images.keys.first;
        _images.remove(oldest)?.dispose();
      }
      // 新位图就绪：喊一声（见 [changes]）。
      _changes.value++;
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

  /// 失效缓存。
  ///
  /// * 不传 [path]（或空串）= 全清：换壁纸、恢复默认走这条；
  /// * 传 [path] = **只清这个壁纸**的两张图；与它无关的请求（别的壁纸）不受影响。
  ///
  /// 两种情况下，**只要真有东西被清**就把世代 +1，好让正在跑的烤图任务无法在之后
  /// 把陈旧位图发布出来。世代是全局的，所以清 A 的图也会让 B 的在途任务白跑一趟 ——
  /// 代价是一次多余的重烤，换来的是不必给每个请求各记一个世代。
  void evict([String? path]) {
    if (path != null && path.isNotEmpty) {
      final hadEntries = _images.keys.any((key) => key.path == path);
      final hadInFlight = _inFlight.keys.any((key) => key.path == path);
      if (!hadEntries && !hadInFlight) {
        return;
      }
      _generation++;
      for (final key in _images.keys.toList(growable: false)) {
        if (key.path == path) {
          _images.remove(key)?.dispose();
        }
      }
      _inFlight.removeWhere((key, _) => key.path == path);
      // 可采样的位图少了一张：同样喊一声（消费者会退到兜底外观，画面确实变了）。
      _changes.value++;
      return;
    }
    if (_images.isEmpty && _inFlight.isEmpty) {
      return;
    }
    _generation++;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _inFlight.clear();
    _changes.value++;
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
///
/// ⚠️ **课程卡片 2026-09-21 起不再读这张图**（它有自己的位图，见
/// [resolveCourseCardPreblurSigma]）。所以这里的 `gaussianCardsDrive` 现在只为
/// 剩下的那一个消费者服务：日视图顶部的摘要替身卡。口径**刻章保持不变** ——
/// 去掉它会让「卡片玻璃 + 全局液态调过磨砂」时那张替身卡的磨砂悄悄变一档，
/// 那是一次没人要的观感变化。这条耦合是历史遗留，要拆得单独评估。
/// 预糊位图的 sigma 上限（逻辑 px）：两条路共用 —— 烤图成本与「取景错位」都随它涨。
///
/// 面板里卡片那根「磨砂强度」滑杆的上限也取它（编辑页 `_glassSliderTiles` 的
/// `blurSigmaMax`）：滑杆能拖到哪、出图就认到哪，别再长出「拖了没变化」的死区。
const double kPreblurMaxSigma = 24;

/// 首页那份位图的 sigma 下限：再小看不出糊（首页那条路上 0 是「不烤」）。
///
/// **卡片那份没有这个下限** —— 卡片的 0 是「清」档（见 [resolveCourseCardPreblurSigma]）。
const double kHomePreblurMinSigma = 2;

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
    return liquidGlassTunedBlur
        .clamp(kHomePreblurMinSigma, kPreblurMaxSigma)
        .toDouble();
  }
  return sheetBlurSigma;
}

/// 课程卡片那张位图该用的 sigma；**卡片不是液态档时返回 null**（不烤）。
///
/// 与 [resolveHomePreblurSigma] 的三处刻意不同：
///
/// * 来源是**卡片自己的**配置（`CourseGlassTuning.blurSigma`），不是首页那份；
/// * 取的是**未套深色配方**的值 —— 位图按一个 sigma 烤一次，而配方里的 ×1.3 是
///   逐帧的光照适配。用烤好的图去表达「深色更糊」是表达不出来的，只会让那次 ×1.3
///   永远不生效。深色只作用于几何与边光。
/// * **区间是 0 ~ [kPreblurMaxSigma]，首页那份是 [kHomePreblurMinSigma] 起**：
///   卡片的 0 是**有效的「清」档** —— 出按屏宽解码的原图、不跑高斯
///   （见 [PreblurredWallpaperCache.obtain]）。用户 2026-09-22 口径「让 0 真的清」：
///   拖到 0 时卡片背景要与壁纸底图一样清晰，而不是一层极轻的糊。旧口径在这里
///   跟着首页一起夹 2，真机表现就是「磨砂调到 0 还带模糊」，而滑杆上 0~1 那两格
///   与 2 完全同观感、25~40 那十六格又全都等于 24 —— 一根滑杆两头都是死区。
double? resolveCourseCardPreblurSigma({
  required CourseCardSurfaceStyle cardStyle,
  required CourseGlassTuning? cardTuning,
}) {
  if (cardStyle != CourseCardSurfaceStyle.liquidGlass) {
    return null;
  }
  final sigma = (cardTuning ?? CourseGlassTuning.courseCard).blurSigma;
  final clamped = sigma.clamp(0.0, kPreblurMaxSigma).toDouble();
  return clamped;
}

/// Pre-blurred wallpaper handed to course-card glass fills.
@immutable
class PreblurredWallpaperData {
  const PreblurredWallpaperData({
    required this.image,
    required this.pageController,
    required this.followsPager,
    this.coverAnchorKey,
    this.alignX = 0,
    this.alignY = 0,
    this.scale = 1,
    this.repaint,
    this.revision = 0,
  });

  final ui.Image image;

  /// 「这张壁纸被 cover 到哪个框」—— 那个框的 widget key。
  ///
  /// `null` = 首页那条路：cover 到**整屏**，左上角是全局原点 (0,0)。
  /// 非 null = 这个框的**全局矩形**才是基准（设置页的周预览就是这样：壁纸铺在预览框里，
  /// 而预览框既不是整屏、也不在屏幕原点 —— 用整屏那套几何去取卡片那一块会与预览背景错位）。
  ///
  /// 存 key 而不是存矩形，是因为基准框会**随滚动移动**，而滚动不触发重建：
  /// 绘制期现取 `localToGlobal` 才跟得上（与 fill 自己取坐标同一时刻、同一套变换）。
  final GlobalKey? coverAnchorKey;

  /// 屏幕上真壁纸的 `BoxFit.cover` 对齐值（-1…1，与
  /// `TimetableSettings.homePageWallpaperAlignX/Y` 同源）。
  ///
  /// 这份位图按「cover 铺满整屏」画，对齐值抄错就是卡内外背景错位 —— 见
  /// [preblurredWallpaperCoverDestRect] 的说明。
  final double alignX;
  final double alignY;

  /// 屏幕上真壁纸的放大倍数（1 = 刚好铺满，见
  /// `TimetableSettings.homePageWallpaperScale`）。
  ///
  /// 与 [alignX] 同一条约束：抄错就是卡内外背景错位（这份位图按「cover 铺满整屏」
  /// 画，缩放要让它的取景与屏幕上那张一致）。
  final double scale;

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
    this.cardBlurSigma,
    this.coverToChild = false,
    this.pageController,
    this.followsPager = false,
    this.wallpaperAlignX = 0,
    this.wallpaperAlignY = 0,
    this.wallpaperScale = 1,
    this.repaint,
    this.enabled = true,
    super.key,
  });

  final String? wallpaperPath;

  /// Desired on-screen blur radius in logical pixels.
  final double blurSigma;

  /// 课程卡片那张位图的磨砂量（逻辑 px）。
  ///
  /// * `null` = **不烤**（卡片不是液态档时就是它）；
  /// * `0` = **烤「清」档**：出按屏宽解码的原图、不跑高斯（用户口径 2026-09-22
  ///   「让 0 真的清」），所以 0 是**有效值**、不是"关掉"。
  ///
  /// ⚠️ 注意这与 [blurSigma] 那份的 `≤ 0 = 不烤` 口径**不同** —— 两个槽在
  /// [_PreblurredWallpaperScopeState._syncRequests] 里按各自的口径传参。
  ///
  /// 为什么要第二张：卡片有自己一套磨砂量（`CourseGlassTuning.blurSigma`），
  /// 而 [blurSigma] 那份还要喂日视图的摘要替身卡。共用一张就会「一处动两处变」。
  /// 两张图的路径、对齐、缩放完全一致，**只有 sigma 不同**。
  final double? cardBlurSigma;

  /// 这张壁纸 cover 到哪个框：`false`（默认）= 整屏（首页那条路）；
  /// `true` = **本 scope 的 child 框**（设置页的周预览：壁纸铺在预览框里）。
  ///
  /// 打开它之后，卡片不再按「屏幕坐标 + 整屏 cover」取自己那一块，而是按 child 框取 ——
  /// 与预览里 `homePageBackdropLayer` 那层 `Positioned.fill(Image(cover))` 同一套几何。
  /// 不打开时逐帧与之前完全一致（首页零回归）。
  final bool coverToChild;

  final PageController? pageController;
  final bool followsPager;

  /// 屏幕上真壁纸的 `BoxFit.cover` 对齐值，必须与渲染壁纸的那一处同源
  /// （见 [PreblurredWallpaperData.alignX]）。
  final double wallpaperAlignX;
  final double wallpaperAlignY;

  /// 屏幕上真壁纸的放大倍数（见 [PreblurredWallpaperData.scale]）。
  final double wallpaperScale;

  /// See [PreblurredWallpaperData.repaint].
  final Listenable? repaint;
  final bool enabled;
  final Widget child;

  static PreblurredWallpaperData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PreblurredWallpaperInherited>()
        ?.data;
  }

  /// 课程卡片那张位图（[cardBlurSigma] 为 null 时恒为 null；为 0 时是「清」档，
  /// 有图）。
  ///
  /// 与 [maybeOf] 是**两条独立的流**：卡片要的是自己那份磨砂量，首页要的是它那份，
  /// 谁都不许去读对方那份（读错只会在观感上体现，不会有异常）。
  static PreblurredWallpaperData? courseCardMaybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CourseCardPreblurredInherited>()
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
    return _isWaiting<_PreblurredWallpaperInherited>(context);
  }

  /// [isWaitingForBitmap] 的卡片版。
  static bool courseCardIsWaitingForBitmap(BuildContext context) {
    return _isWaiting<_CourseCardPreblurredInherited>(context);
  }

  static bool _isWaiting<T extends _PreblurredInherited>(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<T>();
    if (element == null) {
      return false;
    }
    return (element.widget as _PreblurredInherited).data == null;
  }

  @override
  State<PreblurredWallpaperScope> createState() =>
      _PreblurredWallpaperScopeState();
}

/// 一个位图槽的请求簿记。
///
/// 两个槽（首页那份 / 课程卡片那份）的同步逻辑**逐字一样**，只是请求参数不同，
/// 所以把「已到手的是哪张、正在等谁」收进这个持有者，逻辑只写一遍。
class _PreblurSlot {
  ui.Image? image;

  /// 本次等待的令牌。换请求 / 卸载时置空，好让在途回调知道自己是过期的那一个。
  Object? pending;

  String? loadedPath;
  double? loadedSigma;
  double? loadedDevicePixelRatio;
}

class _PreblurredWallpaperScopeState extends State<PreblurredWallpaperScope> {
  final _PreblurSlot _home = _PreblurSlot();
  final _PreblurSlot _card = _PreblurSlot();
  int _revision = 0;

  /// [PreblurredWallpaperScope.coverToChild] 时，包在 child 外面的那个 key：
  /// 它对应的渲染框就是「壁纸被 cover 到的框」，绘制期由 fill 现取全局矩形。
  final GlobalKey _coverKey = GlobalKey();

  /// Replaced handles awaiting end-of-frame disposal. See [_replaceImage].
  final List<ui.Image> _retiredImages = <ui.Image>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRequests();
  }

  @override
  void didUpdateWidget(covariant PreblurredWallpaperScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaperPath != widget.wallpaperPath ||
        oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.cardBlurSigma != widget.cardBlurSigma ||
        oldWidget.enabled != widget.enabled) {
      _syncRequests();
    }
  }

  void _syncRequests() {
    final path = widget.enabled ? widget.wallpaperPath : null;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    _syncSlot(
      slot: _home,
      path: path,
      // 首页那份沿旧口径：≤ 0 = 不烤（全局磨砂被拖到 0 时，首页玻璃带没有成品
      // 磨砂图，走它原来的兜底）。
      sigma: widget.blurSigma > 0 ? widget.blurSigma : null,
      devicePixelRatio: devicePixelRatio,
    );
    _syncSlot(
      slot: _card,
      path: path,
      // 卡片这份的 0 是**有效值**（清档），所以原样透传；只有 null 才是不烤。
      sigma: widget.cardBlurSigma,
      devicePixelRatio: devicePixelRatio,
    );
  }

  void _syncSlot({
    required _PreblurSlot slot,
    required String? path,
    required double? sigma,
    required double devicePixelRatio,
  }) {
    if (path == null || path.isEmpty || sigma == null || sigma < 0) {
      slot.pending = null;
      slot.loadedPath = null;
      slot.loadedSigma = null;
      slot.loadedDevicePixelRatio = null;
      // A build always follows didChangeDependencies / didUpdateWidget, so the
      // field assignment is enough — setState here would be called during build.
      _replaceImage(slot, null);
      return;
    }
    if (slot.loadedPath == path &&
        slot.loadedSigma == sigma &&
        slot.loadedDevicePixelRatio == devicePixelRatio) {
      return;
    }
    slot.loadedPath = path;
    slot.loadedSigma = sigma;
    slot.loadedDevicePixelRatio = devicePixelRatio;

    final token = Object();
    slot.pending = token;
    unawaited(() async {
      final image = await PreblurredWallpaperCache.instance.obtain(
        path: path,
        logicalSigma: sigma,
        devicePixelRatio: devicePixelRatio,
      );
      if (!mounted || slot.pending != token) {
        // Superseded or unmounted: nobody will own this clone, so release it.
        image?.dispose();
        return;
      }
      setState(() {
        _replaceImage(slot, image);
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
  void _replaceImage(_PreblurSlot slot, ui.Image? next) {
    final previous = slot.image;
    if (identical(previous, next)) {
      return;
    }
    slot.image = next;
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
    _home.pending = null;
    _card.pending = null;
    _replaceImage(_home, null);
    _replaceImage(_card, null);
    // This subtree is being torn down and will never paint again, so the
    // retired handles (including the one just queued) can go right away —
    // no need to wait for a frame that may never be scheduled (app paused).
    _disposeRetiredImages();
    super.dispose();
  }

  PreblurredWallpaperData? _dataFor(ui.Image? image) {
    if (image == null) {
      return null;
    }
    return PreblurredWallpaperData(
      image: image,
      pageController: widget.pageController,
      followsPager: widget.followsPager,
      coverAnchorKey: widget.coverToChild ? _coverKey : null,
      alignX: widget.wallpaperAlignX,
      alignY: widget.wallpaperAlignY,
      scale: widget.wallpaperScale,
      repaint: widget.repaint,
      revision: _revision,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 两条流各自发一份：消费者按自己的角色取（首页那份 / 卡片那份），
    // 取错不会抛异常、只会悄悄用错磨砂量，所以两处都不许"顺手读另一份"。
    final child = widget.coverToChild
        ? KeyedSubtree(key: _coverKey, child: widget.child)
        : widget.child;
    return _PreblurredWallpaperInherited(
      data: _dataFor(_home.image),
      child: _CourseCardPreblurredInherited(
        data: _dataFor(_card.image),
        child: child,
      ),
    );
  }
}

/// 两份位图的 inherited 基类。
///
/// 存在的唯一理由是「还在等位图」这条查询两处一模一样（见
/// [PreblurredWallpaperScope.isWaitingForBitmap]）—— 不共基类就得把同一段
/// 取值代码写两遍。
abstract class _PreblurredInherited extends InheritedWidget {
  const _PreblurredInherited({required this.data, required super.child});

  final PreblurredWallpaperData? data;

  @override
  bool updateShouldNotify(covariant _PreblurredInherited oldWidget) {
    return data?.revision != oldWidget.data?.revision ||
        data?.image != oldWidget.data?.image ||
        data?.coverAnchorKey != oldWidget.data?.coverAnchorKey ||
        data?.followsPager != oldWidget.data?.followsPager ||
        data?.alignX != oldWidget.data?.alignX ||
        data?.alignY != oldWidget.data?.alignY ||
        data?.repaint != oldWidget.data?.repaint ||
        data?.pageController != oldWidget.data?.pageController;
  }
}

class _CourseCardPreblurredInherited extends _PreblurredInherited {
  const _CourseCardPreblurredInherited({
    required super.data,
    required super.child,
  });
}

class _PreblurredWallpaperInherited extends _PreblurredInherited {
  const _PreblurredWallpaperInherited({
    required super.data,
    required super.child,
  });
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
/// [alignX] / [alignY] **必须与屏幕上真壁纸的 `BoxFit.cover` 对齐值一致**
/// （`TimetableSettings.homePageWallpaperAlignX/Y`，见 [homePageBackdropImageWidget]）：
/// 这块位图是「贴在屏幕上的那张壁纸」的副本，卡片只是它的一个窗口，对齐值不一致
/// 时卡内透出的就是**错位**的一段背景 —— 卡内外的壁纸边界接不上（默认 0，即居中）。
/// 坐标口径与 [homePageWallpaperVisibleSourceRect] 同一套（align -1 = 贴前缘）。
///
/// Returns [Rect.zero] when the inputs cannot produce a sample.
@visibleForTesting
Rect preblurredWallpaperCoverDestRect({
  required Size imageSize,
  required Size screenSize,
  required double wallpaperOriginX,
  Offset anchor = Offset.zero,
  double alignX = 0,
  double alignY = 0,
  double zoom = 1,
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
  // 用户放大倍数：与屏幕上真壁纸那层 `Transform.scale(alignment: 对齐点)` 同一套
  // 几何 —— 先把 cover 的落点放大，再按对齐值分配溢出（推导见
  // `homePageBackdropImageWidget` 的注释）。zoom = 1 时下面几行与加缩放前逐字相同。
  final zoomed = zoom.clamp(kWallpaperMinScale, kWallpaperMaxScale);
  // cover 下图片在两个方向都不小于屏幕，多出来的部分按对齐值分配：
  // align = -1 贴前缘（溢出全在末尾）、0 居中、+1 贴后缘。
  final fittedWidth = imageSize.width * scale * zoomed;
  final fittedHeight = imageSize.height * scale * zoomed;
  final overflowX = fittedWidth - screenSize.width;
  final overflowY = fittedHeight - screenSize.height;
  // [anchor] 是「被 cover 的那个框」左上角的全局位置：首页那条路是屏幕原点 (0,0)，
  // 设置页预览那条路是预览框自己的位置（壁纸铺在预览框里，不是铺在屏幕上）。
  // 不传 anchor 时下面两行与加它之前逐字相同 —— 首页那条路零回归。
  final destLeft =
      anchor.dx +
      wallpaperOriginX -
      overflowX * (alignX.clamp(-1.0, 1.0) + 1) / 2;
  final destTop =
      anchor.dy - overflowY * (alignY.clamp(-1.0, 1.0) + 1) / 2;
  return Rect.fromLTWH(destLeft, destTop, fittedWidth, fittedHeight);
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
  double alignX = 0,
  double alignY = 0,
  double zoom = 1,
}) {
  final dest = preblurredWallpaperCoverDestRect(
    imageSize: imageSize,
    screenSize: screenSize,
    wallpaperOriginX: wallpaperOriginX,
    alignX: alignX,
    alignY: alignY,
    zoom: zoom,
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

/// 这张填充该读哪一份预糊位图。
///
/// **必须显式指定，不许按「有没有 glass」猜**：高斯档的卡片同样不带 `glass`，
/// 用「带没带 glass」去判会把高斯卡片读成首页那份，而两份的磨砂量可以不同
/// （见 [PreblurredWallpaperScope.cardBlurSigma]）。
enum PreblurredWallpaperSource {
  /// 首页那份：页顶玻璃带、日视图摘要替身卡。
  home,

  /// 课程卡片那份：卡片的两档玻璃材质。
  courseCard,
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
  const PreblurredWallpaperAlignedFill({
    this.glass,
    this.source = PreblurredWallpaperSource.home,
    super.key,
  });

  static PreblurredWallpaperData? _dataOf(
    BuildContext context,
    PreblurredWallpaperSource source,
  ) => switch (source) {
    PreblurredWallpaperSource.home => PreblurredWallpaperScope.maybeOf(context),
    PreblurredWallpaperSource.courseCard =>
      PreblurredWallpaperScope.courseCardMaybeOf(context),
  };

  /// 液态玻璃参数；null = 原行为（直接贴图，即高斯模糊档）。
  final CourseGlassStyle? glass;

  /// 读哪一份预糊位图。
  final PreblurredWallpaperSource source;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final data = _dataOf(context, source);
    return _RenderPreblurredFill(
      image: data?.image,
      screenSize: MediaQuery.sizeOf(context),
      coverAnchorKey: data?.coverAnchorKey,
      pageController: data?.pageController,
      followsPager: data?.followsPager ?? false,
      alignX: data?.alignX ?? 0,
      alignY: data?.alignY ?? 0,
      scale: data?.scale ?? 1,
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
    final data = _dataOf(context, source);
    (renderObject as _RenderPreblurredFill)
      ..image = data?.image
      ..screenSize = MediaQuery.sizeOf(context)
      ..coverAnchorKey = data?.coverAnchorKey
      ..followsPager = data?.followsPager ?? false
      ..alignX = data?.alignX ?? 0
      ..alignY = data?.alignY ?? 0
      ..scale = data?.scale ?? 1
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
    GlobalKey? coverAnchorKey,
    this._alignX = 0,
    this._alignY = 0,
    this._scale = 1,
    this._repaint,
    this._verticalScrollPosition,
    CourseGlassStyle? glass,
  }) {
    // 构造期直接落字段、不走 setter：setter 里的 _syncShader 要 attached 才
    // 建着色器，此刻还没 attach，交给 attach() 统一处理。
    _glass = glass;
    _coverAnchorKey = coverAnchorKey;
  }

  ui.Image? _image;
  set image(ui.Image? value) {
    if (_image == value) {
      return;
    }
    _image = value;
    markNeedsPaint();
  }

  /// 壁纸被 cover 到的那个框（见 [PreblurredWallpaperData.coverAnchorKey]）。
  /// null = 整屏 + 全局原点。
  GlobalKey? _coverAnchorKey;
  set coverAnchorKey(GlobalKey? value) {
    if (_coverAnchorKey == value) {
      return;
    }
    _coverAnchorKey = value;
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

  /// 屏幕上真壁纸的 `BoxFit.cover` 对齐值（见 [PreblurredWallpaperData.alignX]）。
  double _alignX;
  set alignX(double value) {
    if (_alignX == value) {
      return;
    }
    _alignX = value;
    markNeedsPaint();
  }

  double _alignY;
  set alignY(double value) {
    if (_alignY == value) {
      return;
    }
    _alignY = value;
    markNeedsPaint();
  }

  /// 屏幕上真壁纸的放大倍数（见 [PreblurredWallpaperData.scale]）。
  double _scale;
  set scale(double value) {
    if (_scale == value) {
      return;
    }
    _scale = value;
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
    //
    // 「基准框」有两种：首页那条路是整屏（左上角 = 全局原点），设置页预览那条路是
    // 预览框自己（见 [PreblurredWallpaperData.coverAnchorKey]）。基准框的全局矩形
    // **必须在绘制期现取** —— 它随滚动移动，而滚动不触发重建。
    final anchorBox = _coverAnchorKey?.currentContext?.findRenderObject();
    final anchored = anchorBox is RenderBox && anchorBox.hasSize;
    final coverSize = anchored ? anchorBox.size : screen;
    final anchor = anchored ? anchorBox.localToGlobal(Offset.zero) : Offset.zero;
    if (coverSize.width <= 0 || coverSize.height <= 0) {
      return;
    }
    final globalTopLeft = localToGlobal(Offset.zero);
    final dest = preblurredWallpaperCoverDestRect(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      screenSize: coverSize,
      wallpaperOriginX: _wallpaperOriginX(),
      anchor: anchor,
      alignX: _alignX,
      alignY: _alignY,
      zoom: _scale,
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
    uniforms.dispersion.set(glass.dispersion);
    uniforms.rimColor.set(rim.r, rim.g, rim.b);
    uniforms.rim.set(glass.rimStrength);
    uniforms.rimWidth.set(glass.rimWidth);

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
      dispersion = shader.getUniformFloat('u_dispersion'),
      rimColor = shader.getUniformVec3('u_rim_color'),
      rim = shader.getUniformFloat('u_rim'),
      rimWidth = shader.getUniformFloat('u_rim_width');

  final ui.UniformVec2Slot size;
  final ui.UniformVec2Slot texOrigin;
  final ui.UniformVec2Slot texDestSize;
  final ui.UniformFloatSlot radius;
  final ui.UniformVec4Slot tint;
  final ui.UniformFloatSlot refract;
  final ui.UniformFloatSlot band;
  final ui.UniformFloatSlot edgePow;
  final ui.UniformFloatSlot dispersion;
  final ui.UniformVec3Slot rimColor;
  final ui.UniformFloatSlot rim;
  final ui.UniformFloatSlot rimWidth;
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
