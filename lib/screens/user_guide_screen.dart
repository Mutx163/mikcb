import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../widgets/settings_section_widgets.dart';
import 'course_overview_screen.dart';
import 'timetable_settings_screen.dart';

enum GuideAction { startUsing, importCourses, restoreBackup }

class UserGuideScreen extends StatefulWidget {
  final bool requirePrivacyConsent;
  final bool initialPrivacyChecked;
  final Future<bool> Function()? onImportCourses;
  final Future<bool> Function()? onRestoreBackup;

  const UserGuideScreen({
    super.key,
    this.requirePrivacyConsent = false,
    this.initialPrivacyChecked = false,
    this.onImportCourses,
    this.onRestoreBackup,
  });

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen>
    with WidgetsBindingObserver {
  final MiuiLiveActivitiesService _service = MiuiLiveActivitiesService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _isKeepAliveAccessibilityEnabled = false;
  bool _isAutoStartEnabled = false;
  late bool _privacyChecked;
  Timer? _settingsPollTimer;

  int get _totalPages => 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _privacyChecked = widget.initialPrivacyChecked;
    _refreshStatus();
  }

  @override
  void dispose() {
    _settingsPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _settingsPollTimer?.cancel();
      unawaited(_refreshStatusAfterExternalReturn());
    }
  }

  String _permissionSnapshotKey() {
    return [
      _hasNotificationPermission,
      _canPostPromoted,
      _isAutoStartEnabled,
      _isIgnoringBatteryOptimizations,
      _isKeepAliveAccessibilityEnabled,
    ].join(',');
  }

  void _startSettingsStatusPoll({required String baselineKey}) {
    _settingsPollTimer?.cancel();
    var ticks = 0;
    _settingsPollTimer = Timer.periodic(const Duration(milliseconds: 450), (
      timer,
    ) async {
      ticks++;
      if (!mounted || ticks > 30) {
        timer.cancel();
        return;
      }
      await _refreshStatus(showLoading: false);
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_permissionSnapshotKey() != baselineKey) {
        timer.cancel();
      }
    });
  }

  Future<void> _refreshStatusAfterExternalReturn() async {
    for (var i = 0; i < 5; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      if (!mounted) {
        return;
      }
      await _refreshStatus(showLoading: false);
    }
  }

  Future<void> _refreshStatus({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final promotedSupport = await _service.checkPromotedSupport();
    final hasNotificationPermission = await _service
        .checkNotificationPermission();
    final isIgnoringBatteryOptimizations = await _service
        .isIgnoringBatteryOptimizations();
    final isKeepAliveAccessibilityEnabled = await _service
        .isKeepAliveAccessibilityEnabled();
    final isAutoStartEnabled = await _service.isAutoStartEnabled();

    if (!mounted) {
      return;
    }
    setState(() {
      _hasNotificationPermission =
          promotedSupport['hasNotificationPermission'] == true ||
          hasNotificationPermission;
      _hasPromotedPermission = promotedSupport['hasPromotedPermission'] == true;
      _canPostPromoted = promotedSupport['canPostPromoted'] == true;
      _isIgnoringBatteryOptimizations = isIgnoringBatteryOptimizations;
      _isKeepAliveAccessibilityEnabled = isKeepAliveAccessibilityEnabled;
      _isAutoStartEnabled = isAutoStartEnabled;
      _isLoading = false;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    final baselineKey = _permissionSnapshotKey();
    await action();
    if (!mounted) {
      return;
    }
    _startSettingsStatusPoll(baselineKey: baselineKey);
  }

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int page) {
    if (widget.requirePrivacyConsent && !_privacyChecked && page > 1) {
      setState(() => _currentPage = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _currentPage = page);
  }

  void _goPrev() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !widget.requirePrivacyConsent,
      child: FScaffold(
        header: FHeader.nested(
          prefixes: widget.requirePrivacyConsent
              ? const []
              : [FHeaderAction.back(onPress: () => Navigator.pop(context))],
          title: Text(
            widget.requirePrivacyConsent
                ? l10n.firstUseGuideTitle
                : l10n.guideAndPermissionsTitle,
          ),
          suffixes: [
            FHeaderAction(
              icon: const Icon(Icons.refresh),
              semanticsLabel: l10n.refreshStatusTooltip,
              onPress: () => _refreshStatus(),
            ),
          ],
        ),
        childPad: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _buildProgressBar(l10n),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: [
                    _buildWelcomePage(l10n),
                    _buildPrivacyPage(l10n),
                    _buildPermissionsPage(l10n),
                    _buildTipsPage(l10n),
                  ],
                ),
              ),
              _buildBottomBar(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(AppLocalizations l10n) {
    if (_totalPages <= 1) return const SizedBox.shrink();

    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_currentPage + 1} / $_totalPages',
                style: typo.xs2.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _buildPageTitle(l10n),
                style: typo.xs2.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FDeterminateProgress(value: (_currentPage + 1) / _totalPages),
        ],
      ),
    );
  }

  String _buildPageTitle(AppLocalizations l10n) {
    if (_currentPage == 0) return l10n.welcomeTitle;
    if (_currentPage == 1) return l10n.guidePrivacyPageTitle;
    if (_currentPage == 2) return l10n.guidePermissionsPageTitle;
    return l10n.guideTipsPageTitle;
  }

  Widget _buildLanguageSelector(AppLocalizations l10n) {
    final provider = context.read<TimetableProvider?>();
    if (provider == null) return const SizedBox.shrink();

    return SettingsSectionCard(
      title: l10n.languageSectionTitle,
      subtitle: l10n.languageSectionSubtitle,
      child: FSelect<String>(
        hint: l10n.languageModeLabel,
        items: buildLocaleMenuMap(context),
        control: FSelectControl.lifted(
          value: normalizeLocaleTagForDropdown(provider.settings.appLocaleTag),
          onChange: (value) {
            if (value == null) return;
            final next = provider.settings.copyWith(appLocaleTag: value);
            provider.updateTimetableSettings(next);
          },
        ),
      ),
    );
  }

  Widget _buildWelcomePage(AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        FCard.raw(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeAppName,
                  style: typo.lg.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeSubtitle,
                  style: typo.sm.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLanguageSelector(l10n),
        const SizedBox(height: 12),
        FTileGroup(
          label: Text(l10n.welcomeTitle),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FTile(
              prefix: _GuideIconBadge(icon: Icons.rocket_launch_rounded),
              title: Text(l10n.startUsingTitle),
              subtitle: Text(l10n.startUsingSubtitle),
              suffix: const Icon(Icons.chevron_right_rounded),
              onPress: _goNext,
            ),
            if (widget.onImportCourses != null)
              FTile(
                prefix: _GuideIconBadge(icon: Icons.file_upload_outlined),
                title: Text(l10n.importTimetableTitle),
                subtitle: Text(l10n.importTimetableSubtitle),
                suffix: const Icon(Icons.chevron_right_rounded),
                onPress: () => _runWelcomeAction(widget.onImportCourses!),
              ),
            if (widget.onRestoreBackup != null)
              FTile(
                prefix: _GuideIconBadge(icon: Icons.restore_page_rounded),
                title: Text(l10n.restoreBackupTitle),
                subtitle: Text(l10n.restoreBackupSubtitle),
                suffix: const Icon(Icons.chevron_right_rounded),
                onPress: () => _runWelcomeAction(widget.onRestoreBackup!),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _runWelcomeAction(Future<bool> Function() action) async {
    final imported = await action();
    if (imported && mounted) {
      Navigator.of(context).pop(GuideAction.importCourses);
    }
  }

  Widget _buildPrivacyPage(AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final helperText = widget.requirePrivacyConsent
        ? l10n.guidePrivacyHelperRequireConsent
        : l10n.guidePrivacyHelperViewOnly;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        FTileGroup(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FTile(
              prefix: _GuideIconBadge(icon: Icons.school_rounded, filled: true),
              title: Text(
                widget.requirePrivacyConsent
                    ? l10n.guidePrivacyReadBeforeUse
                    : l10n.guidePrivacyViewOnly,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLanguageSelector(l10n),
        const SizedBox(height: 12),
        SettingsSectionCard(
          title: l10n.guidePrivacySectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.guidePrivacyParagraph1, style: typo.sm),
              const SizedBox(height: 8),
              Text(l10n.guidePrivacyParagraph2, style: typo.sm),
              const SizedBox(height: 8),
              Text(l10n.guidePrivacyParagraph3, style: typo.sm),
              const SizedBox(height: 8),
              Text(l10n.guidePrivacyParagraph4, style: typo.sm),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsSectionCard(
          title: l10n.guideRiskTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.guideRiskParagraph1, style: typo.sm),
              const SizedBox(height: 8),
              Text(l10n.guideRiskParagraph2, style: typo.sm),
              const SizedBox(height: 8),
              Text(l10n.guideRiskParagraph3, style: typo.sm),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsSectionCard(
          subtitle: helperText,
          child: Text(
            l10n.guideUmengPrivacyLink,
            style: typo.xs2.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ),
        if (widget.requirePrivacyConsent) ...[
          const SizedBox(height: 12),
          FCheckbox(
            leadingLabel: true,
            label: Text(l10n.guidePrivacyConsentLabel),
            semanticsLabel: l10n.guidePrivacyConsentLabel,
            value: _privacyChecked,
            onChange: (value) {
              setState(() {
                _privacyChecked = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPermissionsPage(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: FCircularProgress());
    }

    final items = _buildPermissionItems(l10n);
    final countableItems = items.where((item) => item.enabled != null).toList();
    final readyCount = countableItems
        .where((item) => item.enabled == true)
        .length;
    final progress = countableItems.isEmpty
        ? 0.0
        : readyCount / countableItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        FTileGroup(
          label: Text(l10n.guidePermissionsHeader),
          description: Text(l10n.guidePermissionsSubtitle),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FTile.raw(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$readyCount / ${countableItems.length} 已完成',
                            style: context.theme.typography.body.sm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: _refreshStatus,
                          prefix: const Icon(Icons.refresh, size: 18),
                          child: Text(l10n.refreshStatusTooltip),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FDeterminateProgress(value: progress),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FTileGroup(
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final item in items) _buildPermissionTile(item)],
        ),
        const SizedBox(height: 12),
        FAlert(
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
          title: Text(l10n.guidePermissionsFooterHint),
        ),
      ],
    );
  }

  List<_PermissionItem> _buildPermissionItems(AppLocalizations l10n) {
    return [
      _PermissionItem(
        icon: Icons.notifications_active_outlined,
        title: l10n.guideStatusNotificationPermission,
        enabled: _hasNotificationPermission,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(() async {
          await _service.requestNotificationPermission();
        }),
      ),
      _PermissionItem(
        icon: Icons.auto_awesome,
        title: l10n.guideStatusIslandSupport,
        enabled: _canPostPromoted,
        enabledLabel: l10n.guideStatusSystemAllowed,
        disabledLabel: _hasPromotedPermission
            ? l10n.guideStatusEnabledPending
            : l10n.guideStatusSuggestedCheck,
        onTap: () => _runAction(_service.openPromotedSettings),
      ),
      _PermissionItem(
        icon: Icons.play_circle_outline_rounded,
        title: l10n.quickActionAutoStartTitle,
        enabled: _isAutoStartEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAutoStartSettings),
      ),
      _PermissionItem(
        icon: Icons.battery_saver_outlined,
        title: l10n.guideStatusBatteryOptimization,
        enabled: _isIgnoringBatteryOptimizations,
        enabledLabel: l10n.guideStatusBatteryUnrestricted,
        disabledLabel: l10n.guideStatusBatteryRestricted,
        onTap: () => _runAction(_service.openBatteryOptimizationSettings),
      ),
      _PermissionItem(
        icon: Icons.accessibility_new_rounded,
        title: l10n.guideStatusKeepAlive,
        enabled: _isKeepAliveAccessibilityEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAccessibilitySettings),
      ),
    ];
  }

  FTile _buildPermissionTile(_PermissionItem item) {
    final colors = context.theme.colors;
    final enabled = item.enabled == true;
    final statusLabel = enabled ? item.enabledLabel : item.disabledLabel;

    return FTile(
      prefix: Icon(item.icon, color: colors.primary),
      title: Text(item.title),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FBadge(
            variant: enabled ? FBadgeVariant.secondary : FBadgeVariant.outline,
            child: Text(statusLabel),
          ),
          const SizedBox(width: 8),
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            size: 20,
            color: enabled ? colors.primary : colors.mutedForeground,
          ),
        ],
      ),
      onPress: item.onTap,
    );
  }

  Widget _buildTipsPage(AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.guideTipsHeader,
                style: typo.md.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.guideTipsSubtitle,
                style: typo.sm.copyWith(color: colors.mutedForeground),
              ),
            ],
          ),
        ),
        SettingsSectionCard(
          child: FAccordion(
            children: [
              FAccordionItem(
                title: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.guideShortNameAdviceTitle,
                        style: typo.sm.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.guideShortNameAdviceSubtitle, style: typo.sm),
                    const SizedBox(height: 10),
                    _buildShortNameExampleRow(
                      l10n.guideShortNameRecommended,
                      l10n.guideShortNameRecommendedExample,
                    ),
                    const SizedBox(height: 4),
                    _buildShortNameExampleRow(
                      l10n.guideShortNameNotRecommended,
                      l10n.guideShortNameNotRecommendedExample,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FButton(
                        variant: FButtonVariant.secondary,
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/courses/overview',
                              ),
                              builder: (_) => const CourseOverviewScreen(),
                            ),
                          );
                        },
                        prefix: const Icon(Icons.edit_outlined, size: 18),
                        child: Text(l10n.guideSetCourseShortNameAction),
                      ),
                    ),
                  ],
                ),
              ),
              FAccordionItem(
                title: Row(
                  children: [
                    Icon(Icons.import_export_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.guideImportMethodsTitle,
                        style: typo.sm.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.guideImportMethodsSubtitle, style: typo.sm),
                    const SizedBox(height: 10),
                    _buildNumberedLine('1', l10n.guideImportMethodStep1),
                    const SizedBox(height: 8),
                    _buildNumberedLine('2', l10n.guideImportMethodStep2),
                    const SizedBox(height: 8),
                    _buildNumberedLine('3', l10n.guideImportMethodStep3),
                    const SizedBox(height: 10),
                    Text(l10n.guideImportMethodExtra, style: typo.xs2),
                  ],
                ),
              ),
              FAccordionItem(
                title: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.guideFinalTipsTitle,
                        style: typo.sm.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.guideFinalTip1, style: typo.sm),
                    const SizedBox(height: 8),
                    Text(l10n.guideFinalTip2, style: typo.sm),
                    const SizedBox(height: 8),
                    Text(l10n.guideFinalTip3, style: typo.sm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShortNameExampleRow(String label, String example) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: context.theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(example, style: context.theme.typography.body.sm)),
      ],
    );
  }

  Widget _buildNumberedLine(String step, String text) {
    final colors = context.theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: colors.secondary,
          foregroundColor: colors.secondaryForeground,
          child: Text(
            step,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.theme.typography.body.sm)),
      ],
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    final colors = context.theme.colors;
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _totalPages - 1;
    final showPrev = !isFirstPage;
    final isPrivacyPage = widget.requirePrivacyConsent && _currentPage == 1;
    final canGoNext = !isPrivacyPage || _privacyChecked;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            if (isPrivacyPage)
              FButton(
                variant: FButtonVariant.ghost,
                onPress: _exitWithoutConsent,
                child: Text(l10n.exitAppAction),
              )
            else if (showPrev)
              FButton(
                variant: FButtonVariant.ghost,
                onPress: _goPrev,
                prefix: const Icon(Icons.arrow_back_rounded, size: 18),
                child: Text(l10n.guidePrevButton),
              )
            else
              const Spacer(),
            const Spacer(),
            if (!isLastPage)
              FButton(
                onPress: canGoNext ? _goNext : null,
                suffix: const Icon(Icons.arrow_forward_rounded, size: 18),
                child: Text(l10n.guideNextButton),
              )
            else
              FButton(
                onPress: _finishGuide,
                suffix: const Icon(Icons.check_rounded, size: 18),
                child: Text(
                  widget.requirePrivacyConsent
                      ? l10n.agreeAndStartAction
                      : l10n.startUsingAction,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _finishGuide() {
    if (widget.requirePrivacyConsent && !_privacyChecked) return;
    Navigator.of(
      context,
    ).pop(widget.requirePrivacyConsent ? GuideAction.startUsing : null);
  }

  Future<void> _exitWithoutConsent() async {
    try {
      await SystemNavigator.pop();
    } catch (_) {
      // Fall back to dismissing the route so the caller can keep the app blocked.
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(false);
  }
}

class _GuideIconBadge extends StatelessWidget {
  const _GuideIconBadge({required this.icon, this.filled = false});

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: filled ? colors.primary : colors.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 20,
        color: filled ? colors.primaryForeground : colors.primary,
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final String title;
  final bool? enabled;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback? onTap;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.enabledLabel,
    required this.disabledLabel,
    this.onTap,
  });
}
