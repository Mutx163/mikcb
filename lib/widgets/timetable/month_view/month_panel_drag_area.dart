import 'package:flutter/material.dart';

import '../../../ui/hyperos/hyperos_motion.dart';

/// 面板纵向拖拽：**一个指针源，同时驱动「网格收放」与「列表滚动」**。
///
/// ## 用户口径（三次，最后一条是实际滑过之后说的）
///
/// 1. 「底部信息区域，应该支持在任意位置上下滑动，可以操作日期表格的上下收起
///    展开」；
/// 2. 「如果想看月视图下面的信息区域，在下滑的时候应该是**先收起上面为一行**，
///    **然后再是下面信息区域滚动**向下」；
/// 3. 「为什么现在滚动的时候，手拉下面信息区域，它可以直接下滑信息区域滚动，
///    而不是先收起上面的东西，**这两个滚动没有一体化的效果**」。
///
/// ## ⚠️ 两版失败实现与各自的死因（别再走第三条一样的路）
///
/// **第一版：外层 `Listener` 判归属，靠布尔"闸门"挡住列表。**
/// 实测列表照样每次滚 416px。死因是**事件派发顺序**：`Listener` 是
/// `Scrollable` 的**祖先**，Flutter 指针事件按 hit-test 路径**最深者先收到**，
/// 等 Listener 改闸门时列表早把这一帧处理完了。
///
/// **第二版：判据搬进自定义 `ScrollPhysics`（还补了 `applyTo` 重写）。**
/// 单测全绿，真机上"一体化"仍然不存在。死因更隐蔽也更致命：
///
/// > 网格收起 ⇒ 面板变高 ⇒ 列表 `viewportDimension` 变大 ⇒ `maxScrollExtent`
/// > 变小。一旦缩到 0（内容还没长到填满面板），`Scrollable` 就判定"不可滚动"，
/// > **当场 `goBallistic` 结束整次拖动**（`IdleScrollActivity.applyNewDimensions`
/// > 就是这么写的）。
///
/// 实测轨迹（拖动中逐步采样 `maxScrollExtent`）：`61 → 36 → 11 → 0`，
/// 同一帧发出 `ScrollEndNotification`；此后指针怎么动、physics 一次都不再被
/// 调用，网格停在半收起、抬手又弹回全展开 —— 用户看到的正是"上面收不起来、
/// 两个滚动各干各的"。
///
/// **结论：只要"面板高度"在同一次手势里变化，就不能让 `Scrollable` 自己滚。**
/// 这不是参数没调好，是机制冲突：`Scrollable` 的拖动会在尺寸变化的瞬间被它
/// 自己的边界判定判死。所以本版把列表的**用户滚动整个关掉**
/// （`NeverScrollableScrollPhysics`），位移一律由本组件算好、用 `jumpTo` 落到
/// 列表上：
///
/// * 只有一个指针源 ⇒ 两块内容**必然**按同一顺序动，一体化是结构保证的；
/// * 面板高度变化时不再有"进行中的 ScrollActivity"可被打断；
/// * 代价：列表惯性要自己补（[_startListFling]），边界回弹本来就没有
///   （Android 的 `ClampingScrollPhysics` 无回弹，这里等价）。
///
/// ## 顺序（用户口径那张表）
///
/// | 手势 | 第一优先 | 之后 |
/// |---|---|---|
/// | 向上拖（dy < 0，看下面） | 网格收起（t → 0） | 收到底后滚列表 |
/// | 向下拖（dy > 0，往回看） | 列表退回顶部 | 到顶后网格展开（t → 1） |
///
/// ## 为什么不用手势竞技场分工
///
/// 两者同向，竞技场只会有一个赢家：要么列表永远滚不动、要么网格永远收不起来；
/// 而且赢家取决于"谁先接受"，与"用户此刻想看哪段"无关。
class MonthPanelDragState {
  /// 网格还能不能往这个方向继续收放（负 = 收起方向、正 = 展开方向）。
  ///
  /// 由页面注入：收起方向答 `t > 0`、展开方向答 `t < 1`。
  bool Function(double dy) gridCanAbsorb = (_) => false;

  /// 网格收放的三件回调（与拉杆共用同一套）。
  VoidCallback? onCollapseStart;
  ValueChanged<double>? onCollapseUpdate;
  ValueChanged<DragEndDetails>? onCollapseEnd;

  /// 本次手势里网格是否消费过位移（决定抬手要不要吸附）。
  bool gridTouched = false;

  /// 新手势开始：清掉上一轮的状态。
  ///
  /// 必须重置：上次手势若在"网格消费"状态结束，不重置就会让吸附判断错位。
  void beginGesture() {
    gridTouched = false;
  }

  /// 这段位移该归网格，还是该归列表。
  ///
  /// 判据就是类注释那张表。抽成静态纯函数是为了能单测 ——「哪段归谁」是这套
  /// 逻辑唯一容易被改错的地方（前两版都栽在这上面）。
  static bool collapseTakesPriority({
    required double dy,
    required bool listCanScroll,
    required bool gridCanAbsorb,
  }) {
    if (dy == 0) {
      return false;
    }
    if (dy < 0) {
      // 往上拖 = 要看下面：网格先让位，与列表当前位置无关。
      return gridCanAbsorb;
    }
    // 往下拖 = 往回看：列表先退回顶部，到顶了才轮到网格展开。
    if (listCanScroll) {
      return false;
    }
    return gridCanAbsorb;
  }
}

