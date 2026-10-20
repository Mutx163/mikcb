import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/hex_color.dart';
import '../day_view/day_view_agenda_surface.dart';

/// 月视图选中日的当日议程（课程 + 考试 + 日程混排）。
///
/// 视觉与**日视图议程卡同一套**：每行就是一张 [DayViewAgendaSurface]，
/// 材质跟随用户的课程卡材质设置，圆角与日视图一致（20）。用户口径
/// （2026-10-20）：「月视图应该跟周视图、日视图保持一致风格」——所以这里
/// 不是自己画一套行样式，而是复用日视图那层。
class MonthDayAgenda extends StatelessWidget {
  const MonthDayAgenda({
    super.key,
    required this.date,
    required this.settings,
    required this.rows,
    required this.onRowTap,
    this.radius = 20,
    this.inkColor,
  });

  final DateTime date;
  final TimetableSettings settings;
  final List<MonthAgendaRow> rows;
  final ValueChanged<MonthAgendaRow> onRowTap;
  final double radius;

  /// 壁纸上的判定墨色；null 时跟主题走。
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final ink = inkColor ?? colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(
            l10n.monthViewAgendaTitle(date.month, date.day),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ink.withValues(alpha: 0.78),
            ),
          ),
        ),
        if (rows.isEmpty)
          // 空态也做成卡：与「有内容」时同一个容器语言，不再是一句浮在
          // 纯色页上的灰字。
          DayViewAgendaSurface(
            settings: settings,
            color: colorScheme.surface,
            radius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Text(
                l10n.monthViewAgendaEmpty,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ink.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AgendaRowTile(
                row: row,
                settings: settings,
                radius: radius,
                inkColor: ink,
                onTap: () => onRowTap(row),
              ),
            ),
      ],
    );
  }
}

class _AgendaRowTile extends StatelessWidget {
  const _AgendaRowTile({
    required this.row,
    required this.settings,
    required this.radius,
    required this.inkColor,
    required this.onTap,
  });

  final MonthAgendaRow row;
  final TimetableSettings settings;
  final double radius;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 行首竖条：考试固定红、其余用课程/日程自身色（与网格圆点同一套语义色）。
    final accent = row.kind == MonthAgendaRowKind.exam
        ? monthExamAccent(colorScheme)
        : parseHexColorOrFallback(
            row.colorHex,
            fallback: colorScheme.primary,
          );
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surface
        : colorScheme.surfaceContainerHighest;

    return DayViewAgendaSurface(
      settings: settings,
      color: cardColor,
      radius: radius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 44,
              child: Text(
                row.clockText ?? '--:--',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: inkColor.withValues(alpha: 0.6),
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
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: inkColor,
                    ),
                  ),
                  if (row.subtitle != null && row.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        row.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: inkColor.withValues(alpha: 0.58),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: inkColor.withValues(alpha: 0.32),
            ),
          ],
        ),
      ),
    );
  }
}

/// 考试在议程行里的强调色（与网格考试圆点同色系）。
Color monthExamAccent(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? const Color(0xFFFF6B6B)
      : const Color(0xFFE5484D);
}

/// 未选中日期时底部那句轻提示。
///
/// 不是单纯的空白占位：截图里「网格缩在上半屏、底下全白」是最丑的形态，
/// 一句提示既填住那块空白、又把「点任一天看详情」这条交互讲明白。
class MonthAgendaPlaceholder extends StatelessWidget {
  const MonthAgendaPlaceholder({super.key, this.inkColor});

  /// 壁纸上的判定墨色；null 时跟主题走。
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = inkColor ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 14,
            color: ink.withValues(alpha: 0.34),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.monthViewTapDayHint,
            style: TextStyle(fontSize: 12, color: ink.withValues(alpha: 0.46)),
          ),
        ],
      ),
    );
  }
}
