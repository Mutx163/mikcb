import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';
import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import 'month_day_cell.dart';
import 'month_metrics.dart';

/// 月历网格：星期表头 + 6 行 × 7 列日期格 + 每行学期周次行标。
///
/// 纯展示部件：数据由 [MonthGridData] 带进来，本部件不取数、不读 provider。
/// 固定 42 格（见 [MonthViewLogic.monthGridDates]）——行数不随月份在 4~6 之间
/// 变化，翻月时整页高度纹丝不动。
///
/// 视觉与周视图/日视图同一套：格子是 [MonthDayCell]（玻璃/实底课程卡材质），
/// 表头与行标用壁纸上的判定墨色（[inkColor]），不用设置页那套固定灰。
///
/// ## 判墨按行（2026-10-21 专业评审 P0-1）
///
/// 一屏壁纸自上而下的亮度可以差 2.5 倍（实测 0.56 → 0.23），所以每个格子必须
/// 用**它自己那一行**的亮度判墨，不能整屏一个数。剖面由页面算好、按行传进来
/// （[rowLuminances]）；拿不到时（还没采到 / 没有壁纸）退回 [inkColor]——
/// 那是整屏带口径，与改动前逐字相同。
///
/// 表头与周次轨**不按行**：它们贴在网格上沿、只有一行字高，整带口径本来就成立。
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
/// 42 格与表头**不参与**逐帧重建 —— 点选态由 `setState` 触发的正常重建负责，
/// 不依赖这个动画。
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.grid,
    required this.settings,
    required this.selectedDate,
    required this.onDayTap,
    required this.rowHeight,
    required this.inkColor,
    this.showWeekNumbers = true,
    required this.progress,
    this.keptRowIndex = 0,
    this.rowLuminances = const <double?>[],
  });

  final MonthGridData grid;
  final TimetableSettings settings;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  /// 单行高度（已由调用方按可用空间算好，并钳在可读区间内）。
  final double rowHeight;

  /// 壁纸上的判定墨色（表头/行标用；格子只在没有逐行数据时回落用它）。
  final Color inkColor;

  /// 每一行背后那段壁纸的亮度（长度 6，元素可为 null）。空 = 没有逐行数据。
  ///
  /// 由页面用 `monthRowLuminances` 算好传入 —— 42 个格子必须按行判墨，
  /// 整屏一个数会错掉一头（见类注释 P0-1）。
  final List<double?> rowLuminances;

  /// 是否显示每行的学期周次行标（「第 N 周」）。学期未配置时内部自动隐藏。
  final bool showWeekNumbers;

  /// 展开进度：1 = 全展开（默认，逐字维持旧行为）、0 = 只留一周、
  /// 中间值 = 拖拽中的连续裁剪。
  ///
  /// 传的是**动画**而不是当前值：本部件只在动画帧里重建裁剪窗口，42 格（见
  /// [AnimatedBuilder.child]）不会被牵连重建。原因见类注释「为什么收的是动画」。
  final Animation<double> progress;

  /// 收起态保留的行（0 基）。判据在 `monthGridRowToKeep`，由页面算好传入。
  final int keptRowIndex;

  /// 行高可读下限：再矮日期数字与圆点会挤在一起。
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
    final mutedInk = inkColor.withValues(alpha: 0.72);

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
                      color: i >= 5
                          ? mutedInk.withValues(alpha: 0.72)
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
      for (var row = 0; row < 6; row++)
        _buildWeekRow(context, row, weekNumberColumnVisible, mutedInk),
    ];

    // 收起 / 拖拽中：**表头固定，只裁剪平移行区**。
    //
    // ⚠️ 这里曾经把表头一起平移（offset 作用在「表头 + 所有行」上），症状是
    // 收起到一行时**还露出半格上一行、表头也不见了**（用户 2026-10-21 实测）：
    // 窗口高度按「表头 + 1 行」算，可内容整体上移把表头推出了窗口 —— 露出来的
    // 自然是被推走那一块后面的上一行下半截。表头是固定表头，不参与滚动。
    //
    // 现在按用户口径（2026-10-21 截图）实现「上下同时收」：窗口变矮、内容上移，
    // 保留行上方的行**走出窗口上沿**，保留行下方的行**被下方面板盖住**。
    // 两者叠加，保留行最后停在窗口最上沿、紧贴面板拉杆。
    //
    // 42 格始终在树上（InkWell 状态与 widget key 不丢）；Transform.translate
    // 会连带命中测试一起移，保留行的格子照常可点。
    final keptRow = keptRowIndex.clamp(
      0,
      (grid.days.length - 1) ~/ kMonthGridDaysPerRow,
    );

    // ── 性能的关键：42 格作为 `child` 交给 AnimatedBuilder ──
    //
    // 动画每一帧只重建 builder 里那几个「叶子」widget（ClipRect / SizedBox /
    // OverflowBox / Transform），`child` 原样传递、一个都不重建。详见类注释
    // 「为什么收的是动画」。
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
            // 全展开：逐字维持旧路径（无裁剪层，一行不多画）。
            //
            // 这一条必须留：展开态是用户停留最久的状态，多一层 ClipRect 就多一次
            // 裁剪、多一层 Transform 就多一个合成层 —— 玻璃卡在里面还得为这些层
            // 多付一份代价，而展开态根本不需要裁剪。
            if (t >= 1) {
              return child!;
            }
            final visibleRows = monthGridVisibleRows(t);
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
    final rowLuminance = row < rowLuminances.length ? rowLuminances[row] : null;
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
                              color: mutedInk.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          for (final day in rowDays)
            Expanded(
              child: Padding(
                // 格间留白：卡片之间要透气（周网格课程卡同样是「留缝」而非贴边）。
                padding: const EdgeInsets.all(MonthMetrics.cellGap),
                // 每格独立重绘层：翻月/选中只脏一两格，静态格不跟着重画。
                child: RepaintBoundary(
                  child: MonthDayCell(
                    entry: day,
                    settings: settings,
                    isToday: day.date == grid.today,
                    isSelected:
                        selectedDate != null && day.date == selectedDate,
                    rowLuminance: rowLuminance,
                    inkOverride: inkColor,
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
