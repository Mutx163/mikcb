import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 内置壁纸（无需联网、不占用户存储）。
///
/// 完整移植自 [bokeh-lava-gradient](https://github.com/keepYaoung/bokeh-lava-gradient)
/// （MIT，© keepYaoung / tommy / joon shin）的 7 个预设：`og` + 3 浅色 + 3 深色。
/// 首页显示层用 [BokehLavaGradient] 做光斑漂移动画；亮度采样与预模糊玻璃
/// 仍走 [renderBuiltInWallpaperImage] 静态位图（可播种、与动画首帧同构）。
enum BuiltInWallpaper {
  /// 原版 `og`：烧橙底 + 暖橙光斑（默认原作配色）。
  og,

  /// 原版 `light1`：奶油底 + 蜜桃/杏色光斑（轻盈，适合日间）。
  /// 持久化主键保持历史值 `lava_light`。
  lavaLight,

  /// 原版 `light2`：近白奶油底 + 鼠尾草绿/陶土光斑。
  light2,

  /// 原版 `light3`：暖奶油底 + 橄榄/大地色光斑。
  light3,

  /// 原版 `dark1`：深烧橙底 + 亮橙/琥珀光斑。
  dark1,

  /// 原版 `dark2`：近黑底 + 强橙光斑（高对比，适合夜间）。
  /// 持久化主键保持历史值 `lava_dark`。
  lavaDark,

  /// 原版 `dark3`：黑底 + 青绿/橙色互补光斑。
  /// 持久化主键保持历史值 `ember_teal`。
  emberTeal;

  /// 稳定持久化主键（[name] 会随枚举重命名变化，故单列）。
  ///
  /// 历史用户数据里的 `lava_dark` / `lava_light` / `ember_teal` 继续认。
  String get value => switch (this) {
    BuiltInWallpaper.og => 'og',
    BuiltInWallpaper.lavaLight => 'lava_light',
    BuiltInWallpaper.light2 => 'light2',
    BuiltInWallpaper.light3 => 'light3',
    BuiltInWallpaper.dark1 => 'dark1',
    BuiltInWallpaper.lavaDark => 'lava_dark',
    BuiltInWallpaper.emberTeal => 'ember_teal',
  };

  static BuiltInWallpaper? fromValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final item in BuiltInWallpaper.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

/// 背景身份键里内置壁纸的前缀（见 `homePageBackdropKey`）。
///
/// 图片壁纸的身份键就是文件路径，内置壁纸没有文件，用这个前缀区分；
/// 预模糊位图缓存与亮度采样都靠它把键还原成预设。
const String kBuiltInWallpaperKeyPrefix = 'builtin:';

/// 内置壁纸的身份键（`builtin:<预设>`）。
String builtInWallpaperKey(BuiltInWallpaper wallpaper) =>
    '$kBuiltInWallpaperKeyPrefix${wallpaper.value}';

/// 一个内置壁纸预设的完整绘制参数。
class BuiltInWallpaperSpec {
  const BuiltInWallpaperSpec({
    required this.base,
    required this.colors,
    required this.opacity,
    required this.brightness,
    this.blobCount = 12,
    this.minBlobRadius = 0.30,
    this.maxBlobRadius = 1.0,
    this.blurStrength = 0.05,
    this.speed = 1.0,
    this.seed = 7,
  });

  /// 光斑背后的底色。
  final Color base;

  /// 光斑循环使用的颜色（与原包预设一致）。
  final List<Color> colors;

  /// 光斑不透明度；小于 1 时重叠光斑之间会混色。
  final double opacity;

  /// 内容叠在该背景上时应使用的明暗极性。
  final Brightness brightness;

  final int blobCount;
  final double minBlobRadius;
  final double maxBlobRadius;

  /// 模糊 sigma 占短边的比例（bokeh 强度）。
  final double blurStrength;

  /// 光斑漂移速度（1 = 原版默认）。
  final double speed;

