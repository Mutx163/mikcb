import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import 'month_day_cell.dart';

/// 月历网格：星期表头 + 6 行 × 7 列日期格 + 每行学期周次行标。
///
/// 纯展示部件：数据由 [MonthGridData] 带进来，本部件不取数、不读 provider。
/// 固定 42 格（见 [MonthViewLogic.monthGridDates]）——行数不随月份在 4~6 之间
/// 变化，翻月时整页高度纹丝不动。
///
/// 行高由外部按可用高度注入（[rowHeight]）：月历是这个页面的主体，把自己
/// 压成半屏、底下留一大片空白是最丑的形态；能撑开就撑开，撑不开再缩到
/// [minRowHeight] 的可读下限。
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.grid,
    required this.selectedDate,
    required this.onDayTap,
    required this.rowHeight,
    this.showWeekNumbers = true,
  });

  final MonthGridData grid;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  /// 单行高度（已由调用方按可用空间算好，并钳在可读区间内）。
  final double rowHeight;

  /// 是否显示每行的学期周次行标（「第 N 周」）。学期未配置时内部自动隐藏。
  final bool showWeekNumbers;

  /// 行高可读下限：再矮日期数字与圆点会挤在一起。
  static const double minRowHeight = 44;

  /// 行高舒适上限：屏幕很高时别把格子拉成大方块（一行 7 格，拉太高显空）。
  static const double maxRowHeight = 78;

  /// 周次行标列宽（够放「第12周」这类窄排版）。
  static const double weekLabelWidth = 30;

  /// 星期表头行高度（标题 + 下内边距）。调用方算可用高度时要扣掉它。
  static const double headerHeight = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedInk = colorScheme.onSurface.withValues(alpha: 0.6);

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (weekNumberColumnVisible)
              const SizedBox(width: weekLabelWidth),
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
                        color: i >= 5 ? mutedInk.withValues(alpha: 0.6) : mutedInk,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < 6; row++)
          _buildWeekRow(context, row, weekNumberColumnVisible, mutedInk),
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
                        // 纯数字挂左边会被读成"日期"（截图里像误入的鬼影）；
                        // 复用既有 l10n「第 N 周」把语义说清，不新增文案。
                        l10n.weekLabel(weekLabel),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: mutedInk.withValues(alpha: 0.5),
                        ),
                      ),
              ),
            ),
          for (final day in rowDays)
            Expanded(
              // 每格独立重绘层：翻月/选中只脏一两格，静态格不跟着重画。
              child: RepaintBoundary(
                child: MonthDayCell(
                  entry: day,
                  isToday: day.date == grid.today,
                  isSelected: selectedDate != null && day.date == selectedDate,
                  onTap: () => onDayTap(day.date),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
