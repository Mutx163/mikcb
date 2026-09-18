import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../hyperos_blurred_header.dart';
import 'glass_surface_shader.dart';

/// 一块「折射玻璃」表面：把实时背景糊掉之后，再按圆角 SDF 在边缘做折射与受光高光。
///
/// 渲染结构等价于「`BackdropFilter` + 内容」，只是滤镜从单纯的高斯换成
/// `compose(我们的着色器, 高斯)`——即着色器拿到的是**已经糊过的**背景，与课程卡片
/// 「拿预模糊位图」的输入形态一致，所以两边折射数学可以逐字同源。
///
/// 为什么是 RenderObject 而不是直接 `BackdropFilter`：着色器需要「本表面在屏幕上的
/// 物理像素矩形」才能把屏幕坐标换回表面局部坐标（见着色器文件头），而这个矩形只有
/// 在 **paint 期**用 `localToGlobal` 取才准。build 期取到的偏移在拖动/滚动/入场动画
/// 期间会一直过期——那些动作只触发重绘不触发重建，取到的会是动画开始前的位置。
/// `liquid_glass_widgets` 的 `progressive_blur` 为同一个理由走了同一条路。
///
/// 不可用时（引擎没有 shader filter 后端 / 着色器没加载出来 / 用户关了模糊或开了
/// 降动效）直接返回 [fallbackBuilder] 给的**既有基础材质**，绝不抛异常、也不留半透明
/// 空壳。
class RefractionGlassSurface extends StatefulWidget {
  const RefractionGlassSurface({
    super.key,
    required this.style,
    required this.fallbackBuilder,
    this.child,
  });

  /// 折射参数（逻辑像素口径）。
  final GlassSurfaceStyle style;

  /// 折射不可用时返回什么。各表面传自己**原有的**基础分支（弹层→实体、坞/圆钮→
  /// 磨砂、顶栏→高斯），这样降级只是「少一层折射」，不会变成另一种没见过的材质。
  final WidgetBuilder fallbackBuilder;

  /// 画在玻璃之上的内容（会被裁到圆角内）。
  final Widget? child;

  /// 现在能不能真的画出折射。
  ///
  /// 三个条件缺一不可：
  /// * `ImageFilter.isShaderFilterSupported` —— 引擎得有 shader filter 后端（即
  ///   Impeller）。桌面/测试环境恒为 false，所以这条路径**在 `flutter test` 里跑不到**，
  ///   只能靠纯单元测试钉住参数与降级行为。
  /// * 着色器已加载 —— 加载失败时保持 false，走基础材质。
  /// * `HyperosBlurredHeader.backdropBlurEnabled` —— 已含「用户关了模糊总开关」与
  ///   「系统无障碍 / 降动效 / 高对比」两类降级，与全 app 其他玻璃表面同一判据。
  static bool isAvailable(BuildContext context) =>
      ui.ImageFilter.isShaderFilterSupported &&
      GlassSurfaceShader.instance.isLoaded &&
      HyperosBlurredHeader.backdropBlurEnabled(context);

  @override
  State<RefractionGlassSurface> createState() => _RefractionGlassSurfaceState();
}

