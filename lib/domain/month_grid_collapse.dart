/// 月视图「网格 ⇄ 条目面板」的收起判据（2026-10-20 立，2026-10-21 重构）。
///
/// ## 用户口径（2026-10-21，带截图）
///
/// > 「月视图永远显示六行日期，每一行就是一个星期。像截图一样，然后收起为一栏
/// > 的时候，应该是：如果这一周在这个月份的第五行，就应该往上滑动的时候，
/// > 上面三行向上收起，下面两行往上逐渐被下面的东西盖起来，然后下面显示一个
/// > 拉杆。下面的条目视图不支持左右滑动，只支持上下滑动，上下滑动操作的就是
/// > 这个收起操作。上面的月份格子支持左右和上下滑动。」
///
/// 翻译成几何：**收起不是把网格裁成一行**，而是**下面那层面板长高、把网格从
/// 下往上盖住**，同时网格自己往上顶。两种位移叠加，于是：
///
/// * 保留行**上方**的行往屏幕上边走出去（被顶上去）；
/// * 保留行**下方**的行被面板盖住（不是被裁掉，是被盖住）。
///
/// 视觉结果就是「上下同时收向保留行」，保留行最后正好停在面板上沿、贴着拉杆。
///
/// ## 两个独立量
///
/// * [kMonthGridRowCount]：网格**永远** 6 行（用户明确要求，不随月份变 4~6）；
/// * `t`（展开进度 0..1）：0 = 完全收起（只剩一行），1 = 完全展开。
///
/// 渲染在 `MonthGrid` / 页面里，本文只放判据 —— 「保留哪一行」「两个位移各多少」
/// 「拖多少算翻面」都有明确期望值，埋在 widget 里就只能靠肉眼看。
library;

import 'dart:math' as math;

/// 网格固定 6 行（见 `MonthViewLogic.monthGridDates` 的 42 格口径）。
const int kMonthGridRowCount = 6;

/// 一行 7 天。
const int kMonthGridDaysPerRow = 7;

/// 收起态保留的行数：1 行（外加星期表头）。
const int kMonthGridCollapsedRows = 1;

/// 拖动判定为「翻面」的比例：拖过总行程的这个比例就吸附到对面，否则弹回起点。
///
/// 取 0.35 而不是 0.5：收起 / 展开是**低风险、可逆**的小动作（不像删除要
/// 二次确认），手指轻轻一划就该响应，太重会读成"卡住不动"。
const double kMonthGridFlipTravel = 0.35;

/// 松手时判方向用的速度阈值（逻辑 px/s）。
///
/// 比 Flutter 的 `kMinFlingVelocity`（50）严：手一抖就翻面会让「想看整月却
/// 只剩一行」频繁误触发，宁可要求更明确的一甩。
const double kMonthGridFlingVelocity = 180;

/// 收起态保留哪一行（0 基）。
///
/// 优先级：含 [selectedDate] 的行 → 含 [today] 的行 → 含本月 1 号的行。
/// 最后一个兜底是给「翻到很远的月份、又没选日期」的场景：那页没有今天，
/// 保留 1 号所在行就是「这页主体开始的那行」。
///
/// [dates] 是 42 格日期（`MonthViewLogic.monthGridDates` 的输出）。
/// 返回值恒落在合法行号内（输入异常时钳到 0 —— 这是渲染路径上的函数，
/// 宁可画第一行也不要抛异常白屏）。
int monthGridRowToKeep({
  required List<DateTime> dates,
  required int year,
  required int month,
  DateTime? selectedDate,
  required DateTime today,
}) {
  if (dates.isEmpty) {
    return 0;
  }
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int? rowOf(DateTime target) {
    for (var i = 0; i < dates.length; i++) {
      if (sameDay(dates[i], target)) {
        return i ~/ kMonthGridDaysPerRow;
      }
    }
    return null;
  }

  final selected = selectedDate;
  if (selected != null) {
    final row = rowOf(selected);
    if (row != null) {
      return row;
    }
  }
  final todayRow = rowOf(today);
  if (todayRow != null) {
    return todayRow;
  }
  return rowOf(DateTime(year, month)) ?? 0;
}

