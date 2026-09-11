// BokehLavaGradient —— 动画 bokeh / lava 渐变背景。
//
// 移植自 bokeh-lava-gradient（MIT License，© keepYaoung / tommy / joon shin）
// https://github.com/keepYaoung/bokeh-lava-gradient
//
// 与原包的对齐与差异：
//   - 保留低分辨率模糊缓冲与「后台 / 被遮挡即暂停」，但驱动方式由 Ticker
//     改为 Timer：Ticker 每 vsync 都请求一帧，节流拦不住出帧，首页静置也会
//     把设备钉在屏幕刷新率上（详见 [BokehLavaGradient.targetFps]）。
//   - 随机分布改为按 [BuiltInWallpaperSpec.seed] 播种，首帧与静态位图
//     （亮度采样 / 预模糊玻璃）完全一致；之后自由漂移。
// 原 MIT 许可与版权信息见 docs/THIRD_PARTY_LICENSES.md。

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'builtin_wallpaper.dart';

/// 内置壁纸的动画渲染 Widget（首页背景 / 设置页缩略图预览）。
///
/// 首页玻璃与墨色极性仍采样 [BuiltInWallpaperImage] 静态位图（单帧成本低、
/// 缓存友好）；本 Widget 只负责可见像素的漂移。[animate] 为 false 时只画
/// 静态首帧（与位图同 seed），供设置页多缩略图避免同时起多个动画。
///
/// Widget 测试里活动的动画计时器会与 `tester.runAsync` 的假时钟互等死锁；
/// 集成测试请把 [debugDisableAnimationForced] 设为 true。
class BokehLavaGradient extends StatefulWidget {
  const BokehLavaGradient({
    super.key,
    required this.wallpaper,
    this.animate = true,
    this.lowResFactor = 0.45,
    this.targetFps = 15,
    this.child,
  });

  /// 测试用：强制所有实例不启动画（集成测试与 runAsync 混用时防死锁）。
  static bool debugDisableAnimationForced = false;

  /// 测试用：累计实际推进的帧数（节拍与启停的观测点）。
  static int debugTickCount = 0;

  final BuiltInWallpaper wallpaper;

  /// 是否启动漂移动画；false 时只画播种首帧。
  final bool animate;

  /// 模糊缓冲分辨率因子（0–1）。约 0.45 时观感与全分辨率几乎一致
  /// （实测逐像素最大差 2/255），但模糊成本按面积降到约 1/5。
  final double lowResFactor;

  /// 目标帧率。
  ///
  /// 光斑是**大半径 + 重模糊**的色块，漂移又只有几 px/s，帧率只影响「多久
  /// 采一次样」，不影响轨迹（[Stopwatch] 实测 dt，掉帧不改变漂移速度）。
  ///
  /// 取 15 而不是 30/60：节拍由 [Timer.periodic] 提供，**每次节拍只请求一帧**。
  /// 早先的实现用 `Ticker`（每帧回调 + 累积式节流）——节流只压住了重绘次数，
  /// 压不住「每 vsync 都请求一帧」：首页静置时设备仍以屏幕刷新率
  /// （实测 60~96 fps）持续出帧，壁纸下方的每块柔光玻璃都要重做一次
  /// backdrop 采样 + 模糊 + 折射，SurfaceFlinger 单核占用 44%、机身 5 分钟
  /// 升到 44℃。改成 Timer 后两帧之间没有任何已排程的帧，渲染管线可以真正
  /// 空闲（实测要求见 test/utils/bokeh_lava_gradient_test.dart 的节拍用例）。
  final int targetFps;

  final Widget? child;

  @override
  State<BokehLavaGradient> createState() => _BokehLavaGradientState();
}

