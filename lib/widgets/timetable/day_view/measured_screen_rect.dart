import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// 把一个子组件的**屏幕竖直区间**量出来，交给 `builder` 做「按位置判色」。
///
/// ## 为什么需要它
///
/// 日视图的议程卡判字色要用「这张卡背后那一小块壁纸多亮」。卡片的竖直位置只有
/// 布局完成后才知道，而判色发生在 build 里 —— 所以必须先量、再重画一次。
///
/// ## 三条设计约束（都是被"别把列表搞卡"逼出来的）
///
/// 1. **不在 paint 里 setState**。`paint` 阶段直接标记脏会在某些路径上触发
///    "markNeedsBuild called during paint"；统一改成 `paint` 里记下矩形、由
///    帧后回调（`addPostFrameCallback`）再置脏，这是 Flutter 的标准时序。
/// 2. **量化**。滚动时矩形每帧都在变，逐像素比较会变成"每帧 setIsState →
///    每帧重建整张卡"，而且字色会随着滚动不断翻转（读起来像闪）。这里把矩形
///    量化成屏幕高度的 [quantizationSteps] 分之一，只有跨过一格才重建。
/// 3. **收敛**。量化后值只增不减地趋于稳定：滚动停下就不再触发；同一格里
///    重复量到同一个值会早退，不会自我循环。
class MeasuredScreenRect extends StatefulWidget {
  const MeasuredScreenRect({
    super.key,
    required this.builder,
    this.quantizationSteps = 32,
  });

  /// `rect` 为 null 表示"还没量到"（首帧）。调用方应按旧口径兜底。
  final Widget Function(BuildContext context, Rect? rect) builder;

  /// 竖直区间量化步数：32 表示"每跨过 3% 屏高才判一次"。
  ///
  /// 步数越多越贴合真实位置，但滚动时重建越频繁。32 是「卡片高度约 10%~16%
  /// 屏高」下的折中：一张卡滚动经过自己身高时只会重判 3~5 次。
  final int quantizationSteps;

  @override
  State<MeasuredScreenRect> createState() => _MeasuredScreenRectState();
}

class _MeasuredScreenRectState extends State<MeasuredScreenRect> {
  Rect? _rect;
  Rect? _pending;
  bool _flushScheduled = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _disposed = false;

  void _onMeasured(Rect rect) {
    // paint 阶段只登记，不在这一阶段置脏。
    _pending = rect;
    if (_flushScheduled) {
      return;
    }
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_disposed) {
        return;
      }
      final next = _pending;
      if (next == null) {
        return;
      }
      final quantized = _quantize(next);
      if (quantized == _rect) {
        return;
      }
      setState(() => _rect = quantized);
    });
  }

  /// 量化：只保留竖直区间（判色只需要上下边界），按屏高等分取整。
  Rect _quantize(Rect rect) {
    final steps = widget.quantizationSteps <= 0 ? 1 : widget.quantizationSteps;
    // 以卡片的**上边界**所在的那一格为准；高度保留真实值，避免把薄卡量化成 0。
    final top = (rect.top * steps).round() / steps;
    final bottom = (rect.bottom * steps).round() / steps;
    return Rect.fromLTRB(
      0,
      top,
      rect.width,
      bottom < top ? top : bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return _MeasureBox(
      onMeasured: _onMeasured,
      child: widget.builder(context, rect),
    );
  }
}

class _MeasureBox extends SingleChildRenderObjectWidget {
  const _MeasureBox({required this.onMeasured, super.child});

  final ValueChanged<Rect> onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureBox(onMeasured);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureBox renderObject,
  ) {
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
