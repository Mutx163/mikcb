import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/class_reminder_service.dart';
import 'package:university_timetable/utils/app_toast.dart';

import '../ui/hyperos/hyperos.dart';
import 'miuix_time_picker_sheet.dart';

/// 单节课提醒弹层：为「这节课（课程 × 真实日期）」设置 / 取消一条
/// 本地通知提醒。入口在课程操作弹窗内，不再有独立设置页。
///
/// - 快捷：按默认提前量（settings.classAlarmLeadMinutes，默认 30 分钟）
///   在上课前提醒；
/// - 自定义：滚轮任选当天 HH:mm；
/// - 已设提醒时展示当前响点并支持一键取消。
Future<void> showClassReminderSheet(
  BuildContext context, {
  required Course course,
  required int week,
}) {
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (_) => _ClassReminderSheetBody(course: course, week: week),
  );
}

String _formatMinuteOfDay(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime? _occurrenceDateFor(TimetableSettings settings, int week, int dayOfWeek) {
  final semesterStart = settings.semesterStartDate;
  if (semesterStart == null) {
    return null;
  }
  final normalizedStart = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).subtract(Duration(days: semesterStart.weekday - 1));
  return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
}

class _ClassReminderSheetBody extends StatefulWidget {
  const _ClassReminderSheetBody({required this.course, required this.week});

  final Course course;
  final int week;

  @override
  State<_ClassReminderSheetBody> createState() =>
      _ClassReminderSheetBodyState();
}

class _ClassReminderSheetBodyState extends State<_ClassReminderSheetBody> {
  bool _working = false;

  void _toast(String message, {AppToastKind kind = AppToastKind.info}) {
    showAppToast(context, message: message, kind: kind);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) {
      return;
    }
    _working = true;
    try {
      await action();
    } finally {
      if (mounted) {
        _working = false;
      }
    }
  }

  Future<void> _save(int minuteOfDay) async {
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final date = _occurrenceDateFor(settings, widget.week, widget.course.dayOfWeek);
    if (date == null) {
      _toast(AppLocalizations.of(context)!.classAlarmNoSemesterToast,
          kind: AppToastKind.warning);
      return;
    }
    final ringAt = DateTime(date.year, date.month, date.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (!ringAt.isAfter(DateTime.now())) {
      _toast(AppLocalizations.of(context)!.classAlarmPastToast,
          kind: AppToastKind.warning);
      return;
    }
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    await provider.setClassReminder(
      ClassReminderEntry(
        courseId: widget.course.id,
        date: ClassReminderEntry.formatDate(date),
        minuteOfDay: minuteOfDay,
      ),
    );
    navigator.pop();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      _toast(l10n.classAlarmSetToast, kind: AppToastKind.success);
    });
  }

  Future<void> _remove() async {
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final date = _occurrenceDateFor(settings, widget.week, widget.course.dayOfWeek);
    if (date == null) {
      return;
    }
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    await provider.removeClassReminder(widget.course.id, ClassReminderEntry.formatDate(date));
    navigator.pop();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      _toast(l10n.classAlarmRemovedToast);
    });
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) => switch (dayOfWeek) {
        1 => l10n.weekdayMon,
        2 => l10n.weekdayTue,
        3 => l10n.weekdayWed,
        4 => l10n.weekdayThu,
        5 => l10n.weekdayFri,
        6 => l10n.weekdaySat,
        _ => l10n.weekdaySun,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    final lead = settings.classAlarmLeadMinutes < 0
        ? 0
        : (settings.classAlarmLeadMinutes > 120 ? 120 : settings.classAlarmLeadMinutes);

    final startText = provider.resolvedCourseStartTime(widget.course);
    final startMinutes = startText == null ? null : ClassReminderService.parseClockMinutes(startText);
    final date = _occurrenceDateFor(settings, widget.week, widget.course.dayOfWeek);
    final localeName = Localizations.localeOf(context).toString();

    final infoParts = <String>[
      if (date != null) DateFormat.MMMd(localeName).format(date),
      _weekdayLabel(l10n, widget.course.dayOfWeek),
      if (startMinutes != null) _formatMinuteOfDay(startMinutes),
    ];

    final existing = date == null
        ? null
        : provider.classReminderFor(widget.course.id, ClassReminderEntry.formatDate(date));

    return HyperosSheet(
      frosted: true,
      title: l10n.classAlarmActionLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            infoParts.join(' · '),
            style: typo.xs2.copyWith(color: colors.mutedForeground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (existing != null) ...[
            HyperosFrostedSurface(
              borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Icon(Icons.alarm_on_rounded, size: 18, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.classAlarmExistingLabel(
                          _formatMinuteOfDay(existing.minuteOfDay),
                        ),
                        style: typo.sm.copyWith(height: 1.25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          HyperosFrostedSheetButton(
            label: l10n.classAlarmQuickOption(lead),
            bordered: false,
            expand: true,
            onPressed: startMinutes == null
                ? null
                : () => _run(() => _save((startMinutes - lead).clamp(0, 1439))),
          ),
          const SizedBox(height: 8),
          HyperosFrostedSheetButton(
            label: l10n.classAlarmCustomOption,
            bordered: false,
            expand: true,
            onPressed: startMinutes == null
                ? null
                : () => _run(() async {
                      final picked = await showMiuixTimePickerSheet(
                        context,
                        initialTime: TimeOfDay(
                          hour: startMinutes ~/ 60,
                          minute: startMinutes % 60,
                        ),
                        title: l10n.selectTimeTitle,
                      );
                      if (picked == null || !mounted) {
                        return;
                      }
                      await _save(picked.hour * 60 + picked.minute);
                    }),
          ),
          if (existing != null) ...[
            const SizedBox(height: 8),
            HyperosButton(
              label: l10n.cancelAction,
              variant: HyperosButtonVariant.destructive,
              expand: true,
              onPressed: () => _run(_remove),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
