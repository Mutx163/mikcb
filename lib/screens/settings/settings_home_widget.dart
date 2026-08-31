part of '../timetable_settings_screen.dart';

String _homeWidgetTargetLabel(
  BuildContext context,
  HomeWidgetPinTarget target,
) {
  final l10n = AppLocalizations.of(context)!;
  return switch (target) {
    HomeWidgetPinTarget.compact22 => l10n.homeWidgetTargetCompact22,
    HomeWidgetPinTarget.miniList22 => l10n.homeWidgetTargetMiniList22,
    HomeWidgetPinTarget.medium24 => l10n.homeWidgetTargetMedium24,
    HomeWidgetPinTarget.large44 => l10n.homeWidgetTargetLarge44,
    HomeWidgetPinTarget.stats22 => l10n.homeWidgetTargetStats22,
    HomeWidgetPinTarget.stats24 => l10n.homeWidgetTargetStats24,
    HomeWidgetPinTarget.todayStrip41 => l10n.homeWidgetTargetTodayStrip41,
    HomeWidgetPinTarget.statsStrip41 => l10n.homeWidgetTargetStatsStrip41,
    HomeWidgetPinTarget.examCard22 => l10n.homeWidgetTargetExamCard22,
    HomeWidgetPinTarget.todayWide42 => l10n.homeWidgetTargetTodayWide42,
  };
}

class _HomeWidgetSettingsScreen extends StatefulWidget {
  const _HomeWidgetSettingsScreen();

