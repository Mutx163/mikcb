import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/hex_color.dart';

/// 月视图选中日的当日议程（课程 + 考试 + 日程混排）。
///
/// 纯展示：行数据由 [MonthViewLogic.buildDayAgenda] 产出，本部件只画。
/// 点击行为由调用方按行类型分派（课程 → 课程详情、考试 → 编辑页、
/// 日程 → 日程编辑页），与日视图议程卡的既有去处一致。
class MonthDayAgenda extends StatelessWidget {
  const MonthDayAgenda({
    super.key,
    required this.date,
    required this.rows,
    required this.onRowTap,
  });

  final DateTime date;
  final List<MonthAgendaRow> rows;
  final ValueChanged<MonthAgendaRow> onRowTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            l10n.monthViewAgendaTitle(date.month, date.day),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Text(
              l10n.monthViewAgendaEmpty,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          )
        else
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AgendaRowTile(
                row: row,
                onTap: () => onRowTap(row),
              ),
            ),
      ],
    );
  }
}

class _AgendaRowTile extends StatelessWidget {
  const _AgendaRowTile({required this.row, required this.onTap});

  final MonthAgendaRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = row.kind == MonthAgendaRowKind.exam
        ? colorScheme.error
        : parseHexColorOrFallback(row.colorHex, fallback: colorScheme.primary);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 26,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text(
                  row.clockText ?? '--:--',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (row.subtitle != null && row.subtitle!.isNotEmpty)
                      Text(
                        row.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空状态（整月无任何事项时给一句引导，而不是一片空网格）。
class MonthEmptyHint extends StatelessWidget {
  const MonthEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosEmptyState(
      title: l10n.monthViewEmptyMonthTitle,
      icon: Icons.calendar_month_outlined,
    );
  }
}
