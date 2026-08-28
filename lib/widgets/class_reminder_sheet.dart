import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/system_alarm_service.dart';
import 'package:university_timetable/utils/app_toast.dart';

import '../ui/hyperos/hyperos.dart';
import 'app_dialogs.dart';
import 'miuix_time_picker_sheet.dart';

/// 这节课闹钟：把闹钟写进系统时钟（AlarmClock.ACTION_SET_ALARM）。
///
/// 点按后弹系统时钟保存页，用户在系统时钟里点保存即完成。
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
  if (semesterStart == null) return null;
  final normalizedStart = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).subtract(Duration(days: semesterStart.weekday - 1));
  return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
}

String _weeksSummary(Course course) {
  final weeks = course.activeWeeks;
  if (weeks.isEmpty) return '—';
  if (weeks.length <= 8) return weeks.join(', ');
  return '${weeks.take(8).join(', ')}…';
}

class _ClassReminderSheetBody extends StatefulWidget {
  const _ClassReminderSheetBody({required this.course, required this.week});

  final Course course;
  final int week;

  @override
  State<_ClassReminderSheetBody> createState() => _ClassReminderSheetBodyState();
}

class _ClassReminderSheetBodyState extends State<_ClassReminderSheetBody> {
  bool _working = false;

  void _toast(String message, {AppToastKind kind = AppToastKind.info}) {
    showAppToast(context, message: message, kind: kind);
  }

