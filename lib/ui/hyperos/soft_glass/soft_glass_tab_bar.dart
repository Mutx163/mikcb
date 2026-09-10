import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'soft_glass_surface.dart';

/// 柔光玻璃底栏 Tab。
class SoftGlassTab {
  const SoftGlassTab({
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  final Widget icon;
  final String label;
  final bool enabled;
}

/// 弹簧描述 —— 直译 Compose `Spring` 常量。
///
/// Compose 的 `dampingRatio` 对应 Flutter 的 `damping`，两者关系为
/// `damping = 2 × ratio × sqrt(mass × stiffness)`（取 mass = 1）。
abstract final class _SoftGlassSprings {
  /// `DampingRatioLowBouncy`(0.75) + `StiffnessMediumLow`(400)：
  /// 指示器归位的回弹（有一点过冲）。
  static const SpringDescription settle = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 30,
  );

  /// `DampingRatioMediumBouncy`(0.5) + `StiffnessMedium`(1500)：按压缩放。
  static const SpringDescription press = SpringDescription(
    mass: 1,
    stiffness: 1500,
    damping: 38.73,
  );

  /// `DampingRatioNoBouncy`(1.0) + `StiffnessHigh`(10000)：速度拉伸的回正。
  static const SpringDescription stretch = SpringDescription(
    mass: 1,
    stiffness: 10000,
    damping: 200,
  );

  /// `DampingRatioNoBouncy`(1.0) + `StiffnessMedium`(1500)：整栏位移回正。
  static const SpringDescription panel = SpringDescription(
    mass: 1,
    stiffness: 1500,
    damping: 77.46,
  );
}

/// 拖动速度估计：对齐 Compose / Android `VelocityTracker` 的滑窗做法。
///
/// 只用窗口（100ms）内的采样点，对 (t, x) 做过原点最小二乘、取斜率当速度。
/// 之前用相邻两帧差分，噪声极大：单帧抖动会被除以极短的 dt 放大成速度尖峰，
/// 直接体现为指示器拉伸量乱跳、`floatingTabTransformOriginX` 左右乱摆。
class _DragVelocity {
  static const int _horizonMicros = 100 * 1000;

  final List<int> _times = <int>[];
  final List<double> _positions = <double>[];

  void reset(Duration time, double x) {
    _times
      ..clear()
      ..add(time.inMicroseconds);
    _positions
      ..clear()
      ..add(x);
  }

  void add(Duration time, double x) {
    final t = time.inMicroseconds;
    _times.add(t);
    _positions.add(x);
    // 至少留窗口外的第一个点做下界，避免窗口内只剩一个点。
    var drop = 0;
    while (drop + 2 < _times.length && _times[drop + 1] < t - _horizonMicros) {
      drop++;
    }
    if (drop > 0) {
      _times.removeRange(0, drop);
      _positions.removeRange(0, drop);
    }
  }

  /// 速度（px/s）。样本不足时返回 0。
  double get velocity {
    if (_times.length < 2) {
      return 0;
    }
    // 以最后一个采样为原点：τ ≤ 0（秒），d 为位移。拟合 d = v·τ。
    final tEnd = _times.last;
    final xEnd = _positions.last;
    var sumTT = 0.0;
    var sumTD = 0.0;
    for (var i = 0; i < _times.length; i++) {
      final tau = (_times[i] - tEnd) / 1000000;
      sumTT += tau * tau;
      sumTD += tau * (_positions[i] - xEnd);
    }
    if (sumTT <= 0) {
      return 0;
    }
    return sumTD / sumTT;
  }
}

/// 柔光玻璃底栏：Hyper-PiliPlus `MiuixFloatingTabBar`。
///
/// - 高 54 胶囊，内容 padding h7 / v3
/// - 指示器：全高胶囊，left = itemWidth·pos − 3，width = itemWidth + 6
/// - **按住指示器横向拖动**可切换 Tab；拖动时按速度横向拉伸指示器、
///   整条栏最多位移 4dp
/// - 松手 spring 回弹到最近的**可用** Tab（`resolveFloatingTabTarget`）
class SoftGlassTabBar extends StatefulWidget {
  const SoftGlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.selectedColor,
    this.unselectedColor,
    this.blurEnabled = true,
    this.iconSize = SoftGlassTokens.tabIconSize,
    this.labelFontSize = 10,
    this.polarity,
  });

  final List<SoftGlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? selectedColor;

  /// 未选中墨色。**缺省与 [selectedColor] 一致**——原版不分选中/未选中，
  /// 只靠字重与指示器区分；仅当确实要额外衰减时才传。
  final Color? unselectedColor;
  final bool blurEnabled;
  final double iconSize;
  final double labelFontSize;
  final SoftGlassPolarity? polarity;

  @override
  State<SoftGlassTabBar> createState() => _SoftGlassTabBarState();
}

