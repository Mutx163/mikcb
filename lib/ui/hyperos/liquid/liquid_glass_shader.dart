import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color, Offset;

import '../../../widgets/glass_shader_program.dart';

/// 全局液态玻璃表面的片元程序。
///
/// 与课程卡片那份（`CourseCardGlassShader`）共用同一个加载器基类，但**是两个
/// 独立的程序**：卡片吃的是预模糊壁纸位图、按局部坐标画；这里吃的是
/// `BackdropFilter` 的实时背景、按屏幕坐标画（见 `glass_surface_refraction.frag`
/// 的坐标系说明）。两者折射数学同源，参数默认值也刻意对齐——见
/// [LiquidGlassStyle] 与 `CourseGlassStyle` 的字段注释。
class LiquidGlassSurfaceShader extends GlassShaderProgram {
  LiquidGlassSurfaceShader._()
    : super(
        assetKey: 'shaders/glass_surface_refraction.frag',
        debugLabel: 'LiquidGlassSurfaceShader',
      );

  static final LiquidGlassSurfaceShader instance = LiquidGlassSurfaceShader._();
}

/// 一块液态玻璃表面的绘制参数（**逻辑像素**）。
///
/// 与 `CourseGlassStyle` 的字段几乎一一对应，多一个 [blurSigma]：卡片拿到的
/// 位图是外面预先糊好的，这里要自己带一次实时模糊。
///
/// 单位是逻辑像素，物理像素换算由 [scaledLengths] 在绘制期按 dpr 做——着色器
/// 那一侧所有长度都是物理像素。
@immutable
class LiquidGlassStyle {
  const LiquidGlassStyle({
    required this.borderRadius,
    required this.tint,
    this.blurSigma = 15,
    this.refraction = 8,
    this.refractionBand = 7,
    this.refractionEdgePow = 2.5,
    this.rimStrength = 0.2,
    this.rimWidth = 3,
    this.rimColor = const Color(0xFFFFFFFF),
    this.lightDirection = const Offset(-0.6, -0.8),
  });

  /// 表面圆角，必须与外面裁剪用的圆角一致：着色器拿它算 SDF 遮罩，对不上会出现
  /// 「圆角被裁掉了但玻璃边缘还是直角」。
  final double borderRadius;

  /// 染色（直通 alpha）。
  final Color tint;

  /// 实时背景的模糊量（逻辑 px）。卡片由 `PreblurredWallpaperCache` 预先糊好，
  /// 这里只能现糊，因此是这一档独有的旋钮。
  final double blurSigma;

  /// 边缘处的最大折射位移（逻辑 px）。
  final double refraction;

  /// 折射作用带宽度（逻辑 px）。
  final double refractionBand;

  /// 位移沿边缘上升的陡缓，越大越集中在最外圈。
  final double refractionEdgePow;

  /// 边缘高光强度（0–1）。
  final double rimStrength;

  /// 边缘高光带宽（逻辑 px）。
  final double rimWidth;

  /// 边缘高光颜色。
  final Color rimColor;

  /// 光来向（屏幕坐标，y 向下）。默认左上。
  final Offset lightDirection;

  /// 把着色器要的四个长度换算成**物理像素**。
  ///
  /// 单独抽成一个具名方法（而不是在绘制期散着乘 dpr）是为了让纯单元测试能钉住
  /// 这四则运算：着色器那条路在 `flutter test` 里根本跑不到（测试环境没有 shader
  /// filter 后端），换算错了只会在真机上表现为「圆角与折射位移整体差一个 dpr」。
  ({double radius, double refract, double band, double rimWidth}) scaledLengths(
    double dpr,
  ) => (
    radius: borderRadius * dpr,
    refract: refraction * dpr,
    band: refractionBand * dpr,
    rimWidth: rimWidth * dpr,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassStyle &&
          other.borderRadius == borderRadius &&
          other.tint == tint &&
          other.blurSigma == blurSigma &&
          other.refraction == refraction &&
          other.refractionBand == refractionBand &&
          other.refractionEdgePow == refractionEdgePow &&
          other.rimStrength == rimStrength &&
          other.rimWidth == rimWidth &&
          other.rimColor == rimColor &&
          other.lightDirection == lightDirection;

  @override
  int get hashCode => Object.hash(
    borderRadius,
    tint,
    blurSigma,
    refraction,
    refractionBand,
    refractionEdgePow,
    rimStrength,
    rimWidth,
    rimColor,
    lightDirection,
  );
}

/// 已解析的 uniform 槽位，绑在一个具体的 [ui.FragmentShader] 实例上。
///
/// 为什么不在每帧调 `shader.getUniformFloat('名字')`：那是一次引擎查询（native
/// 调用），而名字只在拿到着色器实例时解析一次即可。槽位只是「着色器 + 下标」的
/// 轻量包装，`set` 直接写 float，没有名字查找。
///
/// 按名字取而不是硬编码 `setFloat(下标, …)`：下标取决于 .frag 里的声明顺序，
/// 改一次着色器就要同步改一遍 Dart，漏改不报错、只会静默画错。名字写错会当场
/// 抛 ArgumentError。
class LiquidGlassUniforms {
  LiquidGlassUniforms(ui.FragmentShader shader)
    : areaOrigin = shader.getUniformVec2('u_area_origin'),
      areaSize = shader.getUniformVec2('u_area_size'),
      radius = shader.getUniformFloat('u_radius'),
      tint = shader.getUniformVec4('u_tint'),
      refract = shader.getUniformFloat('u_refract'),
      band = shader.getUniformFloat('u_band'),
      edgePow = shader.getUniformFloat('u_edge_pow'),
      rimColor = shader.getUniformVec3('u_rim_color'),
      rim = shader.getUniformFloat('u_rim'),
      rimWidth = shader.getUniformFloat('u_rim_width'),
      lightDir = shader.getUniformVec2('u_light_dir'),
      viewSize = shader.getUniformVec2('u_view_size');

  final ui.UniformVec2Slot areaOrigin;
  final ui.UniformVec2Slot areaSize;
  final ui.UniformFloatSlot radius;
  final ui.UniformVec4Slot tint;
  final ui.UniformFloatSlot refract;
  final ui.UniformFloatSlot band;
  final ui.UniformFloatSlot edgePow;
  final ui.UniformVec3Slot rimColor;
  final ui.UniformFloatSlot rim;
  final ui.UniformFloatSlot rimWidth;
  final ui.UniformVec2Slot lightDir;

  /// 视口的物理像素尺寸。
  ///
  /// 只用来**把采样点铰在屏幕内**：`compose` 内层模糊会把绑定纹理往外扩一圈没有
  /// 内容的区域，贴着屏幕边的玻璃往外采会落进去、读成空的（黑边）。详见 .frag 里
  /// `u_view_size` 的说明。
  final ui.UniformVec2Slot viewSize;
}

/// 校验着色器与 Dart 侧的 uniform 名字对得上，测试专用。
///
/// 名字写错时 [ui.FragmentShader.getUniformVec2] 等会当场抛 ArgumentError ——
/// 但那是**绘制期**才发生的事，一屏几十个表面一起炸在真机上才发现。这个入口让
/// 纯单元测试能在不画任何东西的前提下先把名字对一遍。
///
/// 注意这里**不碰 `u_size` / `u_texture`**：那两个由引擎按「第一个 vec2 /
/// 第一个 sampler2D」自动填与自动绑，Dart 侧设了也没用（见着色器文件头）。
@visibleForTesting
void debugValidateLiquidGlassUniforms(ui.FragmentShader shader) {
  LiquidGlassUniforms(shader);
}
