part of '../timetable_settings_screen.dart';

Widget createClassAlarmSettingsScreen() => const _ClassAlarmSettingsScreen();

/// 上课闹钟设置页：把课表的上课闹钟写进系统时钟。
///
/// 系统时钟的公开契约只支持「时:分 + 周重复」，无法指定具体日期，也无法
/// 读取或删除已写入的闹钟。因此本页策略是：
/// 1. 在所选范围内逐日展开真实课表（按 getWeekIndex 推算每周真实周次），
///    取每天最早一节课的开始时间；
/// 2. 把开始时间一致的星期合并为一个周重复闹钟，尽可能少地覆盖全部天；
/// 3. 时间在不同周波动的星期无法被单一周重复闹钟诚实表达，弹窗明示未覆盖；
/// 4. 假期照响、删除需去系统时钟，都在确认弹窗中说明。
class _ClassAlarmSettingsScreen extends StatefulWidget {
  const _ClassAlarmSettingsScreen();

  @override
  State<_ClassAlarmSettingsScreen> createState() =>
      _ClassAlarmSettingsScreenState();
}

class _ClassAlarmSettingsScreenState extends State<_ClassAlarmSettingsScreen> {
  // 范围档位值与 TimetableSettings.classAlarmRange 的持久化语义一致。
  static const int _rangeNext4Weeks = 0;
  static const int _rangeNext8Weeks = 1;
  static const int _rangeUntilSemesterEnd = 2;

  void _toast(String message, {AppToastKind kind = AppToastKind.info}) {
    showAppToast(context, message: message, kind: kind);
  }

  /// 写入设置并落盘；失败时提示而不是静默丢失改动。
  Future<void> _updateSettingsSafely(
    AppLocalizations l10n,
    TimetableSettings Function(TimetableSettings) mutate,
  ) async {
    final provider = context.read<TimetableProvider>();
    try {
      await provider.updateSettings(mutate(provider.settings));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _toast(l10n.saveFailed, kind: AppToastKind.error);
    }
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) => switch (dayOfWeek) {
        1 => l10n.weekdayMon,
        2 => l10n.weekdayTue,
        3 => l10n.weekdayWed,
        4 => l10n.weekdayThu,
        5 => l10n.weekdayFri,
        6 => l10n.weekdaySat,
        7 => l10n.weekdaySun,
        _ => dayOfWeek.toString(),
      };

  DateTime _normalized(DateTime date) => DateTime(date.year, date.month, date.day);

  /// 学期末日期：学期第一周的周一 + (semesterWeekCount * 7 - 1) 天。
  DateTime _semesterEndDate(TimetableSettings settings) {
    final start = settings.semesterStartDate!;
    final monday = _normalized(start).subtract(Duration(days: start.weekday - 1));
    return monday.add(Duration(days: settings.semesterWeekCount * 7 - 1));
  }

  /// 某个日期所在教学周的真实周次；学期外返回 null（该日不展开）。
  int? _calendarWeekFor(DateTime date, TimetableSettings settings) {
    final provider = context.read<TimetableProvider>();
    if (settings.semesterStartDate == null) {
      return null;
    }
    return provider.getWeekIndex(date, settings.semesterStartDate!);
  }