  Future<void> _addSystemAlarm(int minuteOfDay) async {
    if (_working) return;
    _working = true;
    try {
      final provider = context.read<TimetableProvider>();
      final course = widget.course;
      final startText = provider.resolvedCourseStartTime(course);
      if (!mounted) return;
      if (startText == null) {
        _toast(AppLocalizations.of(context)!.classAlarmInvalidTimeToast,
            kind: AppToastKind.warning);
        return;
      }
      final settings = provider.settings;
      final lead = SystemAlarmLogic.clampLeadMinutes(settings.classAlarmLeadMinutes);
      final label = course.shortName?.trim().isNotEmpty == true
          ? course.shortName!.trim()
          : course.name.trim();
      final plan = SystemAlarmLogic.buildCourseWeeklyPlan(
        dayOfWeek: course.dayOfWeek,
        startTime: startText,
        label: '轻屿 · $label',
        leadMinutes: lead,
        skipUi: settings.classAlarmSkipUi,
      );
      SystemAlarmPlan finalPlan;
      if (minuteOfDay >= 0) {
        finalPlan = SystemAlarmPlan(
          hour: minuteOfDay ~/ 60,
          minute: minuteOfDay % 60,
          label: '轻屿 · $label',
          repeatDays: plan?.repeatDays ?? [SystemAlarmLogic.calendarWeekday(course.dayOfWeek)],
          skipUi: settings.classAlarmSkipUi,
        );
      } else {
        if (plan == null) {
          _toast(AppLocalizations.of(context)!.classAlarmInvalidTimeToast,
              kind: AppToastKind.warning);
          return;
        }
        finalPlan = plan;
      }
      // 响点可能因提前量越过午夜而前移一天（buildCourseWeeklyPlan 的 ringDay
      // 逻辑），确认文案的星期必须跟随真实响点，而非上课日。
      final ringDayIso = finalPlan.repeatDays.isEmpty
          ? course.dayOfWeek
          : SystemAlarmLogic.isoWeekdayFromCalendar(finalPlan.repeatDays.first);
      final weekdayLabel = _weekdayLabel(
        AppLocalizations.of(context)!,
        ringDayIso == 0 ? course.dayOfWeek : ringDayIso,
      );
      final timeText = _formatMinuteOfDay(finalPlan.hour * 60 + finalPlan.minute);
      final weeksText = _weeksSummary(course);
      final startMinutes = SystemAlarmLogic.parseClockMinutes(startText);
      final computedLead = startMinutes == null ? lead : (startMinutes - minuteOfDay).clamp(0, 120);
      final effectiveLead = minuteOfDay < 0 ? lead : computedLead;

      // 先收起当前 sheet，再在宿主上下文弹确认，避免 sheet 盖 dialog 的双层叠加。
      final navigator = Navigator.of(context);
      final hostContext = navigator.context;
      final l10n = AppLocalizations.of(hostContext)!;
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!hostContext.mounted) return;
      final messageStyle = HyperosTypography.listDetail(hostContext).copyWith(
        color: HyperosColors.primaryText(hostContext),
      );
      final confirmed = await showAppConfirmDialogWithBody(
        hostContext,
        title: l10n.classAlarmCourseConfirmTitle,
        body: Text(
          l10n.classAlarmCourseConfirmMessage(weekdayLabel, timeText, effectiveLead, weeksText),
          textAlign: TextAlign.center,
          style: messageStyle,
        ),
        confirmLabel: l10n.confirmAction,
      );
      if (confirmed != true || !hostContext.mounted) return;
      final result = await SystemAlarmService.addAlarm(finalPlan);
      if (!hostContext.mounted) return;
      if (result.launched) {
        showAppToast(hostContext, message: AppLocalizations.of(hostContext)!.classAlarmAddedToast,
            kind: AppToastKind.success);
      } else {
        // PlatformException.message 是英文调试文案，不直接展示给用户。
        showAppToast(hostContext,
            message: AppLocalizations.of(hostContext)!.classAlarmLaunchFailedToast,
            kind: AppToastKind.error);
      }
    } finally {
      if (mounted) _working = false;
    }
  }

  /// 旧版「课程×真实日期」一次性本地通知提醒仍由原生管线调度（迁移保留），
  /// 这里提供应用内取消入口；新写入的系统时钟闹钟不受影响。
  Future<void> _removeLegacyReminder() async {
    if (_working) return;
    _working = true;
    try {
      final provider = context.read<TimetableProvider>();
      final date = _occurrenceDateFor(
        provider.settings,
        widget.week,
        widget.course.dayOfWeek,
      );
      if (date == null) return;
      await provider.removeClassReminder(
        widget.course.id,
        ClassReminderEntry.formatDate(date),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final hostContext = navigator.context;
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!hostContext.mounted) return;
      showAppToast(
        hostContext,
        message: AppLocalizations.of(hostContext)!.classAlarmRemovedToast,
      );
    } finally {
      if (mounted) _working = false;
    }
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
    final lead = SystemAlarmLogic.clampLeadMinutes(settings.classAlarmLeadMinutes);
    final startText = provider.resolvedCourseStartTime(widget.course);
    final startMinutes = startText == null ? null : SystemAlarmLogic.parseClockMinutes(startText);
    final date = _occurrenceDateFor(settings, widget.week, widget.course.dayOfWeek);
    final existing = date == null
        ? null
        : provider.classReminderFor(
            widget.course.id,
            ClassReminderEntry.formatDate(date),
          );
    final localeName = Localizations.localeOf(context).toString();
    final infoParts = <String>[
      if (date != null) DateFormat.MMMd(localeName).format(date),
      _weekdayLabel(l10n, widget.course.dayOfWeek),
      if (startMinutes != null) _formatMinuteOfDay(startMinutes),
    ];
    return HyperosSheet(
      frosted: true,
      title: l10n.classAlarmActionLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            infoParts.join(' · '),
            style: typo.xs2.copyWith(color: colors.foreground),
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
                : () => _addSystemAlarm(startMinutes - lead),
          ),
          const SizedBox(height: 8),
          HyperosFrostedSheetButton(
            label: l10n.classAlarmCustomOption,
            bordered: false,
            expand: true,
            onPressed: startMinutes == null
                ? null
                : () async {
                    final picked = await showMiuixTimePickerSheet(
                      context,
                      initialTime: TimeOfDay(
                        hour: startMinutes ~/ 60,
                        minute: startMinutes % 60,
                      ),
                      title: l10n.selectTimeTitle,
                    );
                    if (picked == null || !mounted) return;
                    await _addSystemAlarm(picked.hour * 60 + picked.minute);
                  },
          ),
          const SizedBox(height: 8),
          HyperosFrostedSheetButton(
            label: l10n.classAlarmOpenClock,
            bordered: false,
            expand: true,
            onPressed: () async {
              if (_working) return;
              _working = true;
              final navigator = Navigator.of(context);
              try {
                final ok = await SystemAlarmService.openSystemAlarms();
                if (!mounted) return;
                if (!ok) {
                  _toast(l10n.classAlarmLaunchFailedToast, kind: AppToastKind.error);
                } else {
                  navigator.pop();
                }
              } finally {
                if (mounted) _working = false;
              }
            },
          ),
          if (existing != null) ...[
            const SizedBox(height: 8),
            HyperosFrostedSheetButton(
              label: l10n.cancelAction,
              bordered: false,
              expand: true,
              variant: HyperosFrostedSheetButtonVariant.destructive,
              onPressed: _removeLegacyReminder,
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
