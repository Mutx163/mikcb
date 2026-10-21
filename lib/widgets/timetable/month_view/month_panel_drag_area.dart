import 'package:flutter/material.dart';

/// 面板纵向拖拽的分流中枢：**网格先收成一行，收完了列表才滚**。
///
/// ## 用户口径（2026-10-21 第二轮，方向与上一轮相反）
///
/// > 「如果想看月视图下面的信息区域，在下滑的时候应该是先收起上面为一行，
/// > 然后再是下面信息区域滚动向下」
///
/// 上一轮实现成「列表能滚就先滚列表，滚到边界才收网格」—— 症状是用户想看
/// 下面的信息，得先滚完一大堆卡片网格才动；滚到哪儿停下、与网格什么关系，
/// 全凭内容多少，读起来是两件事各滚各的。
///
/// ## 现在的心智：一根滚动轴，两段内容
///
/// 把「日期网格 + 信息面板」当成同一根滚动轴上的两段（Material 折叠头就是
/// 这套）：往下滚先压缩上面那段，压到底才开始滚下面；往回滚先让下面退回
/// 顶部，到顶了才把上面展开回来。
///
/// | 手势方向 | 第一优先 | 之后 |
/// |---|---|---|
/// | 向上拖（dy < 0，看下面） | 网格收起（t → 0） | 网格收到底后滚列表 |
/// | 向下拖（dy > 0，看上面） | 列表退回顶部 | 到顶后网格展开（t → 1） |
///
/// ## ⚠️ 判据必须住在 physics 里，不能住在外层 Listener 里
///
/// 这是本轮返工一次的原因，记下来免得下次再踩：
///
/// 第一版把判据放在包住列表的 `Listener` 里，靠一个「闸门」布尔挡住列表。
/// **实测列表照样每次滚 416px** —— 因为 `Listener` 是 `Scrollable` 的**祖先**，
/// 而 Flutter 的指针事件按 hit-test 路径派发，**最深的目标先收到**
/// （`GestureBinding.dispatchEvent` 遍历 `hitTestResult.path`，从叶子往根走）。
/// 于是每次 `PointerMove` 都是「列表先按旧闸门值处理完 → 才轮到 Listener 改
/// 闸门」，第一帧的位移永远漏给列表。
///
/// 正确位置是 [MonthPanelScrollPhysics.applyPhysicsToUserOffset]：它由
/// `ScrollDragController` 在**每次位移生效之前**调用，是唯一能在列表动之前
/// 做决定的点。所以现在由 physics 直接判定并返回 0，列表一个像素都不动。
///
/// ## 为什么不用手势竞技场分工
///
/// 两者同向，竞技场只会有一个赢家：要么列表永远滚不动、要么网格永远收不起来；
/// 而且赢家取决于"谁先接受"，与"用户此刻想看哪段"无关。
///
/// ## 为什么 physics 类型必须恒定
///
/// `Scrollable._shouldUpdatePosition` 用 `physics.runtimeType` 判断要不要重建
/// `ScrollPosition`；类型一变，位置对象重建，**正在进行的拖动直接断掉**。
/// 所以这里永远只传 [MonthPanelScrollPhysics]，状态全部放在共享的
/// [MonthPanelDragState] 里。
class MonthPanelDragState {
  /// 网格还能不能往这个方向继续收放（正 = 展开方向、负 = 收起方向）。
  ///
  /// 由页面注入：收起方向答「t > 0」、展开方向答「t < 1」。
  bool Function(double dy) gridCanAbsorb = (_) => false;

  /// 网格收放的三件回调（与拉杆共用同一套）。
  VoidCallback? onCollapseStart;
  ValueChanged<double>? onCollapseUpdate;
  ValueChanged<DragEndDetails>? onCollapseEnd;

  /// 本次手势里网格是否**已经**消费过位移（用来决定抬手要不要吸附）。
  bool gridTouched = false;

  /// 本次手势里列表是否**也**消费过位移。
  ///
  /// 一旦列表也吃过位移（网格吃到边界后交接），抬手就该保留列表的惯性 ——
  /// 那是列表自己的滚动，不该被网格的吸附打断。
  bool listTouched = false;

  /// 新手势开始：清掉上一轮的状态。
  ///
  /// **每帧重置**是必要的：上次手势若在"网格消费"状态结束，不重置就会表现成
  /// "列表永远滚不动"。
  void beginGesture() {
    gridTouched = false;
    listTouched = false;
  }

  /// 网格要不要吃掉这段位移。
  ///
  /// 判据就是产品口径那张表。抽成静态纯函数是为了能单测 ——「哪段归谁」是
  /// 这套逻辑唯一容易改错的地方（上一轮就改反过一次）。
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

