import 'package:flutter/material.dart';

import '../../../domain/month_view_logic.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/timetable_settings.dart';
import '../../../utils/hex_color.dart';
import '../day_view/day_view_agenda_surface.dart';
import 'month_day_cell.dart';
import 'month_metrics.dart';
import 'month_panel_surface.dart';

/// 月视图选中日的当日议程（课程 + 考试 + 日程混排）。
///
/// ## 2026-10-23 第二轮：标题进卡，卡一律实底
///
/// 用户对着真机截图说「整体看起来非常诡异」—— 拆出来两条原因，都在这一层：
///
/// 1. **日期标题浮在壁纸上**。旧实现把「10月24日」画在卡**外面**、直接压在
///    壁纸上；用户那张壁纸是高饱和彩色斜带，深色标题压上去对比度很低，
///    看起来像一段没对齐的散字。小米日历没有这种东西 —— 它的信息区每一块
///    都是**带标题的卡**。
/// 2. **卡片是玻璃的**。上一轮为了"跟课程卡材质走"去掉了 `forceSolid`，
///    结果卡片半透明、把满屏彩色壁纸透出来，读起来像"一块模糊的洞"，
///    而不是卡。用户截图里小米日历的卡是**实心白**。
///
/// 于是现在：**一块卡包住「标题 + 若干行」**，卡是实底白；每行仍各自可点。
///
/// ## 为什么信息卡与上半日历卡必须同一档实底
///
/// 两者现在共用 `monthInfoCardFill`（= `surface`）。上半那张日历卡是实底，
/// 下半若是玻璃，同一屏就有两种材质 —— 那正是用户 2026-10-20 说过的
/// 「月视图应该跟周视图、日视图保持一致风格」的反面。
class MonthDayAgenda extends StatelessWidget {
  const MonthDayAgenda({
    super.key,
    required this.date,
    required this.settings,
    required this.rows,
    required this.onRowTap,
    this.radius = MonthMetrics.cardRadius,
    this.onAddCourse,
  });

  final DateTime date;
  final TimetableSettings settings;
  final List<MonthAgendaRow> rows;
  final ValueChanged<MonthAgendaRow> onRowTap;
  final double radius;

  /// 空态卡里的「加课」入口。null = 不显示入口（只留说明文字）。
  ///
  /// 空态是用户最可能想「补点什么」的时刻：这一天什么都没排，说一句「这天没有
  /// 安排」然后就没了 —— 手里有活儿要记的人还得自己回首页找加课入口。
  final VoidCallback? onAddCourse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 卡内墨色：卡是实底白，所以按**卡面**判。
    final cardInk = monthInfoCardInk(
      context: context,
      settings: settings,
      cardFill: monthInfoCardFill(context),
    );
    final mutedInk = cardInk.withValues(alpha: MonthInk.secondary);

    return DayViewAgendaSurface(
      settings: settings,
      color: monthInfoCardFill(context),
      radius: radius,
      // ⚠️ **必须实底**。玻璃卡采的是屏级 backdrop（壁纸），父容器不透明也拦不住；
      // 在用户那种高饱和壁纸上，半透明卡读起来就是"一块模糊的洞"而不是卡
      //（2026-10-23 真机截图，用户报"非常诡异"）。
      forceSolid: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题在**卡内**：与小米日历那块「霜降 / 九月十四」同一种结构。
            Text(
              l10n.monthViewAgendaTitle(date.month, date.day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MonthType.title,
                fontWeight: FontWeight.w700,
                color: cardInk,
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              _EmptyDayBody(
                l10n: l10n,
                ink: cardInk,
                mutedInk: mutedInk,
                onAddCourse: onAddCourse,
              )
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: MonthMetrics.rowGap),
                _AgendaRow(
                  row: rows[i],
                  inkColor: cardInk,
                  onTap: () => onRowTap(rows[i]),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// 选中日什么都没有：一句说明 + 一个加课入口（都在卡内，不再另起一张卡）。
class _EmptyDayBody extends StatelessWidget {
  const _EmptyDayBody({
    required this.l10n,
    required this.ink,
    required this.mutedInk,
    required this.onAddCourse,
  });

  final AppLocalizations l10n;
  final Color ink;
  final Color mutedInk;
  final VoidCallback? onAddCourse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.monthViewAgendaEmpty,
          style: TextStyle(fontSize: MonthType.body, color: mutedInk),
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
    );
  }
}

/// 卡内的加课小按钮（描边胶囊，不抢卡内其它行）。
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
            border: Border.all(color: ink.withValues(alpha: MonthInk.hairline)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 15,
                color: ink.withValues(alpha: MonthInk.secondary),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: MonthType.body,
                  fontWeight: FontWeight.w600,
                  color: ink.withValues(alpha: MonthInk.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡内的一行议程：色条 + 时间 + 标题/副标题 + 箭头。
///
/// ⚠️ 它**不再是一张卡**（卡由外面那层提供）：所以这里只画水波纹与内容，
/// 自带一个 `InkWell` 保证每行仍可独立点击。
class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.row,
    required this.inkColor,
    required this.onTap,
  });

  final MonthAgendaRow row;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 行首竖条：考试固定红、其余用课程/日程自身色（与网格色带同一套语义色）。
    final accent = row.kind == MonthAgendaRowKind.exam
        ? monthExamAccent(colorScheme)
        : parseHexColorOrFallback(row.colorHex, fallback: colorScheme.primary);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: MonthType.caption,
                    fontWeight: FontWeight.w600,
                    color: inkColor.withValues(alpha: MonthInk.secondary),
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
                        fontSize: MonthType.title,
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
                            fontSize: MonthType.body,
                            color: inkColor.withValues(alpha: MonthInk.secondary),
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
                color: inkColor.withValues(alpha: MonthInk.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 考试在议程行里的强调色（与网格考试标记同色系）。
Color monthExamAccent(ColorScheme colorScheme) =>
    monthExamDotColor(colorScheme);
