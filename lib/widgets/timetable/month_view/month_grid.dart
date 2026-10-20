import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import 'month_day_cell.dart';

/// 月历网格：星期表头 + 6 行 × 7 列日期格 + 每行学期周次行标。
///
/// 纯展示部件：数据由 [MonthGridData] 带进来，本部件不取数、不读 provider。
/// 固定 42 格（见 [MonthViewLogic.monthGridDates]），页高跨月稳定——
/// 4~6 行可变会重演「整页高度随内容跳」的既有教训。
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.grid,
    required this.selectedDate,
    required this.onDayTap,
    this.showWeekNumbers = true,
  });

  final MonthGridData grid;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  /// 是否显示每行的学期周次行标（「第 N 周」）。学期未配置时内部自动隐藏。
  final bool showWeekNumbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedInk = colorScheme.onSurface.withValues(alpha: 0.55);

    // 周次行标列：只在真的能算出周次时占位（否则留白会更难看）。
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
            if (weekNumberColumnVisible) const SizedBox(width: 24),
            for (final header in headers)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      header,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: mutedInk,
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
    final rowDays = grid.days.sublist(row * 7, row * 7 + 7);
    // 行标取**行内首个落在本月的日期**的周次；整行都在月外（首末行常见）
    // 时取行首那天的周次，仍能标出「这行属于第几周」。
    final anchor = rowDays.firstWhere(
      (day) => !day.isOutsideMonth,
      orElse: () => rowDays.first,
    );
    final weekLabel = anchor.weekIndex;
    return SizedBox(
      height: MonthGrid.rowHeight,
      child: Row(
        children: [
          if (weekNumberColumnVisible)
            SizedBox(
              width: 24,
              child: Center(
                child: weekLabel == null
                    ? const SizedBox.shrink()
                    : Text(
                        '$weekLabel',
                        style: TextStyle(
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: mutedInk.withValues(alpha: 0.7),
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
                  isSelected:
                      selectedDate != null && day.date == selectedDate,
                  onTap: () => onDayTap(day.date),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单行高度。6 行 × 56 = 336，加表头与议程列表后仍在常见屏高内；
  /// 数值固定（不按可用高度均分）是为了让「点某天 → 议程列表出现/消失」
  /// 时网格本身不跳。
  static const double rowHeight = 56;
}