class MonthPanelDragArea extends StatefulWidget {
  const MonthPanelDragArea({
    required this.scrollController,
    required this.dragState,
    required this.child,
    super.key,
  });

  /// 面板列表的控制器：位移由本组件算好后 `jumpTo` 进去。
  ///
  /// 列表自己的用户滚动**必须关掉**（`NeverScrollableScrollPhysics`），原因见
  /// 类注释 —— 让 `Scrollable` 自己滚，它会在"面板高度变化"的瞬间被自己的
  /// 边界判定结束掉拖动。
  final ScrollController scrollController;

  /// 与页面共享的拖拽状态（判据 + 网格回调）。
  final MonthPanelDragState dragState;

  final Widget child;

  /// 边界容差：滚动物理会在边界留亚像素误差，严格比较会让"边界上那一两个
  /// 像素"被判成"还能滚"，用户在那儿拖会觉得第一下没反应。
  static const double edgeTolerance = 1;

  /// 抬手后列表惯性的估算系数（秒）。
  ///
  /// 没有去还原原生摩擦模型：面板内容是一列卡片、滚动距离短，线性近似的手感
  /// 差别看不出来，而省掉一整套 Ticker + 摩擦模拟。
  static const double flingDurationFactor = 0.12;

  /// 触发惯性的最小抬手速度（逻辑 px/s）。
  static const double flingMinVelocity = 120;

  /// 惯性动画的基础时长（毫秒）。
  ///
  /// ⚠️ 必须写成裸**毫秒数**再 `.scaledMs`，不能直接 `Duration(milliseconds:
  /// 260)` —— 本仓有「动画时长走统一换算」的架构守卫，裸 Duration 会被拦
  /// （用户改过「页面转场速度」之后，所有动画都要跟着缩放）。
  static const int flingDurationMs = 260;

  @override
  State<MonthPanelDragArea> createState() => _MonthPanelDragAreaState();
}

class _MonthPanelDragAreaState extends State<MonthPanelDragArea> {
  double? _lastY;
  Duration _lastTime = Duration.zero;
  double _velocity = 0;

  /// 本次手势里列表是否被驱动过（决定抬手要不要给它惯性）。
  bool _listTouched = false;

  ScrollPosition? get _position =>
      widget.scrollController.hasClients
          ? widget.scrollController.position
          : null;

  /// 列表此刻还能不能在这个方向上滚。
  bool _listCanScroll(double dy) {
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
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
    // 按下即接管：正在跑的惯性立刻停住（用户伸手就是要自己控）。
    widget.scrollController.jumpTo(
      widget.scrollController.hasClients ? widget.scrollController.offset : 0,
    );
    widget.dragState.beginGesture();
    _listTouched = false;
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

    final toGrid = MonthPanelDragState.collapseTakesPriority(
      dy: dy,
      listCanScroll: _listCanScroll(dy),
      gridCanAbsorb: widget.dragState.gridCanAbsorb(dy),
    );

    if (toGrid) {
      if (!widget.dragState.gridTouched) {
        widget.dragState.gridTouched = true;
        widget.dragState.onCollapseStart?.call();
      }
      widget.dragState.onCollapseUpdate?.call(dy);
      return;
    }

    _scrollListBy(dy);
  }

  /// 把位移落到列表上（手指向下 dy > 0 ⇒ 内容回退 ⇒ pixels 减小）。
  void _scrollListBy(double dy) {
    final position = _position;
    if (position == null || !position.hasContentDimensions) {
      return;
    }
    final max = position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    final next = (position.pixels - dy).clamp(0.0, max);
    if (next == position.pixels) {
      return;
    }
    _listTouched = true;
    position.jumpTo(next);
  }

  void _onPointerEnd(PointerEvent event) {
    if (widget.dragState.gridTouched) {
      // 网格吃过位移 → 按速度吸附到两端。
      widget.dragState.onCollapseEnd?.call(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, _velocity)),
        ),
      );
    }
    if (_listTouched) {
      _startListFling(_velocity);
    }
    _lastY = null;
    _lastTime = Duration.zero;
    _velocity = 0;
    _listTouched = false;
  }

  /// 抬手后给列表补一段惯性（原生拖动被关掉了，这是替代品）。
  void _startListFling(double velocity) {
    final position = _position;
    if (position == null ||
        velocity.abs() < MonthPanelDragArea.flingMinVelocity) {
      return;
    }
    final max = position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    // 手指向下（velocity > 0）⇒ 内容继续回退 ⇒ pixels 减小。
    final target =
        (position.pixels - velocity * MonthPanelDragArea.flingDurationFactor)
            .clamp(0.0, max);
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    widget.scrollController.animateTo(
      target,
      duration: MonthPanelDragArea.flingDurationMs.scaledMs,
      curve: Curves.easeOutCubic,
    );
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
