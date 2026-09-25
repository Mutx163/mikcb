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
                  // 渲染性能设置快照：只在调试版 / 性能版可见（与内存监测同一个
                  // 包名门控）。调性能时不必再翻三层设置页回忆「现在是什么材质
                  // 档」—— 打一条就能和 logcat 里的 `[frame-perf]` 读数对上。
                  if (showMemoryStats)
                    HyperosListTile(
                      title: l10n.performanceSnapshotEntryTitle,
                      subtitle: l10n.performanceSnapshotEntrySubtitle,
                      onTap: _logPerformanceSnapshot,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 手动打一条快照。自动的两次（启动、改设置）在 `main.dart` 与
  /// `TimetableProvider` 里；这一条是给「已经卡了、想立刻留一份现场」用的。
  Future<void> _logPerformanceSnapshot() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    await logPerformanceSettingsSnapshot(
      provider.settings,
      reason: 'manualExport',
    );
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.performanceSnapshotEntryDone,
      kind: AppToastKind.success,
    );
  }

  /// 走统一入口 [openLogViewer]，避免各页各配一份日志页参数。
  Future<void> _openAppLogsPage() =>
      openLogViewer(context, AppLogSource.merged);

  Future<void> _updateRecordingPreference(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    try {
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
    } catch (_) {
      // 落盘失败：provider 已回滚内存与课表镜像并 rethrow，不接就没人提示。
      reportSettingsPersistFailure(this);
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
