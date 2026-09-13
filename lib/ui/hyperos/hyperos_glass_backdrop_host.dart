import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 屏级 OS4 玻璃采样源控制器。
///
/// 一个"屏"（页面 / 首页）持有一个：里面的玻璃表面（顶栏带、玻璃坞、卡片、弹层）
/// 都从它取 [backdrop]，并在挂载期间 [acquire] 请求录帧；被压在 modal 路由下面的
/// 页面则由 modal 里的玻璃通过 [HyperosGlassBackdropRegistry] 拿到它并代为请求。
class HyperosGlassBackdropController {
  HyperosGlassBackdropController({this.onDemandChanged});

  /// 采样源：由本屏的捕获写快照，屏内外所有玻璃共享同一份。
  final MiuixLayerBackdrop backdrop = MiuixLayerBackdrop();

  /// 开关切换回调：宿主用它 setState，重建捕获节点的 `enabled`。
  final VoidCallback? onDemandChanged;

  int _consumers = 0;

  /// 当前是否有玻璃需要背景（有则开录帧；没有任何玻璃时零开销）。
  bool get capturing => _consumers > 0;

  /// 有玻璃挂载 / 弹层要展开时调用。
  void acquire() {
    _consumers++;
    if (_consumers == 1) onDemandChanged?.call();
  }

  /// 玻璃卸载 / 弹层关闭时调用。
  void release() {
    if (_consumers == 0) return;
    _consumers--;
    if (_consumers == 0) onDemandChanged?.call();
  }

  void dispose() => backdrop.dispose();
}

/// 屏级采样源注册表。
///
/// 路由栈里被压在下面的页面仍然挂载，modal 路由（sheet / dialog / 弹层）里的玻璃
/// 看不到它的 `InheritedWidget`，只能从这里取"当前最上面那一屏"的采样源 —— 那正是
/// 压在 modal 下面、应该被采样的画面。[_screens] 按挂载顺序入栈：push 的页面后
/// 挂载、pop 时先销毁，因此 `last` 恒等于栈顶那一屏。
abstract final class HyperosGlassBackdropRegistry {
  static final List<HyperosGlassBackdropController> _screens =
      <HyperosGlassBackdropController>[];

  /// 栈顶那一屏的采样源（没有屏时为 null）。
  static HyperosGlassBackdropController? get active =>
      _screens.isEmpty ? null : _screens.last;

  static void register(HyperosGlassBackdropController controller) {
    _screens.remove(controller);
    _screens.add(controller);
  }

  static void unregister(HyperosGlassBackdropController controller) {
    _screens.remove(controller);
  }

  /// 取"离 [context] 最近的"采样源：页内优先用本页作用域，modal 路由回落到注册表。
  static HyperosGlassBackdropController? resolve(BuildContext context) =>
      HyperosGlassBackdropScope.maybeOf(context)?.controller ?? active;
}

/// 屏级 OS4 玻璃采样源宿主。
///
/// 上游玻璃（`MiuixGlass*`）不自己抓背景：它从 [MiuixLayerBackdrop] 取一张由
/// `MiuixLayerBackdropCapture` 录制的图层快照。捕获必须包住「玻璃之下的页面
/// 内容」，且**不能包含玻璃自身**（上游要求：防反馈采样）。本组件把三件事收在一处：
///
/// 1. 给屏内所有玻璃下发**本屏专属**的 [MiuixLayerBackdrop]（经
///    [HyperosGlassBackdropScope]）。不能用全局那一份：路由栈里被压在下面的页面
///    仍然挂载着，两个宿主会往同一个 backdrop 里互相覆盖快照。
/// 2. 注册进 [HyperosGlassBackdropRegistry]，让 modal 路由（sheet / dialog）里的
///    玻璃也能采到本屏画面。
/// 3. **有玻璃要采样时才真正录帧**。捕获节点是重绘边界，开启期间页面每次重绘
///    （滚动、动画）都要多做一次全页 `toImageSync`；没有任何玻璃时不录。开关只改
///    绘制行为、不改控件树形态，因此不会重建页面子树（不丢滚动位置、不 relayout）。
class HyperosGlassBackdropHost extends StatefulWidget {
  const HyperosGlassBackdropHost({super.key, required this.child});

  final Widget child;

  @override
  State<HyperosGlassBackdropHost> createState() =>
      _HyperosGlassBackdropHostState();
}

