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
    // 落盘失败回滚并 rethrow（`settings_repository.dart` 的 `_rollbackSettingsWrite`）。
    // 不接的话：开关弹回去了但用户什么都不知道，而周报**其实被排上了**
    // （下面 `WeeklyReportService.schedule` 用的是新值），下次开机用户收到一份
    // 他明明关掉过的周报。
    try {
      await provider.updateSettings(
        provider.settings.copyWith(weeklyReportEnabled: enabled),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
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
