// BokehLavaGradient —— 动画 bokeh / lava 渐变背景。
//
// 移植自 bokeh-lava-gradient（MIT License，© keepYaoung / tommy / joon shin）
// https://github.com/keepYaoung/bokeh-lava-gradient
//
// 与原包的对齐与差异：
//   - 保留 Ticker 逐帧动画：光斑在模糊层下缓慢漂移（原版低分辨率模糊、
//     fps 节流、后台/被遮挡暂停全部保留）。
//   - 随机分布改为按 [BuiltInWallpaperSpec.seed] 播种，首帧与静态位图
//     （亮度采样 / 预模糊玻璃）完全一致；之后自由漂移。
// 原 MIT 许可与版权信息见 docs/THIRD_PARTY_LICENSES.md。

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'builtin_wallpaper.dart';

/// 内置壁纸的动画渲染 Widget（首页背景 / 设置页缩略图预览）。
///
/// 首页玻璃与墨色极性仍采样 [BuiltInWallpaperImage] 静态位图（单帧成本低、
/// 缓存友好）；本 Widget 只负责可见像素的漂移。[animate] 为 false 时只画
/// 静态首帧（与位图同 seed），供设置页多缩略图避免同时起多个 Ticker。
///
/// Widget 测试里 Ticker 会与 `tester.runAsync` 假时钟死锁；集成测试请把
/// [debugDisableAnimationForced] 设为 true。
class BokehLavaGradient extends StatefulWidget {
  const BokehLavaGradient({
    super.key,
    required this.wallpaper,
    this.animate = true,
    this.lowResFactor = 0.45,
    this.targetFps = 30,
    this.child,
  });

  /// 测试用：强制所有实例不启 Ticker（集成测试与 runAsync 混用时防死锁）。
  static bool debugDisableAnimationForced = false;

  final BuiltInWallpaper wallpaper;

  /// 是否启动 Ticker 漂移；false 时只画播种首帧。
  final bool animate;

  /// 模糊缓冲分辨率因子（0–1）。约 0.45 时观感与全分辨率几乎一致
  /// （实测逐像素最大差 2/255），但模糊成本按面积降到约 1/5。
  final double lowResFactor;

  /// 目标帧率。
  ///
  /// 光斑漂移只有 6~26 px/s，20 帧就够用；取 30 是因为它同时是 60 / 90 / 120Hz
  /// 的公约数，三种常见刷新率都能精确命中目标间隔（累积式节流见
  /// [FrameThrottle]）。20fps 在 90Hz 屏上只能稳定跑到 18fps（5 帧推一次）。
  final int targetFps;

  final Widget? child;

  bool get _startsTicker => animate && !debugDisableAnimationForced;

  @override
  State<BokehLavaGradient> createState() => _BokehLavaGradientState();
}

