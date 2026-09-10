import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show Rect;

/// 柔光玻璃折射滤镜（`shaders/soft_glass_refraction.frag`）的装载与装配。
///
/// 整条折射路径是可选的：只要当前后端跑不了 `ImageFilter.shader`（该 API 仅
/// Impeller 支持），或资源装载失败，[available] 即为 false，调用方退回纯高斯
/// + 描边路径。柔光玻璃必须在任何后端上都能画出来。
///
/// **每个玻璃面必须独占一个 [SoftGlassRefractionLens]。** 折射几何（控件在
/// backdrop 快照里的位置）只有在 paint 时实测才知道，而 `FragmentShader` 的
/// uniform 状态是随对象共享的——同一个 shader 实例被两个面同时上屏会互相串值。
abstract final class SoftGlassRefraction {
  /// 一键关停开关。现场排查「玻璃发黑 / 发白」时置 false，即可让柔光玻璃
  /// 整体退回纯高斯路径，用来判断问题出在折射 shader 还是 token。
  static const bool enabled = true;

  static const String assetKey = 'shaders/soft_glass_refraction.frag';

  /// 折射位移带宽度占控件高度的比例：原版 refraction_height 18dp，
  /// 作用面为 54dp 药丸 / 56dp 圆钮，取 18/54。
  static const double bandFraction = 18 / 54;

  /// 最大折射位移占控件高度的比例：原版 refraction_amount 18dp。
  static const double amountFraction = 18 / 54;

  /// 色散偏移占控件高度的比例：原版 chromatic_aberration 1dp。
  static const double chromaticFraction = 1 / 54;

  /// 噪声系数：原版 noiseCoefficient。
  static const double noiseCoefficient = 0.095;

  /// 折射 shader 只用于这类小尺寸浮层；大面板一律走高斯（见 [maxSurfaceHeight]）。
  static const double maxSurfaceHeight = 72;

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// 当前后端（仅 Impeller）是否支持 `ImageFilter.shader`。
  static bool get backendSupported => ui.ImageFilter.isShaderFilterSupported;

  /// 折射路径是否可用。
  static bool get available => enabled && backendSupported && _program != null;

  /// 预加载 shader。可安全重复调用（共享同一个 Future），失败只吞掉不抛异常。
  static Future<void> warmUp() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    if (!enabled || !backendSupported) {
      return;
    }
    try {
      _program = await ui.FragmentProgram.fromAsset(assetKey);
    } catch (_) {
      _program = null;
    }
  }

  /// 取一个折射透镜（每块玻璃面一个）。不可用时返回 null，调用方走回退路径。
  static SoftGlassRefractionLens? createLens() {
    final program = _program;
    if (program == null) {
      return null;
    }
    return SoftGlassRefractionLens._(program.fragmentShader());
  }
}

/// 单块玻璃面的折射透镜：持有一个独占的 [ui.FragmentShader]，按实测几何出滤镜。
class SoftGlassRefractionLens {
  SoftGlassRefractionLens._(this._shader) {
    // 常量参数只设一次。下标 0/1 是 u_size，由引擎按绑定纹理尺寸写入，这里
    // **不能**设；几何（下标 2–5）每次出滤镜时按实测值刷新。
    _shader
      ..setFloat(6, SoftGlassRefraction.bandFraction)
      ..setFloat(7, SoftGlassRefraction.amountFraction)
      ..setFloat(8, SoftGlassRefraction.chromaticFraction)
      ..setFloat(9, SoftGlassRefraction.noiseCoefficient);
  }

  final ui.FragmentShader _shader;
  bool _disposed = false;

  /// 按控件在 backdrop 快照中的矩形（物理像素）出滤镜。
  ///
  /// [geometry] 必须是**全局逻辑坐标 × devicePixelRatio**：引擎给 shader 的
  /// `FlutterFragCoord()` 落在 backdrop 快照纹理空间里，而该快照是整屏范围的。
  ui.ImageFilter filterFor(Rect geometry, ui.Size viewSize) {
    assert(!_disposed, 'SoftGlassRefractionLens 已释放，不能继续出滤镜');
    _shader
      ..setFloat(2, geometry.left)
      ..setFloat(3, geometry.top)
      ..setFloat(4, geometry.width)
      ..setFloat(5, geometry.height)
      ..setFloat(10, viewSize.width)
      ..setFloat(11, viewSize.height);
    return ui.ImageFilter.shader(_shader);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _shader.dispose();
  }
}
