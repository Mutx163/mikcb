// BokehLavaGradient —— bokeh / lava 渐变背景（静态版）。
//
// 移植自 bokeh-lava-gradient（MIT License，© keepYaoung / tommy / joon shin）
// https://github.com/keepYaoung/bokeh-lava-gradient
//
// 与原包的差异（按本仓库壁纸链路收敛）：
//   - 去掉 Ticker 逐帧动画：内置壁纸作为「静态背景位图」参与亮度采样与
//     预模糊玻璃，动画会与缓存位图不一致，也增加耗电。
//   - 随机分布改为可播种的随机数生成器，同一预设每次渲染完全一致。
// 原 MIT 许可与版权信息见 docs/THIRD_PARTY_LICENSES.md。

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'builtin_wallpaper.dart';

/// 内置壁纸的静态渲染 Widget（预览用）。
///
/// 首页使用 [BuiltInWallpaperImage] 位图入口（复用壁纸管线），本 Widget 只
/// 用于设置页缩略图预览，两者共用同一份 [BuiltInWallpaperSpec] 参数。
class BokehLavaGradient extends StatelessWidget {
  const BokehLavaGradient({super.key, required this.wallpaper, this.child});

  final BuiltInWallpaper wallpaper;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final spec = builtInWallpaperSpec(wallpaper);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: spec.base),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 0.0;
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0.0;
            if (width <= 0 || height <= 0) {
              return const SizedBox.shrink();
            }
            return ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: math.max(0.1, _blurSigma(spec, width, height)),
                sigmaY: math.max(0.1, _blurSigma(spec, width, height)),
                tileMode: TileMode.decal,
              ),
              child: CustomPaint(
                painter: _BlobPainter(spec),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// 模糊 sigma：短边 × blurStrength，与原包的 lowRes 方案等效。
double _blurSigma(BuiltInWallpaperSpec spec, double width, double height) =>
    math.min(width, height) * spec.blurStrength;

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.spec);

  final BuiltInWallpaperSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final random = math.Random(spec.seed);
    final colors = [
      for (final color in spec.colors) color.withValues(alpha: spec.opacity),
    ];
    for (var i = 0; i < spec.blobCount; i++) {
      final radius =
          shortest *
          (spec.minBlobRadius +
              (spec.maxBlobRadius - spec.minBlobRadius) * random.nextDouble());
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final color = colors[i % colors.length];
      final shader = RadialGradient(
        colors: [color, color, color.withValues(alpha: 0)],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) => oldDelegate.spec != spec;
}