/// 展开进度 [t]（0..1，0 = 收起）下**网格窗口**应露出几行（表头除外）。
///
/// 注意这是**窗口**的行数，不是网格内容的行数 —— 内容永远是 6 行（用户口径），
/// 收起只是窗口变小：上面几行被顶出窗口、下面几行被面板盖住。
///
/// **行数线性插值而不是总高插值**：直接插总高会让 6 行同时缩放，看起来像
/// 「整块被压扁」。越界的 [t] 钳回 0..1。
double monthGridVisibleRows(double t) {
  final clamped = t.clamp(0.0, 1.0);
  return kMonthGridCollapsedRows +
      (kMonthGridRowCount - kMonthGridCollapsedRows) * clamped;
}

/// 收起 / 展开动画的松手吸附目标（0 = 收起、1 = 展开）。
///
/// 判据按优先级：
/// 1. 明确的甩动方向压倒一切（[velocityDy] 向上 = 收起、向下 = 展开）；
/// 2. 没甩够速度就看**行程**：从 [startValue] 走过 [kMonthGridFlipTravel]
///    的比例就吸附到对面；
/// 3. 都不够 → 弹回起点状态（手指在临界点抖动不会翻面）。
double monthGridSettleTarget({
  required double startValue,
  required double currentValue,
  required double velocityDy,
}) {
  if (velocityDy <= -kMonthGridFlingVelocity) {
    return 0;
  }
  if (velocityDy >= kMonthGridFlingVelocity) {
    return 1;
  }
  final traveled = (startValue - currentValue).abs();
  if (traveled >= kMonthGridFlipTravel) {
    return currentValue < startValue ? 0 : 1;
  }
  return startValue >= 0.5 ? 1 : 0;
}

/// 月格子该用的行高：**目标是正方形**。
///
/// 用户 2026-10-21 口径：「收起到一行的时候，日期框框不是正方形，是一个上下的
/// 长方形」。根因是旧口径只按高度均分（6 行铺满可用高度、上限 78），而格宽只有
/// 约 `(屏宽 - 左右内边距 - 周次列) / 7 ≈ 47` —— 于是格子被拉成竖长方形。
///
/// 正确判据是取「高度能给的」与「宽度能给的」**较小者**：手机竖屏宽度更紧，
/// 按宽度定行高自然得到正方形；平板 / 横屏那种高度更紧的场景由高度兜住。
///
/// [horizontalPadding] 与网格给滚动视图的水平 padding 必须同源（同一个常量），
/// 否则算出来的正方形会偏、格子又变回长方形。
double monthGridRowHeight({
  required double availableWidth,
  required double availableForGrid,
  required bool weekNumberColumnVisible,
  required double horizontalPadding,
  required double weekLabelWidth,
  required double minRowHeight,
  required double maxRowHeight,
}) {
  final horizontalBudget =
      availableWidth -
      horizontalPadding * 2 -
      (weekNumberColumnVisible ? weekLabelWidth : 0);
  final squareRowHeight = horizontalBudget / kMonthGridDaysPerRow;
  return math
      .min(availableForGrid / kMonthGridRowCount, squareRowHeight)
      .clamp(minRowHeight, maxRowHeight);
}

/// 网格**内容**相对窗口的纵向偏移（非负；调用方取负后上移）。
///
/// 把保留行顶到窗口顶端 —— 于是保留行上方的行走出窗口（视觉上向上收起）。
///
/// [rowOffsetProgress]：1 = 完全顶上去（收起态）、0 = 不动（展开态）。
double monthGridScrollOffset({
  required int keptRow,
  required double rowHeight,
  required double rowOffsetProgress,
}) {
  return keptRow * rowHeight * rowOffsetProgress.clamp(0.0, 1.0);
}

/// 某一刻的完整版面：网格窗口高度、面板高度、内容位移。
///
/// 三者必须**同源算出来**，否则「面板盖到哪儿」「网格顶到哪儿」会各说各话 ——
/// 症状就是收起后仍露出半格（2026-10-21 实际发生过一次）。
class MonthGridLayout {
  const MonthGridLayout({
    required this.rowHeight,
    required this.gridHeight,
    required this.panelHeight,
    required this.scrollOffset,
    required this.keptRow,
  });

