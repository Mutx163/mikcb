import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'frame_perf_probe.dart';

/// 给任意一层挂「这一帧被画了几次」的计数（读数是 [FramePerfProbe] 的 `layers=`）。
///
/// 用途：转场这类「每帧都在动、但不知道钱花在哪一层」的场景，用计数区分
/// 「某层在逐帧重画」与「某层根本没动」。计数只在探针安装（profile 带
/// `PERF_PROBE=true`）时生效，其余情况是一次布尔判断。
///
/// 两个设计要点（都是踩过的坑）：
/// * [enabled] 而不是「不满足就换一个 widget」：`OverlayGetxController` 那类
///   每帧会变的判据（比如蒙层 alpha 从 0 变正），若靠增删 widget 表达，
///   转场中途会换掉元素、反而制造卡顿。这里结构恒定，只翻一个 bool。
/// * 零面积也照样会走 `paint`：`ColoredBox` 宽度收到 0 时 GPU 不做像素工作，
///   但计数照样涨。所以「宽度是不是 0」必须由调用点通过 [enabled] 说明，
///   否则读数会给出「这一层每帧都在画」的错误结论。
class PaintProbe extends SingleChildRenderObjectWidget {
  const PaintProbe({
    required this.name,
    this.enabled = true,
    required Widget super.child,
    super.key,
  });

  /// 输出里的层名（`layers=pageMoving:1,overlayStill:41`）。
  final String name;

  /// 为 false 时不计（用于零面积/完全透明这类「画了等于没画」的情况）。
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPaintProbe(name, enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaintProbe renderObject,
  ) {
    renderObject
      ..name = name
      ..enabled = enabled;
  }
}

class RenderPaintProbe extends RenderProxyBox {
  RenderPaintProbe(this._name, this._enabled);

  String _name;
  bool _enabled;

  set name(String value) => _name = value;

  set enabled(bool value) {
    if (value == _enabled) {
      return;
    }
    _enabled = value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_enabled && FramePerfProbe.isInstalled) {
      FramePerfProbe.noteLayerPaint(_name);
    }
    super.paint(context, offset);
  }
}
