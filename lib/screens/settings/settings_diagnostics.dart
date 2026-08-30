part of '../timetable_settings_screen.dart';

/// 诊断与日志。
///
/// 排障入口此前散在三处：应用日志在「关于」，内存监测在设置页脚。
/// 出问题的人要在多处找线索，这里收成一个口子。超级岛自检有意不收——
/// 它是超级岛的功能入口，放「超级岛与通知」的维护组用户才找得到；
/// 收进诊断页曾收到用户反馈「太深、不知道功能去哪了」。
///
/// 「记录应用日志」开关 2026-08-30 从日志查看页头部迁来：开关是配置，
/// 查看页应是纯阅读器——此前开关卡+折叠排序卡占掉页面大半，日志列表
/// 被挤到底部。功能入口不收进这里的原则不变，配置类开关不受限。
class _DiagnosticsScreen extends StatefulWidget {
  const _DiagnosticsScreen();

  @override
  State<_DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<_DiagnosticsScreen> {
  late final Future<bool> _diagnosticsBuildFuture =
      MemoryStatsService.isDiagnosticsBuild();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recordingEnabled = context
        .watch<TimetableProvider>()
        .settings
        .liveEnableLocalDiagnostics;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.diagnosticsEntryTitle),
      child: FutureBuilder<bool>(
        future: _diagnosticsBuildFuture,
        builder: (context, snapshot) {
          final showMemoryStats = snapshot.data == true;
          return HyperosListView(
            pageStorageKey: const PageStorageKey<String>(
              'settings-diagnostics',
            ),
            children: [
              HyperosListGroup(
                children: [
                  HyperosListTile(
                    title: l10n.aboutAppLogsTitle,
                    details: l10n.aboutAppLogsSubtitle,
                    onTap: _openAppLogsPage,
                  ),
                  HyperosSwitchTile(
                    title: l10n.aboutRecordDiagnosticsTitle,
                    subtitle: l10n.aboutRecordDiagnosticsSubtitle,
                    value: recordingEnabled,
                    onChanged: _updateRecordingPreference,
                  ),
                  if (showMemoryStats)
                    HyperosListTile(
                      title: l10n.memoryStatsEntryTitle,
                      onTap: () {
                        HyperosNavigation.push(
                          context,
                          settings: const RouteSettings(
                            name: '/settings/memory-stats',
                          ),
                          builder: (_) => const MemoryStatsScreen(),
                        );
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 走统一入口 [openLogViewer]，避免各页各配一份日志页参数。
  Future<void> _openAppLogsPage() =>
      openLogViewer(context, AppLogSource.merged);

  Future<void> _updateRecordingPreference(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(liveEnableLocalDiagnostics: value),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      return;
    }
    showAppToast(
      context,
      message: value
          ? l10n.aboutLiveDiagnosticsEnabled
          : l10n.aboutLiveDiagnosticsDisabled,
      kind: AppToastKind.success,
    );
  }
}
