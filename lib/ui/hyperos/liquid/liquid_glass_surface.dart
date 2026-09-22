import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixGlassEdgeFade;

import '../../../models/liquid_glass_tuning.dart';
import '../frosted/liquid_glass_degradation.dart';
import '../hyperos_blurred_header.dart';
import 'liquid_glass_shader.dart';

/// 这块玻璃表面**按哪个作用域取参数**。
///
/// 2026-09-19 起，规矩从「全 app 只有一份参数」改成「**两个作用域，各自只有一个出口**」：
///
/// * [pinnedChrome]：**固定小件** —— 弹窗家族（选择弹窗 / 列表弹窗 / 二级子卡 / 右上角
///   菜单弹窗 / 常驻球与菜单钮）、底部弹窗与对话框、子页返回键。它们**永远是液态玻璃的
///   标准档**：用户的全局材质档位、5 个「作用范围」开关、模糊总开关、自定义档位与滑杆
///   一律不参与。
/// * [followsUser]：其余表面 —— 首页玻璃带与星期栏（同一条连续带）、底栏药丸与坞内圆钮、
///   悬浮钮等。跟随用户在「课程页面」里选的档位与滑杆。
///
/// 两个作用域**各自只有一个出口**，表面依旧不许自带参数 —— 这是历史教训：旧的
/// 「每个表面自己传档位」把同一块材质搞出好几种观感，那条通道被整体删过。
/// 别把 [pinnedChrome] 当成「又允许表面带参数」的后门。
enum LiquidGlassRole {
  /// 跟随用户在「课程页面」里选的玻璃档位与滑杆。
  followsUser,

  /// 固定小件：永远是液态玻璃的标准档，用户改不动。
  pinnedChrome,
}

/// 按 [role] 解析这块表面该用哪份调参。
///
/// 抽成纯函数是为了让单元测试能在**没有 shader 后端**的环境里钉住这条规则
/// （整条渲染路径在 `flutter test` 里跑不到，见 [LiquidGlassSurface.isAvailable]）。
LiquidGlassTuning liquidGlassTuningForRole(
  FrostedAppearance? appearance,
  LiquidGlassRole role,
) => switch (role) {
  LiquidGlassRole.pinnedChrome => LiquidGlassPreset.standard.recommendedTuning,
  LiquidGlassRole.followsUser =>
    appearance?.liquidGlassTuning ?? LiquidGlassTuning.defaults,
};

/// 穹顶（depth effect）只给**接近方形的小件**：常驻球、坞内圆钮、悬浮钮这类。
/// 玻璃带 / 药丸这类细长条不参与 —— 细长条的边缘折射朝中心偏会读成奇怪的扭曲，
/// 而大面板（弹窗、底部弹窗）短边太长，本来就到不了穹顶区。
const double _domeFullBelowSide = 48;
const double _domeFadeToSide = 96;
const double _domeFullBelowAspect = 1.5;
const double _domeFadeToAspect = 3;

/// 手指高光光斑半径的上限（逻辑 px）：光斑半径取 1.5×表面短边，大面板上不封顶会把
/// 整块玻璃都照进光斑里。
const double kPointerGlowRadiusCap = 180;

/// 按表面尺寸推导穹顶强度（0..1）：短边越大越弱，细长条越扁越弱，两者相乘。
///
/// 这是**几何适配**（与 [LiquidGlassSurface.maxRefraction] 同一性质），不是材质
/// 参数 —— 表面自己没有通道把它传进来，绘制期由 RenderObject 按自身布局尺寸算，
/// 所以不破坏「两个作用域，各自只有一个出口」的规矩。抽成纯函数是为了让单元测试
/// 能钉住这套推导。
@visibleForTesting
double liquidGlassDomeForSize(Size size) {
  final shortSide = math.min(size.width, size.height);
  final longSide = math.max(size.width, size.height);
  double sideRamp;
  if (shortSide <= _domeFullBelowSide) {
    sideRamp = 1;
  } else if (shortSide >= _domeFadeToSide) {
    sideRamp = 0;
  } else {
    sideRamp = (_domeFadeToSide - shortSide) / (_domeFadeToSide - _domeFullBelowSide);
  }
  final aspect = longSide / math.max(shortSide, 1e-3);
  double aspectRamp;
  if (aspect <= _domeFullBelowAspect) {
    aspectRamp = 1;
  } else if (aspect >= _domeFadeToAspect) {
    aspectRamp = 0;
  } else {
    aspectRamp =
        (_domeFadeToAspect - aspect) / (_domeFadeToAspect - _domeFullBelowAspect);
  }
  final dome = sideRamp * aspectRamp;
  return dome.clamp(0.0, 1.0);
}


/// 短边 ≤ 这个值的表面按「窄件」压折射（逻辑 px）。
const double _narrowSurfaceBelowSide = 52;

