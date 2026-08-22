part of '../timetable_settings_screen.dart';

Widget createMorningAlarmSettingsScreen() => const _MorningAlarmSettingsScreen();

/// 早八闹钟设置页：把第一节课的闹钟写进系统时钟。
///
/// 系统时钟的公开契约只支持「时:分 + 周重复」；无法指定具体某一天，
/// 也无法读取/删除已写入的闹钟。因此本页的职责是：
/// 1. 批量写入一个覆盖剩余教学日的周重复闹钟（假期会误响，弹窗明示）；
/// 2. 管响铃偏好（提前量 / 跳过确认页）；
/// 3. 引导跳转系统时钟完成删除与管理（固定标签「轻屿·早八」便于识别）。
class _MorningAlarmSettingsScreen extends StatefulWidget {
  const _MorningAlarmSettingsScreen();

  @override
  State<_MorningAlarmSettingsScreen> createState() =>
      _MorningAlarmSettingsScreenState();
}

class _MorningAlarmSettingsScreenState
    extends State<_MorningAlarmSettingsScreen> {
  static const String _alarmLabel = '轻屿·早八';

  TimetableSettings get _settings => context.read<TimetableProvider>().settings;

  void _toast(String message, {AppToastKind kind = AppToastKind.info}) {
    showAppToast(context, message: message, kind: kind);
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
    final labels = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    if (dayOfWeek < 1 || dayOfWeek > labels.length) {
      return dayOfWeek.toString();
    }
    return labels[dayOfWeek - 1];
  }

  /// 当前时刻之后仍有课的「星期 + 当天第一节开始时间」集合。
  List<MorningClassDayFirstSection> _collectRemainingFirstSections() {
    final provider = context.read<TimetableProvider>();
    final scheme = provider.activeTimeScheme;
    if (scheme == null || scheme.sections.isEmpty) {
      return const [];
    }
    final earliestStart = MorningClassAlarmLogic.firstSectionStartMinutes(
      scheme.sections,
    );
    if (earliestStart == null) {
      return const [];
    }
    final earliestClock = MorningClassAlarmLogic.formatClock(earliestStart);
    final now = DateTime.now();
    final result = <MorningClassDayFirstSection>[];
    for (var day = 1; day <= 7; day++) {
      final courses = provider.getActiveCoursesForDay(day);
      if (courses.isEmpty) {
        continue;
      }
      final hasUpcoming = courses.any((course) {
        final start = MorningClassAlarmLogic.parseClockMinutes(
          course.startTime,
        );
        if (start != null) {
          final nowMinutes = now.hour * 60 + now.minute;
          return start > nowMinutes;
        }
        // 时间无法解析时保守视为「还有课」，交给周重复闹钟覆盖。
        return true;
      });
      if (hasUpcoming) {
        result.add(
          MorningClassDayFirstSection(dayOfWeek: day, startTime: earliestClock),
        );
      }
    }
    return result;
  }

  Future<void> _addAllAlarms() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final scheme = provider.activeTimeScheme;
    if (scheme == null || scheme.sections.isEmpty) {
      _toast(l10n.morningClassAlarmNoSchemeToast, kind: AppToastKind.warning);
      return;
    }
    final days = _collectRemainingFirstSections();
    if (days.isEmpty) {
      _toast(l10n.morningClassAlarmNoCourseToast, kind: AppToastKind.warning);
      return;
    }
    final lead = MorningClassAlarmLogic.clampLeadMinutes(
      _settings.morningClassAlarmLeadMinutes,
    );
    final plan = MorningClassAlarmLogic.buildWeeklyPlan(
      days: days,
      label: _alarmLabel,
      leadMinutes: lead,
      skipUi: _settings.morningClassAlarmSkipUi,
    );
    if (plan == null) {
      _toast(l10n.morningClassAlarmNoCourseToast, kind: AppToastKind.warning);
      return;
    }
    final dayNames = days
        .map((day) => _weekdayLabel(l10n, day.dayOfWeek))
        .join('、');
    final ringTime = MorningClassAlarmLogic.formatClock(
      plan.hour * 60 + plan.minute,
    );
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.morningClassAlarmWeeklyConfirmTitle,
      message: l10n.morningClassAlarmWeeklyConfirmMessage(
        ringTime,
        dayNames,
      ),
    );
    if (confirmed != true) {
      return;
    }
    final result = await MorningClassAlarmService.addAlarm(plan);
    if (!mounted) {
      return;
    }
    if (result.launched) {
      _toast(l10n.morningClassAlarmAddedToast, kind: AppToastKind.success);
      return;
    }
    _toast(
      result.error ?? l10n.morningClassAlarmLaunchFailedToast,
      kind: AppToastKind.error,
    );
  }

  Future<void> _openSystemClock() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await MorningClassAlarmService.openSystemAlarms();
    if (!mounted) {
      return;
    }
    if (!ok) {
      _toast(l10n.morningClassAlarmLaunchFailedToast, kind: AppToastKind.error);
    }
  }

  Future<void> _pickLeadMinutes() async {
    final l10n = AppLocalizations.of(context)!;
    final options = <int>[10, 15, 20, 30, 45, 60];
    final current = MorningClassAlarmLogic.clampLeadMinutes(
      _settings.morningClassAlarmLeadMinutes,
    );
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: l10n.morningClassAlarmLeadTitle,
      items: {
        for (final minutes in options)
          l10n.morningClassAlarmLeadMinutesLabel(minutes): minutes,
      },
      currentValue: options.contains(current) ? current : 30,
      cancelLabel: l10n.cancelAction,
    );
    if (selected == null || selected == current || !mounted) {
      return;
    }
    await context.read<TimetableProvider>().updateSettings(
          _settings.copyWith(morningClassAlarmLeadMinutes: selected),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.morningClassAlarmEntryTitle),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: _buildContent,
      ),
    );
  }

  Widget _buildContent(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final settings = _settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.morningClassAlarmGroupSetup),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.alarm_add_outlined,
              iconAccent: HyperosIconColors.orange,
              title: l10n.morningClassAlarmAddAllTitle,
              details: l10n.morningClassAlarmAddAllSubtitle,
              onTap: _addAllAlarms,
            ),
            HyperosListTile(
              icon: Icons.schedule_outlined,
              iconAccent: HyperosIconColors.blue,
              title: l10n.morningClassAlarmOpenClock,
              onTap: _openSystemClock,
            ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.morningClassAlarmGroupBehavior),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.timer_outlined,
              iconAccent: HyperosIconColors.teal,
              title: l10n.morningClassAlarmLeadTitle,
              details: l10n.morningClassAlarmLeadMinutesLabel(
                MorningClassAlarmLogic.clampLeadMinutes(
                  settings.morningClassAlarmLeadMinutes,
                ),
              ),
              onTap: _pickLeadMinutes,
            ),
            HyperosSwitchTile(
              icon: Icons.bolt_outlined,
              iconAccent: HyperosIconColors.purple,
              title: l10n.morningClassAlarmSkipUiTitle,
              subtitle: l10n.morningClassAlarmSkipUiSubtitle,
              value: settings.morningClassAlarmSkipUi,
              onChanged: (value) {
                context.read<TimetableProvider>().updateSettings(
                      settings.copyWith(morningClassAlarmSkipUi: value),
                    );
              },
            ),
          ],
        ),
        const HyperosSectionGap(),
      ],
    );
  }
}
