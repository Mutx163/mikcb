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
  };
}

class _HomeWidgetSettingsScreen extends StatefulWidget {
  const _HomeWidgetSettingsScreen();

  @override
  State<_HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<_HomeWidgetSettingsScreen> {
  static const double _defaultWidgetHeightAdjustment = -11;
  static const double _defaultWidgetCornerRadius = 22;

  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  bool _isPersisting = false;
  bool _isCheckingPinSupport = true;
  bool _canRequestPinWidget = false;
  TimetableSettings? _pendingPersist;
  final Set<HomeWidgetPinTarget> _pinningTargets = <HomeWidgetPinTarget>{};

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _loadPinWidgetSupport();
  }

  @override
  void dispose() {
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

  int get _homeWidgetSectionCount =>
      (_draft.widgetShowCountdown ? 4 : 3) + 1;

  Widget _buildHomeWidgetSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    var section = index;
    if (!_draft.widgetShowCountdown && section >= 2) {
      section += 1;
    }

    final Widget content = switch (section) {
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
                      const Expanded(child: SizedBox()),
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

  String _widgetHeightAdjustmentLabel(AppLocalizations l10n) {
    if (_draft.widgetHeightAdjustment == _defaultWidgetHeightAdjustment) {
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
  }
}
