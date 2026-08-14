import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../providers/timetable_provider.dart';
import '../services/weekly_report_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// 课程统计设置二级页（右上角入口）：周报推送开关等
class StatisticsSettingsScreen extends StatelessWidget {
  const StatisticsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, _) {
        final enabled = provider.settings.weeklyReportEnabled;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.statisticsSettingsTitle),
          child: HyperosListView(
            children: [
              HyperosSettingsBlock(
                title: l10n.weeklyReportTitle,
                child: _buildWeeklyReportTile(
                  context,
                  l10n,
                  provider,
                  enabled,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyReportTile(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProvider provider,
    bool enabled,
  ) {
    final nextFire = WeeklyReportService.nextFireAt();
    final nextFireLabel = DateFormat.MMMd(l10n.localeName).format(nextFire);
    final nextFireTime =
        '${nextFire.hour.toString().padLeft(2, '0')}:${nextFire.minute.toString().padLeft(2, '0')}';

    return HyperosSwitchTile(
      icon: Icons.notifications_active_outlined,
      iconAccent: enabled ? HyperosIconColors.orange : HyperosIconColors.blue,
      title: l10n.weeklyReportTitle,
      subtitle: enabled
          ? l10n.weeklyReportNextFire(nextFireLabel, nextFireTime)
          : l10n.weeklyReportDisabledHint,
      value: enabled,
      onChanged: (value) => _setWeeklyReportEnabled(
        context,
        provider,
        value,
      ),
    );
  }

  Future<void> _setWeeklyReportEnabled(
    BuildContext context,
    TimetableProvider provider,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: enabled),
    );
    await WeeklyReportService.schedule(
      enabled: enabled,
      l10n: l10n,
      allCourses: provider.courses,
      currentWeek: provider.currentWeek,
      semesterWeekCount: provider.settings.semesterWeekCount,
    );
    if (context.mounted) {
      showAppToast(
        context,
        message: enabled
            ? l10n.weeklyReportEnabledHint
            : l10n.weeklyReportDisabledHint,
      );
    }
  }
}
