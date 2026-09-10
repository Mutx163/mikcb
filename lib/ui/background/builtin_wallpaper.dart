import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 内置壁纸（无需联网、不占用户存储）。
///
/// 接入自 [bokeh-lava-gradient](https://github.com/keepYaoung/bokeh-lava-gradient)
/// （MIT，© keepYaoung / tommy / joon shin）的动画 bokeh 渐变：多个柔和的
/// 径向渐变光斑在模糊层下缓慢漂移，整体铺满屏幕。
///
/// 这里**内联移植**而不是加 git 依赖：一是依赖会引入包解析与 CI 网络风险，
/// 二是本仓库壁纸链路（亮度采样、预模糊玻璃、备份）都按「文件路径」建模，
/// 内置壁纸需要一个由代码生成的位图入口，移植后可以直接复用同一套管线。
enum BuiltInWallpaper {
  /// 深色：近黑底 + 橙/琥珀光斑（高对比，适合夜间）。
  lavaDark,

  /// 浅色：奶油底 + 蜜桃/杏色光斑（轻盈，适合日间）。
  lavaLight,

  /// 深色：黑底 + 青绿/橙色互补光斑。
  emberTeal;

  /// 稳定持久化主键（[name] 会随枚举重命名变化，故单列）。
  String get value => switch (this) {
    BuiltInWallpaper.lavaDark => 'lava_dark',
    BuiltInWallpaper.lavaLight => 'lava_light',
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
    this.seed = 7,
  });

  /// 光斑背后的底色。
  final Color base;

  /// 光斑循环使用的颜色（与原包的 `og` / `light1` / `dark3` 预设一致）。
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

  /// 光斑初始分布与速度的随机种子：同一预设每次渲染都一致，
  /// 保证「内置壁纸」在预览、亮度采样与首页之间画面完全相同。
  final int seed;
}

const Map<BuiltInWallpaper, BuiltInWallpaperSpec> _kSpecs = {
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

/// 把内置壁纸渲染成一张位图，供 ImageProvider / 亮度采样复用。
///
/// 之所以渲染成位图而不是直接画 Widget：首页玻璃（预模糊位图、玻璃带采样）
/// 与墨色极性都按「背景图文件」建模，位图入口能让内置壁纸无缝复用整套
/// 管线，且 `toImage` 只在首个请求时执行一次（由调用方缓存）。
Future<ui.Image> renderBuiltInWallpaperImage(
  BuiltInWallpaper wallpaper, {
  int width = kBuiltInWallpaperWidth,
  int height = kBuiltInWallpaperHeight,
}) async {
  final spec = builtInWallpaperSpec(wallpaper);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  // 与 BokehLavaGradient 完全同构：底色 + 低分辨率模糊层上的光斑。
  canvas.drawRect(Offset.zero & size, Paint()..color = spec.base);

  final shortest = size.shortestSide;
  final random = math.Random(spec.seed);
  final paintColors = [
    for (final color in spec.colors) color.withValues(alpha: spec.opacity),
  ];

  final layerRecorder = ui.PictureRecorder();
  final layerCanvas = Canvas(layerRecorder);
  for (var i = 0; i < spec.blobCount; i++) {
    final radius =
        shortest *
        (spec.minBlobRadius +
            (spec.maxBlobRadius - spec.minBlobRadius) * random.nextDouble());
    final center = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final color = paintColors[i % paintColors.length];
    final shader = RadialGradient(
      colors: [color, color, color.withValues(alpha: 0)],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    layerCanvas.drawCircle(center, radius, Paint()..shader = shader);
  }
  final layer = layerRecorder.endRecording();
  // 光斑层整体高斯模糊 → bokeh。sigma 与 [BokehLavaGradient] 同源（短边 ×
  // blurStrength），保证设置页缩略图与首页位图是同一张画面。
  canvas.saveLayer(
    Offset.zero & size,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: shortest * spec.blurStrength,
        sigmaY: shortest * spec.blurStrength,
        tileMode: TileMode.decal,
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

/// 内置壁纸对应的 [ImageProvider]，按预设缓存同一份位图。
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
Future<double?> sampleBuiltInWallpaperTopLuminance(
  BuiltInWallpaper wallpaper, {
  Size? viewportSize,
}) async {
  final image = await renderBuiltInWallpaperImage(wallpaper);
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
