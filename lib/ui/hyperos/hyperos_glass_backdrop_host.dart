import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 页级 OS4 玻璃采样源宿主。
///
/// 上游玻璃（`MiuixGlass*`）不自己抓背景：它从 [MiuixLayerBackdrop] 取一张由
/// `MiuixLayerBackdropCapture` 录制的图层快照。捕获必须包住「弹层之下的页面
/// 内容」，且**不能包含玻璃自身**（上游要求：防反馈采样）。本组件把两件事
/// 收在一处：
///
/// 1. 给页内弹层提供**本页专属**的 [MiuixLayerBackdrop]（经
///    [HyperosGlassBackdropScope] 下发）。不能用全局那一份：路由栈里被压在
///    下面的页面仍然挂载着，两个宿主会往同一个 backdrop 里互相覆盖快照，
///    采到的背景会是另一页的画面。
/// 2. **只在弹层展开时才真正录帧**。捕获节点是重绘边界，开启期间页面每次
///    重绘（滚动、动画）都要多做一次全页 `toImageSync`；常开会让设置页滚动
///    掉帧。开关只改绘制行为、不改控件树形态，因此展开/收起不会重建页面
///    子树（不丢滚动位置、不整页 relayout）。
class HyperosGlassBackdropHost extends StatefulWidget {
  const HyperosGlassBackdropHost({super.key, required this.child});

  final Widget child;

  @override
  State<HyperosGlassBackdropHost> createState() =>
      _HyperosGlassBackdropHostState();
}

class _HyperosGlassBackdropHostState extends State<HyperosGlassBackdropHost> {
  final MiuixLayerBackdrop _backdrop = MiuixLayerBackdrop();

  /// 本页当前有多少个玻璃弹层在展开（含「抬手前预热」）。
  int _consumers = 0;

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  void _acquire() {
    _consumers++;
    if (_consumers == 1 && mounted) {
      setState(() {});
    }
  }

  void _release() {
    if (_consumers == 0) {
      return;
    }
    _consumers--;
    if (_consumers == 0 && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return HyperosGlassBackdropScope(
      backdrop: _backdrop,
      acquire: _acquire,
      release: _release,
      child: HyperosLayerBackdropCapture(
        backdrop: _backdrop,
        enabled: _consumers > 0,
        child: widget.child,
      ),
    );
  }
}

/// 页内 OS4 玻璃弹层拿采样源、并按需开关页级捕获的作用域。
///
/// 用 [maybeOf] 读取（`getInheritedWidgetOfExactType`，不建立依赖）：宿主页是
/// 页面级常量，页面中途不会换采样源，所以弹层不需要跟着它重建。
class HyperosGlassBackdropScope extends InheritedWidget {
  const HyperosGlassBackdropScope({
    super.key,
    required this.backdrop,
    required this.acquire,
    required this.release,
    required super.child,
  });

  /// 本页的采样源：页级捕获往这里写快照，页内弹层从这里取。
  final MiuixLayerBackdrop backdrop;

  /// 有弹层要展开（或手指已按下列、即将展开）时调用，页级捕获随即开启。
  final VoidCallback acquire;

  /// 弹层关闭（或抬手后并未展开）时调用，页级捕获随即关闭。
  final VoidCallback release;

  static HyperosGlassBackdropScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HyperosGlassBackdropScope>();

  @override
  bool updateShouldNotify(HyperosGlassBackdropScope oldWidget) =>
      !identical(oldWidget.backdrop, backdrop);
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