/// 窄件上给 [LiquidGlassSurface.maxRefraction] 用的折射位移上限；宽/高的表面返回
/// null（= 不压，用材质里那一份位移）。
///
/// **为什么需要**：折射位移的作用带（`refractionBand`，标准档 14.5dp）是**绝对值**，
/// 不随表面变小。放在 56dp 的药丸 / 圆钮上它只占短边的 26%，贴着边、读成「玻璃的
/// 边」；放在 38dp 的悬浮胶囊上占了 38%，上下两条带几乎连起来，整块就读成**一圈
/// 描边**而不是一块玻璃（设置页那条约 40dp 的星期条同理）。
///
/// 折算口径沿用「按厚度折算」的旧意图，只是量纲换成了折射位移：旧厚度上限 40 →
/// 窄件封顶 8~14、设置页预览封顶 22（55%）；折射量程 0~20，故窄件取 8~14（默认
/// 折射 8 不被误压），预览按同比例取 11。短边 > [_narrowSurfaceBelowSide] 的组合
/// 带（约 84dp）保持全量位移，与首页那条带一致。
///
/// 与 [liquidGlassDomeForSize] 同一性质：
/// **几何适配**，不是材质参数 —— 按表面自己的尺寸算，不经过
/// [FrostedAppearanceScope]，所以不破坏「两个作用域，各自只有一个出口」的规矩。
/// 抽成纯函数是为了让单元测试能钉住这套推导。
///
/// 与上面两个兄弟不同，这条适配**由调用点算**（而不是渲染对象按自身 `size` 算）：
/// 窄件的尺寸在 build 期就是常量（`SizedBox` 高度 / 玻璃带高度），调用点传值比让
/// 渲染对象反推更直白，也避免把所有短边 ≤52 的表面一刀切（常驻球、返回键这些
/// 44~48dp 的小件目前按全量位移，本轮不动它们）。
double? narrowSurfaceMaxRefraction(double shortSide) =>
    shortSide > _narrowSurfaceBelowSide
    ? null
    : (shortSide * 0.28).clamp(8.0, 14.0);

