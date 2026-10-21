import 'package:flutter/material.dart';

/// 面板**任意位置**上下拖动都能收放日期表格，同时保留列表自己的滚动。
///
/// ## 用户口径（2026-10-21 晚）
///
/// 「底部信息区域，应该支持在任意位置上下滑动，可以操作日期表格的上下收起展开」。
///
/// ## 为什么不能只靠外层 GestureDetector
///
/// 列表里的 `Scrollable` 会整段赢走纵向手势，外层 `GestureDetector` 的
/// `onVerticalDragUpdate` 一次都收不到（本仓实测：列表 offset=250、外层零回调）。
///
/// ## 做法：Listener 听原始指针 + 列表照常滚
///
/// `Listener` 与 `Scrollable` 是**共存**的（实测：同一次拖动里 PointerMove 收到
/// 2 次、列表也正常滚了 250）—— 因为 Listener 不参与手势竞技场，只旁观指针流。
/// 所以本组件：
///
/// * 让列表照常滚（不做任何拦截）；
/// * 同时用 Listener 读指针位移，判断「这一刻列表是不是已经滚不动了」：
///   - 还能滚 → 这段归列表，什么都不做；
///   - 已到边界 → 这段交给表格收放。
///
/// 于是**同一次手势里**就能从「滚列表」无缝切到「收放表格」，不用抬手重来。
class MonthPanelDragArea extends StatefulWidget {
  const MonthPanelDragArea({
    required this.scrollController,
    required this.onCollapseStart,
    required this.onCollapseUpdate,
    required this.onCollapseEnd,
    required this.child,
    super.key,
  });

  /// 面板列表的控制器（只读它的位置，不改它的滚动）。
  final ScrollController scrollController;

  /// 表格收放的三个回调（与拉杆共用同一套）。
  final VoidCallback onCollapseStart;
  final ValueChanged<double> onCollapseUpdate;
  final ValueChanged<DragEndDetails> onCollapseEnd;

  final Widget child;

  /// 边界容差：滚动物理会在边界留亚像素误差，严格比较会让"边界上那一两个像素"
  /// 被判成"还能滚"，用户在那儿拖会觉得第一下没反应。
  static const double edgeTolerance = 1;

  @override
  State<MonthPanelDragArea> createState() => _MonthPanelDragAreaState();
}

class _MonthPanelDragAreaState extends State<MonthPanelDragArea> {
  /// 本段手势是否已经交给表格收放。
  bool _claimed = false;

  double? _lastY;
  Duration _lastTime = Duration.zero;
  double _velocity = 0;

  /// 列表此刻还能不能在这个方向上滚。
  bool _listCanScroll(double dy) {
    final controller = widget.scrollController;
    if (!controller.hasClients) {
      return false;
    }
    final position = controller.position;
    if (!position.hasContentDimensions) {
      return false;
    }
    const tolerance = MonthPanelDragArea.edgeTolerance;
    if (dy < 0) {
      return position.pixels < position.maxScrollExtent - tolerance;
    }
    if (dy > 0) {
      return position.pixels > position.minScrollExtent + tolerance;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _claimed = false;
    _lastY = event.position.dy;
    _lastTime = event.timeStamp;
    _velocity = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final lastY = _lastY;
    if (lastY == null) {
      _lastY = event.position.dy;
      _lastTime = event.timeStamp;
      return;
    }
    final dy = event.position.dy - lastY;
    _lastY = event.position.dy;

    final dtMs = (event.timeStamp - _lastTime).inMicroseconds / 1000.0;
    if (dtMs > 0) {
      _velocity = dy / dtMs * 1000.0;
    }
    _lastTime = event.timeStamp;

    if (dy == 0) {
      return;
    }
    if (_listCanScroll(dy)) {
      // 这段归列表：它自己会滚（我们只是旁观）。
      return;
    }
    if (!_claimed) {
      _claimed = true;
      widget.onCollapseStart();
    }
    widget.onCollapseUpdate(dy);
  }

  void _onPointerEnd(PointerEvent event) {
    if (_claimed) {
      widget.onCollapseEnd(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, _velocity)),
        ),
      );
    }
    _claimed = false;
    _lastY = null;
    _lastTime = Duration.zero;
    _velocity = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 空白处也要能接指针（面板下半没内容时同样是"任意位置"的一部分）。
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.child,
    );
  }
}
