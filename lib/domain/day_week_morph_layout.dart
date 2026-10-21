/// 日视图 ↔ 周视图「列宽形变」的纯几何计算（2026-10-21）。
///
/// 这条转场要表达的观感：**选中那一天那一列向左右撑开到整屏**，旁边的日子
/// 被推开（反向则收窄、旁边的日子被让回来）。所以几何的自变量是**列宽**，
/// 不是窗口的宽高比例。
///
/// 这里只做算术，不碰 UI：输入 `progress`（形变进度，0 = 周视图，1 = 日视图）
/// 与视口尺寸，输出每一列的左边界与宽度。纯函数便于单测（`test/domain/`
/// 允许新增），也给 widget 层一个唯一事实来源——不要在 build 里另立一套公式。
///
/// ## 为什么「邻居只平移、不压窄」
///
/// 非选中列保持周视图原宽、随选中列撑开被推出画面，而不是「瓜分剩余宽度」
/// 一起压窄（后者是「等分挤压」）。理由有两条：
///
/// 1. **观感**：等分挤压把 6 个邻居压到 20~40px 时，卡里的标题会退化成一竖条、
///    房间号消失，中途读起来像一堆挤扁的色块（浏览器原型实测）。
/// 2. **成本**：邻居只平移 ⇒ 它们不需要重排、玻璃卡身后的壁纸采样区也不变；
///    真正在变宽/变窄的只有选中那一列。「每帧重排 7 列几十张卡」是本仓明确
///    测过的重活（`CourseSurface` 类注释、`2026-10-20-day-view-open-close-flash`
///    的 Alternatives 段给过 3~9ms/帧的量级）。
library;

import 'dart:math' as math;

/// 一列的几何：左边界（相对内容区最左）与宽度，单位逻辑像素。
class MorphColumnRect {
  const MorphColumnRect({required this.left, required this.width});

  final double left;
  final double width;

  /// 右边界（不含）：`left + width`。
  double get right => left + width;

  /// 中点横坐标。
  double get center => left + (width / 2);

  @override
  String toString() =>
      'MorphColumnRect(left: ${left.toStringAsFixed(2)}, '
      'width: ${width.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      other is MorphColumnRect &&
      other.left == left &&
      other.width == width;

  @override
  int get hashCode => Object.hash(left, width);
}

/// 一次形变中全部列的几何快照。
///
/// [columns] 与「可见日」一一对应（下标 0 = 可见的第一天），顺序不变。
class MorphColumnsLayout {
  const MorphColumnsLayout({
    required this.columns,
    required this.timeColumnWidth,
    required this.selectedIndex,
  });

  /// 每一列的几何，顺序与可见日一致。
  final List<MorphColumnRect> columns;

  /// 时间列宽度。周视图是 [timeColumnWidth]（34/40），日视图收到 0。
  final double timeColumnWidth;

  /// 选中日的下标（即正在撑开/收窄的那一列）。
  final int selectedIndex;

  /// 选中列的几何。
  MorphColumnRect get selected => columns[selectedIndex];

  @override
  String toString() =>
      'MorphColumnsLayout(time: ${timeColumnWidth.toStringAsFixed(1)}, '
      'selected: $selectedIndex, columns: $columns)';
}

/// 形变全程的时间列最小可见宽度。
///
/// 不取 0 有两个原因：
/// 1. `timetable_empty_slot_layer.dart` 里有一处
///    `(localPosition.dx / dayWidth).floor()` —— 除数为 0 时
///    `NaN.floor()` / `Infinity.floor()` 会**抛** `UnsupportedError`，
///    不是无害的空操作。
/// 2. 时间列本身是 `SizedBox(width:)`，宽度 0 时里面的 `Text` 仍会被布局，
///    debug 下刷 overflow 断言。
///
/// 1 逻辑像素足够：视觉上等同于消失，但让所有除法有定义。
const double kMorphMinColumnWidth = 1;

