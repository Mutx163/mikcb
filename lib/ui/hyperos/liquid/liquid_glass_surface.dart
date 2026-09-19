import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../hyperos_blurred_header.dart';
import 'liquid_glass_shader.dart';

/// 一块**液态玻璃**表面：把实时背景糊掉之后，再按圆角 SDF 在边缘做折射与受光高光。
///
/// 渲染结构等价于「`BackdropFilter` + 内容」，只是滤镜从单纯的高斯换成
/// `compose(我们的着色器, 高斯)`——即着色器拿到的是**已经糊过的**背景，与课程卡片
/// 「拿预模糊位图」的输入形态一致，所以两边折射数学可以逐字同源。
///
/// 为什么是 RenderObject 而不是直接 `BackdropFilter`：着色器需要「本表面在屏幕上的
/// 物理像素矩形」才能把屏幕坐标换回表面局部坐标（见着色器文件头），而这个矩形只有
/// 在 **paint 期**用 `localToGlobal` 取才准。build 期取到的偏移在拖动/滚动/入场动画
/// 期间会一直过期——那些动作只触发重绘不触发重建，取到的会是动画开始前的位置。
/// 上游 `progressive_blur` 为同一个理由走了同一条路。
///
/// 不可用时（引擎没有 shader filter 后端 / 着色器没加载出来 / 用户关了模糊或开了
/// 降动效）直接返回 [fallbackBuilder] 给的**既有基础材质**，绝不抛异常、也不留半透明
/// 空壳。
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.fallbackBuilder,
    required this.borderRadius,
    this.grouped = false,
    this.refractionFactor,
    this.maxRefraction,
    this.clipBehavior = Clip.antiAlias,
  });

  /// 画在玻璃之上的内容（会被裁到圆角内）。
  final Widget child;

  /// 折射不可用时返回什么。各表面传自己**原有的**基础分支（弹层→实体、坞/圆钮→
  /// 磨砂、顶栏→高斯），这样降级只是「少一层折射」，不会变成另一种没见过的材质。
  final WidgetBuilder fallbackBuilder;

  /// 表面圆角。必须与外面裁剪用的圆角一致（着色器按它算 SDF 遮罩）。
  final double borderRadius;

  /// 是否加入祖先 [BackdropGroup] 的共享采样。
  ///
  /// 置真时本表面**不**采样「自己正下方那一层」，而是采样组内第一个分组滤镜处
  /// 缓存的背景。弹层家族靠它拿到「遮罩压暗之前的页面」——否则玻璃里会连弹窗的
  /// 黑色蒙层一起折射进去，看起来像一块脏玻璃。没有祖先组时退化为普通采样。
  final bool grouped;

  /// 折射强度缩放（0..1）：非空且 <1 时边缘折射位移按该比例衰减。
  /// 用于入场动画——折射从近零生长到满值，玻璃「凝固」入场，边缘对周边内容的
  /// 镜像随进度减弱，揭示完成后回到完整观感。
  final double? refractionFactor;

  /// 折射位移上限（逻辑 px）。null = 不压，用调参里的 `refraction`。
  ///
  /// 这是**几何适配**，不是材质参数：窄玻璃带（如设置页预览里约 40dp 的
  /// 星期条）上，全量折射位移会让上下两条边缘折射带占满整条带，读成一圈
  /// 描边而不是「一条玻璃带」。材质旋钮仍只从 [FrostedAppearanceScope] 出，
  /// 这里只允许**往下压**，不允许往上加。
  final double? maxRefraction;

  final Clip clipBehavior;

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
      LiquidGlassSurfaceShader.instance.isLoaded &&
      HyperosBlurredHeader.backdropBlurEnabled(context);

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface> {
  @override
  void initState() {
    super.initState();
    // 幂等预热：即使 main.dart 的预热被跳过（或首个液态玻璃表面先于它挂载），
    // 也能自己把程序拉起来。加载完成后 [ListenableBuilder] 会把玻璃补上。
    unawaited(LiquidGlassSurfaceShader.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LiquidGlassSurfaceShader.instance,
      builder: (context, _) {
        if (!LiquidGlassSurface.isAvailable(context)) {
          return widget.fallbackBuilder(context);
        }
        // 全 app 唯一的参数入口：表面只提供自己的圆角与当前明暗，折射旋钮、
        // 底色、光来向一律从 [FrostedAppearanceScope] 里那一份调参出，所以不存在
        // 「这个表面折射 8、那个表面折射 12」。
        final tuning =
            FrostedAppearanceScope.of(context).liquidGlassTuning ??
            LiquidGlassTuning.defaults;
        final style = tuning.toStyle(
          borderRadius: widget.borderRadius,
          brightness: Theme.of(context).brightness,
        );
        return _LiquidGlassLayer(
          style: style,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          // 视口逻辑尺寸：着色器拿它把折射采样点铰在屏幕内（贴着屏幕边的玻璃
          // 往外采样会落进模糊扩出来的空区域、读成黑边）。
          viewSize: MediaQuery.sizeOf(context),
          grouped: widget.grouped,
          refractionFactor: widget.refractionFactor,
          maxRefraction: widget.maxRefraction,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            clipBehavior: widget.clipBehavior,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _LiquidGlassLayer extends SingleChildRenderObjectWidget {
  const _LiquidGlassLayer({
    required this.style,
    required this.devicePixelRatio,
    required this.viewSize,
    required this.grouped,
    required this.refractionFactor,
    required this.maxRefraction,
    required super.child,
  });

  final LiquidGlassStyle style;
  final double devicePixelRatio;

  /// 视口（屏幕）的**逻辑**尺寸；绘制期乘 dpr 后喂给着色器的 `u_view_size`。
  final Size viewSize;

  final bool grouped;
  final double? refractionFactor;
  final double? maxRefraction;

  /// 与 `BackdropFilter.grouped` 同一套查找方式：从祖先 [BackdropGroup] 取共享键。
  ///
  /// 与 Flutter 自带 `BackdropFilter` 一样在 `createRenderObject` /
  /// `updateRenderObject` 里查（那两处在 build 期，注册依赖是合法的）。
  BackdropKey? _backdropKey(BuildContext context) =>
      grouped ? BackdropGroup.of(context)?.backdropKey : null;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLiquidGlass(
    style: style,
    devicePixelRatio: devicePixelRatio,
    viewSize: viewSize,
    backdropKey: _backdropKey(context),
    refractionFactor: refractionFactor,
    maxRefraction: maxRefraction,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderLiquidGlass renderObject) =>
      renderObject.update(
        style: style,
        devicePixelRatio: devicePixelRatio,
        viewSize: viewSize,
        backdropKey: _backdropKey(context),
        refractionFactor: refractionFactor,
        maxRefraction: maxRefraction,
      );
}

class _RenderLiquidGlass extends RenderProxyBox {
  _RenderLiquidGlass({
    required this._style,
    required this._devicePixelRatio,
    required this._viewSize,
    required this._backdropKey,
    required this._refractionFactor,
    required this._maxRefraction,
  });

  LiquidGlassStyle _style;
  double _devicePixelRatio;
  Size _viewSize;
  BackdropKey? _backdropKey;
  double? _refractionFactor;
  double? _maxRefraction;

  /// 由本对象创建、本对象释放（见 [detach]）。
  ///
  /// 这是**所有权**上的选择，不是正确性要求：引擎把着色器交给渲染列表前会复制一份
  /// uniform（`lib/ui/painting/fragment_shader.cc` 的 `ReusableFragmentShader::shader`），
  /// 所以「设 uniform → 立刻绘制」不被打断时，多个表面共用一个实例也不会互相踩。
  ui.FragmentShader? _shader;

  /// 绑定在 [_shader] 上的 uniform 槽位，跟着着色器实例一起换。
  LiquidGlassUniforms? _uniforms;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  void update({
    required LiquidGlassStyle style,
    required double devicePixelRatio,
    required Size viewSize,
    required BackdropKey? backdropKey,
    required double? refractionFactor,
    required double? maxRefraction,
  }) {
    if (_style == style &&
        _devicePixelRatio == devicePixelRatio &&
        _viewSize == viewSize &&
        _backdropKey == backdropKey &&
        _refractionFactor == refractionFactor &&
        _maxRefraction == maxRefraction) {
      return;
    }
    _style = style;
    _devicePixelRatio = devicePixelRatio;
    _viewSize = viewSize;
    _backdropKey = backdropKey;
    _refractionFactor = refractionFactor;
    _maxRefraction = maxRefraction;
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
    final shader = LiquidGlassSurfaceShader.instance.newShader();
    if (shader != null) {
      _shader = shader;
      _uniforms = null;
    }
    return shader;
  }

  void _configure(ui.FragmentShader shader) {
    final uniforms = _uniforms ??= LiquidGlassUniforms(shader);

    // paint 期的全局原点（逻辑像素）——见类注释，build 期取会过期。
    final origin = localToGlobal(Offset.zero);
    final dpr = _devicePixelRatio;
    final scaled = _style.scaledLengths(dpr);
    final tint = _style.tint;
    final rimColor = _style.rimColor;
    final light = _style.lightDirection;
    final factor = _refractionFactor;

    uniforms.areaOrigin.set(origin.dx * dpr, origin.dy * dpr);
    uniforms.areaSize.set(size.width * dpr, size.height * dpr);
    // 视口物理尺寸：着色器用它把折射采样点铰在屏幕内（模糊扩出来的那圈没有内容，
    // 贴着屏幕边的玻璃往外采会落进去、读成黑边）。
    uniforms.viewSize.set(_viewSize.width * dpr, _viewSize.height * dpr);
    uniforms.radius.set(scaled.radius);
    uniforms.tint.set(tint.r, tint.g, tint.b, tint.a);
    // 先按窄带上限压（几何适配），再乘入场进度（0..1）。
    final cap = _maxRefraction;
    final cappedRefract = cap == null
        ? scaled.refract
        : math.min(scaled.refract, cap * dpr);
    uniforms.refract.set(
      factor == null || factor >= 1
          ? cappedRefract
          : cappedRefract * factor.clamp(0.0, 1.0),
    );
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
    final backdropLayer = layer ??= BackdropFilterLayer();
    backdropLayer.backdropKey = _backdropKey;
    backdropLayer.filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      // `tileMode` 必须显式给。默认值（unspecified → decal）会把模糊结果在
      // 离图边约 3σ 的一条带里淡成**透明黑**，而着色器在玻璃边缘是把采样点
      // 朝**外**推的（最多 `refraction` 个逻辑 px），正好探进这条带 —— 于是
      // 每块玻璃贴图边的那一侧就被涂出一条黑线（真机实测：把「模糊」调到 0
      // 这条线即消失，因为 3σ 归零）。同一份几何下磨砂档用 clamp
      // （见 `stable_frosted_surface.dart`），并不发黑，故照抄同一个值。
      inner: ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      ),
    );
    context.pushLayer(backdropLayer, super.paint, offset);
  }
}

/// Paints a no-op grouped backdrop filter before modal dim layers.
///
/// The first filter in a [BackdropGroup] caches the backdrop. Placing this
/// before the dim layer means later liquid glass surfaces in the same group
/// sample the undimmed page instead of the darkened modal scrim.
class UndimmedBackdropCapture extends StatelessWidget {
  const UndimmedBackdropCapture({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01),
        child: const SizedBox.expand(),
      ),
    );
  }
}
