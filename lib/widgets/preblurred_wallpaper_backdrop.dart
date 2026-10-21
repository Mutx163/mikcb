import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'preblurred_wallpaper_glass.dart';

/// 首页壁纸的**预烤模糊**底图：整屏铺一张烤好的位图，运行时不做任何滤镜。
///
/// ## 它和 `PreblurredWallpaperScope` 那两份的关系
///
/// 同一张缓存（[PreblurredWallpaperCache]）、同一套烤图路径，但**互不相干**：
///
/// * 那两份永远是"底料"——被裁成一条玻璃带或一张卡片，由
///   `PreblurredWallpaperAlignedFill` 从整屏位图里取自己那一块；
/// * 这一份是**壁纸本身**——不加裁剪地铺满整屏，取代清晰原图。
///
/// 所以它**不寄生在那个 scope 上**：`useHomePreblur` 在「实体卡片」档
/// （模糊总开关关）恒为 false、整棵树里根本没有那个 scope
/// （见 `ui/home/home_chrome_spec.dart` 的 `useHomePreblur`），
/// 而壁纸模糊是独立的观感开关，必须在模糊总开关关掉时照样生效。
/// 这里直接向缓存要图，只认自己的 sigma。
///
/// ## 三条不可动的行为（每条都在本仓有事故背书）
///
/// 1. **位图没到之前画清晰原图，不是画空白**。`obtain` 是异步的
///    （解码 → 高斯 → `toImage`）。在途期间继续显示原图（[fallback]），
///    到位后切换 —— 与 `gaplessPlayback: true` 同一种承诺。返回
///    `SizedBox.shrink()` 会在换壁纸 / 冷启动时闪一帧纯色底，正是启动预热器
///    存在要消掉的那个现象（`utils/home_startup_visual_primer.dart` 类注释）。
/// 2. **失败一律回落原图**。文件丢了、解码失败、烤图抛错，全部退化成 [fallback]。
///    模糊是增益功能，不许成为"壁纸没了"的新原因。
/// 3. **句柄所有权在调用方，且必须延迟到帧末释放**。`obtain` 交出来的是
///    `clone()`，谁拿谁负责 dispose；而渲染对象在本帧里可能还会用旧句柄画最后一笔，
///    提前释放就是 `Canvas.drawImageRect` 的 `assert(!image.debugDisposed)`。
///    做法与 `_PreblurredWallpaperScopeState._replaceImage` 逐字同源。
///
/// ## 取景几何一个字都不改
///
/// [alignX] / [alignY] 直接喂给 [RawImage] 的 `BoxFit.cover` 对齐值，缩放由调用方
/// 在外面套 `Transform.scale(alignment: 同一对齐点)` —— 与清晰原图那条路同源，
/// 否则位置编辑页、卡片取景、屏上壁纸三处会立刻错位
/// （`2026-09-20-preblur-wallpaper-align.md` 记的就是这一次）。
class PreblurredWallpaperBackdrop extends StatefulWidget {
  const PreblurredWallpaperBackdrop({
    required this.wallpaperPath,
    required this.sigma,
    required this.alignX,
    required this.alignY,
    required this.fallback,
    super.key,
  });

  /// 壁纸文件绝对路径（与 `homePageBackdropKey` 同口径）。
  final String wallpaperPath;

  /// 期望的**屏上**模糊量（逻辑 px）。必须 > 0 —— 0 档由调用方直接走原图。
  final double sigma;

  /// 屏幕上真壁纸的 `BoxFit.cover` 对齐值（-1…1）。
  final double alignX;
  final double alignY;

  /// 位图未就绪 / 烤图失败时画的东西：调用方传的清晰原图。
  final Widget fallback;

  @override
  State<PreblurredWallpaperBackdrop> createState() =>
      _PreblurredWallpaperBackdropState();
}

