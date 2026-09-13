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
///
/// 它本身是 [ChangeNotifier]：开关（有人要录帧 / 没人要）变化时通知宿主，宿主只重建
/// 那个捕获节点，不惊动页面子树。
class HyperosGlassBackdropController extends ChangeNotifier {
  /// 采样源：由本屏的捕获写快照，屏内外所有玻璃共享同一份。
  final MiuixLayerBackdrop backdrop = MiuixLayerBackdrop();

  int _consumers = 0;

  /// 当前是否有玻璃需要背景（有则开录帧；没有任何玻璃时零开销）。
  bool get capturing => _consumers > 0;

  /// 有玻璃挂载 / 弹层要展开时调用。
  void acquire() {
    _consumers++;
    if (_consumers == 1) notifyListeners();
  }

  /// 玻璃卸载 / 弹层关闭时调用。
  void release() {
    if (_consumers == 0) return;
    _consumers--;
    if (_consumers == 0) notifyListeners();
  }

  @override
  void dispose() {
    backdrop.dispose();
    super.dispose();
  }
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
  const HyperosGlassBackdropHost({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;

  /// 外部持有的采样源（首页要自己按「按下更多按钮」预热录帧，并把同一份传给
  /// 弹层）。为空则自建、并随宿主一起释放。
  final HyperosGlassBackdropController? controller;

  @override
  State<HyperosGlassBackdropHost> createState() =>
      _HyperosGlassBackdropHostState();
}

class _HyperosGlassBackdropHostState extends State<HyperosGlassBackdropHost> {
  late final HyperosGlassBackdropController _controller =
      widget.controller ?? HyperosGlassBackdropController();

  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  /// 只有"整屏最外层、且在跑"的宿主才占注册表栈顶。两条门槛都不能少：
  ///
  /// * **最外层**（上面没有别的屏级作用域）：屏里可以套屏 —— 首页的
  ///   `HyperosRootPage` 自带一层，玻璃坞的内嵌设置页也自带一层。它们都采不到外层
  ///   背景（**壁纸**），一旦登记就顶掉外层：菜单 / 弹层按栈顶取采样源时拿到一张
  ///   不含壁纸的快照 → 面板画的是透明图 → 底下的字直接透出来（真机现象：
  ///   "开了内置壁纸，首页右上角菜单变透明"）。
  /// * **在跑**（`TickerMode` 为真）：被 `Visibility` 盖住、节拍已停的那一屏不再
  ///   绘制，它的 backdrop 永远没有新快照。
  void _syncRegistration() {
    final outermost = HyperosGlassBackdropScope.maybeOf(context) == null;
    final live = outermost && TickerMode.valuesOf(context).enabled;
    if (live == _registered) return;
    _registered = live;
    if (live) {
      HyperosGlassBackdropRegistry.register(_controller);
    } else {
      HyperosGlassBackdropRegistry.unregister(_controller);
    }
  }

  @override
  void dispose() {
    HyperosGlassBackdropRegistry.unregister(_controller);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosGlassBackdropScope(
      controller: _controller,
      // 捕获节点自己订阅控制器（见 HyperosLayerBackdropCapture）：开关只触发
      // `markNeedsPaint`，**不重建任何 widget** —— 玻璃表面是在自己的
      // didChangeDependencies 里 acquire 的，那时若 markNeedsBuild 一个不在
      // 当前构建链上的祖先，会直接抛 "setState() called during build"。
      child: HyperosLayerBackdropCapture(
        controller: _controller,
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
    required this.controller,
    required Widget super.child,
  });

  /// 采样源 + 录帧开关的持有者。渲染对象订阅它：开关变化只 `markNeedsPaint`。
  final HyperosGlassBackdropController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHyperosLayerBackdropCapture(
      controller,
      MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHyperosLayerBackdropCapture)
      ..controller = controller
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderHyperosLayerBackdropCapture extends RenderProxyBox {
  _RenderHyperosLayerBackdropCapture(
    this._controller,
    this._devicePixelRatio,
  ) {
    _controller.addListener(_onDemandChanged);
  }

  HyperosGlassBackdropController _controller;
  HyperosGlassBackdropController get controller => _controller;
  set controller(HyperosGlassBackdropController value) {
    if (identical(_controller, value)) return;
    _controller.removeListener(_onDemandChanged);
    final previousBackdrop = _controller.backdrop;
    _controller = value..addListener(_onDemandChanged);
    if (attached) {
      previousBackdrop.unregisterCapture(this);
      _controller.backdrop.registerCapture(this);
    }
    markNeedsPaint();
  }

  /// "有没有玻璃在采样"变了：只重绘本节点（当帧末补一次快照）。
  ///
  /// 这里刻意不 `markNeedsBuild`：玻璃表面是在自己的 `didChangeDependencies`
  /// （构建期）里 acquire 的，此刻标脏一个不在当前构建链上的祖先会抛
  /// `setState() called during build`；而录帧本来就只是绘制行为。
  void _onDemandChanged() {
    if (attached) markNeedsPaint();
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// 只有还有玻璃需要背景时才录帧。
  bool get recording => _controller.capturing;

  // 独立重绘边界：子树绘制进本节点的 OffsetLayer，快照直接对真实图层出图，
  // 避免重录子树带来的图层重入。
  @override
  bool get isRepaintBoundary => true;

  // 本节点是重绘边界，位置变化不触发 paint，录制时记下的坐标会过期；因此登记
  // 自身，让 backdrop 在采样时实时取全局坐标。
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.backdrop.registerCapture(this);
  }

  @override
  void detach() {
    _controller.backdrop.unregisterCapture(this);
    super.detach();
  }

  /// 上一次录帧后是否已经通知过消费者（玻璃）。
  ///
  /// 玻璃就在本捕获子树里时（页内玻璃都是），`updateSnapshot` 的通知会让它
  /// `markNeedsPaint`，进而把本节点也标脏 → 又录一次 → 又通知…… 变成 60fps 的
  /// 自激重绘：真机实测「外观与配色」页静止也吃满一个核、整机发烫掉帧。
  ///
  /// 录帧只应在**内容变了**时发生，所以这一帧若是被自己的通知带出来的，直接跳过，
  /// 循环即止（代价：连续滚动时最多两帧的采样延迟）。
  bool _notifiedSinceCapture = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_notifiedSinceCapture) {
      _notifiedSinceCapture = false;
      return;
    }
    _scheduleCapture();
  }

  bool _captureScheduled = false;

  void _scheduleCapture() {
    if (!recording || _captureScheduled || !hasSize || size.isEmpty) return;
    _captureScheduled = true;
    // 帧结束后再快照，避免在 paint 阶段改状态触发同帧重入。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!attached || !hasSize || size.isEmpty || !recording) return;
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
    _notifiedSinceCapture = true;
    _controller.backdrop.updateSnapshot(
      image,
      localToGlobal(Offset.zero),
      dpr,
    );
  }
}
