import 'package:flutter/material.dart';

import '../../../domain/month_grid_collapse.dart';
import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import 'month_day_cell.dart';

/// 月历网格：星期表头 + 6 行 × 7 列日期格 + 每行学期周次行标。
///
/// 纯展示部件：数据由 [MonthGridData] 带进来，本部件不取数、不读 provider。
/// 固定 42 格（见 [MonthViewLogic.monthGridDates]）——行数不随月份在 4~6 之间
/// 变化，翻月时整页高度纹丝不动。
///
/// 视觉与周视图/日视图同一套：格子是 [MonthDayCell]（玻璃/实底课程卡材质），
/// 表头与行标用壁纸上的判定墨色（[inkColor]），不用设置页那套固定灰。
///
/// ## 收起 / 展开（2026-10-20）
///
/// [collapseProgress] 是连续的展开进度（1 = 全展开、0 = 只留一周），由页面把
/// 拖拽接到动画控制器上再传进来。收起不是「隐藏 5 行」而是**裁剪 + 平移**：
/// 42 格始终在树上（widget key 与 InkWell 状态不丢），把窗口对准「保留行」
/// （[keptRowIndex]，判据见 `monthGridRowToKeep`）。判据本身在
/// `month_grid_collapse.dart`（纯 Dart 可单测），本部件只管画。
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
    this.collapseProgress = 1.0,
    this.keptRowIndex = 0,
  });

  final MonthGridData grid;
  final TimetableSettings settings;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  /// 单行高度（已由调用方按可用空间算好，并钳在可读区间内）。
  final double rowHeight;

  /// 壁纸上的判定墨色（表头/行标/日期文字都用它，见 [monthCellInkColor]）。
  final Color inkColor;

  /// 是否显示每行的学期周次行标（「第 N 周」）。学期未配置时内部自动隐藏。
  final bool showWeekNumbers;

  /// 展开进度：1 = 全展开（默认，逐字维持旧行为）、0 = 只留一周、
  /// 中间值 = 拖拽中的连续裁剪。
  final double collapseProgress;

  /// 收起态保留的行（0 基）。判据在 `monthGridRowToKeep`，由页面算好传入。
  final int keptRowIndex;

  /// 行高可读下限：再矮日期数字与圆点会挤在一起。
  static const double minRowHeight = 44;

  /// 行高舒适上限：屏幕很高时别把格子拉成大方块（一行 7 格，拉太高显空）。
  static const double maxRowHeight = 78;

  /// 周次行标列宽（够放「第12周」这类窄排版）。
  static const double weekLabelWidth = 30;

  /// 一行几天。
  static const int daysPerRow = 7;

  /// 网格左右的内边距（与页面给 `SingleChildScrollView` 的水平 padding 同值）。
  ///
  /// 调用方算「格宽 = (可用宽 - 左右内边距 - 周次列) / 7」时要减掉它 ——
  /// 两处不同源的话，算出来的"正方形行高"会偏，格子又变回长方形。
  static const double horizontalPadding = 10;

  /// 星期表头行高度（标题 + 下内边距）。调用方算可用高度时要扣掉它。
  static const double headerHeight = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mutedInk = inkColor.withValues(alpha: 0.66);

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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: i >= 5
                          ? mutedInk.withValues(alpha: 0.7)
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

    // 全展开：逐字维持旧路径（无裁剪层，一行不多画）。
    if (collapseProgress >= 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [headerRow, ...rows],
      );
    }

    // 收起 / 拖拽中：**表头固定，只裁剪平移行区**。
    //
    // ⚠️ 这里曾经把表头一起平移（offset 作用在「表头 + 所有行」上），症状是
    // 收起到一行时**还露出半格上一行、表头也不见了**（用户 2026-10-21 实测）：
    // 窗口高度按「表头 + 1 行」算，可内容整体上移把表头推出了窗口 —— 露出来的
    // 自然是被推走那一块后面的上一行下半截。表头是固定表头，不参与滚动。
    //
    // 行区的窗口高度按行数插值、内容按 keptRow × 行高 × (1 - 进度) 上移，
    // 于是收起时恰好只剩保留行完整一格，展开时窗口长到 6 行、位移归零。
    // 42 格始终在树上（InkWell 状态与 widget key 不丢）；Transform.translate
    // 会连带命中测试一起移，保留行的格子照常可点。
    final visibleRows = monthGridVisibleRows(collapseProgress);
    final keptRow = keptRowIndex.clamp(
      0,
      (grid.days.length - 1) ~/ kMonthGridDaysPerRow,
    );
    final rowOffset = keptRow * rowHeight * (1 - collapseProgress);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        headerRow,
        ClipRect(
          child: SizedBox(
            height: visibleRows * rowHeight,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(0, -rowOffset),
                child: Column(mainAxisSize: MainAxisSize.min, children: rows),
              ),
            ),
          ),
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
                    : Text(
                        // 纯数字挂左边会被读成"日期"（真机截图里像误入的鬼影）；
                        // 复用既有 l10n「第 N 周」把语义说清，不新增文案。
                        l10n.weekLabel(weekLabel),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: mutedInk.withValues(alpha: 0.75),
                        ),
                      ),
              ),
            ),
          for (final day in rowDays)
            Expanded(
              child: Padding(
                // 格间留白：卡片之间要透气（周网格课程卡同样是「留缝」而非贴边）。
                padding: const EdgeInsets.all(1.5),
                // 每格独立重绘层：翻月/选中只脏一两格，静态格不跟着重画。
                child: RepaintBoundary(
                  child: MonthDayCell(
                    entry: day,
                    settings: settings,
                    isToday: day.date == grid.today,
                    isSelected:
                        selectedDate != null && day.date == selectedDate,
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