/// 祖先链上有没有「跟随链」这一帧**给不出变换**（`CompositedTransformFollower`）。
///
/// 问到它就等于问「本表面的屏幕原点可不可信」：`u_area_origin` 是 paint 期用
/// `localToGlobal` 取的（见 [_RenderLiquidGlass._configure]），而
/// `RenderFollowerLayer.getCurrentTransform()` 的契约是「没有 layer / 算不出变换
/// ⇒ 返回**单位阵**」。于是原点会退化成**本表面的布局位置** —— 首页那颗常驻球是
/// `Stack` 的左上角对齐子节点，退化成屏幕左上角；着色器按
/// `local = FlutterFragCoord - u_area_origin` 摆形状，圆就画到屏幕角上：球的图标
/// （走合成期算出的正常变换）留在右上角，只有玻璃那层跑到左上角
/// （2026-09-22 真机：进外观编辑页再退出后如此）。那颗球自己的可见性门控管的是
/// 「整颗球要不要画」，管不到形状的坐标，这一条补的就是它。
///
/// 判据与 `FHeaderActionBall` 的门控同源（`layer != null &&
/// getLastTransform() != null`）：同一件事必须问同一句话，两处口径不许分叉。
bool liquidGlassFollowerTransformMissing(RenderObject? node) {
  RenderObject? current = node;
  while (current != null) {
    if (current is RenderFollowerLayer) {
      final layer = current.layer;
      if (layer == null || layer.getLastTransform() == null) {
        return true;
      }
    }
    current = current.parent;
  }
  return false;
}

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
/// 不可用时（引擎没有 shader filter 后端 / 着色器没加载出来 / 系统降级；跟随用户的
/// 表面还包括「用户关了模糊」）直接返回 [fallbackBuilder] 给的**既有基础材质**，
/// 绝不抛异常、也不留半透明空壳。参数来自哪个作用域见 [LiquidGlassRole]。
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.fallbackBuilder,
    required this.borderRadius,
    this.grouped = false,
    this.refractionFactor,
    this.maxRefraction,
    this.role = LiquidGlassRole.followsUser,
    this.clipBehavior = Clip.antiAlias,
    this.preferCanvasBoardWhenAncestorScaled = false,
    this.forceCanvasBoard = false,
    this.canvasBoardColor,
  });

  /// 祖先链存在等比缩放（<1）时，是否改用 canvas 圆角板代替 BackdropFilter。
  ///
  /// 只给「让位时板子必须跟着缩」的表面开（OS4 弹层一级注入面）：液态玻璃的
  /// 板子是 `BackdropFilterLayer` + 屏幕坐标 shader，图层不跟 canvas 矩阵走，
  /// 真机上会读成「内容缩了、背景板没缩」。其它表面（选择弹层入场
  /// `Transform.scale` 等）保持 false —— 那条路靠 `_ancestorScale` 校正 shader
  /// 几何，玻璃形变是设计的一部分，不能在动画里突然变成实底板。
  final bool preferCanvasBoardWhenAncestorScaled;

  /// 无条件改画 canvas 板（宿主让位作用域说「正在让位」时置 true）。
  ///
  /// 真机上 `_ancestorScale()` 可能量成 1，只靠 [preferCanvasBoardWhenAncestorScaled]
  /// 等于开关没开 —— 浅色玻璃底板停在原尺寸、内容却在缩。让位期间由宿主显式
  /// 下发，不依赖渲染树变换。
  final bool forceCanvasBoard;

  /// canvas 底板用色。null = 用液态 [LiquidGlassStyle.tint]（半透明染色，
  /// 没有模糊时会读成透明片）。OS4 一级让位时传更实的奶白/深色。
  final Color? canvasBoardColor;

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

  /// 参数作用域（见 [LiquidGlassRole]）。
  ///
  /// 默认 [LiquidGlassRole.followsUser]；弹窗家族 / 底部弹窗 / 返回键这些**固定小件**
  /// 传 [LiquidGlassRole.pinnedChrome]，从此不受用户的材质设置影响。
  final LiquidGlassRole role;

  /// 现在能不能真的画出折射。
  ///
  /// **技术下限**（两个作用域都要过）：引擎得有 shader filter 后端（即 Impeller）、
  /// 且着色器已加载 —— 桌面/测试环境 `isShaderFilterSupported` 恒为 false，所以这条
  /// 路径在 `flutter test` 里跑不到，只能靠纯单元测试钉住参数与降级行为。
  ///
  /// 往上的门禁按 [role] 分岔：
  /// * [LiquidGlassRole.pinnedChrome]：只再过一道**技术 / 系统**门禁
  ///   （[LiquidGlassDegradation.shouldDegrade]：平台视图上方、系统无障碍降级）。
  ///   用户关模糊、选实体/高斯/柔光、关「作用范围」开关，**都不能**把这些小件从玻璃上摘下来。
  /// * [LiquidGlassRole.followsUser]：与全 app 其他玻璃表面同一判据
  ///   （[HyperosBlurredHeader.backdropBlurEnabled] 已含用户模糊总开关与系统降级）。
  static bool isAvailable(
    BuildContext context, [
    LiquidGlassRole role = LiquidGlassRole.followsUser,
  ]) {
    if (!ui.ImageFilter.isShaderFilterSupported ||
        !LiquidGlassSurfaceShader.instance.isLoaded) {
      return false;
    }
    if (role == LiquidGlassRole.pinnedChrome) {
      return !LiquidGlassDegradation.shouldDegrade(context);
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  /// 解析某个角色**此刻真正会用的**渲染参数。
  ///
  /// 为什么抽成 `@visibleForTesting` 静态函数：测试环境没有 shader filter 后端
  /// （[isAvailable] 恒 false），`build` 一律走 `fallbackBuilder`、**永远不构造玻璃层**，
  /// 于是「成对开关有没有真的传下去」在 widget test 里观测不到 —— 而它一旦漏传，
  /// 症状只是"深色观感不对"，不会有任何测试报错。这函数把那套解析变成可断言的对象，
  /// 与同文件的 [liquidGlassDomeForSize] 同一性质。
  ///
  /// 成对语义（2026-09-21）：**形状**按 role 锁（[LiquidGlassRole.pinnedChrome] 永远
  /// 标准档，用户那套深色档也不参与），**配方**是光照适配、对所有角色一视同仁 ——
  /// 漏给某个 role 就会重现「同一材质两种观感」的翻版（同一材质深浅两套观感）。
  @visibleForTesting
  static LiquidGlassStyle resolveStyleFor({
    required FrostedAppearance appearance,
    required LiquidGlassRole role,
    required double borderRadius,
    required Brightness brightness,
  }) {
    final tuning = liquidGlassTuningForRole(appearance, role);
    final pinned = role == LiquidGlassRole.pinnedChrome;
    return tuning.toStyle(
      borderRadius: borderRadius,
      brightness: brightness,
      dark: pinned ? null : appearance.liquidGlassTuningDark,
      link: pinned ? true : appearance.linkLiquidGlassTuning,
      darkBoost: appearance.darkGlassBoostEnabled,
    );
  }

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // 控制器必须在 initState 里建：若懒初始化（late final 首次访问发生在
    // dispose），SingleTickerProviderStateMixin 建 ticker 时会查 TickerMode
    // 祖先 —— 在 unmount 路径上查祖先是 debug 断言直接炸的事。
    _glowController =
        AnimationController(vsync: this, duration: _glowFade)
          ..addListener(_pushPointer);
    // 幂等预热：即使 main.dart 的预热被跳过（或首个液态玻璃表面先于它挂载），
    // 也能自己把程序拉起来。加载完成后 [ListenableBuilder] 会把玻璃补上。
    unawaited(LiquidGlassSurfaceShader.instance.ensureLoaded());
  }

  @override
  void dispose() {
    _glowController.dispose();
    // ⚠️ `_pointer` 在这里**不能 dispose**：卸载顺序是 State.dispose 先于
    // 渲染对象 detach，而渲染对象 detach 时还要在它上面 removeListener ——
    // 对已 dispose 的 ChangeNotifier 调 removeListener 在 debug 下会炸。
    // 留给 GC（测试环境走不到玻璃路径，这个坑只能靠注释守住）。
    super.dispose();
  }

  /// 按压进度的渐隐时长 —— 跟手开（forward）是瞬时的，抬手渐隐走这段。
  static const Duration _glowFade = Duration(milliseconds: 140);

  late final AnimationController _glowController;

  /// 指针状态（本地逻辑坐标, 按压进度），经 [ValueNotifier] 直达渲染对象。
  /// 记录放在通知器里而不是 State 字段里：变化走 markNeedsPaint，不走整树重建。
  final ValueNotifier<(Offset?, double)> _pointer = ValueNotifier((null, 0));

  void _pushPointer() {
    _pointer.value = (_pointer.value.$1, _glowController.value);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointer.value = (event.localPosition, _pointer.value.$2);
    _glowController.forward();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _pointer.value = (event.localPosition, _pointer.value.$2);
  }

  void _handlePointerRelease() {
    // 位置留在原地，让光斑跟着渐隐一起停住，而不是跳走。
    _glowController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // 所有液态玻璃默认套转场重绘驱动：形状按屏幕坐标画，路由壳的
    // RepaintBoundary 只挪图层不重画时，必须靠它逐帧 markNeedsPaint
    // （见 LiquidGlassTransitionRepaint / 2026-09-21「按钮分成两层」）。
    return LiquidGlassTransitionRepaint(
      child: ListenableBuilder(
        listenable: LiquidGlassSurfaceShader.instance,
        builder: (context, _) {
          if (!LiquidGlassSurface.isAvailable(context, widget.role)) {
            return widget.fallbackBuilder(context);
          }
          // 两个作用域，各自只有一个出口：表面只提供自己的圆角与当前明暗，折射旋钮、
          // 底色、光来向一律从 [resolveStyleFor] 出 —— 固定小件拿标准档，其余拿
          // [FrostedAppearanceScope] 里那一份，表面自己仍然碰不到参数。
          final style = LiquidGlassSurface.resolveStyleFor(
            appearance: FrostedAppearanceScope.of(context),
            role: widget.role,
            borderRadius: widget.borderRadius,
            brightness: Theme.of(context).brightness,
          );
          // 边缘高光强度：二级开合时随 MiuixGlassEdgeFade 渐变；无作用域 = 1。
          final rimFade = MiuixGlassEdgeFade.of(context).clamp(0.0, 1.0);
          return Listener(
            // translucent：不挡子内容自己的手势，也不挡玻璃背后（如坞下面）的命点。
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: (_) => _handlePointerRelease(),
            onPointerCancel: (_) => _handlePointerRelease(),
            child: _LiquidGlassLayer(
              style: style,
              pointer: _pointer,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              // 视口逻辑尺寸：着色器拿它把折射采样点铰在屏幕内（贴着屏幕边的玻璃
              // 往外采样会落进模糊扩出来的空区域、读成黑边）。
              viewSize: MediaQuery.sizeOf(context),
              grouped: widget.grouped,
              refractionFactor: widget.refractionFactor,
              maxRefraction: widget.maxRefraction,
              rimFade: rimFade,
              preferCanvasBoardWhenAncestorScaled:
                  widget.preferCanvasBoardWhenAncestorScaled,
              forceCanvasBoard: widget.forceCanvasBoard,
              canvasBoardColor: widget.canvasBoardColor,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                clipBehavior: widget.clipBehavior,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiquidGlassLayer extends SingleChildRenderObjectWidget {
  const _LiquidGlassLayer({
    required this.style,
    required this.pointer,
    required this.devicePixelRatio,
    required this.viewSize,
    required this.grouped,
    required this.refractionFactor,
    required this.maxRefraction,
    this.rimFade = 1.0,
    this.preferCanvasBoardWhenAncestorScaled = false,
    this.forceCanvasBoard = false,
    this.canvasBoardColor,
    required super.child,
  });

  final LiquidGlassStyle style;
  final double rimFade;
  final bool preferCanvasBoardWhenAncestorScaled;
  final bool forceCanvasBoard;
  final Color? canvasBoardColor;

  /// 指针状态（本地逻辑坐标, 按压进度）。渲染对象订阅它，变化时自己重绘。
  final ValueListenable<(Offset?, double)> pointer;

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
    pointer: pointer,
    devicePixelRatio: devicePixelRatio,
    viewSize: viewSize,
    backdropKey: _backdropKey(context),
    refractionFactor: refractionFactor,
    maxRefraction: maxRefraction,
    rimFade: rimFade,
    preferCanvasBoardWhenAncestorScaled: preferCanvasBoardWhenAncestorScaled,
    forceCanvasBoard: forceCanvasBoard,
    canvasBoardColor: canvasBoardColor,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderLiquidGlass renderObject) =>
      renderObject.update(
        style: style,
        pointer: pointer,
        devicePixelRatio: devicePixelRatio,
        viewSize: viewSize,
        backdropKey: _backdropKey(context),
        refractionFactor: refractionFactor,
        maxRefraction: maxRefraction,
        rimFade: rimFade,
        preferCanvasBoardWhenAncestorScaled: preferCanvasBoardWhenAncestorScaled,
        forceCanvasBoard: forceCanvasBoard,
        canvasBoardColor: canvasBoardColor,
      );
}

class _RenderLiquidGlass extends RenderProxyBox {
  _RenderLiquidGlass({
    required this._style,
    required this._pointer,
    required this._devicePixelRatio,
    required this._viewSize,
    required this._backdropKey,
    required this._refractionFactor,
    required this._maxRefraction,
    required this._rimFade,
    required this._preferCanvasBoardWhenAncestorScaled,
    required this._forceCanvasBoard,
    required this._canvasBoardColor,
  });

  LiquidGlassStyle _style;
  double _devicePixelRatio;
  Size _viewSize;
  BackdropKey? _backdropKey;
  double? _refractionFactor;
  double? _maxRefraction;
  double _rimFade;
  bool _preferCanvasBoardWhenAncestorScaled;
  bool _forceCanvasBoard;
  Color? _canvasBoardColor;

  /// 指针状态（本地逻辑坐标, 按压进度 0..1），由 State 持有、widget 传入。
  /// 渲染对象订阅它：变化只触发重绘，不惊动整棵树。
  ValueListenable<(Offset?, double)> _pointer;

  void _onPointerChanged() {
    if (attached) {
      markNeedsPaint();
    }
  }

  /// 上次 paint 时的屏幕原点（逻辑 px）。null = 还没画过 / 刚 attach。
  Offset? _paintedOrigin;

  /// 原点监视是否已挂上帧末回调（同一时刻只允许一个）。
  bool _originWatchArmed = false;

  /// 玻璃形状按**屏幕绝对坐标**画（shader 的 `u_area_origin` = paint 期
  /// `localToGlobal`）。祖先图层（转场壳 RepaintBoundary、Overlay 偏移、
  /// TransformLayer）可以只改合成矩阵、**不**调用本节点 paint —— 形状就冻在
  /// 旧屏幕位置，而图标/文字按局部坐标画仍停在布局位。真机读成「按钮分成两层：
  /// 玻璃跑了，实体留在原地」（壁纸页四颗钮、右上角菜单球等同族）。
  ///
  /// 帧末对比：若 `localToGlobal` 已相对上次 paint 变了，就 `markNeedsPaint`
  /// 让 shader 重算 origin。静止时 distance≈0，不触发重绘。
  void _armOriginWatch() {
    if (_originWatchArmed || !attached) {
      return;
    }
    _originWatchArmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originWatchArmed = false;
      if (!attached) {
        return;
      }
      final origin = localToGlobal(Offset.zero);
      final painted = _paintedOrigin;
      if (painted != null && (origin - painted).distanceSquared > 0.25) {
        markNeedsPaint();
      }
      // 祖先随时可能再挪（转场、让位、跟随链），持续看守；代价是每帧一次
      // localToGlobal + 空比较，比错位后「玻璃永远偏在右边」便宜得多。
      _armOriginWatch();
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pointer.addListener(_onPointerChanged);
    _paintedOrigin = null;
    _armOriginWatch();
  }

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
    required ValueListenable<(Offset?, double)> pointer,
    required double devicePixelRatio,
    required Size viewSize,
    required BackdropKey? backdropKey,
    required double? refractionFactor,
    required double? maxRefraction,
    required double rimFade,
    required bool preferCanvasBoardWhenAncestorScaled,
    required bool forceCanvasBoard,
    required Color? canvasBoardColor,
  }) {
    if (identical(_pointer, pointer) &&
        _style == style &&
        _devicePixelRatio == devicePixelRatio &&
        _viewSize == viewSize &&
        _backdropKey == backdropKey &&
        _refractionFactor == refractionFactor &&
        _maxRefraction == maxRefraction &&
        _rimFade == rimFade &&
        _preferCanvasBoardWhenAncestorScaled ==
            preferCanvasBoardWhenAncestorScaled &&
        _forceCanvasBoard == forceCanvasBoard &&
        _canvasBoardColor == canvasBoardColor) {
      return;
    }
    final pointerSwapped = !identical(_pointer, pointer);
    if (pointerSwapped && attached) {
      _pointer.removeListener(_onPointerChanged);
    }
    _style = style;
    _pointer = pointer;
    _devicePixelRatio = devicePixelRatio;
    _viewSize = viewSize;
    _backdropKey = backdropKey;
    _refractionFactor = refractionFactor;
    _maxRefraction = maxRefraction;
    _rimFade = rimFade;
    _preferCanvasBoardWhenAncestorScaled = preferCanvasBoardWhenAncestorScaled;
    _forceCanvasBoard = forceCanvasBoard;
    _canvasBoardColor = canvasBoardColor;
    if (pointerSwapped && attached) {
      _pointer.addListener(_onPointerChanged);
    }
    markNeedsPaint();
  }

  @override
  void detach() {
    _originWatchArmed = false;
    _paintedOrigin = null;
    _pointer.removeListener(_onPointerChanged);
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

  /// 祖先链当前的等比缩放（入场变形动画期间 < 1）。
  ///
  /// 着色器里的坐标是**屏幕物理像素**，所以表面被祖先缩放时，它在屏幕上占据的
  /// 范围也缩了；而 `u_area_size` 是本表面的布局尺寸，不会。两者不对齐，动画早期
  /// 就会出现「形状还是满尺寸、面板已经缩到 15%」——面板边角落到形状之外，alpha 0
  /// 处透出下面的压暗蒙层，读起来就是开合过程中一块块发黑（旧版第三方包为同一件
  /// 事专门维护了一份「未缩放变换」快照）。
  ///
  /// 取 `getMaxScaleOnAxis`（而不是分别取 x/y）：弹层只有等比缩放，非等比下取最大
  /// 轴至少不会把形状缩没。取不到（未 attach / 退化矩阵）时按 1 处理。
  double _ancestorScale() {
    if (!attached) {
      return 1;
    }
    final scale = getTransformTo(null).getMaxScaleOnAxis();
    return scale.isFinite && scale > 0 ? scale : 1;
  }

  void _configure(ui.FragmentShader shader) {
    final uniforms = _uniforms ??= LiquidGlassUniforms(shader);

    // paint 期的全局原点（逻辑像素）——见类注释，build 期取会过期。
    final origin = localToGlobal(Offset.zero);
    final dpr = _devicePixelRatio;
    // 祖先缩放：形状与所有长度都要跟着它走，否则动画期间形状与面板对不上。
    final scale = _ancestorScale();
    final scaled = _style.scaledLengths(dpr, scale: scale);
    final tint = _style.tint;
    final rimColor = _style.rimColor;
    final factor = _refractionFactor;

    uniforms.areaOrigin.set(origin.dx * dpr, origin.dy * dpr);
    uniforms.areaSize.set(size.width * dpr * scale, size.height * dpr * scale);
    // 视口物理尺寸：着色器用它把折射采样点铰在屏幕内（模糊扩出来的那圈没有内容，
    // 贴着屏幕边的玻璃往外采会落进去、读成黑边）。
    uniforms.viewSize.set(_viewSize.width * dpr, _viewSize.height * dpr);
    uniforms.radius.set(scaled.radius);
    uniforms.tint.set(tint.r, tint.g, tint.b, tint.a);
    uniforms.dispersion.set(_style.dispersion);
    // 穹顶：按布局尺寸推导（见 liquidGlassDomeForSize），与 dpr / 祖先缩放无关
    // —— 它混的是**方向**，不是长度。
    uniforms.dome.set(
      liquidGlassDomeForSize(Size(size.width, size.height)),
    );
    // 先按窄带上限压（几何适配），再乘入场进度（0..1）。
    final cap = _maxRefraction;
    final cappedRefract = cap == null
        ? scaled.refract
        : math.min(scaled.refract, cap * dpr * scale);
    uniforms.refract.set(
      factor == null || factor >= 1
          ? cappedRefract
          : cappedRefract * factor.clamp(0.0, 1.0),
    );
    uniforms.band.set(scaled.band);
    uniforms.edgePow.set(_style.refractionEdgePow);
    uniforms.rimColor.set(rimColor.r, rimColor.g, rimColor.b);
    // 边缘高光随二级开合渐显（MiuixGlassEdgeFade）；静止态 rimFade=1 不变。
    uniforms.rim.set(_style.rimStrength * _rimFade.clamp(0.0, 1.0));
    uniforms.rimWidth.set(scaled.rimWidth);
    // 手指高光：位置在 paint 期换算成屏幕物理 px（滚动/拖动中才跟得上）；
    // 半径取 1.5×短边，封顶防止大面板上光斑铺满整块玻璃。
    final (pointerLocal, pointerGlow) = _pointer.value;
    if (pointerLocal != null) {
      final pointerGlobal = localToGlobal(pointerLocal);
      uniforms.pointer.set(pointerGlobal.dx * dpr, pointerGlobal.dy * dpr);
    }
    uniforms.pointerGlow.set(pointerGlow);
    final shortSide = math.min(size.width, size.height);
    uniforms.pointerRadius.set(
      math.min(shortSide * 1.5, kPointerGlowRadiusCap) * dpr * scale,
    );
    // u_size 与 u_texture 由引擎自动填/自动绑，这里不设（见着色器文件头）。
  }

  /// 祖先链上是否有「还没淡完」的半透明层，有就返回它的 alpha（否则 1）。
  ///
  /// **这是上游 OS4 弹层给的处境**：它在入场/退场期间把整块面板包进
  /// `Opacity(panelAlpha)`（`flutter_miuix` 的 `popup_presenter.dart` 里
  /// `panel: Opacity(opacity: panelAlpha, child: surfaceBuilder(...))`；
  /// `dropdown` / `dialog` 两类的 `panelAlpha = fade`，形变类才恒为 1）。而 Opacity
  /// 会把子树隔离进离屏层 —— `BackdropFilter` 读不到背后的东西，玻璃就渲染成一块黑，
  /// 越淡越黑。本仓自己的弹窗早就绕开了这个坑（`hyperos_select.dart` 的注释写着
  /// 「No Opacity here」），但注入给上游的那条路绕不开。
  ///
  /// 只认 `RenderOpacity`（上游用的就是普通 `Opacity`）。`AnimatedOpacity` 的
  /// alpha 藏在 Animation 里、读它的值有踩空的风险，暂不覆盖。
  double _ancestorOpacity() {
    var alpha = 1.0;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is RenderOpacity) {
        alpha = math.min(alpha, node.opacity.clamp(0.0, 1.0));
        if (alpha <= 0) {
          return 0;
        }
      }
    }
    return alpha;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shader = child == null ? null : _ensureShader();
    if (shader == null) {
      layer = null;
      _paintedOrigin = null;
      if (child != null) {
        super.paint(context, offset);
      }
      return;
    }

    // 让位期间改画 canvas 圆角板：宿主显式 force，或（兜底）祖先缩放可被量到。
    //
    // 为什么不能只靠祖先缩放：真机上 `_ancestorScale()` 可能返回 1，浅色玻璃
    // 底板停在原尺寸，而菜单文字跟着让位变换缩 —— 用户口径「深色材质缩了，
    // 浅色材质完全没缩」（2026-09-22）。
    //
    // canvas 圆角矩形与内容同处一条变换链：板子和行一起朝支点缩。
    // 让位结束（force=false 且 scale=1）的下一帧切回液态玻璃。
    final ancestorScale = _ancestorScale();
    final useCanvasBoard =
        _forceCanvasBoard ||
        (_preferCanvasBoardWhenAncestorScaled && ancestorScale < 0.999) ||
        // 跟随链这一帧算不出变换 ⇒ 屏幕原点不可信（会退化成布局位置，见
        // [liquidGlassFollowerTransformMissing]）。这时**形状一步都不画**：宁可
        // 退成同一块 canvas 板（位置由图层合成负责、是对的，只是这一刻没有材质），
        // 也不能让形状按不可信的原点画到屏幕角上 —— 真机读成「右上角的球跑到
        // 左上角」（2026-09-22）。板上记的 `_paintedOrigin` 是那个不可信的值，
        // 帧末看守发现它变了就会标脏重画，链路一恢复下一帧自动回到玻璃。
        liquidGlassFollowerTransformMissing(this);
    if (useCanvasBoard) {
      layer = null;
      final rrect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(_style.borderRadius),
      );
      // 让位底板用色：优先宿主传入的「像原玻璃卡」的实色；退回 tint 时是半透明
      // 染色（无模糊 → 读成透明片，真机 2026-09-22）。
      final boardColor = _canvasBoardColor ?? _style.tint;
      _paintedOrigin = localToGlobal(Offset.zero);
      context.canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawRRect(rrect, Paint()..color = boardColor)
        ..restore();
      if (child != null) {
        super.paint(context, offset);
      }
      return;
    }

    // 祖先在淡出：这一帧挂滤镜层只会得到一块黑（采样不到背景）。退化成与材质
    // 同色的圆角填充 —— 上面的 Opacity 会照常把它淡掉，读起来是「面板在淡」，
    // 而不是「面板先变黑再淡」。淡完（alpha 回到 1）下一帧就恢复玻璃。
    if (_ancestorOpacity() < 1) {
      layer = null;
      final radius = _style.borderRadius * _devicePixelRatio;
      _paintedOrigin = localToGlobal(Offset.zero);
      context.canvas
        ..save()
        ..translate(offset.dx, offset.dy)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(radius),
          ),
          Paint()..color = _style.tint,
        )
        ..restore();
      if (child != null) {
        super.paint(context, offset);
      }
      return;
    }

    _configure(shader);
    // 形状按屏幕坐标画；记下本帧 origin，供 [_armOriginWatch] 发现
    // 「祖先图层挪了但本节点没被标脏重画」——那是「玻璃跑了、实体留在原地」的根因。
    _paintedOrigin = localToGlobal(Offset.zero);

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
        // blur-tile-mode-ok：σ=0.01 的技法性空模糊（3σ ≈ 0.03 逻辑 px，肉眼不可见），
        // 它存在的意义只是"让 BackdropGroup 先缓存一份未压暗的背景"。decal 与 clamp
        // 在这种量级上没有可观察差别。
        filter: ui.ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 让「按屏幕坐标摆形状」的玻璃在**转场 / 位移动画期间逐帧重画**。
///
/// ## 为什么必须有它
///
/// 液态玻璃着色器的几何按**屏幕物理像素**算，其中 `u_area_origin` 是 Dart 侧在
/// **paint 期**用 `localToGlobal` 读的（见 `glass_surface_refraction.frag` 文件头与
/// [_RenderLiquidGlass._configure]）：**形状要正，这一帧就得重画一次。**
///
/// 而 `HyperosPageRoute` 的转场外壳把整页包进了 `RepaintBoundary`
/// （`hyperos_navigation.dart` 的 `_HyperosTransitionPageShell`，为的是滑入时整页像素
/// 复用、不逐帧重栅格化）。框架对「没被标脏的重绘边界」只换图层偏移、不重画。
/// 于是转场期间玻璃的 `u_area_origin` 停在"上一次重画时"的屏幕位置，偏差正是这段
/// 时间页面滑过的距离 —— 玻璃会**整块**（形状 + 折射进来的内容）偏在一侧。
/// 真机两次实锤：
///
/// * 2026-09-20 外观编辑页预览：顶栏 / 星期栏里扫出一根细竖线（偏差扫进那 48px 的
///   边缘外溢区）；
/// * 2026-09-21 壁纸页四颗悬浮按钮：「按钮被分成了两层，玻璃那层跑到了右边，原位置
///   剩下了一个透明按钮」，且**不动它就一直错位**（本页落定后没有别的重绘去改写缓存）。
///
/// 本节点订阅宿主路由的**主 + 副**动画，转场每推进一帧就 `markNeedsPaint`，把形状
/// 重新钉在当前位置；自己又是重绘边界，所以这次重画只覆盖自己这棵子树，不牵连整页
/// （保住外壳那笔优化）。动画停住就不再 tick ⇒ 静止时零额外重画。副动画也要听：
/// 本页被后一页盖住时，页面是被视差推着走的（同一件事）。
///
/// ## 只有"按屏幕坐标算形状"的材质需要它
///
/// 快照类（柔光）与磨砂类材质的位置由图层合成负责，不重画也是对的；实体档更是完全不按
/// 屏幕坐标算形状。所以这是个**纯几何刷新**的包装：它一个材质参数都不碰，不构成
/// 「表面自带参数通道」那个后门（那两个作用域的规矩见 [LiquidGlassRole]）。
///
/// ## ⚠️ 不要改成「转场期间先不画、落定后再画」
///
/// 那条看似更省事，但本仓否过两次：
///
/// * 2026-09-20 首页玻璃带 / 外观编辑页：用户明确不要进场时的任何闪动 —— 落定瞬间才
///   出现就是一次闪动；
/// * 2026-09-21 壁纸页四颗按钮：照那条改完之后用户立刻报「进入退出的时候，按钮一直在
///   变材质」。
///
/// 正确做法是**照旧画、每帧重算坐标**：位置一路都对，材质一路不变。
class LiquidGlassTransitionRepaint extends StatefulWidget {
  const LiquidGlassTransitionRepaint({required this.child, super.key});

  final Widget child;

  @override
  State<LiquidGlassTransitionRepaint> createState() =>
      _LiquidGlassTransitionRepaintState();
}

class _LiquidGlassTransitionRepaintState
    extends State<LiquidGlassTransitionRepaint> {
  Animation<double>? _primary;
  Animation<double>? _secondary;
  Listenable? _driver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 宿主路由（没有路由 —— 例如直接 pump 进测试 —— 退化成"不驱动"，行为与不加
    // 本节点一致）。
    final route = ModalRoute.of(context);
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (identical(primary, _primary) && identical(secondary, _secondary)) {
      return;
    }
    _primary = primary;
    _secondary = secondary;
    _driver = Listenable.merge(<Listenable?>[primary, secondary]);
  }

  @override
  Widget build(BuildContext context) =>
      _GlassTransitionRepaint(driver: _driver, child: widget.child);
}

class _GlassTransitionRepaint extends SingleChildRenderObjectWidget {
  const _GlassTransitionRepaint({required this.driver, required super.child});

  /// 转场动画；每 tick 一次就把子树标脏一次。null = 不驱动。
  final Listenable? driver;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassTransitionRepaint(driver);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    if (renderObject is! _RenderGlassTransitionRepaint) {
      return;
    }
    renderObject.driver = driver;
  }
}

class _RenderGlassTransitionRepaint extends RenderProxyBox {
  _RenderGlassTransitionRepaint(Listenable? driver) : _driver = driver {
    _driver?.addListener(markNeedsPaint);
  }

  Listenable? _driver;

  set driver(Listenable? value) {
    if (identical(_driver, value)) {
      return;
    }
    _driver?.removeListener(markNeedsPaint);
    _driver = value;
    _driver?.addListener(markNeedsPaint);
  }

  /// 独立重绘边界：标脏只让本子树重画，不动宿主页面的缓存像素。
  @override
  bool get isRepaintBoundary => true;

  @override
  void dispose() {
    // 必须摘干净：dispose 之后 markNeedsPaint 会在 debug 下抛异常。
    _driver?.removeListener(markNeedsPaint);
    _driver = null;
    super.dispose();
  }
}
