import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// 把子组件的**真实屏幕矩形**在帧后回调里回报（可重测，2026-10-23 加）。
///
/// ## 为什么不能用 `day_view/measured_screen_rect.dart`
///
/// 那个为「按位置判字色」服务：把矩形按屏高等分量化成 32 档，并在滚动时反复
/// 更新。判色只需要「大概在哪一行」，量化是为了别每帧重建。
///
/// 但「卡片对卡片」转场要的是**飞行终点**：量化过的矩形会让卡片落地时偏几像素，
/// 读作「卡了一下」；无节制地反复更新则会让终点在转场途中漂移。
///
/// ## 什么时候重量
///
/// 两件事任一发生就重量一次：
///
/// 1. 自身**尺寸变了**（换字号 / 换行数 / 换卡宽）；
/// 2. 调用方把 [revision] 加一（换日、换周、重开转场时用）。
///
/// **位置漂移不单独触发**：滚动时每帧位置都在变，跟着重量会让调用方每帧重建一次
/// 首页（实测一次滑动 30+ 页，每页一次壁纸采样，直接把主线程饿到 ANR）。所以
/// 位置由「新一轮转场时 bump revision」刷新，尺寸变化另有一条廉价通道。
///
/// 这三条对应三个真实 bug：
///
/// * 只量一次 ⇒ 列表滚动复用元素后，旧终点会落到**别的课**身上（`SliverList`
///   复用时不换 key 就会发生）；
/// * 换日后不重量 ⇒ 卡片朝上一轮的位置飞；
/// * 每帧都量 ⇒ 同一帧多跑一遍 build（转场已由 `AnimationController` 驱动）。
///
/// 所以调用方应当：给它一个稳定 `key`（`ValueKey(courseId)`），并在「新一轮
/// 转场开始」时把 [revision] 加一。
///
/// ## 时机
///
/// 在 `performLayout` 里登记、帧后回调置脏（避免 "markNeedsBuild during paint"，
/// 也避免布局期读变换）。隐藏的子树**不会 paint**，但布局照常执行 —— 转场期间
/// 面板被裁掉大半时这一点是必须的。
class MeasureFlightTarget extends StatefulWidget {
  const MeasureFlightTarget({
    super.key,
    required this.onMeasured,
    required this.child,
    this.revision = 0,
  });

  /// 可测量之后回调（全局坐标）。
  ///
  /// 调用方应当写进一个**无需重建**的缓存（`FlightTargetCache`），并在值真的
  /// 变化时才重建一次。
  final ValueChanged<Rect> onMeasured;

  /// 变化即重量。换日 / 换周 / 重开转场时加一。
  final int revision;

  final Widget child;

  @override
  State<MeasureFlightTarget> createState() => _MeasureFlightTargetState();
}

class _MeasureFlightTargetState extends State<MeasureFlightTarget> {
  RenderBox? _pending;
  bool _scheduled = false;
  bool _reported = false;
  bool _disposed = false;

  /// 上一次上报的尺寸：尺寸变了也要重量（同一门课换了字号 / 换了行数）。
  Size? _lastSize;

  /// 上一次上报时的 [MeasureFlightTarget.revision]。
  int _lastRevision = -1;

  @override
  void didUpdateWidget(covariant MeasureFlightTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != _lastRevision) {
      // 新一轮：允许重量，但等下一次 layout 自己触发（此刻还没布局）。
      _reported = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _onMeasured(RenderBox box) {
    _pending = box;
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) {
        return;
      }
      final box = _pending;
      // 尺寸为空说明这一帧还没排到这个（面板刚挂载 / 被隐藏但尚未布局），
      // **不要**标记成已上报 —— 下一帧布局还会再触发一次。
      if (box == null || !box.hasSize || box.size.isEmpty) {
        return;
      }
      final size = box.size;
      // 尺寸没变、代数也没变 ⇒ 这次布局只是位置动了，按上面的理由不上报。
      if (_reported && _lastSize == size && _lastRevision == widget.revision) {
        return;
      }
      // 帧后回调里读全局坐标是安全的：这一帧的布局与变换都已确定。
      final rect = box.localToGlobal(Offset.zero) & size;
      _reported = true;
      _lastSize = size;
      _lastRevision = widget.revision;
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

  final ValueChanged<RenderBox> onMeasured;

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

  ValueChanged<RenderBox> _onMeasured;
  bool _inLayout = false;

  set onMeasured(ValueChanged<RenderBox> value) {
    _onMeasured = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    // ⚠️ 必须在这里「通知」，但**不能**在这里读全局坐标。
    //
    // 1. 为什么不能在 paint 里通知：飞行终点所属的面板在转场期间被裁剪
    //    （只露出摘要卡那一条），裁掉的部分**不会 paint** —— 在 paint 里登记
    //    就永远收不到。performLayout 照常执行。
    // 2. 为什么不能在 performLayout 里读 localToGlobal：会在布局期间读未完成的
    //    变换，debug 下直接抛 "Cannot get renderObject's position during layout"。
    //
    // 所以这里只把「自己」交出去，由 State 层在帧后回调里换算成屏幕矩形。
    if (!_inLayout && attached && hasSize && !size.isEmpty) {
      _inLayout = true;
      _onMeasured(this);
      _inLayout = false;
    }
  }
}