class _RefractionGlassSurfaceState extends State<RefractionGlassSurface> {
  @override
  void initState() {
    super.initState();
    // 幂等预热：即使 main.dart 的预热被跳过（或首个折射表面先于它挂载），
    // 也能自己把程序拉起来。加载完成后 [ListenableBuilder] 会把玻璃补上。
    unawaited(GlassSurfaceShader.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlassSurfaceShader.instance,
      builder: (context, _) {
        if (!RefractionGlassSurface.isAvailable(context)) {
          return widget.fallbackBuilder(context);
        }
        return _RefractionGlassLayer(
          style: widget.style,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.style.borderRadius),
            child: widget.child ?? const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _RefractionGlassLayer extends SingleChildRenderObjectWidget {
  const _RefractionGlassLayer({
    required this.style,
    required this.devicePixelRatio,
    required super.child,
  });

  final GlassSurfaceStyle style;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRefractionGlass(
    style: style,
    devicePixelRatio: devicePixelRatio,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRefractionGlass renderObject,
  ) => renderObject.update(
    style: style,
    devicePixelRatio: devicePixelRatio,
  );
}

class _RenderRefractionGlass extends RenderProxyBox {
  _RenderRefractionGlass({
    required this._style,
    required this._devicePixelRatio,
  });

  GlassSurfaceStyle _style;
  double _devicePixelRatio;

  /// 由本对象创建、本对象释放（见 [detach]）。
  ///
  /// 这是**所有权**上的选择，不是正确性要求：引擎把着色器交给渲染列表前会复制一份
  /// uniform（`lib/ui/painting/fragment_shader.cc` 的 `ReusableFragmentShader::shader`），
  /// 所以「设 uniform → 立刻绘制」不被打断时，多个表面共用一个实例也不会互相踩。
  ui.FragmentShader? _shader;

  /// 绑定在 [_shader] 上的 uniform 槽位，跟着着色器实例一起换。
  GlassSurfaceUniforms? _uniforms;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  void update({
    required GlassSurfaceStyle style,
    required double devicePixelRatio,
  }) {
    if (_style == style && _devicePixelRatio == devicePixelRatio) {
      return;
    }
    _style = style;
    _devicePixelRatio = devicePixelRatio;
    markNeedsPaint();
  }

  @override
  void detach() {
    _shader?.dispose();
    _shader = null;
    _uniforms = null;
    super.detach();
  }

  /// 惰性取着色器实例：首个 paint 前程序可能刚好就绪，这里取到就留下。
  ///
  /// 上层 widget 已经保证「不可用时不建这个 render object」，所以这里返回 null 只
  /// 可能是极端竞态；此时退回「只画内容、不叠滤镜」，不抛异常。
  ui.FragmentShader? _ensureShader() {
    final existing = _shader;
    if (existing != null) {
      return existing;
    }
    final shader = GlassSurfaceShader.instance.newShader();
    if (shader != null) {
      _shader = shader;
      _uniforms = null;
    }
    return shader;
  }

  void _configure(ui.FragmentShader shader) {
    final uniforms = _uniforms ??= GlassSurfaceUniforms(shader);

    // paint 期的全局原点（逻辑像素）——见类注释，build 期取会过期。
    final origin = localToGlobal(Offset.zero);
    final dpr = _devicePixelRatio;
    final scaled = _style.scaledLengths(dpr);
    final tint = _style.tint;
    final rimColor = _style.rimColor;
    final light = _style.lightDirection;

    uniforms.areaOrigin.set(origin.dx * dpr, origin.dy * dpr);
    uniforms.areaSize.set(size.width * dpr, size.height * dpr);
    uniforms.radius.set(scaled.radius);
    uniforms.tint.set(tint.r, tint.g, tint.b, tint.a);
    uniforms.refract.set(scaled.refract);
    uniforms.band.set(scaled.band);
    uniforms.edgePow.set(_style.refractionEdgePow);
    uniforms.rimColor.set(rimColor.r, rimColor.g, rimColor.b);
    uniforms.rim.set(_style.rimStrength);
    uniforms.rimWidth.set(scaled.rimWidth);
    uniforms.lightDir.set(light.dx, light.dy);
    // u_size 与 u_texture 由引擎自动填/自动绑，这里不设（见着色器文件头）。
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shader = child == null ? null : _ensureShader();
    if (shader == null) {
      layer = null;
      if (child != null) {
        super.paint(context, offset);
      }
      return;
    }

    _configure(shader);

    final sigma = _style.blurSigma;
    (layer ??= BackdropFilterLayer()).filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    context.pushLayer(layer!, super.paint, offset);
  }
}