  /// 静态位图 / 动画首帧的随机种子：同一预设每次渲染都一致，
  /// 保证「内置壁纸」在预览、亮度采样与首页首帧之间画面完全相同。
  final int seed;
}

const Map<BuiltInWallpaper, BuiltInWallpaperSpec> _kSpecs = {
  // og — bright burnt base + 9-color orange gradient
  BuiltInWallpaper.og: BuiltInWallpaperSpec(
    base: Color(0xFFC65318),
    colors: [
      Color(0xFFFFE6B8),
      Color(0xFFFFD089),
      Color(0xFFFFB85C),
      Color(0xFFFF9A43),
      Color(0xFFFC7C2C),
      Color(0xFFF26019),
      Color(0xFFD94E10),
      Color(0xFFFFCBA0),
      Color(0xFF932D00),
    ],
    opacity: 0.85,
    brightness: Brightness.dark,
  ),
  // light1（lavaLight）— cream base + pastel peach/apricot
  BuiltInWallpaper.lavaLight: BuiltInWallpaperSpec(
    base: Color(0xFFFFF1E2),
    colors: [
      Color(0xFFFFE0C8),
      Color(0xFFFFD3B0),
      Color(0xFFFFC9A8),
      Color(0xFFFFE6D6),
      Color(0xFFFAD4B8),
      Color(0xFFFFBE99),
      Color(0xFFFFEAD2),
    ],
    opacity: 0.60,
    brightness: Brightness.light,
    seed: 23,
  ),
  // light2 — near-white cream + sage/terracotta; opacity raised so blobs
  // do not wash out on the pale base.
  BuiltInWallpaper.light2: BuiltInWallpaperSpec(
    base: Color(0xFFFFF8EE),
    colors: [
      Color(0xFF9BBF8E),
      Color(0xFFAE5C34),
      Color(0xFFECF2E5),
      Color(0xFFFFF4D8),
    ],
    opacity: 0.80,
    brightness: Brightness.light,
    seed: 41,
  ),
  // light3 — warm cream + sage/olive/terracotta earth tones
  BuiltInWallpaper.light3: BuiltInWallpaperSpec(
    base: Color(0xFFF7E0B6),
    colors: [
      Color(0xFF5E8863),
      Color(0xFF1C1F16),
      Color(0xFFAE5C34),
      Color(0xFF9BBF8E),
      Color(0xFFFFF4D8),
    ],
    opacity: 0.60,
    brightness: Brightness.light,
    seed: 59,
  ),
  // dark1 — deep burnt base + glowing orange/amber
  BuiltInWallpaper.dark1: BuiltInWallpaperSpec(
    base: Color(0xFF8F2C00),
    colors: [
      Color(0xFFFFE6B8),
      Color(0xFFFFD089),
      Color(0xFFFFB85C),
      Color(0xFFFF9A43),
      Color(0xFFFC7C2C),
      Color(0xFFF26019),
      Color(0xFFD94E10),
      Color(0xFFFFCBA0),
      Color(0xFF932D00),
    ],
    opacity: 0.85,
    brightness: Brightness.dark,
    seed: 17,
  ),
  // dark2（lavaDark）— near-black + strong orange glow
  BuiltInWallpaper.lavaDark: BuiltInWallpaperSpec(
    base: Color(0xFF160B04),
    colors: [
      Color(0xFFFF8A2A),
      Color(0xFFFF6A14),
      Color(0xFFFFB152),
      Color(0xFFFFC97A),
      Color(0xFFE2530E),
      Color(0xFF7A2600),
      Color(0xFFFFD089),
    ],
    opacity: 0.90,
    brightness: Brightness.dark,
    seed: 11,
  ),
  // dark3（emberTeal）— black + teal/green complementary + orange on top
  BuiltInWallpaper.emberTeal: BuiltInWallpaperSpec(
    base: Color(0xFF000000),
    colors: [
      Color(0xFF09353C),
      Color(0xFF64AA74),
      Color(0xFF034753),
      Color(0xFFC15B2E),
      Color(0xFFB14415),
      Color(0xFFC15B2E),
      Color(0xFFB14415),
    ],
    opacity: 0.72,
    brightness: Brightness.dark,
    seed: 37,
  ),
};

BuiltInWallpaperSpec builtInWallpaperSpec(BuiltInWallpaper wallpaper) =>
    _kSpecs[wallpaper]!;

/// 内置壁纸的静态渲染尺寸。
///
/// 与首页壁纸解码宽度同量级即可：光斑本身是低频模糊内容，
/// 放大到全屏不会暴露细节，小尺寸可以显著降低模糊与内存开销。
const int kBuiltInWallpaperWidth = 720;
const int kBuiltInWallpaperHeight = 1600;

/// 从 [spec] 的 seed 生成光斑初始布局，供静态位图与动画首帧共用。
///
/// 与原版动画的 `_BlobField.ensureSize` 同构：半径 = 短边 × [min,max] 区间，
/// 速度 = 短边比例/秒。返回记录：`(x, y, vx, vy, r)`。
List<({double x, double y, double vx, double vy, double r})>
builtInWallpaperSeededBlobs(
  BuiltInWallpaperSpec spec,
  Size size,
) {
  final shortest = size.shortestSide;
  final random = math.Random(spec.seed);
  return [
    for (var i = 0; i < spec.blobCount; i++)
      (
        x: random.nextDouble() * size.width,
        y: random.nextDouble() * size.height,
        vx: _seededVelocity(random, shortest, spec.speed),
        vy: _seededVelocity(random, shortest, spec.speed),
        r: shortest *
            (spec.minBlobRadius +
                (spec.maxBlobRadius - spec.minBlobRadius) *
                    random.nextDouble()),
      ),
  ];
}

double _seededVelocity(math.Random random, double shortest, double speed) =>
    (random.nextBool() ? 1 : -1) *
    (0.3 + 0.9 * random.nextDouble()) *
    speed *
    shortest *
    0.06;

/// 把光斑场推进 [elapsed] 秒（与动画同款边界反弹）。
///
/// 供 chrome 墨色在动画壁纸上做「当前画面」亮度估算，无需 GPU 重绘。
List<({double x, double y, double vx, double vy, double r})>
advanceBuiltInWallpaperBlobs(
  List<({double x, double y, double vx, double vy, double r})> blobs,
  Size size,
  double elapsedSeconds,
) {
  if (blobs.isEmpty || elapsedSeconds <= 0) {
    return blobs;
  }
  return [
    for (final b in blobs)
      _advanceBlob(b, size, elapsedSeconds),
  ];
}

({double x, double y, double vx, double vy, double r}) _advanceBlob(
  ({double x, double y, double vx, double vy, double r}) b,
  Size size,
  double dt,
) {
  var x = b.x + b.vx * dt;
  var y = b.y + b.vy * dt;
  var vx = b.vx;
  var vy = b.vy;
  final mx = b.r * 0.4;
  if (x < -mx) {
    x = -mx;
    vx = -vx;
  } else if (x > size.width + mx) {
    x = size.width + mx;
    vx = -vx;
  }
  if (y < -mx) {
    y = -mx;
    vy = -vy;
  } else if (y > size.height + mx) {
    y = size.height + mx;
    vy = -vy;
  }
  return (x: x, y: y, vx: vx, vy: vy, r: b.r);
}

/// 估算内置壁纸在动画时刻 [elapsed] 的三条亮度带。
///
/// 单位空间近似（无视口 crop）：目的只是让顶栏/星期栏墨色跟上漂移亮斑，
/// 不追求与 GPU cover 采样像素级一致。课程卡片走自己的表面色，不读这里。
({double top, double weekday, double body}) estimateBuiltInWallpaperBandsAt(
  BuiltInWallpaper wallpaper,
  Duration elapsed,
) {
  final spec = builtInWallpaperSpec(wallpaper);
  const size = Size(1, 1);
  final blobs = advanceBuiltInWallpaperBlobs(
    builtInWallpaperSeededBlobs(spec, size),
    size,
    elapsed.inMicroseconds / 1e6,
  );
  final base = _srgbLuminanceOf(spec.base);
  final blobLuma = [
    for (final c in spec.colors) _srgbLuminanceOf(c),
  ];

  double bandLuma(double fromFrac, double toFrac) {
    const rows = 7;
    const cols = 5;
    var total = 0.0;
    var count = 0;
    for (var row = 0; row < rows; row++) {
      final y = fromFrac + (toFrac - fromFrac) * (row + 0.5) / rows;
      for (var col = 0; col < cols; col++) {
        final x = (col + 0.5) / cols;
        var luma = base;
        for (var i = 0; i < blobs.length; i++) {
          final b = blobs[i];
          final dx = x - b.x;
          final dy = y - b.y;
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist >= b.r) {
            continue;
          }
          // 与 RadialGradient 核心段 [0, 0.45] 同构的软混合。
          final t = (1 - dist / b.r).clamp(0.0, 1.0);
          final weight = t * t * spec.opacity;
          luma = luma * (1 - weight) + blobLuma[i % blobLuma.length] * weight;
        }
        total += luma;
        count++;
      }
    }
    return count == 0 ? base : total / count;
  }