/// 计算形变进行到 [progress] 时每一列的几何。
///
/// - [progress]：0 = 周视图，1 = 日视图。**必须是曲线作用后的值**（调用方传
///   `DayViewExpandMotion.curve.transform(controller.value)`），这里不再叠曲线——
///   几何层不该知道动画手感。
/// - [viewportWidth]：内容区总宽（不含任何外边距）。
/// - [weekTimeColumnWidth]：周视图的时间列宽（日视图里收到 0）。
/// - [visibleDayCount]：可见日数量（5 或 7）。
/// - [selectedIndex]：选中日在 [visibleDayCount] 里的下标。
///
/// 返回值保证：
/// - `progress == 0` 时逐值还原周视图（`timeColumnWidth == weekTimeColumnWidth`，
///   每列 `left == t + i * dayWidth`、`width == dayWidth`）；
/// - `progress == 1` 时选中列铺满（`left == 0`、`width == viewportWidth`）、
///   时间列宽 0，邻居在视口外；
/// - 邻居列宽恒为周视图的 `dayWidth`（只平移、不压窄）；
/// - 任何宽度都不小于 [kMorphMinColumnWidth]。
MorphColumnsLayout morphColumnsLayout({
  required double progress,
  required double viewportWidth,
  required double weekTimeColumnWidth,
  required int visibleDayCount,
  required int selectedIndex,
}) {
  assert(visibleDayCount > 0, 'visibleDayCount must be positive');
  assert(
    selectedIndex >= 0 && selectedIndex < visibleDayCount,
    'selectedIndex out of range',
  );
  assert(viewportWidth >= 0, 'viewportWidth must not be negative');

  final t = progress.clamp(0.0, 1.0);

  // 周视图里一天占的宽度。用 max(viewport, ...) 兜住「视口比时间列还窄」这种
  // 退化情形（分屏/极小窗），否则 dayWidth 为负会让后面所有坐标翻号。
  final gridWidth = math.max(0, viewportWidth - weekTimeColumnWidth);
  final dayWidth = math.max(kMorphMinColumnWidth, gridWidth / visibleDayCount);

  // 时间列：周视图宽 → 日视图 0（日视图没有时间列）。
  //
  // 这里**不夹下限**：日视图里选中列左边界就是 0，时间列若留 1px 会和它重叠出
  // 一条缝。除零风险不在这个量上——除数用的是下面 `dayWidth`，而本方案里
  // 邻居列保持原宽，`dayWidth` 全程不变（见 [kMorphMinColumnWidth] 的说明）。
  final timeWidth = weekTimeColumnWidth * (1 - t);

  // 选中列：dayWidth → 整屏。
  final selectedWidth = math.max(
    kMorphMinColumnWidth,
    dayWidth + (viewportWidth - dayWidth) * t,
  );

  // 选中列的左边界：周视图里是 `时间列 + i × 日宽`，日视图里是 0。
  final weekSelectedLeft = weekTimeColumnWidth + selectedIndex * dayWidth;
  final selectedLeft = weekSelectedLeft * (1 - t);

  final columns = <MorphColumnRect>[];
  for (var i = 0; i < visibleDayCount; i++) {
    if (i == selectedIndex) {
      columns.add(
        MorphColumnRect(left: selectedLeft, width: selectedWidth),
      );
      continue;
    }
    // 邻居：保持原宽，按「与选中列隔着几列」被推到选中列左/右侧。
    final distance = (i - selectedIndex).abs();
    final double left;
    if (i < selectedIndex) {
      left = selectedLeft - distance * dayWidth;
    } else {
      left = selectedLeft + selectedWidth + (distance - 1) * dayWidth;
    }
    columns.add(MorphColumnRect(left: left, width: dayWidth));
  }

  return MorphColumnsLayout(
    columns: List<MorphColumnRect>.unmodifiable(columns),
    timeColumnWidth: timeWidth,
    selectedIndex: selectedIndex,
  );
}
