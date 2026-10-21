import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/hyperos/hyperos.dart';

import 'day_view_ink_style.dart';

/// 日视图议程卡上的小徽标（2026-10-20 自 `timetable_day_view_part.dart` 搬出）。
///
/// 原 `_TimetableScreenState._buildDayAgendaStatusBadge`：字号 10.5 / 行高 1 /
/// 胶囊圆角 999，颜色全部由调用方算好（墨色、底色的判据在卡片里）。
class DayAgendaStatusBadge extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color backgroundColor;

  const DayAgendaStatusBadge({
    super.key,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w400,
          fontSize: 10.5,
          height: 1,
        ),
      ),
    );
  }
}

/// 「这一周有作业」的小圆点（原 `_buildDayAgendaHomeworkDot`）。
class DayAgendaHomeworkDot extends StatelessWidget {
  const DayAgendaHomeworkDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.assignment_outlined,
        size: 11,
        color: HyperosColors.destructive,
      ),
    );
  }
}

/// 课程卡右上角的「课程备注」胶囊按钮（原 `_buildDayAgendaNoteAction`）。
///
/// [ink] 是卡片调色板算好的前景色；文案从当前 locale 取（原实现由调用方
/// 传入 `l10n`，组件化后按同一次 build 的 context 取，语种不会变）。
class DayAgendaNoteAction extends StatelessWidget {
  final Color ink;
  final VoidCallback onPressed;

  const DayAgendaNoteAction({
    super.key,
    required this.ink,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: dayAgendaInkWash(ink, lightAlpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: dayAgendaInkWash(ink, lightAlpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 14, color: ink),
                const SizedBox(width: 5),
                Text(
                  l10n.courseNoteAction,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「记作业」按钮：与 [DayAgendaNoteAction] 并排的独立入口（2026-10-21）。
///
/// 为什么从备注弹层里拆出来：那个弹层原来是「整门课简介 + 本节有作业开关 +
/// 本周备注」三样东西挤在一起，作业标记夹在两个文本框中间。用户的话是
/// 「单独做两个按钮，这里就不做了，单独就给成新建作业」。
///
/// 拆开之后两件事各自成立：备注就是记文字，作业就是新出一条作业。而且作业
/// 走的是 `AddTaskScreen`，那里有课程绑定、截止日期、完成态，比弹层里一个
/// 光秃秃的开关能表达的东西多得多。
class DayAgendaTaskAction extends StatelessWidget {
  final Color ink;
  final VoidCallback onPressed;

  /// 本周已有作业时改成「作业」+ 实心图标，让用户知道点进去不是空的。
  final bool hasTask;

  const DayAgendaTaskAction({
    super.key,
    required this.ink,
    required this.onPressed,
    this.hasTask = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: dayAgendaInkWash(ink, lightAlpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: dayAgendaInkWash(ink, lightAlpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasTask
                      ? Icons.assignment_turned_in_outlined
                      : Icons.assignment_outlined,
                  size: 14,
                  color: ink,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.courseTaskAction,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
