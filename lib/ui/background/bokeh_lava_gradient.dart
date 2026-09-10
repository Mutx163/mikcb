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

  /// 模糊缓冲分辨率因子（0–1）。约 0.45 时观感与全分辨率几乎一致。
  final double lowResFactor;

  /// 目标帧率；漂移很慢，约 30 足够。
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
  Duration _last = Duration.zero;

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
    final intervalUs = 1000000 / widget.targetFps;
    final dtUs = (elapsed - _last).inMicroseconds;
    if (_last != Duration.zero && dtUs < intervalUs) {
      return;
    }
    final dt = _last == Duration.zero
        ? 1 / widget.targetFps
        : dtUs / 1000000.0;
    _last = elapsed;
    _field.tick(dt);
    _repaint.value++;
  }

  @override
  void didUpdateWidget(covariant BokehLavaGradient old) {
    super.didUpdateWidget(old);
    if (widget.wallpaper != old.wallpaper ||
        widget.lowResFactor != old.lowResFactor) {
      final spec = builtInWallpaperSpec(widget.wallpaper);
      _field = _BlobField(spec, widget.lowResFactor);
      _last = Duration.zero;
    }
    if (widget.animate != old.animate) {
      if (widget.animate) {
        WidgetsBinding.instance.addObserver(this);
        _ticker = createTicker(_onTick)..start();
      } else {
        _ticker?.dispose();
        _ticker = null;
        WidgetsBinding.instance.removeObserver(this);
        _last = Duration.zero;
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
      _last = Duration.zero;
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
        final paintColors = [
          for (final c in spec.colors)
            c.withValues(alpha: spec.opacity),
        ];

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
                  filterQuality: FilterQuality.low,
                  child: SizedBox(
                    width: lowW,
                    height: lowH,
                    child: RepaintBoundary(
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                          tileMode: TileMode.decal,
                        ),
                        child: CustomPaint(
                          painter: _BlobPainter(
                            _field,
                            paintColors,
                            _repaint,
                          ),
                          child: const SizedBox.expand(),
                        ),
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
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.field, this.colors, Listenable repaint)
    : super(repaint: repaint);

  final _BlobField field;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    field.ensureSize(size);
    for (var i = 0; i < field.blobs.length; i++) {
      final b = field.blobs[i];
      final c = colors[i % colors.length];
      final center = Offset(b.x, b.y);
      final shader = RadialGradient(
        colors: [c, c, c.withValues(alpha: 0)],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: b.r));
      canvas.drawCircle(center, b.r, Paint()..shader = shader);
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

  void ensureSize(Size newSize) {
    // 模糊缓冲是低分辨率：种子布局按缓冲尺寸换算，与静态全分辨率首帧
    // 在归一化空间一致（速度也按短边比例，与分辨率无关）。
    if (newSize == size && blobs.isNotEmpty) {
      return;
    }
    size = newSize;
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