  /// 在所选范围内逐日展开真实课表，返回「星期几 + 第一节课时间」行。
  List<ClassAlarmDayFirstSection> _collectOccurrences(int range) {
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final scheme = provider.activeTimeScheme;
    if (scheme == null || scheme.sections.isEmpty) {
      return const [];
    }
    final today = _normalized(DateTime.now());

    // 计算范围的结束日期（含当天）；起点一律从今天起——过去的日子无法设闹钟。
    var endDate = today.add(const Duration(days: 27));
    switch (range) {
      case _rangeNext8Weeks:
        endDate = today.add(const Duration(days: 55));
      case _rangeUntilSemesterEnd:
        if (settings.semesterStartDate == null) {
          endDate = today.add(const Duration(days: 27));
        } else {
          endDate = _semesterEndDate(settings);
          if (endDate.isBefore(today)) {
            endDate = today;
          }
        }
    }

    final rows = <ClassAlarmDayFirstSection>[];
    for (var date = today; !date.isAfter(endDate); date = date.add(const Duration(days: 1))) {
      final week = _calendarWeekFor(date, settings);
      if (week == null || week < 1) {
        continue;
      }
      final courses = provider.getActiveCoursesForDay(date.weekday, week: week);
      if (courses.isEmpty) {
        continue;
      }
      // 课程真实钟点按「节次号 → 生效时间模板」解析（与超级岛同一套语义，
      // 与课程卡片显示一致）。开始节次超出模板节数的课程是导入产生的幻影行
      // （行内存量钟点可能是 00:00 等占位值），直接跳过，绝不能参与取最早。
      String? bestClock;
      var bestMinutes = -1;
      for (final course in courses) {
        final realStart = provider.resolvedCourseStartTime(course);
        if (realStart == null) {
          continue;
        }
        final minutes = ClassAlarmLogic.parseClockMinutes(realStart);
        if (minutes == null) {
          continue;
        }
        if (bestMinutes < 0 || minutes < bestMinutes) {
          bestMinutes = minutes;
          bestClock = realStart.trim();
        }
      }
      if (bestClock == null) {
        continue;
      }
      rows.add(ClassAlarmDayFirstSection(
        dayOfWeek: date.weekday,
        startTime: bestClock,
      ));
    }
    return rows;
  }

  Future<void> _batchAdd() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    if (provider.activeTimeScheme == null) {
      _toast(l10n.classAlarmNoSchemeToast, kind: AppToastKind.warning);
      return;
    }
    final rows = _collectOccurrences(settings.classAlarmRange);
    if (rows.isEmpty) {
      _toast(l10n.classAlarmNoDataToast, kind: AppToastKind.warning);
      return;
    }
    final grouping = ClassAlarmLogic.groupFromOccurrences(
      rows: rows,
      leadMinutes: ClassAlarmLogic.clampLeadMinutes(settings.classAlarmLeadMinutes),
    );
    if (grouping.groups.isEmpty) {
      _toast(l10n.classAlarmNoDataToast, kind: AppToastKind.warning);
      return;
    }
    final detailParts = <String>[];
    for (final group in grouping.groups) {
      final days = group.dayOfWeeks
          .map((d) => _weekdayLabel(l10n, d))
          .join(l10n.classAlarmDaySeparator);
      final clock = ClassAlarmLogic.formatClock(group.plan.hour * 60 + group.plan.minute);
      detailParts.add('$days $clock');
    }
    var message =
        l10n.classAlarmConfirmMessage(detailParts.join(l10n.classAlarmDetailSeparator));
    if (grouping.variableDays.isNotEmpty) {
      final variableDays = grouping.variableDays
          .map((d) => _weekdayLabel(l10n, d))
          .join(l10n.classAlarmDaySeparator);
      message += l10n.classAlarmVariableSuffix(variableDays);
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.classAlarmConfirmTitle,
      message: message,
      confirmLabel: l10n.confirmAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    // 逐组分发；首个失败立即中止并如实汇报已写入数量——系统时钟无法
    // 读取去重，盲目连发只会堆积重复闹钟。
    final total = grouping.groups.length;
    final label = l10n.appTitle;
    var launchedCount = 0;
    for (final group in grouping.groups) {
      final result = await ClassAlarmService.addAlarm(
        group.plan.copyWith(label: label, skipUi: settings.classAlarmSkipUi),
      );
      if (!result.launched) {
        break;
      }
      launchedCount++;
    }
    if (!mounted) {
      return;
    }
    if (launchedCount == total) {
      _toast(l10n.classAlarmAddedToast, kind: AppToastKind.success);
    } else if (launchedCount == 0) {
      _toast(l10n.classAlarmLaunchFailedToast, kind: AppToastKind.error);
    } else {
      _toast(
        l10n.classAlarmPartialAddedToast(launchedCount, total),
        kind: AppToastKind.warning,
      );
    }
  }