  @override
  State<_HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<_HomeWidgetSettingsScreen>
    with WidgetsBindingObserver {
  static const double _defaultWidgetHeightAdjustment = -11;
  static const double _defaultWidgetCornerRadius = 22;

  /// 「跟随当前课表」的哨兵值：绑定语义是 null（未登记），但
  /// HyperosSelectTile 对 null 值不渲染值标签（hyperosSelectLabelFor 对
  /// null 直接返回空），用空串占位才能把「跟随当前课表」显示出来。
  static const String _followActiveValue = '';

  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  final HomeWidgetBindingService _homeWidgetBindingService =
      HomeWidgetBindingService();
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  List<HomeWidgetInstance> _widgetInstances = const <HomeWidgetInstance>[];
  Timer? _autoSaveTimer;
  bool _isPersisting = false;
  bool _isCheckingPinSupport = true;
  bool _canRequestPinWidget = false;
  /// Android 12+ 未授予「闹钟和提醒」权限时为 true，顶部展示引导横幅。
  bool _canScheduleExactAlarms = true;
  TimetableSettings? _pendingPersist;
  final Set<HomeWidgetPinTarget> _pinningTargets = <HomeWidgetPinTarget>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _loadPinWidgetSupport();
    _loadExactAlarmPermission();
    _loadWidgetInstances();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // 从桌面/系统弹窗回到前台：桌面小组件集合可能已变化（用户去桌面加了
    // 或删了卡片，系统不会通知 App 界面），稍候重查——pin 确认后启动器
    // 需要一拍才完成绑定，立即查可能拿到旧集合。
    _loadExactAlarmPermission();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadWidgetInstances();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeWidgetSettingsTitle),
      child: HyperosListView(
        itemCount: _homeWidgetSectionCount,
        itemBuilder: _buildHomeWidgetSection,
      ),
    );
  }

  /// 未授权时多一个「精确闹钟权限」引导分区。
  int get _exactAlarmBannerSections => _canScheduleExactAlarms ? 0 : 1;

  int get _homeWidgetSectionCount =>
      (_draft.widgetShowCountdown ? 4 : 3) + 2 + _exactAlarmBannerSections;

  Widget _buildHomeWidgetSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    var section = index;
    // 权限引导横幅固定在第 1 位，未展示时跳过；未展示倒计时分区时再偏移。
    if (section >= _exactAlarmBannerSections) {
      section -= _exactAlarmBannerSections;
    }
    if (!_draft.widgetShowCountdown && section >= 2) {
      section += 1;
    }

    final Widget content = switch (section) {
      -1 => _buildExactAlarmBannerSection(l10n),
      0 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetQuickAddTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.compact22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.miniList22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.medium24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.large44,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.stats22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.stats24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.todayStrip41,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.statsStrip41,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.examCard22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.todayWide42,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetTodayCourseTitle),
          HyperosListGroup(
            children: [
              HyperosSelectTile<WidgetBackgroundStyle>(
                label: l10n.homeWidgetBackgroundStyleLabel,
                items: {
                  for (final v in WidgetBackgroundStyle.values)
                    widgetBackgroundStyleLabel(l10n, v): v,
                },
                value: _draft.widgetBackgroundStyle,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetBackgroundStyle: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowLocationTitle,
                subtitle: l10n.homeWidgetShowLocationSubtitle,
                value: _draft.widgetShowLocation,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetShowLocation: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowCountdownTitle,
                subtitle: l10n.homeWidgetShowCountdownSubtitle,
                value: _draft.widgetShowCountdown,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(widgetShowCountdown: value));
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetHideCompletedTitle,
                subtitle: l10n.homeWidgetHideCompletedSubtitle,
                value: _draft.widgetHideCompletedCourses,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetHideCompletedCourses: value),
                  );
                },
              ),
              HyperosSwitchTile(
                title: l10n.homeWidgetShowTomorrowTitle,
                subtitle: l10n.homeWidgetShowTomorrowSubtitle,
                value: _draft.widgetShowTomorrowCourses,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetShowTomorrowCourses: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetCountdownLeadTitle),
          HyperosListGroup(
            children: [
              HyperosSelectTile<int>(
                label: l10n.homeWidgetCountdownLeadTitle,
                items: {
                  l10n.homeWidgetCountdownLeadAlways: 0,
                  for (final m in const [1, 5, 10, 15, 20, 30, 40, 50, 60])
                    l10n.beforeClassMinutesOption(m): m,
                },
                value: _draft.widgetCountdownLeadMinutes,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetCountdownLeadMinutes: value),
                  );
                },
              ),
              HyperosSelectTile<LiveCountdownTextStyle>(
                label: l10n.widgetCountdownStyleTitle,
                items: {
                  for (final v in LiveCountdownTextStyle.values)
                    liveCountdownTextStyleLabel(l10n, v): v,
                },
                value: _draft.widgetCountdownTextStyle,
                onChanged: (value) {
                  _updateDraft(
                    _draft.copyWith(widgetCountdownTextStyle: value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetHeightAdjustTitle),
          HyperosListGroup(
            children: [
              HyperosSliderTile(
                title: _widgetHeightAdjustmentLabel(l10n),
                value: _draft.widgetHeightAdjustment,
                min: _defaultWidgetHeightAdjustment - 16,
                max: _defaultWidgetHeightAdjustment + 16,
                divisions: 32,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(widgetHeightAdjustment: value),
                  debounce: true,
                ),
              ),
              HyperosSliderTile(
                title: l10n.homeWidgetCornerRadiusTitle,
                valueLabel: '${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                value: _draft.widgetCornerRadius,
                min: _defaultWidgetCornerRadius - 14,
                max: _defaultWidgetCornerRadius + 14,
                divisions: 28,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(widgetCornerRadius: value),
                  debounce: true,
                ),
              ),
            ],
          ),
        ],
      ),
      4 => _buildWidgetBindingSection(l10n),
      _ => _SettingsResetTile(
        scope: SettingsResetScope.homeWidget,
        onReset: _updateDraft,
      ),
    };

    if (index == 0) {
      return content;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const HyperosSectionGap(), content],
    );
  }

  /// 「各卡片绑定管理」：列出桌面上真实存在的今日课程卡片，
  /// 逐张选择显示哪个课表（跟随当前课表 / 我的课表 / TA的课表）。
  Widget _buildWidgetBindingSection(AppLocalizations l10n) {
    if (_widgetInstances.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.homeWidgetBindingSectionTitle),
          HyperosListGroup(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  l10n.homeWidgetBindingEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final normalProfiles = _timetableProvider.profiles
        .where((profile) => !profile.isPartnerImported)
        .toList(growable: false);
    final partnerProfile = _timetableProvider.partnerProfile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.homeWidgetBindingSectionTitle),
        HyperosListGroup(
          children: [
            for (final instance in _widgetInstances)
              HyperosSelectTile<String>(
                label: _homeWidgetTargetLabel(
                  context,
                  _pinTargetForType(instance.widgetType),
                ),
                items: {
                  l10n.homeWidgetBindingFollowActive: _followActiveValue,
                  for (final profile in normalProfiles) profile.name: profile.id,
                  if (partnerProfile != null)
                    partnerProfile.name: partnerProfile.id,
                },
                value: instance.boundProfileId ?? _followActiveValue,
                onChanged: (profileId) => _setWidgetBinding(
                  instance.appWidgetId,
                  profileId == _followActiveValue ? null : profileId,
                ),
              ),
          ],
        ),
      ],
    );
  }

  HomeWidgetPinTarget _pinTargetForType(HomeWidgetType? type) {
    return switch (type) {
      HomeWidgetType.compact => HomeWidgetPinTarget.compact22,
      HomeWidgetType.miniList => HomeWidgetPinTarget.miniList22,
      HomeWidgetType.medium => HomeWidgetPinTarget.medium24,
      HomeWidgetType.large => HomeWidgetPinTarget.large44,
      HomeWidgetType.todayStrip => HomeWidgetPinTarget.todayStrip41,
      HomeWidgetType.todayWide => HomeWidgetPinTarget.todayWide42,
      null => HomeWidgetPinTarget.compact22,
    };
  }

  Future<void> _loadWidgetInstances() async {
    final instances = await _homeWidgetBindingService.listTodayWidgetInstances();
    if (!mounted) {
      return;
    }
    setState(() {
      _widgetInstances = instances;
    });
  }

  Future<void> _setWidgetBinding(int appWidgetId, String? profileId) async {
    final ok = await _homeWidgetBindingService.setWidgetBinding(
      appWidgetId,
      profileId,
    );
    if (!mounted) {
      return;
    }
    await _loadWidgetInstances();
    if (!mounted) {
      return;
    }
    if (!ok) {
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.homeWidgetBindingSaveFailed,
      );
    }
  }

  String _widgetHeightAdjustmentLabel(AppLocalizations l10n) {    if (_draft.widgetHeightAdjustment == _defaultWidgetHeightAdjustment) {
      return l10n.defaultLabel;
    }
    if (_draft.widgetHeightAdjustment > _defaultWidgetHeightAdjustment) {
      return l10n.higherByValue(
        (_draft.widgetHeightAdjustment - _defaultWidgetHeightAdjustment)
            .toStringAsFixed(0),
      );
    }
    return l10n.lowerByValue(
      (_defaultWidgetHeightAdjustment - _draft.widgetHeightAdjustment)
          .toStringAsFixed(0),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _pendingPersist = next;
    if (_isPersisting) {
      return;
    }
    _drainPersistQueue();
  }

  Future<void> _drainPersistQueue() async {
    _isPersisting = true;
    try {
      while (_pendingPersist != null) {
        final next = _pendingPersist!;
        _pendingPersist = null;
        await _persistDraft(next);
      }
    } finally {
      _isPersisting = false;
    }
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = _timetableProvider;
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }

  Future<void> _loadExactAlarmPermission() async {
    final granted = await _homeWidgetService.canScheduleExactAlarms();
    if (!mounted) {
      return;
    }
    setState(() {
      _canScheduleExactAlarms = granted;
    });
  }

  Future<void> _requestExactAlarmPermission() async {
    await _homeWidgetService.requestScheduleExactAlarm();
    // 回到前台时 didChangeAppLifecycleState 会重查授权状态。
  }

  /// 「精确闹钟权限」引导分区：Android 12+ 未授予时提示并一键跳系统授权页。
  Widget _buildExactAlarmBannerSection(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosHintBanner(
          icon: Icon(
            Icons.alarm_rounded,
            size: 18,
            color: HyperosColors.primary(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeWidgetExactAlarmBannerTitle,
                style: HyperosTypography.listTitle(context),
              ),
              const SizedBox(height: 4),
              Text(l10n.homeWidgetExactAlarmBannerText),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: HyperosButton(
                  label: l10n.homeWidgetExactAlarmGrantAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: _requestExactAlarmPermission,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadPinWidgetSupport() async {
    final supported = await _homeWidgetService.canRequestPinWidget();
    if (!mounted) {
      return;
    }
    setState(() {
      _canRequestPinWidget = supported;
      _isCheckingPinSupport = false;
    });
  }

  Widget _buildPinWidgetButton(HomeWidgetPinTarget target) {
    final isLoading = _pinningTargets.contains(target);
    final canPin = !_isCheckingPinSupport && _canRequestPinWidget && !isLoading;
    return SizedBox(
      width: double.infinity,
      child: HyperosButton(
        label: _homeWidgetTargetLabel(context, target),
        variant: HyperosButtonVariant.secondary,
        expand: true,
        loading: isLoading || _isCheckingPinSupport,
        onPressed: canPin ? () => _requestPinWidget(target) : null,
      ),
    );
  }

  Future<void> _requestPinWidget(HomeWidgetPinTarget target) async {
    setState(() {
      _pinningTargets.add(target);
    });
    final result = await _homeWidgetService.requestPinWidget(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _pinningTargets.remove(target);
    });

    final message = switch (result) {
      HomeWidgetPinRequestResult.requested => AppLocalizations.of(
        context,
      )!.homeWidgetPinRequested(_homeWidgetTargetLabel(context, target)),
      HomeWidgetPinRequestResult.unsupported =>
        AppLocalizations.of(context)!.homeWidgetPinUnsupportedManual(
          _homeWidgetTargetLabel(context, target),
        ),
      HomeWidgetPinRequestResult.invalidWidgetType => AppLocalizations.of(
        context,
      )!.homeWidgetInvalidType,
      HomeWidgetPinRequestResult.failed => AppLocalizations.of(
        context,
      )!.homeWidgetPinFailedManual(_homeWidgetTargetLabel(context, target)),
    };
    showAppToast(context, message: message);
    // 请求未受理（unsupported/failed）时集合不变、重查无害；真正「已确认
    // 添加」发生在系统弹窗之后，由 resumed 刷新兜底，这里即时重查一次。
    unawaited(_loadWidgetInstances());
  }
}
