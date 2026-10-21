/// 月视图的**字阶与栅格**：整页只有一个真源。
///
/// ## 为什么必须收在一处
///
/// 2026-10-21 的专业评审量了真机截图：这一页同时用了 **9 级字号**
/// （9 / 9.5 / 11 / 11.5 / 12 / 12.5 / 13 / 13.5 / 14 / 15 / 16 / 17 / 21），
/// 其中 11.5、9.5、13.5 这类半像素值与任何一级都不成比例 —— 层级因此不可预期：
/// 「本月概览」标题（13）和卡片标题（13）同重，而副标题 11.5 与说明 11 差半级，
/// 读起来只是"有的字大一点"。
///
/// 左边线同样有四条：品牌名 14.1dp、卡片填充 13.5dp、分区标题 11.7dp、
/// 周次轨 17.2dp。四条都差 1~5dp —— 版面找不到一根真正的竖线，这是"拼装感"
/// 的主要来源。
///
/// 所以字阶只留四级（caption / body / title / display）加两个专用值，
/// 左轴只留一条 [MonthMetrics.axisInset]。
library;

/// 月视图的字号阶梯。
///
/// 四级主阶：11 → 12 → 13 → 20。所有可见文字都落在这四级上或紧邻它的
/// 两个专用值（日期数字 14、月标题 17）—— 不再新增 11.5 / 9.5 这类中间值。
abstract final class MonthType {
  /// 最小一级：星期表头、统计标签、周次轨（[rail]）、圆点旁的说明。
  static const double caption = 11;

  /// 正文/副标题：卡片副行、空态说明、按钮文字。
  static const double body = 12;

  /// 标题级：分区标题、卡片标题、当日议程的行标题。
  static const double title = 13;

  /// 展示级：本月概览里的三个大数字。
  static const double display = 20;

  /// 日期数字（网格格子里）。比 [title] 大一级、比 [display] 小得多，是个专用值：
  /// 它要在一格 ~46dp 的方形里当主体，13 字号会显得空、16 会顶到圆点。
  static const double dayNumber = 14;

  /// 工具行的月份（`1月`）—— 整页视觉重心，比日期数字大一级。
  static const double monthTitle = 17;

  /// 工具行的年份（`2027年`）：弱色、比月份小四级，只作上下文。
  static const double monthYear = 13;

  /// 周次轨（`第 17 周`）。宽度被 40dp 的窄列卡着，只能取这一档；
  /// 必须配合 `maxLines: 1` + `FittedBox` 使用，否则会折成两行。
  static const double rail = 10;
}

/// 月视图的栅格与间距。
abstract final class MonthMetrics {
  /// **唯一的左轴**：品牌名、网格卡片、分区标题、面板卡片全部落在这条线上。
  ///
  /// 取 14 的依据：旧的四条线是 11.7 / 13.5 / 14.1 / 17.2，14 落在中位数附近，
  /// 且与首页顶栏（8 + 4 微调 + 字侧边距 ≈ 14）自然对齐 —— 不改顶栏也能同轴。
  static const double axisInset = 14;

  /// 网格卡片之间的缝。卡片填充左边缘因此比 [axisInset] 内缩这条缝。
  static const double cellGap = 1.5;

  /// 网格左右内边距。**必须由 [axisInset] 推出来**，不能另写一个数：
  /// 卡片左边缘 = 内边距 + [cellGap]，要和面板卡片同轴就只能这么算。
  static const double gridHorizontalPadding = axisInset - cellGap;

  /// 分区之间（概览卡 → 「本月有安排的日子」）的竖向间距。
  static const double sectionGap = 18;

  /// 分区标题与它下面第一张卡之间。
  static const double sectionTitleGap = 8;

  /// 面板内列表项之间。
  static const double itemGap = 8;

  /// 面板卡片圆角（与日视图议程卡同档）。
  static const double cardRadius = 20;

  /// 面板底部「溶解」渐隐带的高度。
  ///
  /// 面板是一条可滚动的列表，底部又浮着玻璃坞药丸 —— 不处理时列表项会被药丸
  /// 从中间切开，半行字露在外面，读起来是渲染错误（2026-10-21 真机）。
  /// 一条从面板底色到透明的短渐变让内容**淡出**而不是**被切断**。
  static const double panelBottomFade = 28;
}