class _HyperosGlassBackdropHostState extends State<HyperosGlassBackdropHost> {
  late final HyperosGlassBackdropController _controller =
      HyperosGlassBackdropController(
        onDemandChanged: () {
          if (!mounted) return;
          // 玻璃表面在 build / didChangeDependencies 里挂载即 acquire，此时同步
          // setState 会触发「setState() called during build」。空闲期（弹层展开、
          // 手指按下这类事件回调）直接重建，让捕获当帧就位；否则推到帧末。
          if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
            setState(() {});
          } else {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        },
      );

  @override
  void initState() {
    super.initState();
    HyperosGlassBackdropRegistry.register(_controller);
  }

  @override
  void dispose() {
    HyperosGlassBackdropRegistry.unregister(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosGlassBackdropScope(
      controller: _controller,
      child: HyperosLayerBackdropCapture(
        backdrop: _controller.backdrop,
        enabled: _controller.capturing,
        child: widget.child,
      ),
    );
  }
}

/// 屏内玻璃表面拿采样源的作用域。
///
/// 用 [maybeOf] 读取（`getInheritedWidgetOfExactType`，不建立依赖）：宿主页是
/// 页面级常量，页面中途不会换采样源，所以玻璃不需要跟着它重建。
class HyperosGlassBackdropScope extends InheritedWidget {
  const HyperosGlassBackdropScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// 本屏的采样源与"按需录帧"开关。
  final HyperosGlassBackdropController controller;

  /// 兼容旧读取点：本屏采样源。
  MiuixLayerBackdrop get backdrop => controller.backdrop;

  /// 兼容旧读取点：请求 / 归还录帧。
  VoidCallback get acquire => controller.acquire;

  VoidCallback get release => controller.release;

  static HyperosGlassBackdropScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HyperosGlassBackdropScope>();

  @override
  bool updateShouldNotify(HyperosGlassBackdropScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}

/// [MiuixLayerBackdropCapture] 的可开关版本（上游同名类没有 `enabled`）。
///
/// 上游实现（`flutter_miuix` 1.2.0，
/// `lib/src/theme/miuix/blur/miuix_layer_backdrop.dart`，Apache-2.0）：本节点是
/// 独立重绘边界，帧绘制结束后对自己的真实图层做一次 `toImageSync` 快照写回
/// backdrop。这里只加一条：`enabled == false` 时不排期快照；节点与图层照旧
/// 存在，所以开关不改控件树形态。
class HyperosLayerBackdropCapture extends SingleChildRenderObjectWidget {
  const HyperosLayerBackdropCapture({
    super.key,
    required this.backdrop,
    required this.enabled,
    required Widget super.child,
  });

  final MiuixLayerBackdrop backdrop;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHyperosLayerBackdropCapture(
      backdrop,
      enabled,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHyperosLayerBackdropCapture)
      ..backdrop = backdrop
      ..enabled = enabled
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderHyperosLayerBackdropCapture extends RenderProxyBox {
  _RenderHyperosLayerBackdropCapture(
    this._backdrop,
    this._enabled,
    this._devicePixelRatio,
  );

  MiuixLayerBackdrop _backdrop;
  MiuixLayerBackdrop get backdrop => _backdrop;
  set backdrop(MiuixLayerBackdrop value) {
    if (identical(_backdrop, value)) return;
    _backdrop.unregisterCapture(this);
    _backdrop = value;
    if (attached) _backdrop.registerCapture(this);
    markNeedsPaint();
  }

  bool _enabled;
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    // 开启当帧就要录一次，否则弹层首帧采不到背景（只剩材质底色）。
    markNeedsPaint();
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  // 独立重绘边界：子树绘制进本节点的 OffsetLayer，快照直接对真实图层出图，
  // 避免重录子树带来的图层重入。
  @override
  bool get isRepaintBoundary => true;

  // 本节点是重绘边界，位置变化不触发 paint，录制时记下的坐标会过期；因此登记
  // 自身，让 backdrop 在采样时实时取全局坐标。
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _backdrop.registerCapture(this);
  }

  @override
  void detach() {
    _backdrop.unregisterCapture(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _scheduleCapture();
  }

  bool _captureScheduled = false;

  void _scheduleCapture() {
    if (!_enabled || _captureScheduled || !hasSize || size.isEmpty) return;
    _captureScheduled = true;
    // 帧结束后再快照，避免在 paint 阶段改状态触发同帧重入。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!attached || !hasSize || size.isEmpty || !_enabled) return;
      _capture();
    });
  }

  void _capture() {
    final offsetLayer = layer;
    if (offsetLayer is! OffsetLayer) return;
    final dpr = _devicePixelRatio;
    final ui.Image image = offsetLayer.toImageSync(
      Offset.zero & size,
      pixelRatio: dpr,
    );
    _backdrop.updateSnapshot(image, localToGlobal(Offset.zero), dpr);
  }
}