class _SoftGlassTabBarState extends State<SoftGlassTabBar>
    with TickerProviderStateMixin {
  /// 视觉位置（浮点下标）。拖动时直接写，松手后 spring 到整数。
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  /// 指示器按压进度 0→1。
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// 速度拉伸量（占指示器宽度的比例，上限 [SoftGlassTokens.maximumStretch]）。
  late final AnimationController _stretch = AnimationController.unbounded(
    vsync: this,
  );

  /// 整栏横向位移（dp）。
  late final AnimationController _panel = AnimationController.unbounded(
    vsync: this,
  );

  /// 拖动起手点是否落在指示器内 —— 由 [_onPointerDown] 置位，[_onDragStart] 消费。
  bool _pressed = false;
  bool _dragging = false;

  /// 当前拖动位移（px），用于算整栏位移比例。
  double _dragOffsetPx = 0;

  /// 手势速度（px/s），用于拉伸方向与幅度。
  ///
  /// 拖动过程中的速度只能自己算：`DragUpdateDetails` 只有 delta，
  /// `DragEndDetails` 才带终速，而拉伸必须在拖动进行中就实时反应
  /// （原版也是边走边 `velocityTracker.addPosition`）。
  final _DragVelocity _velocityTracker = _DragVelocity();
  double _velocity = 0;

  /// 实测栏宽（逻辑像素），整栏位移比例的分母。
  ///
  /// 原版用 `constraints.maxWidth`（实测值），不是宽度上限：本组件的上限是
  /// `min(槽数 × 80, 380)`，而坞容器还会再夹到 272 —— 拿上限当分母会把比例
  /// 算小（272/380 ≈ 0.72），位移曲线偏慢、封顶偏晚。由 build 里的
  /// LayoutBuilder 每帧写入。
  double _barWidth = 0;

  /// 本帧由拖动提交的目标下标 —— 同步外部选中时不再二次动画。
  int? _pendingCommittedIndex;

  @override
  void didUpdateWidget(covariant SoftGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) {
      return;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _syncExternalSelection(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    _stretch.dispose();
    _panel.dispose();
    super.dispose();
  }

  int get _count => widget.tabs.length;

  /// 底栏宽度上限：`min(槽数 × 80, 380)`（原版 `widthIn(max = ...)`）。
  double get _maxBar => (_count * SoftGlassTokens.maximumItemWidth)
      .clamp(0, SoftGlassTokens.maximumWidth)
      .toDouble();

  /// 整栏位移比例的分母：优先用实测栏宽，尚未布局时退回上限。
  double get _panelReferenceWidth => _barWidth > 0 ? _barWidth : _maxBar;

  /// 最近可用 Tab：先按四舍五入取整，再在已启用项里找最近
  /// （对齐 `resolveFloatingTabTarget`）。
  int _resolveTarget(double position) {
    if (_count <= 0) {
      return 0;
    }
    final rounded = position.round().clamp(0, _count - 1);
    final enabled = <int>[
      for (var i = 0; i < _count; i++)
        if (widget.tabs[i].enabled) i,
    ];
    if (enabled.isEmpty) {
      return rounded;
    }
    var best = enabled.first;
    for (final index in enabled) {
      final candidateDelta = (index - rounded).abs();
      final bestDelta = (best - rounded).abs();
      if (candidateDelta < bestDelta ||
          (candidateDelta == bestDelta &&
              (index - position).abs() < (best - position).abs())) {
        best = index;
      }
    }
    return best;
  }

  void _syncExternalSelection(int index) {
    if (_pendingCommittedIndex == index) {
      _pendingCommittedIndex = null;
      return;
    }
    _pendingCommittedIndex = null;
    if ((_position.value - index).abs() > 0.001) {
      _settleTo(index.toDouble());
    }
  }

  void _settleTo(double target) {
    _position.animateWith(
      SpringSimulation(_SoftGlassSprings.settle, _position.value, target, 0),
    );
  }

  /// `floatingTabStretch`：每秒钟跨过的 Tab 数 / 8 × 0.18，封顶 0.18。
  double _stretchFor(double velocityPxPerSecond, double tabWidthPx) {
    if (tabWidthPx <= 0) {
      return 0;
    }
    final tabsPerSecond = velocityPxPerSecond.abs() / tabWidthPx;
    return (tabsPerSecond /
            SoftGlassTokens.fullStretchTabsPerSecond *
            SoftGlassTokens.maximumStretch)
        .clamp(0, SoftGlassTokens.maximumStretch);
  }

  /// `floatingTabTransformOriginX`：拉伸时把变换原点朝速度反方向挪。
  double _transformOriginX(double velocityPxPerSecond, double stretch) {
    if (stretch <= 0 || velocityPxPerSecond == 0) {
      return 0.5;
    }
    final direction = velocityPxPerSecond > 0 ? 1.0 : -1.0;
    final normalized = (stretch / SoftGlassTokens.maximumStretch).clamp(0.0, 1.0);
    return (0.5 + direction * normalized * 0.35).clamp(0.15, 0.85);
  }

  /// `floatingTabPanelDragFraction` + `MaximumPanelOffsetDp`。
  double _panelOffsetFor(double dragOffsetPx, double panelWidthPx) {
    if (panelWidthPx <= 0) {
      return 0;
    }
    final fraction = (dragOffsetPx / panelWidthPx).clamp(-1.0, 1.0);
    final eased = Curves.easeOut.transform(fraction.abs());
    return SoftGlassTokens.maximumPanelOffsetDp *
        (fraction.isNegative ? -1 : 1) *
        eased;
  }

  void _onPointerDown(PointerDownEvent event, double cellLeft, double cellWidth) {
    _velocityTracker.reset(event.timeStamp, event.localPosition.dx);
    _velocity = 0;
    // 起手点必须落在**当前选中格**内，否则不进入按压/拖动。
    // 原版闸门用的是格子宽度 `[pos × itemWidth, +itemWidth]`，不是指示器
    // 的视觉矩形（指示器左右各多出 3dp 溢出）。
    final dx = event.localPosition.dx;
    final inside = dx >= cellLeft && dx <= cellLeft + cellWidth;
    if (!inside) {
      return;
    }
    _pressed = true;
    _press.animateWith(
      SpringSimulation(_SoftGlassSprings.press, _press.value, 1, 0),
    );
  }

  void _endPress() {
    if (!_pressed) {
      return;
    }
    _pressed = false;
    _press.animateWith(
      SpringSimulation(_SoftGlassSprings.press, _press.value, 0, 0),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    _velocityTracker.add(event.timeStamp, event.localPosition.dx);
    _velocity = _velocityTracker.velocity;
  }

  void _onDragStart(double itemWidth) {
    // 起手点必须落在指示器内（_pressed 只在按下于指示器范围时置位），
    // 否则不进入拖动——对齐原版 awaitFirstDown 之后的区间判断。
    if (!_pressed) {
      return;
    }
    _press.stop();
    _press.value = 1;
    _dragging = true;
    _position.stop();
    _panel.stop();
    _dragOffsetPx = 0;
    _velocity = 0;
  }

  void _onDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (!_dragging || itemWidth <= 0 || _count <= 0) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    _dragOffsetPx += delta;
    final next = (_position.value + delta / itemWidth)
        .clamp(0.0, (_count - 1).toDouble());
    _position.value = next;
    _stretch.value = _stretchFor(_velocity, itemWidth);
    _panel.value = _panelOffsetFor(_dragOffsetPx, _panelReferenceWidth);
  }

  void _onDragEnd(double itemWidth) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    // 松手即清零速度（原版 `finishGesture` 同样把 velocityPxPerSecond 归零）：
    // 拉伸与变换原点都按 velocity=0 回正，原点回中由
    // `floatingTabTransformOriginX(0, ·)` 负责，不用终速。
    _velocity = 0;
    final target = _resolveTarget(_position.value);
    _pendingCommittedIndex = target;
    _applyPendingTarget(target);
    _stretch.animateWith(
      SpringSimulation(_SoftGlassSprings.stretch, _stretch.value, 0, 0),
    );
    _releasePanel();
    _endPress();
  }

  void _onDragCancel() {
    if (!_dragging) {
      _endPress();
      return;
    }
    _dragging = false;
    _velocity = 0;
    _applyPendingTarget(widget.selectedIndex.clamp(0, _count - 1));
    _stretch.animateWith(
      SpringSimulation(_SoftGlassSprings.stretch, _stretch.value, 0, 0),
    );
    _releasePanel();
    _endPress();
  }

  void _applyPendingTarget(int target) {
    _settleTo(target.toDouble());
    if (target != widget.selectedIndex) {
      widget.onTabSelected(target);
    }
  }

  /// 松手后整栏从当前位移 spring 回 0。
  void _releasePanel() {
    _dragOffsetPx = 0;
    _panel.animateWith(
      SpringSimulation(
        _SoftGlassSprings.panel,
        _panel.value,
        0,
        0,
        tolerance: const Tolerance(distance: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final count = _count;
    final isDark =
        widget.polarity == SoftGlassPolarity.dark ||
        (widget.polarity == null &&
            Theme.of(context).brightness == Brightness.dark);
    // 原版 selected 与 unselected **同色**（纯白 / 纯黑）：选中态只靠字重
    // （SemiBold vs Medium）+ 指示器区分，未选中不做透明度衰减。
    final selectedInk =
        widget.selectedColor ?? (isDark ? Colors.white : Colors.black);
    final unselectedInk = widget.unselectedColor ?? selectedInk;
    final indicatorColor = SoftGlassTokens.indicatorFill(
      context,
      polarity: widget.polarity,
    );
    final selected = widget.selectedIndex.clamp(0, count - 1);
    final maxBar = _maxBar;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_panel]),
      builder: (context, child) => Transform.translate(
        // 整栏位移吸附到物理像素整数（原版 `IntOffset(panelOffsetPx.roundToInt())`），
        // 否则分数逻辑像素平移会在拖动期间发出亚像素抖动。
        offset: Offset((_panel.value * dpr).round() / dpr, 0),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBar),
        child: SizedBox(
          height: SoftGlassTokens.barHeight,
          width: double.infinity,
          child: SoftGlassSurface(
            blurEnabled: widget.blurEnabled,
            polarity: widget.polarity,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SoftGlassTokens.horizontalContentPadding,
                vertical: SoftGlassTokens.verticalContentPadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 内容区宽度 = 实测栏宽 − 左右 padding。反推出整栏宽度作为
                  // 「整栏位移比例」的分母——原版用的就是整栏的
                  // `constraints.maxWidth`，不是宽度上限（见 [_barWidth]）。
                  _barWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth +
                            SoftGlassTokens.horizontalContentPadding * 2
                      : maxBar;
                  final itemWidth = constraints.maxWidth / count;
                  double indicatorLeft(double position) =>
                      itemWidth * position -
                      SoftGlassTokens.indicatorHorizontalOverflow;
                  final indicatorWidthPx =
                      itemWidth + SoftGlassTokens.indicatorHorizontalOverflow * 2;
                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _position,
                      _press,
                      _stretch,
                    ]),
                    builder: (context, _) {
                      final pos = _position.value.clamp(
                        0.0,
                        (count - 1).toDouble(),
                      );
                      final stretch = _stretch.value;
                      final pressScale = 1 +
                          (SoftGlassTokens.pressedScale - 1) * _press.value;
                      final originX = _transformOriginX(_velocity, stretch);
                      return Stack(
                        children: [
                          Positioned(
                            left: indicatorLeft(pos),
                            top: 0,
                            bottom: 0,
                            width: indicatorWidthPx,
                            child: Transform(
                              alignment: Alignment(originX * 2 - 1, 0),
                              transform: Matrix4.diagonal3Values(
                                pressScale * (1 + stretch),
                                pressScale,
                                1,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: indicatorColor,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) => _onPointerDown(
                              event,
                              // 闸门按格子算，不是指示器的视觉矩形。
                              itemWidth * pos,
                              itemWidth,
                            ),
                            onPointerMove: _onPointerMove,
                            onPointerUp: (_) {
                              if (!_dragging) {
                                _endPress();
                              }
                            },
                            onPointerCancel: (_) {
                              if (!_dragging) {
                                _endPress();
                              }
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) => _onDragStart(itemWidth),
                              onHorizontalDragUpdate: (details) =>
                                  _onDragUpdate(details, itemWidth),
                              onHorizontalDragEnd: (_) => _onDragEnd(itemWidth),
                              onHorizontalDragCancel: _onDragCancel,
                              child: Row(
                                children: [
                                  for (var i = 0; i < count; i++)
                                    SizedBox(
                                      width: itemWidth,
                                      height: double.infinity,
                                      child: _SoftGlassTabItem(
                                        tab: widget.tabs[i],
                                        selected: i == selected,
                                        selectedColor: selectedInk,
                                        unselectedColor: unselectedInk,
                                        iconSize: widget.iconSize,
                                        labelFontSize: widget.labelFontSize,
                                        // 只有选中项跟着按压进度缩图标
                                        // （原版 SelectedIconPressedScale 0.90）。
                                        pressProgress: i == selected
                                            ? _press.value
                                            : 0,
                                        onTap: widget.tabs[i].enabled
                                            ? () => widget.onTabSelected(i)
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked：图标在上、文字在下（参考 FloatingTabItemContent.Stacked）。
class _SoftGlassTabItem extends StatelessWidget {
  const _SoftGlassTabItem({
    required this.tab,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.iconSize,
    required this.labelFontSize,
    required this.pressProgress,
    this.onTap,
  });

  final SoftGlassTab tab;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double iconSize;
  final double labelFontSize;
  final double pressProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = tab.enabled;
    final ink = !enabled
        ? (selected ? selectedColor : unselectedColor).withValues(alpha: 0.22)
        : (selected ? selectedColor : unselectedColor);
    final iconScale = 1 +
        (SoftGlassTokens.selectedIconPressedScale - 1) * pressProgress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // 原版 Stacked 的内边距是 horizontal 2 / vertical 2。
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: iconScale,
              child: IconTheme.merge(
                data: IconThemeData(color: ink, size: iconSize),
                child: tab.icon,
              ),
            ),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ink,
                fontSize: labelFontSize,
                // 原版 Stacked 的字号 10sp / 行高 11sp。
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