class _PreblurredWallpaperBackdropState
    extends State<PreblurredWallpaperBackdrop> {
  /// 当前展示的位图（本 State 拥有的 clone 句柄）。
  ui.Image? _image;

  /// 本次等待的令牌：换请求 / 卸载时置空，好让在途回调知道自己是过期的那一个。
  Object? _pending;

  String? _loadedPath;
  double? _loadedSigma;
  double? _loadedDevicePixelRatio;

  /// 待释放的旧句柄（帧末统一释放，见类注释第 3 条）。
  final List<ui.Image> _retired = <ui.Image>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PreblurredWallpaperBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaperPath != widget.wallpaperPath ||
        oldWidget.sigma != widget.sigma) {
      _sync();
    }
  }

  void _sync() {
    final path = widget.wallpaperPath;
    final sigma = widget.sigma;
    if (path.isEmpty || sigma <= 0) {
      _clear();
      return;
    }
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (devicePixelRatio <= 0) {
      _clear();
      return;
    }
    if (_loadedPath == path &&
        _loadedSigma == sigma &&
        _loadedDevicePixelRatio == devicePixelRatio) {
      // 同参：不重复请求（否则每次重建都换一次整屏位图）。
      return;
    }
    _loadedPath = path;
    _loadedSigma = sigma;
    _loadedDevicePixelRatio = devicePixelRatio;

    // **先同步问一次缓存**：命中就当场贴，第一帧直接是糊好的成品。
    //
    // 为什么必须这样：`obtain` 即使命中缓存也返回 `Future`（`Future.value` 也要等
    // 一个微任务），而本控件的第一帧在微任务之前就画了 —— 于是"缓存里明明有糊图，
    // 第一帧还是先画清晰原图、第二帧才换"（2026-10-21 用户报：日/周视图切月视图时
    // 整页闪一帧没糊的壁纸）。月视图是个全新页面，壁纸控件从零开始，必然撞上这一帧。
    //
    // 只在**首次同步**（或换壁纸/换 sigma）时问；问不到再走异步那条，那时确实没得
    // 贴（烤图要解码 + 高斯），画原图就是正确行为。
    final peeked = PreblurredWallpaperCache.instance.peek(
      path: path,
      logicalSigma: sigma,
      devicePixelRatio: devicePixelRatio,
    );
    if (peeked != null) {
      _pending = null;
      // `_sync` 在 didChangeDependencies / didUpdateWidget 里跑，后面必然跟着一次
      // build，所以这里只需赋值、不需要 setState（同 `_replaceImage` 的用法）。
      _replaceImage(peeked);
      return;
    }

    final token = Object();
    _pending = token;
    unawaited(() async {
      ui.Image? image;
      try {
        image = await PreblurredWallpaperCache.instance.obtain(
          path: path,
          logicalSigma: sigma,
          devicePixelRatio: devicePixelRatio,
        );
      } catch (_) {
        // 烤图失败：保持原图（类注释第 2 条）。
        image = null;
      }
      if (!mounted || _pending != token) {
        // 被后来的请求顶掉 / 已卸载：没人会拥有这个 clone，就地释放。
        image?.dispose();
        return;
      }
      if (image == null) {
        // 拿不到位图（文件没了 / 解码失败）：退到原图，且**不**再重试同一组参数
        // （`_loadedPath` 已记下，避免每帧重烤）。
        setState(() => _replaceImage(null));
        return;
      }
      setState(() => _replaceImage(image));
    }());
  }

  void _clear() {
    _pending = null;
    _loadedPath = null;
    _loadedSigma = null;
    _loadedDevicePixelRatio = null;
    _replaceImage(null);
  }

  /// 换掉自己持有的句柄；旧的那份延迟到帧末释放（见类注释第 3 条）。
  void _replaceImage(ui.Image? next) {
    final previous = _image;
    if (identical(previous, next)) {
      return;
    }
    _image = next;
    if (previous != null) {
      _retired.add(previous);
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeRetired());
    }
  }

  void _disposeRetired() {
    if (_retired.isEmpty) {
      return;
    }
    final retired = List<ui.Image>.of(_retired);
    _retired.clear();
    for (final image in retired) {
      image.dispose();
    }
  }

  @override
  void dispose() {
    _pending = null;
    _replaceImage(null);
    // 本子树不会再画：连刚排队的那份也可以立刻放掉，不必等一个可能永不来的帧。
    _disposeRetired();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null || image.width <= 0 || image.height <= 0) {
      return widget.fallback;
    }
    return RawImage(
      image: image,
      fit: BoxFit.cover,
      alignment: Alignment(
        widget.alignX.clamp(-1.0, 1.0),
        widget.alignY.clamp(-1.0, 1.0),
      ),
    );
  }
}