  return (
    top: bandLuma(0, 0.12),
    weekday: bandLuma(0.12, 0.20),
    body: bandLuma(0.20, 1),
  );
}

double _srgbLuminanceOf(Color color) {
  double lin(int c) {
    final v = c / 255.0;
    if (v <= 0.03928) {
      return v / 12.92;
    }
    return math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * lin((color.r * 255).round()) +
      0.7152 * lin((color.g * 255).round()) +
      0.0722 * lin((color.b * 255).round());
}

/// 把内置壁纸渲染成一张静态位图，供亮度采样 / 预模糊玻璃复用。
///
/// 首页**显示**层走 [BokehLavaGradient] 动画；本入口只服务「需要单帧像素」
/// 的管线（墨色极性、玻璃带采样），因此刻意不带动画——与动画首帧同 seed
/// 同构，画面观感一致。
Future<ui.Image> renderBuiltInWallpaperImage(
  BuiltInWallpaper wallpaper, {
  int width = kBuiltInWallpaperWidth,
  int height = kBuiltInWallpaperHeight,
}) async {
  final spec = builtInWallpaperSpec(wallpaper);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  canvas.drawRect(Offset.zero & size, Paint()..color = spec.base);

  final shortest = size.shortestSide;
  final blobs = builtInWallpaperSeededBlobs(spec, size);
  final paintColors = [
    for (final color in spec.colors) color.withValues(alpha: spec.opacity),
  ];

  final layerRecorder = ui.PictureRecorder();
  final layerCanvas = Canvas(layerRecorder);
  for (var i = 0; i < blobs.length; i++) {
    final b = blobs[i];
    final color = paintColors[i % paintColors.length];
    final shader = RadialGradient(
      colors: [color, color, color.withValues(alpha: 0)],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(b.x, b.y), radius: b.r));
    layerCanvas.drawCircle(Offset(b.x, b.y), b.r, Paint()..shader = shader);
  }
  final layer = layerRecorder.endRecording();
  canvas.saveLayer(
    Offset.zero & size,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: shortest * spec.blurStrength,
        sigmaY: shortest * spec.blurStrength,
        // clamp 而非 decal：光斑渐变会一路铺到画布边界，decal 把界外当透明，
        // 模糊后四周会留一圈渐隐并透出底色。必须与动画层
        // （BokehLavaGradient 的 ImageFiltered）严格同口径 —— 首帧与这份
        // 位图是「同构」承诺，亮度采样与预模糊玻璃都建立在这个不变量上。
        tileMode: TileMode.clamp,
      ),
  );
  canvas.drawPicture(layer);
  canvas.restore();
  layer.dispose();

  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