class _BokehLavaGradientState extends State<BokehLavaGradient>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Ticker? _ticker;
  late _BlobField _field;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  late FrameThrottle _throttle = FrameThrottle(widget.targetFps);

  @override
  void initState() {
    super.initState();
    final spec = builtInWallpaperSpec(widget.wallpaper);
    _field = _BlobField(spec, widget.lowResFactor);
    if (widget._startsTicker) {
      WidgetsBinding.instance.addObserver(this);
      _ticker = createTicker(_onTick)..start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _throttle.tick(elapsed);
    if (dt == null) {
      return;
    }
    _field.tick(dt);
    _repaint.value++;
  }

  @override
  void didUpdateWidget(covariant BokehLavaGradient old) {
    super.didUpdateWidget(old);
    if (widget.targetFps != old.targetFps) {
      _throttle = FrameThrottle(widget.targetFps);
    }
    if (widget.wallpaper != old.wallpaper ||
        widget.lowResFactor != old.lowResFactor) {
      final spec = builtInWallpaperSpec(widget.wallpaper);
      _field = _BlobField(spec, widget.lowResFactor);
      _throttle.reset();
    }
    if (widget.animate != old.animate) {
      if (widget.animate) {
        WidgetsBinding.instance.addObserver(this);
        _ticker = createTicker(_onTick)..start();
      } else {
        _ticker?.dispose();
        _ticker = null;
        WidgetsBinding.instance.removeObserver(this);
        _throttle.reset();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ticker = _ticker;
    if (ticker == null) {
      return;
    }
    final active = state == AppLifecycleState.resumed;
    if (active && !ticker.isActive) {
      _throttle.reset();
      ticker.start();
    } else if (!active && ticker.isActive) {
      ticker.stop();
    }
  }

  @override
  void dispose() {
    if (_ticker != null) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _ticker?.dispose();
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

/// 把不规则的 Ticker 回调聚合成稳定的目标帧节拍。
///
/// 三条关键约定，都是踩过的坑：
///
/// 1. **阈值必须是整数微秒。** `Duration.inMicroseconds` 是整数，若拿
///    `1000000 / targetFps` 的 double（33333.333…）当阈值，恰好等于 33333µs
///    的那一帧会被判成「还没到间隔」而整帧丢弃、时间累积到下一帧 ——
///    60Hz 屏稳定退化成 33/50ms 交替（实际 20fps），120Hz 屏在 33/42ms
///    之间来回跳。
/// 2. **用累积判定，而不是单帧 dt 与阈值比大小**，并留出 [toleranceUs] 的
///    提前量吸收引擎时间戳抖动。两者缺一都会让节拍塌到下一档。
/// 3. 返回的 dt 始终是**真实经过的时间**，所以节流只影响重绘节拍、不影响
///    光斑轨迹；真的掉帧时它自然就大。
///
/// 另：起始判定用显式的 [_hasBaseline] 而非 `_last == Duration.zero` 哨兵 ——
/// 后者在 Ticker 首次回调恰好为 0 时会把标称步长走两次。
@visibleForTesting
class FrameThrottle {
  FrameThrottle(this.targetFps);

  final int targetFps;

  /// 结算阈值上的提前量。
  ///
  /// Ticker 的 `elapsed` 来自引擎时间戳，并不是精确的 1/hz，会有几百微秒的
  /// 抖动。若严格要求累积量 ≥ 目标间隔才结算，抖动会让相当一部分本该
  /// 「2 帧一推」的节拍被推迟到「3 帧一推」—— 实测 60Hz ±300µs 抖动下平均
  /// 间隔从 33.3ms 掉到 40.1ms（约 25fps）。留 2ms 提前量即可吸收这类抖动，
  /// 而它远小于任何常见刷新率的单帧间隔（240Hz 也有 4.17ms），不会误触发到
  /// 更短的节拍上。
  static const int toleranceUs = 2000;

  Duration _last = Duration.zero;
  int _pendingUs = 0;
  bool _hasBaseline = false;

  /// 目标帧间隔（整数微秒）。
  int get intervalUs => (1000000 / targetFps).round();

  /// 触发结算的累积量下限。
  int get _thresholdUs => intervalUs - toleranceUs;

  /// 喂入一次 Ticker 回调。
  ///
  /// 返回本次应当推进的秒数；`null` 表示这一帧还不到目标间隔，不推进也不重绘。
  /// 返回值始终是**真实经过的时间**，所以光斑轨迹不会因节流而漂移。
  double? tick(Duration elapsed) {
    if (!_hasBaseline) {
      // 起始帧（首次启动、resume、换壁纸后的第一帧）：走一个标称步长，
      // 不把暂停期间的真实时长灌进来。
      _hasBaseline = true;
      _last = elapsed;
      _pendingUs = 0;
      return 1 / targetFps;
    }
    _pendingUs += (elapsed - _last).inMicroseconds;
    _last = elapsed;
    if (_pendingUs < _thresholdUs) {
      return null;
    }
    final dt = _pendingUs / 1000000.0;
    _pendingUs = 0;
    return dt;
  }

  /// 重置时间基准：下一次 [tick] 会重新走起始分支。
  void reset() {
    _last = Duration.zero;
    _pendingUs = 0;
    _hasBaseline = false;
  }
}