  Future<void> _openSystemClock() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ClassAlarmService.openSystemAlarms();
    if (!mounted) {
      return;
    }
    if (!ok) {
      _toast(l10n.classAlarmLaunchFailedToast, kind: AppToastKind.error);
    }
  }

  Future<void> _pickLeadMinutes() async {
    final l10n = AppLocalizations.of(context)!;
    final options = <int>[0, 10, 15, 20, 30, 45, 60];
    final current = ClassAlarmLogic.clampLeadMinutes(
      context.read<TimetableProvider>().settings.classAlarmLeadMinutes,
    );
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: l10n.classAlarmLeadTitle,
      items: {
        for (final minutes in options)
          l10n.classAlarmLeadMinutesLabel(minutes): minutes,
      },
      currentValue: options.contains(current) ? current : 30,
      cancelLabel: l10n.cancelAction,
    );
    if (selected == null || selected == current || !mounted) {
      return;
    }
    await _updateSettingsSafely(
      l10n,
      (settings) => settings.copyWith(classAlarmLeadMinutes: selected),
    );
  }

  Future<void> _pickRange() async {
    final l10n = AppLocalizations.of(context)!;
    final current =
        context.read<TimetableProvider>().settings.classAlarmRange;
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: l10n.classAlarmRangeLabel,
      items: {
        l10n.classAlarmRangeNext4Weeks: _rangeNext4Weeks,
        l10n.classAlarmRangeNext8Weeks: _rangeNext8Weeks,
        l10n.classAlarmRangeRemaining: _rangeUntilSemesterEnd,
      },
      currentValue:
          current >= _rangeNext4Weeks && current <= _rangeUntilSemesterEnd
              ? current
              : _rangeNext4Weeks,
      cancelLabel: l10n.cancelAction,
    );
    if (selected == null || selected == current || !mounted) {
      return;
    }
    await _updateSettingsSafely(
      l10n,
      (settings) => settings.copyWith(classAlarmRange: selected),
    );
  }

  String _rangeLabel(AppLocalizations l10n, int range) => switch (range) {
        _rangeNext8Weeks => l10n.classAlarmRangeNext8Weeks,
        _rangeUntilSemesterEnd => l10n.classAlarmRangeRemaining,
        _ => l10n.classAlarmRangeNext4Weeks,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.classAlarmEntryTitle),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: _buildContent,
      ),
    );
  }

  Widget _buildContent(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<TimetableProvider>().settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.classAlarmGroupSetup),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.alarm_add_outlined,
              iconAccent: HyperosIconColors.orange,
              title: l10n.classAlarmAddAllTitle,
              onTap: _batchAdd,
            ),
            HyperosListTile(
              icon: Icons.date_range_outlined,
              iconAccent: HyperosIconColors.blue,
              title: l10n.classAlarmRangeLabel,
              details: _rangeLabel(l10n, settings.classAlarmRange),
              onTap: _pickRange,
            ),
            HyperosListTile(
              icon: Icons.schedule_outlined,
              iconAccent: HyperosIconColors.teal,
              title: l10n.classAlarmOpenClock,
              onTap: _openSystemClock,
            ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.classAlarmGroupBehavior),
        HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.timer_outlined,
              iconAccent: HyperosIconColors.purple,
              title: l10n.classAlarmLeadTitle,
              details: l10n.classAlarmLeadMinutesLabel(
                ClassAlarmLogic.clampLeadMinutes(settings.classAlarmLeadMinutes),
              ),
              onTap: _pickLeadMinutes,
            ),
            HyperosSwitchTile(
              icon: Icons.bolt_outlined,
              iconAccent: HyperosIconColors.orange,
              title: l10n.classAlarmSkipUiTitle,
              subtitle: l10n.classAlarmSkipUiSubtitle,
              value: settings.classAlarmSkipUi,
              onChanged: (value) {
                _updateSettingsSafely(
                  l10n,
                  (current) => current.copyWith(classAlarmSkipUi: value),
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