  /// 单行高度（正方形目标，见 [monthGridRowHeight]）。
  final double rowHeight;

  /// 网格**可见窗口**高度（含星期表头）。
  final double gridHeight;

  /// 下方条目面板的高度（占满剩下的空间）。
  final double panelHeight;

  /// 网格内容相对窗口的纵向位移（**正数**；绘制时取负即上移）。
  final double scrollOffset;

  /// 收起后停住的那一行（0 基）。
  final int keptRow;
}

/// 算出某一刻的完整版面。
///
/// [t] = 展开进度（0 收起 / 1 展开）。
///
/// 两个位移**同时发生**（用户口径「上面三行向上收起，下面两行往上逐渐被下面的
/// 东西盖起来」）：
///
/// * 网格窗口从「表头 + 6 行」缩到「表头 + 1 行」；
/// * 面板高度从 0 长到「可用高 - 收起后网格窗口高」，把网格下方的行盖掉。
///
/// 行高按**始终 6 行**的可用空间算：网格永远显示六行，收起只缩小窗口，
/// 行高本身不能跟着变（否则收起时格子会突然变高，读起来像「字放大了」）。
MonthGridLayout monthGridLayout({
  required double t,
  required double availableHeight,
  required double headerHeight,
  required double horizontalPadding,
  required double availableWidth,
  required bool weekNumberColumnVisible,
  required double weekLabelWidth,
  required double minRowHeight,
  required double maxRowHeight,
  required int keptRow,
  double handleHeight = 0,
  double topPadding = 0,
}) {
  final progress = t.clamp(0.0, 1.0);
  final visibleRows = monthGridVisibleRows(progress);

  final rowHeight = monthGridRowHeight(
    availableWidth: availableWidth,
    // 行高只能用「扣掉上内边距、把手之后」的高度：这三样都占同一块可用高度，
    // 少扣一个，算出的行高就偏大，6 行必然放不下（溢出 8px 就是这么来的）。
    availableForGrid:
        availableHeight - topPadding - handleHeight - headerHeight,
    weekNumberColumnVisible: weekNumberColumnVisible,
    horizontalPadding: horizontalPadding,
    weekLabelWidth: weekLabelWidth,
    minRowHeight: minRowHeight,
    maxRowHeight: maxRowHeight,
  );

  // gridHeight **包含**页面那层上内边距：调用方会把网格包在一个
  // `Padding(top: 同一值)` 里，那 8px 是真实占用的高度。不包含的话
  // PageView 少给 8px，MonthGrid 溢出（本仓实际踩过：overflow 8px）。
  // 注意行高预算里已经扣过它，两处不能重复扣（那会少 8px 反向留白）。
  final gridHeight = topPadding + headerHeight + visibleRows * rowHeight;
  final scrollOffset = monthGridScrollOffset(
    keptRow: keptRow,
    rowHeight: rowHeight,
    // 展开态保留行就在原位（0），收起态把它顶到窗口顶端（1）。
    rowOffsetProgress: 1 - progress,
  );

  return MonthGridLayout(
    rowHeight: rowHeight,
    gridHeight: gridHeight,
    // 面板吃掉剩下的空间，先扣掉**表格把手**那一条与页面**上内边距**：
    // 两者都长在网格外面，却占同一块可用高度。不扣就会把面板顶出屏幕
    // （`Expanded` 只吃剩下的空间）。
    panelHeight: math.max(
      0,
      availableHeight - topPadding - gridHeight - handleHeight,
    ),
    scrollOffset: scrollOffset,
    keptRow: keptRow,
  );
}

/// 数学边界自检用的常量组合（测试引用；运行时不消费）。
///
/// 放这里而不是测试里：钳制范围与行列数是**同一套口径**的两半，分开写迟早漂。
(int, int) monthGridRowBounds({
  int dateCount = kMonthGridRowCount * kMonthGridDaysPerRow,
}) {
  final maxRow = math.max(0, (dateCount - 1) ~/ kMonthGridDaysPerRow);
  return (0, maxRow);
}
