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

  // ---------------------------------------------------------------------
  // 光学参数：一律 **dp 绝对值**（上游 `GlassRefractionSpec` 同口径）
  // ---------------------------------------------------------------------
  //
  // 早先按「占控件高度的比例」（18/54）表达，只对 54dp 药丸成立——同一组比例
  // 套到大面板上会算出巨大的透镜，于是当时被迫加了「面板不挂透镜」的尺寸闸门。
  // 改成绝对值后，药丸、圆钮、弹层、面板共用同一套透镜，闸门随之撤掉。
  // 出滤镜时按 devicePixelRatio 折成物理像素（shader 全程用物理像素）。

  /// 折射带宽度（dp）—— 上游 `GlassRefractionSpec.height`。
  static const double refractionHeightDp = 18;

  /// 最大折射位移（dp）—— 上游 `GlassRefractionSpec.amount`。
  static const double refractionAmountDp = 18;

  /// 色散偏移（dp）—— 上游 `GlassRefractionSpec.chromaticAberration`。
  static const double chromaticAberrationDp = 1;

  /// 噪声系数：原版 noiseCoefficient。
  static const double noiseCoefficient = 0.095;

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
  SoftGlassRefractionLens._(this._shader);

  final ui.FragmentShader _shader;
  bool _disposed = false;

  /// 按控件在 backdrop 快照中的矩形出滤镜。
  ///
  /// 几何量一律是**物理像素**：
  /// * [geometry]：控件矩形，取全局逻辑坐标 × devicePixelRatio；
  /// * [viewSize]：视图物理尺寸（判断引擎给的是整屏快照还是已裁到控件）；
  /// * [cornerRadiusPx]：实际形状的圆角半径，胶囊传短边一半。shader 内部会再
  ///   夹一次上限，这里不必自己夹。
  ///
  /// 下标 0/1 是 `u_size`，由引擎按绑定纹理尺寸写入，这里**不能**设。
  ui.ImageFilter filterFor(
    Rect geometry,
    ui.Size viewSize, {
    required double devicePixelRatio,
    required double cornerRadiusPx,
  }) {
    assert(!_disposed, 'SoftGlassRefractionLens 已释放，不能继续出滤镜');
    final dpr = devicePixelRatio;
    _shader
      ..setFloat(2, geometry.left)
      ..setFloat(3, geometry.top)
      ..setFloat(4, geometry.width)
      ..setFloat(5, geometry.height)
      ..setFloat(6, SoftGlassRefraction.refractionHeightDp * dpr)
      ..setFloat(7, SoftGlassRefraction.refractionAmountDp * dpr)
      ..setFloat(8, SoftGlassRefraction.chromaticAberrationDp * dpr)
      ..setFloat(9, SoftGlassRefraction.noiseCoefficient)
      ..setFloat(10, viewSize.width)
      ..setFloat(11, viewSize.height)
      ..setFloat(12, cornerRadiusPx);
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
