/// 月历网格的**收起 / 展开**判据（2026-10-20 立，纯 Dart 可单测）。
///
/// ## 用户要的交互
///
/// 「支持上滑、下拉，上滑把日期列表收起，收到只有一行，显示一个星期七天的，
/// 动画流畅，展开是把这个日期列表展开到底部，显示铺底」。
///
/// 状态只有一个连续量：展开进度 `t`（0 = 收起 / 1 = 展开），手指拖着走、
/// 松手按下面的判据吸附到两端。渲染（裁剪 + 平移）在 `MonthGrid` 里，
/// 本文只放**判据**——「收起留哪一行」「可见行数怎么插值」「拖多少算翻面」，
/// 这些都有明确期望值，埋在 widget 里就只能靠肉眼看。
///
/// ## 为什么「收起」是 1 行而不是全藏
///
/// 收起态要能一眼看出「这一周是哪一周、今天周几」，所以保留**一周七天的
/// 日期行**（外加星期表头）。全藏起来就只剩空壳，得先展开才知道自己在看哪一周
/// —— 系统日历（iOS / Google）的收起态同样保留一周。
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

/// 展开进度 [t]（0..1，0 = 收起）下应可见的行数（表头除外）。
///
/// **行数线性插值而不是总高插值**：直接插总高会让 6 行同时缩放，看起来像
/// 「整块被压扁」；按行数插值则每格位移一致，读起来是「下面几行被收上去」。
/// 越界的 [t] 原样钳回 0..1。
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

/// 数学边界自检用的常量组合（测试引用；运行时不消费）。
///
/// 放这里而不是测试里：钳制范围与行列数是**同一套口径**的两半，分开写迟早漂。
(int, int) monthGridRowBounds({
  int dateCount = kMonthGridRowCount * kMonthGridDaysPerRow,
}) {
  final maxRow = math.max(0, (dateCount - 1) ~/ kMonthGridDaysPerRow);
  return (0, maxRow);
}
