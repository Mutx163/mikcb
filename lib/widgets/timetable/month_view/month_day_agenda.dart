import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/hex_color.dart';
import '../day_view/day_view_agenda_surface.dart';

/// 月视图选中日的当日议程（课程 + 考试 + 日程混排）。
///
/// 视觉与**日视图议程卡同一套**：每行就是一张 [DayViewAgendaSurface]，
/// 圆角与日视图一致（20）。用户口径（2026-10-20）：「月视图应该跟周视图、
/// 日视图保持一致风格」——所以不是自己画一套行样式，而是复用日视图那层。
///
/// ## 材质例外：这里一律实体（2026-10-21）
///
/// 用户口径：「下面的信息区域，为什么每一个卡片，在白色的背景下，还能显示出
/// 壁纸来，这不合理」。
///
/// 根因：玻璃卡在 `CourseSurface` 里是 `BackdropFilter`，采的是**屏级
/// backdrop**（壁纸），而不是"父容器画的白色"—— 父容器不透明也拦不住它。
/// 于是卡片里能看见壁纸纹理，而它明明躺在一块白色面板上。
///
/// 所以本族的卡片**强制实体材质**（`forceSolid: true`）。这是"容器决定材质"
/// 的正当例外：玻璃的意义是透出背景，而这里的背景是面板，不是壁纸。
class MonthDayAgenda extends StatelessWidget {
  const MonthDayAgenda({
    super.key,
    required this.date,
    required this.settings,
    required this.rows,
    required this.onRowTap,
    this.radius = 20,
    this.inkColor,
    this.onAddCourse,
  });

  final DateTime date;
  final TimetableSettings settings;
  final List<MonthAgendaRow> rows;
  final ValueChanged<MonthAgendaRow> onRowTap;
  final double radius;

  /// 壁纸上的判定墨色；null 时跟主题走。
  final Color? inkColor;

  /// 空态卡里的「加课」入口。null = 不显示入口（只留说明文字）。
  ///
  /// 空态是用户最可能想「补点什么」的时刻：这一天什么都没排，说一句「这天没有
  /// 安排」然后就没了 —— 手里有活儿要记的人还得自己回首页找加课入口。
  final VoidCallback? onAddCourse;

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
            // 面板内一律实体：玻璃会透出屏级 backdrop（壁纸），
            // 而它躺在白色面板上（见类注释）。
            forceSolid: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.monthViewAgendaEmpty,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ink.withValues(alpha: 0.5),
                    ),
                  ),
                  if (onAddCourse != null) ...[
                    const SizedBox(height: 12),
                    _AddCourseAction(
                      label: l10n.monthViewAgendaAddCourse,
                      ink: ink,
                      onTap: onAddCourse!,
                    ),
                  ],
                ],
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

/// 空态卡里的「加课」小按钮（描边胶囊，不抢卡内文字）。
class _AddCourseAction extends StatelessWidget {
  const _AddCourseAction({
    required this.label,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ink.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: ink.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
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
        : parseHexColorOrFallback(row.colorHex, fallback: colorScheme.primary);
    final cardColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.surface
        : colorScheme.surfaceContainerHighest;

    return DayViewAgendaSurface(
      settings: settings,
      color: cardColor,
      radius: radius,
      // 面板内一律实体：玻璃会透出屏级 backdrop（壁纸），
      // 而它躺在白色面板上（见 MonthDayAgenda 类注释）。
      forceSolid: true,
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

/// 未选中日期时的底部内容在 [MonthPanelOverview]（本月概览 + 有安排的日子）。
///
/// 这里曾经是一个 `MonthAgendaPlaceholder`：一句「点任意一天查看安排」。
/// 用户在 2026-10-21 要求删掉那句话 —— 它既没回答问题（这个月到底有多少事），
/// 又把整块下半屏留成空白。现在换成有数据的概览，见 `month_panel_overview.dart`。
