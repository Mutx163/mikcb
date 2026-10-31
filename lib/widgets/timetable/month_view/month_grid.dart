import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';
import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import 'month_day_cell.dart';
import 'month_metrics.dart';

/// 月历网格：星期表头 + 4~6 行 × 7 列日期格 + 每行学期周次行标。
///
/// 纯展示部件：数据由 [MonthGridData] 带进来，本部件不取数、不读 provider。
/// 格子数据恒为 42 个（见 [MonthViewLogic.monthGridDates]），但**只画需要的
/// 行数** —— 尾部若整行都是邻月补位格就不画（`MonthGridData.rowsInMonth`）。
///
/// ## 2026-10-25：行数不再恒 6
///
/// 旧口径是"永远显示六行"（用户 2026-10-21 要求），换来的是"翻月时整页高度
/// 纹丝不动"。真机上那条保证的代价太大：约一半的月份尾部多出一整行纯灰的
/// 邻月数字（2026 年 10 月的第 6 行 `2 3 4 5 6 7 8` 全是 11 月），白占约
/// 45dp 且正落在视觉重心下方，读起来像"表格没画完"。
///
/// 用户 2026-10-25 明确选了「接受翻月时卡片高度变化」，于是改成按月份自适应。
/// 行高仍由调用方按行数统一算好传进来（[rowHeight]），本部件不自己算。
///
/// ## 2026-10-23：格子不再带卡片材质，也不再按壁纸判墨
///
/// 这一层现在整个躺在一张**白色日历卡**里（`MonthCalendarCard`），所以：
///
/// * 格子只画内容（日号 + 色带 + 角标），材质由卡提供；
/// * 墨色按**主题**判（`colorScheme.onSurface`），不再按壁纸逐行亮度 ——
///   2026-10-21 那套 `rowLuminances` 是为"格子直接压在壁纸上"设计的，卡一变白
///   它就失效了（拿壁纸亮度去判白卡上的字，暗壁纸会算出白字 → 白压白）。
///
/// 表头与周次轨同理：它们也在白卡里。
///
/// ## 收起 / 展开（2026-10-20）
///
/// [progress] 是连续的展开进度（1 = 全展开、0 = 只留一周），由页面把拖拽接到
/// 动画控制器上再传进来。收起不是「隐藏 5 行」而是**裁剪 + 平移**：
/// 42 格始终在树上（widget key 与 InkWell 状态不丢），把窗口对准「保留行」
/// （[keptRowIndex]，判据见 `monthGridRowToKeep`）。判据本身在
/// `month_grid_collapse.dart`（纯 Dart 可单测），本部件只管画。
///
/// ## 为什么收的是「动画」而不是一个 double（2026-10-21）
///
/// 改前页面把 `_gridExpand.value` 当普通参数传进来，于是**每一帧都要由页面重建
/// 整棵**（否则值不会变）—— 42 个格子跟着重建。真机实测 42 格/帧、总 build
/// 914 次/帧，而日视图与周视图同一时刻只有 1 次。
///
/// 现在订阅动画的责任落在本部件内部：[AnimatedBuilder] 的 `child` 是那 42 格
/// （只建一次），动画帧里只重建「裁剪窗口 + 上移量」这几个叶子 widget。
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.grid,
    required this.selectedDate,
    required this.onDayTap,
    required this.rowHeight,
    required this.progress,
    this.showWeekNumbers = true,
    this.keptRowIndex = 0,
  });

  final MonthGridData grid;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  /// 单行高度（已由调用方按可用空间算好，并钳在可读区间内）。
  final double rowHeight;

  /// 展开进度：1 = 全展开（默认，逐字维持旧行为）、0 = 只留一周、
  /// 中间值 = 拖拽中的连续裁剪。
  ///
  /// 传的是**动画**而不是当前值：本部件只在动画帧里重建裁剪窗口，42 格（见
  /// [AnimatedBuilder.child]）不会被牵连重建。原因见类注释「为什么收的是动画」。
  final Animation<double> progress;

  /// 收起态保留的行（0 基）。判据在 `monthGridRowToKeep`，由页面算好传入。
  final int keptRowIndex;

  /// 是否显示每行的学期周次行标（「第 N 周」）。学期未配置时内部自动隐藏。
  final bool showWeekNumbers;

  /// 行高可读下限：再矮日期数字与色带会挤在一起。
  static const double minRowHeight = 44;

  /// 行高舒适上限：屏幕很高时别把格子拉成大方块（一行 7 格，拉太高显空）。
  static const double maxRowHeight = 78;

  /// 周次行标列宽。
  ///
  /// ## 34 → 40 的由来（2026-10-21 专业评审）
  ///
  /// 上一版取 34，注释写的是「34 是 9px 字号下『第 12 周』一行排得下的最小宽度」。
  /// 真机截图实测**这句话是错的**：`第 17 周` 在 34dp 列里折成了两行
  /// （「第 17」/「周」），两行小字紧贴在日期格左侧，读起来像误入的鬼影。
  ///
  /// 按 11px 中文实测：`第 17 周`（两个汉字 + 空格 + 两位数字 + 空格）约 44dp。
  /// 40 配合「FittedBox 兜底缩放」能稳稳压进一行；再加宽就会挤压 7 列的格宽
  /// （每格少 1dp，方形格子跟着变窄）。
  static const double weekLabelWidth = 40;

  /// 一行几天。
  static const int daysPerRow = 7;

  /// 网格左右的内边距：由左轴推出来，不另写一个数（见 [MonthMetrics]）。
  ///
  /// 调用方算「格宽 = (可用宽 - 左右内边距 - 周次列) / 7」时要减掉它 ——
  /// 两处不同源的话，算出来的"正方形行高"会偏，格子又变回长方形。
  static const double horizontalPadding = MonthMetrics.gridHorizontalPadding;

  /// 星期表头行高度（标题 + 下内边距）。调用方算可用高度时要扣掉它。
  static const double headerHeight = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // 表头与周次轨：压在白卡上，跟主题走。
    //
    // 表头用 [MonthInk.tertiary]（对比度 3.79:1）—— 旧实现这里是 0.62，与
    // 副行、注脚、箭头挤在五个几乎一样的档位上，语义没分级（见 MonthInk 注释）。
    final mutedInk = colorScheme.onSurface.withValues(
      alpha: MonthInk.tertiary,
    );

    // 本批日期实际要画几行（4~6）。2026-10-25 之前恒 6 行，尾部常多出一整行
    // 纯邻月补位格（2026 年 10 月的第 6 行八个数字全是 11 月），白占一行高度。
    // 判据在 `MonthGridData.rowsInMonth`。
    final rowCount = grid.rowsInMonth;

    // 周次行标列：只在真的能算出周次时占位（学期未配置时整列收起，
    // 否则左边会挂一条毫无意义的空白）。
    final weekNumberColumnVisible =
        showWeekNumbers && grid.days.any((day) => day.weekIndex != null);

    final headers = <String>[
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    // 表头钉在 [headerHeight]：这个常量既被调用方的行高预算扣掉，也是收起态
    // 裁剪窗口的上沿。此前它只是"文档值"（实际渲染 ~20），收起窗口比内容高
    // 出的那 4px 会露出下一行的顶边 —— 现在让布局兑现文档。
    final headerRow = SizedBox(
      height: headerHeight,
      child: Row(
        children: [
          if (weekNumberColumnVisible) const SizedBox(width: weekLabelWidth),
          for (var i = 0; i < headers.length; i++)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    headers[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: MonthType.caption,
                      fontWeight: FontWeight.w600,
                      // 周末表头比工作日**重一档**（secondary vs tertiary），
                      // 而不是旧实现那种"同色再压一个 0.72"—— 旧写法在五个
                      // 几乎一样的档位里又加了一档，肉眼分不出，周末列因此
                      // 没有边界（用户扫读时找不到"一周从哪儿开始"）。
                      //
                      // ⚠️ 两者都取 [MonthInk] 里已有的档：新增一个 alpha 就是
                      // 把刚收敛好的档位重新打散。
                      color: i >= 5
                          ? colorScheme.onSurface.withValues(
                              alpha: MonthInk.secondary,
                            )
                          : mutedInk,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final rows = [
      for (var row = 0; row < rowCount; row++)
        _buildWeekRow(context, row, weekNumberColumnVisible, mutedInk),
    ];

    // 收起 / 拖拽中：**表头固定，只裁剪平移行区**。
    //
    // ⚠️ 这里曾经把表头一起平移（offset 作用在「表头 + 所有行」上），症状是
    // 收起到一行时**还露出半格上一行、表头也不见了**（用户 2026-10-21 实测）：
    // 窗口高度按「表头 + 1 行」算，可内容整体上移把表头推出了窗口 —— 露出来的
    // 自然是被推走那一块后面的上一行下半截。表头是固定表头，不参与滚动。
    //
    // 画出来的格子始终在树上（InkWell 状态与 widget key 不丢）；Transform.translate
    // 会连带命中测试一起移，保留行的格子照常可点。
    //
    // ⚠️ 上界用 `rowCount - 1` 而**不是**「42 格的最后一行」：收起态要保留的
    // 行若落在被裁掉的那一行（比如 5 行月的 keptRow 被算成 4 以上），窗口会
    // 对着一行根本没画出来的内容 —— 症状是收起来后一片空白。
    final keptRow = keptRowIndex.clamp(0, rowCount - 1);

    // ── 性能的关键：42 格作为 `child` 交给 AnimatedBuilder ──
    //
    // 动画每一帧只重建 builder 里那几个「叶子」widget（ClipRect / SizedBox /
    // OverflowBox / Transform），`child` 原样传递、一个都不重建。详见类注释
    // 「为什么收的是动画」。
    //
    // ⚠️ **树形必须恒定**（2026-10-21 实测踩到，别再改回去）：这里**不能**按
    // `t >= 1` 分叉成「展开态返回裸 child / 收起态返回 ClipRect」。那样 t 一
    // 越过 1 子树深度就变了，Flutter 按位置复用元素 ⇒ 整棵 42 格销毁重建。
    // 交替拖动（t 在 0.93 与 1.00 之间来回）实测 **504 格/帧**，比优化前更差。
    //
    // 所以裁剪层**恒在**。代价是展开态多一层 ClipRect + 一次 Transform。
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 表头不参与动画，留在 builder 外面（每帧不动它）。
        headerRow,
        AnimatedBuilder(
          animation: progress,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          builder: (context, child) {
            final t = progress.value;
            // 窗口行数按**这一页真实要画的行数**插值（4~6），不是恒 6 —— 否则
            // 5 行月的窗口会比内容高一整行，收起态露出的是空白。
            final visibleRows = monthGridVisibleRows(t, rowCount: rowCount);
            // 内容上移量：收起时把保留行顶到窗口顶端，展开时归零。
            final rowOffset = monthGridScrollOffset(
              keptRow: keptRow,
              rowHeight: rowHeight,
              rowOffsetProgress: 1 - t,
            );
            // 窗口裁剪：高度按可见行数插值，内容整体上移。
            return ClipRect(
              child: SizedBox(
                height: visibleRows * rowHeight,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Transform.translate(
                    offset: Offset(0, -rowOffset),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    int row,
    bool weekNumberColumnVisible,
    Color mutedInk,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final rowDays = grid.days.sublist(row * 7, row * 7 + 7);
    // 行标取**行内首个落在本月的日期**的周次；整行都在月外（首末行常见）
    // 时取行首那天的周次，仍能标出「这行属于第几周」。
    final anchor = rowDays.firstWhere(
      (day) => !day.isOutsideMonth,
      orElse: () => rowDays.first,
    );
    final weekLabel = anchor.weekIndex;
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          if (weekNumberColumnVisible)
            SizedBox(
              width: weekLabelWidth,
              child: Center(
                child: weekLabel == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(right: 4),
                        // 周次轨是**一行**文字：40dp 去掉右侧留白只剩 ~36dp，
                        // 「第 17 周」在 11px 中文下实测约 44dp —— 所以既缩字号
                        // （[MonthType.rail] = 10）又用 FittedBox 兜底：再宽的
                        // 周号（第 30 周）也只是轻微缩放，不会折成「第 17 / 周」。
                        //
                        // ⚠️ 旧实现既没有 maxLines 也没有缩放，真机实测直接折成
                        // 两行、紧贴在日期格左边，读起来像误入的鬼影。
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            // 纯数字挂左边会被读成"日期"（真机截图里像误入的鬼影）；
                            // 复用既有 l10n「第 N 周」把语义说清，不新增文案。
                            l10n.weekLabel(weekLabel),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: MonthType.rail,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              // 旧实现是 `mutedInk.withValues(alpha: 0.8)` —— 又
                              // 一个只差 0.02 的档位（见 [MonthInk] 的注释）。
                              // 周次轨就是 tertiary 这一档，不再另压。
                              color: mutedInk,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          for (final day in rowDays)
            Expanded(
              child: Padding(
                // 格间留白：格子之间要透气。
                padding: const EdgeInsets.all(MonthMetrics.cellGap),
                // 每格独立重绘层：翻月/选中只脏一两格，静态格不跟着重画。
                child: RepaintBoundary(
                  child: MonthDayCell(
                    entry: day,
                    isToday: day.date == grid.today,
                    isSelected:
                        selectedDate != null && day.date == selectedDate,
                    onTap: () => onDayTap(day.date),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