  /// 列表此刻还能不能在这个方向上滚（physics 手里有 position，直接算）。
  static bool listCanScroll(ScrollMetrics position, double dy) {
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
}

/// 面板列表的滚动物理：轮到网格时吞掉位移，并且**不让列表起惯性**。
///
/// 只改 `applyPhysicsToUserOffset` 是不够的：网格吃位移时列表纹丝不动，但
/// `ScrollDragController` 仍在累计速度，抬手会照常抛出惯性 —— 表现成"网格收起
/// 的同时，列表自己滑走一截"。所以 [createBallisticSimulation] 也要管：
/// 这次手势若整段由网格消费，就直接返回 null。
class MonthPanelScrollPhysics extends ClampingScrollPhysics {
  const MonthPanelScrollPhysics({required this.dragState, super.parent});

  /// ⚠️ 必须重写，否则**本类会被整个丢掉**。
  ///
  /// `Scrollable` 组装 physics 的方式是
  /// `_physics = 平台默认; _physics = physicsFromWidget?.applyTo(_physics)`，
  /// 而 `ScrollPhysics.applyTo` 的默认实现返回的是 `parent`（即平台那份
  /// `ClampingScrollPhysics`）—— 于是最终挂到 `ScrollPosition` 上的是**父类
  /// 实例**，本类的 `applyPhysicsToUserOffset` 一次都不会被调用。
  ///
  /// 本轮实测踩过：面板位移全漏给列表（每次都滚 416px），而方法里打断点
  /// 一次都不进。按 SDK 文档的示例重写 `applyTo` 之后才真正生效。
  @override
  MonthPanelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MonthPanelScrollPhysics(
      dragState: dragState,
      parent: buildParent(ancestor),
    );
  }

  final MonthPanelDragState dragState;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset != 0) {
      final toGrid = MonthPanelDragState.collapseTakesPriority(
        dy: offset,
        listCanScroll: MonthPanelDragState.listCanScroll(position, offset),
        gridCanAbsorb: dragState.gridCanAbsorb(offset),
      );
      if (toGrid) {
        // 先喂网格再返回 0：顺序反了会有一帧列表也吃到这段位移。
        if (!dragState.gridTouched) {
          dragState.gridTouched = true;
          dragState.onCollapseStart?.call();
        }
        dragState.onCollapseUpdate?.call(offset);
        return 0;
      }
      dragState.listTouched = true;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 整段手势都被网格吃了：抬手不许有惯性（列表本来就没动）。
    // 网格吃过、随后又交接给列表的，保留列表的惯性 —— 那是它自己的滚动。
    if (dragState.gridTouched && !dragState.listTouched) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

/// 面板拖拽的**生命周期**旁观者：只负责"手势开始 / 结束"两个时刻。
///
/// 位移的去向不在这一层判（见 [MonthPanelDragState] 里那段 ⚠️：`Listener` 是
/// `Scrollable` 的祖先，事件比列表晚到，判不得）。这里只做两件 physics 做不了
/// 的事：
///
/// 1. `onPointerDown` 重置手势状态（physics 不知道手势边界）；
/// 2. `onPointerUp` 用指针位移算速度，交给网格做吸附。
class MonthPanelDragArea extends StatefulWidget {
  const MonthPanelDragArea({
    required this.dragState,
    required this.child,
    super.key,
  });

  /// 与列表那份 [MonthPanelScrollPhysics] 共用的同一个实例。
  final MonthPanelDragState dragState;

  final Widget child;

  /// 边界容差：滚动物理会在边界留亚像素误差，严格比较会让"边界上那一两个
  /// 像素"被判成"还能滚"，用户在那儿拖会觉得第一下没反应。
  static const double edgeTolerance = 1;

  @override
  State<MonthPanelDragArea> createState() => _MonthPanelDragAreaState();
}

class _MonthPanelDragAreaState extends State<MonthPanelDragArea> {
  double? _lastY;
  Duration _lastTime = Duration.zero;
  double _velocity = 0;

  void _onPointerDown(PointerDownEvent event) {
    widget.dragState.beginGesture();
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
  }

  void _onPointerEnd(PointerEvent event) {
    if (widget.dragState.gridTouched) {
      // 网格吃过位移 → 按速度吸附到两端。
      //
      // 注意：即使中途已经交接给列表（`listTouched`），这里仍要调一次 end ——
      // 否则网格停在半收起状态，而列表以为自己在独立滚动，两块各停一半。
      widget.dragState.onCollapseEnd?.call(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, _velocity)),
        ),
      );
    }
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