/// 内置壁纸对应的 [ImageProvider]，按预设缓存同一份静态位图。
///
/// [ImageProvider] 契约要求相等性稳定，这里用预设作为相等键，避免每次
/// build 都重新渲染一张全屏位图。
@immutable
class BuiltInWallpaperImage extends ImageProvider<BuiltInWallpaperImage> {
  const BuiltInWallpaperImage(this.wallpaper);

  final BuiltInWallpaper wallpaper;

  @override
  Future<BuiltInWallpaperImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BuiltInWallpaperImage>(this);

  @override
  ImageStreamCompleter loadImage(
    BuiltInWallpaperImage key,
    ImageDecoderCallback decode,
  ) {
    // 位图由代码渲染，不走字节解码；[decode] 仍接收以满足 ImageProvider
    // 契约（ResizeImage 等包装器会自行处理尺寸）。
    return OneFrameImageStreamCompleter(_render());
  }

  Future<ImageInfo> _render() async {
    final image = await renderBuiltInWallpaperImage(wallpaper);
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuiltInWallpaperImage && other.wallpaper == wallpaper;

  @override
  int get hashCode => wallpaper.hashCode;

  @override
  String toString() => 'BuiltInWallpaperImage(${wallpaper.value})';
}

/// 渲染内置壁纸并采样顶部亮度，供状态栏 / 顶栏墨色极性使用。
///
/// 与 [sampleHomePageWallpaperTopLuminance] 同口径：按 [viewportSize] 做
/// cover 裁剪后取顶部条带，保证内置壁纸和图片壁纸的自动黑白结果一致。
/// [width]/[height] 仅供测试缩小渲染尺寸，生产路径用默认全尺寸。
Future<double?> sampleBuiltInWallpaperTopLuminance(
  BuiltInWallpaper wallpaper, {
  Size? viewportSize,
  int? width,
  int? height,
}) async {
  final image = await renderBuiltInWallpaperImage(
    wallpaper,
    width: width ?? kBuiltInWallpaperWidth,
    height: height ?? kBuiltInWallpaperHeight,
  );
  try {
    final byteData = await image.toByteData();
    if (byteData == null) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final buffer = byteData.buffer.asUint8List();
    var total = 0.0;
    var count = 0;
    // 顶部 9% 条带，与图片壁纸的 top band 同义。
    const fromRow = 0;
    final toRow = math.max(1, (height * 0.09).ceil());
    for (var row = fromRow; row < toRow; row++) {
      final rowOffset = row * width * 4;
      for (var column = 0; column < width; column++) {
        final offset = rowOffset + column * 4;
        final red = _linearize(buffer[offset]);
        final green = _linearize(buffer[offset + 1]);
        final blue = _linearize(buffer[offset + 2]);
        total += 0.2126 * red + 0.7152 * green + 0.0722 * blue;
        count++;
      }
    }
    return count == 0 ? null : total / count;
  } finally {
    image.dispose();
  }
}

double _linearize(int component) {
  final value = component / 255.0;
  if (value <= 0.03928) {
    return value / 12.92;
  }
  return math.pow((value + 0.055) / 1.055, 2.4) as double;
}
