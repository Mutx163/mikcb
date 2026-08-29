part of '../timetable_settings_screen.dart';

Widget createLiveSettingsScreen() => const _LiveSettingsScreen();

/// Public factory for debug deep-link navigation (debug builds only).
Widget createLiveTestingSettingsScreen() => const _LiveTestingSettingsScreen();

class _LiveSettingsScreen extends StatefulWidget {
  const _LiveSettingsScreen();

  @override
  State<_LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<_LiveSettingsScreen> {
  late TimetableSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveSettingsTitle),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: _buildLiveSettingsSection,
      ),
    );
  }

  Widget _buildLiveSettingsSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final beforeClassSummary = _liveDisplaySummary(
      context,
      _draft.beforeClassDisplaySettings,
    );
    final duringEndSummary = _draft.liveDuringEndFollowBeforeClass
        ? l10n.followBeforeClassSetting
        : _liveDisplaySummary(context, _draft.duringEndDisplaySettings);
    // 提醒 / 显示是偏好，保活与自检是维护诊断——两种心智不该挤在同一个
    // 无名大组里（IA §3 分组可预期 + §8 隔离精神），拆成三个带标签组。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.liveGroupReminders),
        HyperosListGroup(
          children: [
            HyperosListTile(
              title: l10n.liveReminderTimingTitle,
              onTap: () async {
                await HyperosNavigation.push(
                  context,
                  builder: (_) => const LiveReminderTimingScreen(),
                );
                if (!mounted) return;
                setState(() {
                  _draft = context.read<TimetableProvider>().settings;
                });
              },
            ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.liveGroupDisplay),
        HyperosListGroup(
          children: [
            HyperosListTile(
              title: l10n.beforeClassDisplaySettingsTitle,
              details: beforeClassSummary,
              onTap: () async {
                await HyperosNavigation.push(
                  context,
                  builder: (_) => LiveDisplaySettingsScreen(
                    title: l10n.beforeClassDisplaySettingsTitle,
                    forDuringEnd: false,
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _draft = context.read<TimetableProvider>().settings;
                });
              },
            ),
            HyperosListTile(
              title: l10n.duringEndDisplaySettingsTitle,
              details: duringEndSummary,
              onTap: () async {
                await HyperosNavigation.push(
                  context,
                  builder: (_) => LiveDisplaySettingsScreen(
                    title: l10n.duringEndDisplaySettingsTitle,
                    forDuringEnd: true,
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _draft = context.read<TimetableProvider>().settings;
                });
              },
            ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.liveGroupMaintenance),
        HyperosListGroup(
          children: [
            HyperosListTile(
              title: l10n.liveKeepAliveTitle,
              onTap: () async {
                await HyperosNavigation.push(
                  context,
                  builder: (_) => const LiveKeepAliveSettingsScreen(),
                );
                if (!mounted) return;
                setState(() {
                  _draft = context.read<TimetableProvider>().settings;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveTestingSettingsScreen extends StatefulWidget {
  const _LiveTestingSettingsScreen();

  @override
  State<_LiveTestingSettingsScreen> createState() =>
      _LiveTestingSettingsScreenState();
}

class _LiveTestingSettingsScreenState extends State<_LiveTestingSettingsScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 1);

  final MiuiLiveActivitiesService _liveService = MiuiLiveActivitiesService();
  Map<String, dynamic>? _debugStatus;
  bool _loadingDebugStatus = true;
  bool _exportingDiagnostics = false;
  bool _clearingDiagnostics = false;
  bool _testToggling = false;
  Timer? _autoRefreshTimer;
  bool _refreshInFlight = false;
  bool _isAppResumed = true;
  bool _autoRefreshEnabled = true;
  DateTime? _lastDebugStatusUpdatedAt;
  bool _holidayOverrideEnabled = false;
  bool? _lastKnownTestSessionActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TimetableProvider>();
    _holidayOverrideEnabled = provider.settings.holidayOverrideEnabled;
    _lastKnownTestSessionActive = provider.hasLiveTestFixtureCourses;
    unawaited(_refreshDebugStatus(showLoading: true));
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || !_isAppResumed) {
        return;
      }
      // 预设课自动结束不发 notify（管线路径可能跨越生命周期），靠这里轮询
      // 翻转开始/取消按钮，且不受「自动刷新」开关影响。
      final sessionActive = provider.hasLiveTestFixtureCourses;
      if (_lastKnownTestSessionActive != sessionActive) {
        setState(() => _lastKnownTestSessionActive = sessionActive);
      }
      if (!_autoRefreshEnabled) {
        return;
      }
      unawaited(_refreshDebugStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshDebugStatus({bool showLoading = false}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (mounted && showLoading) {
      setState(() {
        _loadingDebugStatus = true;
      });
    }
    try {
      final status = await _liveService.getLiveUpdateDebugStatus();
      if (!mounted) return;
      setState(() {
        _debugStatus = status;
        _loadingDebugStatus = false;
        _lastDebugStatusUpdatedAt = DateTime.now();
      });
    } finally {
      _refreshInFlight = false;
      if (mounted && showLoading) {
        setState(() {
          _loadingDebugStatus = false;
        });
      }
    }
  }

  Future<void> _openLiveDiagnosticsViewer() =>
      openLogViewer(context, AppLogSource.live);

  Future<void> _exportLiveDiagnostics() async {
    final l10n = AppLocalizations.of(context)!;
    if (_exportingDiagnostics) return;
    setState(() {
      _exportingDiagnostics = true;
    });
    final logPath = await _liveService.exportLiveDiagnosticsFile();
    if (!mounted) return;
    var exportPath = logPath;
    var shareText = l10n.liveDiagnosticsShareText;
    var shareSubject = l10n.liveDiagnosticsShareSubject;
    if ((exportPath == null || exportPath.isEmpty) && _debugStatus != null) {
      exportPath = await _exportCurrentDebugSnapshot();
      shareText = l10n.liveDiagnosticsSnapshotShareText;
      shareSubject = l10n.liveDiagnosticsSnapshotShareSubject;
    }
    if (!mounted) return;
    setState(() {
      _exportingDiagnostics = false;
    });
    if (exportPath == null || exportPath.isEmpty) {
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.liveDiagnosticsNothingToExport,
        kind: AppToastKind.warning,
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(exportPath)],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }

  Future<String?> _exportCurrentDebugSnapshot() async {
    final snapshot = _debugStatus;
    if (snapshot == null) {
      return null;
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}mikcb-live-debug-snapshot-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    final payload = <String, dynamic>{
      'exportedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'source': 'live_testing_screen_snapshot',
      'debugStatus': snapshot,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  Future<void> _clearLiveDiagnostics() async {
    if (_clearingDiagnostics) return;
    setState(() {
      _clearingDiagnostics = true;
    });
    final cleared = await _liveService.clearLiveDiagnostics();
    if (!mounted) return;
    setState(() {
      _clearingDiagnostics = false;
    });
    showAppToast(
      context,
      message: cleared
          ? AppLocalizations.of(context)!.liveDiagnosticsCleared
          : AppLocalizations.of(context)!.liveDiagnosticsClearFailed,
      kind: cleared ? AppToastKind.success : AppToastKind.error,
    );
  }

  /// 自检测试会话开关：空闲态点击 = 开始测试（正式选课优先，无课可测时自动
  /// 兜底预设课）；测试中点击 = 立即取消（摘除预设课、重刷快照、停岛）。
  /// 预设课到点自动结束时覆盖层摘除并发 notify，按钮无需操作自动回到开始态。
  Future<void> _toggleTestSession() async {
    if (_testToggling) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _testToggling = true);
    try {
      if (provider.hasLiveTestFixtureCourses) {
        await provider.cancelLiveTestFixtureSession();
        if (!mounted) return;
        showAppToast(
          context,
          message: l10n.liveTestingSessionCanceled,
          kind: AppToastKind.info,
        );
      } else {
        await _showTestOptions(context);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      if (mounted) {
        setState(() => _testToggling = false);
      }
    }
    if (mounted) {
      await _refreshDebugStatus(showLoading: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = _debugSectionMap(_debugStatus?['summary']);
    final environment = _debugSectionMap(_debugStatus?['environment']);
    final service = _debugSectionMap(_debugStatus?['service']);
    final course = _debugSectionMap(_debugStatus?['course']);
    final timing = _debugSectionMap(_debugStatus?['timing']);
    final switches = _debugSectionMap(_debugStatus?['switches']);
    final display = _debugSectionMap(_debugStatus?['display']);
    final notification = _debugSectionMap(_debugStatus?['notification']);
    final recentDiagnostics = _debugSectionMap(
      _debugStatus?['recentDiagnostics'],
    );

    _debugL10nContext = context;
    final serviceRunning = summary['serviceRunning'] == true;
    final isActuallyPromotable = summary['isActuallyPromotable'] == true;
    final statusText = _debugValueText(summary['statusText']);
    final notIslandReason = _debugValueText(summary['notIslandReason']);
    final rawDebugJson = _debugStatus == null
        ? ''
        : JsonEncoder.withIndent('  ').convert(_debugStatus);
    final refreshedAt = _lastDebugStatusUpdatedAt;
    final refreshedAtText = refreshedAt == null
        ? l10n.liveTestingNotRefreshed
        : '${refreshedAt.hour.toString().padLeft(2, '0')}:${refreshedAt.minute.toString().padLeft(2, '0')}:${refreshedAt.second.toString().padLeft(2, '0')}';

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveSelfCheckTitle),
      child: HyperosListView(
        itemCount: _liveTestingSections().length,
        itemBuilder: (context, index) => _buildLiveTestingSection(
          context,
          _liveTestingSections()[index],
          l10n: l10n,
          summary: summary,
          environment: environment,
          service: service,
          course: course,
          timing: timing,
          switches: switches,
          display: display,
          notification: notification,
          recentDiagnostics: recentDiagnostics,
          serviceRunning: serviceRunning,
          isActuallyPromotable: isActuallyPromotable,
          statusText: statusText,
          notIslandReason: notIslandReason,
          rawDebugJson: rawDebugJson,
          refreshedAtText: refreshedAtText,
        ),
      ),
    );
  }

  List<_LiveTestingSection> _liveTestingSections() => [
    if (!kReleaseMode) _LiveTestingSection.holidayOverride,
    _LiveTestingSection.notification,
    _LiveTestingSection.islandStatus,
    // 时间校正是排障旋钮，不是偏好：它属于「岛显示得对不对」，
    // 因此从「提醒时间」页移到这里，与状态诊断放在一起。
    _LiveTestingSection.timeCorrection,
    if (_debugStatus != null) ...[
      _LiveTestingSection.debugEnvironment,
      _LiveTestingSection.debugService,
      _LiveTestingSection.debugCourse,
      _LiveTestingSection.debugTiming,
      _LiveTestingSection.debugSwitches,
      _LiveTestingSection.debugDisplay,
      _LiveTestingSection.debugNotification,
      _LiveTestingSection.debugRecentLogs,
      _LiveTestingSection.rawJson,
    ],
    _LiveTestingSection.localLogs,
  ];

  Widget _buildLiveTestingSection(
    BuildContext context,
    _LiveTestingSection section, {
    required AppLocalizations l10n,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> environment,
    required Map<String, dynamic> service,
    required Map<String, dynamic> course,
    required Map<String, dynamic> timing,
    required Map<String, dynamic> switches,
    required Map<String, dynamic> display,
    required Map<String, dynamic> notification,
    required Map<String, dynamic> recentDiagnostics,
    required bool serviceRunning,
    required bool isActuallyPromotable,
    required String statusText,
    required String notIslandReason,
    required String rawDebugJson,
    required String refreshedAtText,
  }) {
    return switch (section) {
      _LiveTestingSection.holidayOverride => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosSectionLabel(text: l10n.liveTestingHolidayOverride),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                value: _holidayOverrideEnabled,
                onChanged: (value) {
                  setState(() {
                    _holidayOverrideEnabled = value;
                  });
                  final provider = context.read<TimetableProvider>();
                  provider.updateTimetableSettings(
                    provider.settings.copyWith(holidayOverrideEnabled: value),
                  );
                  provider.refreshLiveActivityNow(forceSnapshotSync: true);
                },
                title: _holidayOverrideEnabled
                    ? l10n.liveTestingHolidayModeEnabled
                    : l10n.liveTestingHolidayModeDisabled,
                subtitle: _holidayOverrideEnabled
                    ? l10n.liveTestingHolidayModeEnabledDesc
                    : l10n.liveTestingHolidayOverrideSubtitle,
              ),
            ],
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.notification => Builder(
        builder: (context) {
          // 自检测试会话状态 = 预设课覆盖层挂载中。arm/disarm 都会
          // notifyListeners：点「开始测试」进入测试态、点「取消测试」退出，
          // 预设课到点自动结束时也自动回到开始态。
          final sessionActive = context
              .watch<TimetableProvider>()
              .hasLiveTestFixtureCourses;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HyperosControlCard(
                title: l10n.liveTestingNotificationTitle,
                subtitle: l10n.liveTestingNotificationSubtitle,
                child: HyperosControlCardInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sessionActive) ...[
                        _DebugStatusChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: l10n.liveTestingSessionRunning,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                      ],
                      HyperosButton(
                        label: sessionActive
                            ? l10n.liveTestingCancelAction
                            : l10n.liveTestingStartAction,
                        variant: sessionActive
                            ? HyperosButtonVariant.destructive
                            : HyperosButtonVariant.primary,
                        loading: _testToggling,
                        onPressed: _testToggling
                            ? null
                            : () => _toggleTestSession(),
                      ),
                      if (!kReleaseMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.liveTestingUmengHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            HyperosButton(
                              label: l10n.liveTestingCrashAction,
                              variant: HyperosButtonVariant.secondary,
                              onPressed: () => _triggerUmengTestCrash(context),
                            ),
                            HyperosButton(
                              label: l10n.liveTestingAnrAction,
                              variant: HyperosButtonVariant.secondary,
                              onPressed: () => _triggerUmengTestAnr(context),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const HyperosSectionGap(),
            ],
          );
        },
      ),
      _LiveTestingSection.islandStatus => Builder(
        builder: (context) {
          final semesterUnset =
              context.watch<TimetableProvider>().settings.semesterStartDate ==
              null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HyperosControlCard(
                title: l10n.liveTestingIslandStatusTitle,
                subtitle: l10n.liveTestingIslandStatusSubtitle,
                // Mixed inset content + full-bleed [HyperosSwitchTile]: do not
                // wrap the switch in [HyperosControlCardInset] (double 16dp).
                edgeToEdge: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HyperosControlCardInset(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (semesterUnset) ...[
                            Text(
                              l10n.pleaseSetSemesterStartDate,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DebugStatusChip(
                                icon: serviceRunning
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.stop_circle_outlined,
                                label: serviceRunning
                                    ? l10n.liveTestingServiceStatusRunning
                                    : l10n.liveTestingServiceStatusStopped,
                                color: serviceRunning
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              _DebugStatusChip(
                                icon: isActuallyPromotable
                                    ? Icons.verified_outlined
                                    : Icons.warning_amber_rounded,
                                label: statusText,
                                color: isActuallyPromotable
                                    ? HyperosIconColors.green
                                    : HyperosIconColors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.liveTestingNoIslandReasonTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notIslandReason.isEmpty
                                ? l10n.liveTestingNoIslandReasonEmpty
                                : notIslandReason,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              HyperosButton(
                                label: _loadingDebugStatus
                                    ? l10n.liveTestingRefreshing
                                    : l10n.liveTestingRefreshAction,
                                variant: HyperosButtonVariant.secondary,
                                loading: _loadingDebugStatus,
                                onPressed: _loadingDebugStatus
                                    ? null
                                    : () => _refreshDebugStatus(
                                        showLoading: true,
                                      ),
                              ),
                              HyperosButton(
                                label: _exportingDiagnostics
                                    ? l10n.liveTestingExporting
                                    : l10n.liveTestingExportAction,
                                variant: HyperosButtonVariant.secondary,
                                loading: _exportingDiagnostics,
                                onPressed: _exportingDiagnostics
                                    ? null
                                    : _exportLiveDiagnostics,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Mid-card preference row: square press fill, single 16dp.
                    HyperosControlCardRowScope(
                      isFirst: false,
                      isLast: false,
                      child: HyperosSwitchTile(
                        value: _autoRefreshEnabled,
                        onChanged: (value) {
                          setState(() {
                            _autoRefreshEnabled = value;
                          });
                        },
                        title: l10n.liveTestingAutoRefreshTitle,
                        subtitle: _autoRefreshEnabled
                            ? l10n.liveTestingAutoRefreshOn(
                                _autoRefreshInterval.inSeconds,
                              )
                            : l10n.liveTestingAutoRefreshOff,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HyperosControlCardScope.defaultHorizontalPadding,
                        0,
                        HyperosControlCardScope.defaultHorizontalPadding,
                        HyperosControlCardScope.defaultBodyBottomInset,
                      ),
                      child: Text(
                        l10n.liveTestingRefreshedAt(refreshedAtText),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const HyperosSectionGap(),
            ],
          );
        },
      ),
      _LiveTestingSection.timeCorrection => Consumer<TimetableProvider>(
        builder: (context, provider, _) {
          final seconds = provider.settings.liveTimeCorrectionSeconds;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosSectionLabel(text: l10n.timeCorrectionTitle),
              HyperosListGroup(
                children: [
                  HyperosSliderTile(
                    title: l10n.timeCorrectionLabel(
                      formatLiveTimeCorrection(l10n, seconds),
                    ),
                    dialogTitle: l10n.timeCorrectionTitle,
                    dialogHelper: l10n.timeCorrectionHelp,
                    value: seconds.toDouble().clamp(-30, 30),
                    min: -30,
                    max: 30,
                    divisions: 60,
                    onChanged: (value) {
                      unawaited(
                        provider.updateTimetableSettings(
                          provider.settings.copyWith(
                            liveTimeCorrectionSeconds: value.round(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const HyperosSectionGap(),
            ],
          );
        },
      ),
      _LiveTestingSection.debugEnvironment => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionEnvironment,
            data: environment,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugService => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionService,
            data: service,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugCourse => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(title: l10n.liveTestingSectionCourse, data: course),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugTiming => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(title: l10n.liveTestingSectionTiming, data: timing),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugSwitches => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionSwitches,
            data: switches,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugDisplay => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionDisplay,
            data: display,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugNotification => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionNotification,
            data: notification,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugRecentLogs => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionRecentLogs,
            data: recentDiagnostics,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.rawJson => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosControlCard(
            title: l10n.liveTestingRawDataTitle,
            subtitle: l10n.liveTestingRawDataSubtitle,
            child: HyperosControlCardInset(
              child: HyperosAccordion(
                items: [
                  HyperosAccordionItem(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.liveTestingExpandRawJson),
                        Text(
                          l10n.liveTestingExpandRawJsonSubtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    child: Text(
                      rawDebugJson,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.localLogs => HyperosControlCard(
        title: l10n.liveTestingLocalLogsTitle,
        subtitle: l10n.liveTestingLocalLogsSubtitle,
        child: HyperosControlCardInset(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              HyperosButton(
                label: _clearingDiagnostics
                    ? l10n.liveTestingClearingLogs
                    : l10n.liveTestingClearLogsAction,
                variant: HyperosButtonVariant.secondary,
                loading: _clearingDiagnostics,
                onPressed: _clearingDiagnostics ? null : _clearLiveDiagnostics,
              ),
              HyperosButton(
                label: l10n.liveTestingViewPhoneLogsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: _openLiveDiagnosticsViewer,
              ),
              HyperosButton(
                label: l10n.liveTestingMoreTesterOptionsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () {
                  HyperosNavigation.push(
                    context,
                    builder: (_) => const AboutScreen(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    };
  }
}

enum _LiveTestingSection {
  holidayOverride,
  notification,
  islandStatus,
  timeCorrection,
  debugEnvironment,
  debugService,
  debugCourse,
  debugTiming,
  debugSwitches,
  debugDisplay,
  debugNotification,
  debugRecentLogs,
  rawJson,
  localLogs,
}

BuildContext? _debugL10nContext;

Map<String, dynamic> _debugSectionMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

String _debugValueText(dynamic value) {
  if (value == null) return '';
  if (value is bool) {
    return value
        ? AppLocalizations.of(_debugL10nContext!)!.yesLabel
        : AppLocalizations.of(_debugL10nContext!)!.noLabel;
  }
  return value.toString();
}

class _DebugStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DebugStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSectionCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _DebugSectionCard({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return HyperosControlCard(
      title: title,
      subtitle: AppLocalizations.of(
        context,
      )!.liveTestingCurrentNativeFieldsSubtitle,
      child: HyperosControlCardInset(
        child: Column(
          children: data.entries
              .map(
                (entry) => _DebugValueRow(
                  label: entry.key,
                  value: _debugValueText(entry.value).isEmpty
                      ? '-'
                      : _debugValueText(entry.value),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DebugValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 144,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _triggerUmengTestCrash(BuildContext context) async {
  if (!context.mounted) return;
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.liveTestingCrashSoon,
    kind: AppToastKind.warning,
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestCrash();
}

Future<void> _triggerUmengTestAnr(BuildContext context) async {
  if (!context.mounted) return;
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.liveTestingAnrSoon,
    kind: AppToastKind.warning,
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestAnr();
}

void _showLiveTestingTriggerResult(
  BuildContext context,
  LiveTestingTriggerResult result,
) {
  if (result.message == null) return;
  showAppToast(
    context,
    message: result.message!,
    kind: switch (result.status) {
      LiveTestingTriggerStatus.success => AppToastKind.success,
      LiveTestingTriggerStatus.inFlight => AppToastKind.warning,
      LiveTestingTriggerStatus.error => AppToastKind.error,
    },
  );
}

Future<void> _showTestOptions(BuildContext context) async {
  final provider = context.read<TimetableProvider>();
  await provider.initialize();
  if (!context.mounted) return;
  final result = await triggerLiveUpdateTest(
    context: context,
    provider: provider,
    source: 'settings_screen',
  );
  if (!context.mounted) return;
  _showLiveTestingTriggerResult(context, result);
}
