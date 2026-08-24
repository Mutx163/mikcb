part of '../timetable_settings_screen.dart';

/// 诊断与日志。
///
/// 排障入口此前散在三处：应用日志在「关于」，超级岛自检在「超级岛与通知」，
/// 内存监测在设置页脚。出问题的人要在三个地方找线索。这里收成一个口子。
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
                  HyperosListTile(
                    title: l10n.liveSelfCheckTitle,
                    details: l10n.liveSelfCheckSubtitle,
                    onTap: () {
                      HyperosNavigation.push(
                        context,
                        settings: const RouteSettings(
                          name: '/settings/live/self-check',
                        ),
                        builder: (_) => const _LiveTestingSettingsScreen(),
                      );
                    },
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
}
