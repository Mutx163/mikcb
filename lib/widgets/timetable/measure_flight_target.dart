import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// 把子组件的**真实屏幕矩形**在首帧后回报一次（不量化）。
///
/// ## 为什么不能用 `day_view/measured_screen_rect.dart`
///
/// 那个为「按位置判字色」服务：把矩形按屏高等分量化成 32 档，并在滚动时反复
/// 更新。判色只需要「大概在哪一行」，量化是为了别每帧重建。
///
/// 但「卡片对卡片」转场要的是**飞行终点**：量化过的矩形会让卡片落地时偏几像素，
/// 读作「卡了一下」；反复更新则会让终点在转场途中漂移。
///
/// 所以这里单独做一次：**只量一次、不量化、不多次**。
///
/// ## 时机
///
/// 在 `paint` 里登记、帧后回调置脏（与上面那个同一套标准时序，避免
/// "markNeedsBuild during paint"）。首帧之后布局已完成，量到的就是最终位置。
class MeasureFlightTarget extends StatefulWidget {
  const MeasureFlightTarget({
    super.key,
    required this.onMeasured,
    required this.child,
  });

  /// 首个可测量的帧之后回调一次（全局坐标）。
  ///
  /// 调用方应当把它写进一个**无需重建**的缓存（例如 `Map`），而不是直接
  /// `setState`：转场已经由 `AnimationController` 驱动每帧重建，这里再触发一次
  /// 重建只会让同一帧多跑一遍 build。
  final ValueChanged<Rect> onMeasured;

  final Widget child;

  @override
  State<MeasureFlightTarget> createState() => _MeasureFlightTargetState();
}

class _MeasureFlightTargetState extends State<MeasureFlightTarget> {
  Rect? _pending;
  bool _scheduled = false;
  bool _reported = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _onMeasured(Rect rect) {
    _pending = rect;
    if (_scheduled || _reported) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || _reported) {
        return;
      }
      final rect = _pending;
      if (rect == null || rect.isEmpty) {
        return;
      }
      _reported = true;
      widget.onMeasured(rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MeasureBox(onMeasured: _onMeasured, child: widget.child);
  }
}

class _MeasureBox extends SingleChildRenderObjectWidget {
  const _MeasureBox({required this.onMeasured, super.child});

  final ValueChanged<Rect> onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureBox(onMeasured);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureBox renderObject) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderMeasureBox extends RenderProxyBox {
  _RenderMeasureBox(this._onMeasured);

  ValueChanged<Rect> _onMeasured;

  set onMeasured(ValueChanged<Rect> value) {
    _onMeasured = value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 布局已完成、允许读全局坐标。只登记，置脏交给帧后回调。
    if (attached && hasSize) {
      _onMeasured(localToGlobal(Offset.zero) & size);
    }
    super.paint(context, offset);
  }
}