class _BokehLavaGradientState extends State<BokehLavaGradient>
    with WidgetsBindingObserver {
  Timer? _timer;
  late _BlobField _field;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  /// 真实经过时间：dt 取实测值而不是标称节拍，掉帧只影响采样密度、
  /// 不改变漂移速度（轨迹与节拍解耦，与旧 Ticker 实现同口径）。
  final Stopwatch _clock = Stopwatch();
  double _lastSeconds = 0;

  /// 由 [TickerMode] 决定：本页被别的路由覆盖时宿主会关掉它的动画。
  bool _tickerModeEnabled = true;

  /// 由 App 生命周期决定：后台不推进、也不请求帧。
  bool _appActive = true;

  Duration get _interval =>
      Duration(microseconds: (1000000 / widget.targetFps).round());

  bool get _shouldAnimate =>
      widget.animate &&
      !BokehLavaGradient.debugDisableAnimationForced &&
      _tickerModeEnabled &&
      _appActive;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _field = _BlobField(
      builtInWallpaperSpec(widget.wallpaper),
      widget.lowResFactor,
    );
    // 观察者常驻：定时器只在「可见 + 前台」时存在，回到前台这一步必须由
    // observer 唤起，所以不能在停表时顺手把 observer 摘掉。
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode 原先由 createTicker 隐式遵守；换 Timer 后必须显式读写。
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncTimer();
  }

  void _syncTimer() {
    if (_shouldAnimate) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    if (_timer != null) {
      return;
    }
    _clock.start();
    _lastSeconds = _clock.elapsedMicroseconds / 1000000.0;
    _timer = Timer.periodic(_interval, _onTick);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void _onTick(Timer _) {
    final now = _clock.elapsedMicroseconds / 1000000.0;
    final dt = now - _lastSeconds;
    if (dt <= 0) {
      return;
    }
    _lastSeconds = now;
    _field.tick(dt);
    _repaint.value++;
    BokehLavaGradient.debugTickCount++;
  }

  @override
  void didUpdateWidget(covariant BokehLavaGradient old) {
    super.didUpdateWidget(old);
    if (widget.wallpaper != old.wallpaper ||
        widget.lowResFactor != old.lowResFactor) {
      _field = _BlobField(
        builtInWallpaperSpec(widget.wallpaper),
        widget.lowResFactor,
      );
    }
    if (widget.animate != old.animate || widget.targetFps != old.targetFps) {
      // 节拍间隔在建定时器时就固定了，改目标帧率必须重建。
      _stopTimer();
      _syncTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = builtInWallpaperSpec(widget.wallpaper);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        if (w <= 0 || h <= 0) {
          return ColoredBox(color: spec.base, child: widget.child);
        }
        final f = widget.lowResFactor.clamp(0.1, 1.0);
        final lowW = w * f < 1 ? 1.0 : w * f;
        final lowH = h * f < 1 ? 1.0 : h * f;
        final sigma = math.max(
          0.1,
          math.min(lowW, lowH) * spec.blurStrength,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: spec.base),
            ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: 1 / f,
                  alignment: Alignment.topLeft,
                  // 刻意不给 filterQuality：`RenderTransform.paint` 一旦拿到
                  // 非空 filterQuality，就会**无条件**建一个
                  // `ImageFilterLayer(ImageFilter.matrix(...))`，等于每帧多一次
                  // 全屏离屏 + 矩阵重采样。实测（低分辨率缓冲 162×360 放大
                  // 2.22×）带与不带 filterQuality、乃至与全分辨率直接绘制相比，
                  // 逐像素最大差仅 2/255 —— 放大质量本就来自引擎默认的双线性
                  // 采样，这个参数只买得到开销。
                  child: SizedBox(
                    width: lowW,
                    height: lowH,
                    // 不包 RepaintBoundary：`ImageFiltered` 的
                    // `_ImageFilterRenderObject` 自身 `isRepaintBoundary` 为
                    // true（child != null && enabled），已经能把
                    // `_repaint` 驱动的重绘挡在这一层，外面再包一层只会白多
                    // 一个 OffsetLayer 的每帧记录开销。
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: sigma,
                        sigmaY: sigma,
                        // clamp 与项目其余模糊管线（PreblurredWallpaperCache
                        // / BuiltInWallpaperImage）同口径：缓冲边缘按边界像素
                        // 延展。decal 把界外当透明，光斑漂到边缘时模糊会在
                        // 四周留下渐隐带并露出底层纯色。
                        tileMode: TileMode.clamp,
                      ),
                      child: CustomPaint(
                        painter: _BlobPainter(
                          _field,
                          _paintColorsFor(spec),
                          _repaint,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }

  /// 上次换算 [paintColors] 用的 spec；[builtInWallpaperSpec] 返回的是 const
  /// 实例，所以 identity 判等既准确又便宜。
  BuiltInWallpaperSpec? _paintColorsSpec;
  List<Color> _paintColors = const <Color>[];

  /// 带透明度的光斑配色。
  ///
  /// 必须缓存：早先每次 build 都新建一个 List，而 [_BlobPainter.shouldRepaint]
  /// 用 `!identical(old.colors, colors)` 判等 —— 结果父级任何一次 setState 都会
  /// 额外触发一次全屏重绘，和动画自身的重绘叠在一起。
  List<Color> _paintColorsFor(BuiltInWallpaperSpec spec) {
    if (identical(_paintColorsSpec, spec)) {
      return _paintColors;
    }
    final colors = [
      for (final c in spec.colors) c.withValues(alpha: spec.opacity),
    ];
    _paintColorsSpec = spec;
    _paintColors = colors;
    return colors;
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.field, this.colors, Listenable repaint)
    : super(repaint: repaint);

  final _BlobField field;
  final List<Color> colors;

  /// 每个光斑的径向渐变 shader，圆心固定在原点并跨帧复用。
  ///
  /// 光斑半径在整个动画期间恒定（只有圆心在动，见 [_BlobField.tick]），所以
  /// shader 可以建在 (0,0)，绘制时 `canvas.translate` 到实际圆心即可。早先是
  /// 每帧为 12 个光斑各调一次 `RadialGradient.createShader`，等于每秒几百个
  /// `ui.Gradient` 原生对象，白白喂给 GC。
  final List<ui.Shader> _shaders = <ui.Shader>[];
  int _shaderGeneration = -1;
  List<Color> _shaderColors = const <Color>[];

  void _ensureShaders() {
    final blobs = field.blobs;
    if (_shaderGeneration == field.generation &&
        identical(_shaderColors, colors) &&
        _shaders.length == blobs.length) {
      return;
    }
    _shaderGeneration = field.generation;
    _shaderColors = colors;
    _shaders
      ..clear()
      ..addAll([
        for (var i = 0; i < blobs.length; i++)
          RadialGradient(
            colors: [
              colors[i % colors.length],
              colors[i % colors.length],
              colors[i % colors.length].withValues(alpha: 0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: blobs[i].r)),
      ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    field.ensureSize(size);
    _ensureShaders();
    final blobs = field.blobs;
    final paint = Paint();
    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      // shader 建在原点，所以这里平移画布而不是重建 shader。
      canvas.save();
      canvas.translate(b.x, b.y);
      paint.shader = _shaders[i];
      canvas.drawCircle(Offset.zero, b.r, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      !identical(old.field, field) || !identical(old.colors, colors);
}

class _Blob {
  double x, y;
  double vx, vy;
  double r;
  _Blob(this.x, this.y, this.vx, this.vy, this.r);
}

/// 可播种的漂移光斑场：首帧与 [renderBuiltInWallpaperImage] 同构。
class _BlobField {
  _BlobField(this.spec, this.lowResFactor);

  final BuiltInWallpaperSpec spec;
  final double lowResFactor;

  Size size = Size.zero;
  final List<_Blob> blobs = [];

  /// 每次重新播种 +1；供 [_BlobPainter] 判断缓存的 shader 是否还有效。
  int generation = 0;

  void ensureSize(Size newSize) {
    // 模糊缓冲是低分辨率：种子布局按缓冲尺寸换算，与静态全分辨率首帧
    // 在归一化空间一致（速度也按短边比例，与分辨率无关）。
    //
    // 容差半像素：布局尺寸偶尔会因系统栏 inset / 旋转动画出现亚像素抖动，
    // 精确相等比较会让光斑瞬间跳回播种位置。
    if (blobs.isNotEmpty &&
        (newSize.width - size.width).abs() < 0.5 &&
        (newSize.height - size.height).abs() < 0.5) {
      return;
    }
    size = newSize;
    generation++;
    final seeded = builtInWallpaperSeededBlobs(spec, size);
    blobs
      ..clear()
      ..addAll([
        for (final b in seeded) _Blob(b.x, b.y, b.vx, b.vy, b.r),
      ]);
  }

  /// 推进 dt 秒；光斑在边界反弹（中心可略超出边缘）。
  void tick(double dt) {
    if (blobs.isEmpty) {
      return;
    }
    final bounds = size;
    for (final b in blobs) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      final mx = b.r * 0.4;
      if (b.x < -mx) {
        b.x = -mx;
        b.vx = -b.vx;
      } else if (b.x > bounds.width + mx) {
        b.x = bounds.width + mx;
        b.vx = -b.vx;
      }
      if (b.y < -mx) {
        b.y = -mx;
        b.vy = -b.vy;
      } else if (b.y > bounds.height + mx) {
        b.y = bounds.height + mx;
        b.vy = -b.vy;
      }
    }
  }
}
