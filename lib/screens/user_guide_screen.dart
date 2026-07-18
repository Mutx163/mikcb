import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../widgets/third_party_disclaimer_card.dart';
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
      child: HyperosSubpage(
        onBack: widget.requirePrivacyConsent
            ? null
            : () => Navigator.pop(context),
        prefixes: widget.requirePrivacyConsent ? const [] : null,
        suffixes: [
          FHeaderAction(
            icon: const Icon(Icons.refresh),
            semanticsLabel: l10n.refreshStatusTooltip,
            onPress: () => _refreshStatus(),
          ),
        ],
        title: Text(
          widget.requirePrivacyConsent
              ? l10n.firstUseGuideTitle
              : l10n.guideAndPermissionsTitle,
        ),
        headerExtension: _buildProgressBar(l10n),
        child: HyperosBlurredBodyInset(
          child: Column(
            children: [
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
                style: typo.xs2.copyWith(color: colors.mutedForeground),
              ),
              const SizedBox(width: 8),
              Text(
                _buildPageTitle(l10n),
                style: typo.xs2.copyWith(color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HyperosLinearProgress(value: (_currentPage + 1) / _totalPages),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosSectionLabel(text: l10n.languageSectionTitle),
        HyperosListGroup(
          children: [
            HyperosSelectTile<String>(
              label: l10n.languageModeLabel,
              items: buildLocaleMenuMap(context),
              value: normalizeLocaleTagForDropdown(
                provider.settings.appLocaleTag,
              ),
              onChanged: (value) {
                final next = provider.settings.copyWith(appLocaleTag: value);
                provider.updateTimetableSettings(next);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomePage(AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        HyperosCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.welcomeAppName, style: typo.sm),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                style: typo.sm.copyWith(color: colors.mutedForeground),
              ),
            ],
          ),
        ),
        const HyperosSectionGap(),
        ThirdPartyDisclaimerCard(text: l10n.thirdPartyDisclaimer),
        const HyperosSectionGap(),
        _buildLanguageSelector(l10n),
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            _GuideActionTile(
              icon: Icons.rocket_launch_rounded,
              title: l10n.startUsingTitle,
              subtitle: l10n.startUsingSubtitle,
              onTap: _goNext,
            ),
            if (widget.onImportCourses != null)
              _GuideActionTile(
                icon: Icons.file_upload_outlined,
                title: l10n.importTimetableTitle,
                subtitle: l10n.importTimetableSubtitle,
                onTap: () => _runWelcomeAction(widget.onImportCourses!),
              ),
            if (widget.onRestoreBackup != null)
              _GuideActionTile(
                icon: Icons.restore_page_rounded,
                title: l10n.restoreBackupTitle,
                subtitle: l10n.restoreBackupSubtitle,
                onTap: () => _runWelcomeAction(widget.onRestoreBackup!),
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

  /// Body copy matching about-page「项目定位」sheet ([AboutInfoSheetBody]).
  TextStyle _guideBodyStyle() {
    return HyperosTypography.listDetail(
      context,
    ).copyWith(color: HyperosColors.primaryText(context), height: 1.45);
  }

  /// Secondary / footnote body (same size as [_guideBodyStyle], muted ink).
  TextStyle _guideMutedBodyStyle() {
    return HyperosTypography.listDetail(context).copyWith(height: 1.45);
  }

  Widget _buildPrivacyPage(AppLocalizations l10n) {
    final bodyStyle = _guideBodyStyle();
    final mutedBodyStyle = _guideMutedBodyStyle();
    final helperText = widget.requirePrivacyConsent
        ? l10n.guidePrivacyHelperRequireConsent
        : l10n.guidePrivacyHelperViewOnly;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        HyperosListGroup(
          children: [
            Padding(
              padding: HyperosTokens.rowPaddingUniform,
              child: Row(
                children: [
                  _GuideIconBadge(icon: Icons.school_rounded, filled: true),
                  const SizedBox(width: HyperosTokens.rowContentGap),
                  Expanded(
                    child: Text(
                      widget.requirePrivacyConsent
                          ? l10n.guidePrivacyReadBeforeUse
                          : l10n.guidePrivacyViewOnly,
                      style: HyperosTypography.listTitle(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const HyperosSectionGap(),
        _buildLanguageSelector(l10n),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.guidePrivacySectionTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.guidePrivacyParagraph1, style: bodyStyle),
                const SizedBox(height: 8),
                Text(l10n.guidePrivacyParagraph2, style: bodyStyle),
                const SizedBox(height: 8),
                Text(l10n.guidePrivacyParagraph3, style: bodyStyle),
                const SizedBox(height: 8),
                Text(l10n.guidePrivacyParagraph4, style: bodyStyle),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.guideRiskTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.guideRiskParagraph1, style: bodyStyle),
                const SizedBox(height: 8),
                Text(l10n.guideRiskParagraph2, style: bodyStyle),
                const SizedBox(height: 8),
                Text(l10n.guideRiskParagraph3, style: bodyStyle),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          subtitle: helperText,
          child: HyperosControlCardInset(
            child: Text(l10n.guideUmengPrivacyLink, style: mutedBodyStyle),
          ),
        ),
        if (widget.requirePrivacyConsent) ...[
          const HyperosSectionGap(),
          HyperosCheckboxTile(
            title: l10n.guidePrivacyConsentLabel,
            value: _privacyChecked,
            onChanged: (value) {
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
      return const Center(child: HyperosCircularProgress());
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
        HyperosSectionLabel(text: l10n.guidePermissionsHeader),
        const SizedBox(height: 8),
        HyperosControlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.guidePermissionsSubtitle,
                style: HyperosTypography.listDetail(context),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.guidePermissionsProgressLabel(
                        readyCount,
                        countableItems.length,
                      ),
                      style: context.theme.typography.body.sm,
                    ),
                  ),
                  HyperosButton(
                    label: l10n.refreshStatusTooltip,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _refreshStatus,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              HyperosLinearProgress(value: progress),
            ],
          ),
        ),
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [for (final item in items) _buildPermissionTile(item)],
        ),
        const HyperosSectionGap(),
        HyperosHintBanner(
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

  Widget _buildPermissionTile(_PermissionItem item) {
    final colors = context.theme.colors;
    final enabled = item.enabled == true;
    final statusLabel = enabled ? item.enabledLabel : item.disabledLabel;

    return _GuidePermissionTile(
      icon: item.icon,
      title: item.title,
      statusLabel: statusLabel,
      enabled: enabled,
      onTap: item.onTap,
      enabledColor: colors.primary,
      disabledColor: colors.mutedForeground,
    );
  }

  Widget _buildTipsPage(AppLocalizations l10n) {
    final bodyStyle = _guideBodyStyle();
    final mutedBodyStyle = _guideMutedBodyStyle();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        HyperosSectionLabel(text: l10n.guideTipsHeader),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
          child: Text(l10n.guideTipsSubtitle, style: mutedBodyStyle),
        ),
        // 短名称建议卡片
        HyperosControlCard(
          title: l10n.guideShortNameAdviceTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.guideShortNameAdviceSubtitle, style: bodyStyle),
                const SizedBox(height: 12),
                _buildShortNameExampleRow(
                  l10n.guideShortNameRecommended,
                  l10n.guideShortNameRecommendedExample,
                ),
                const SizedBox(height: 6),
                _buildShortNameExampleRow(
                  l10n.guideShortNameNotRecommended,
                  l10n.guideShortNameNotRecommendedExample,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: HyperosButton(
                    label: l10n.guideSetCourseShortNameAction,
                    variant: HyperosButtonVariant.secondary,
                    expand: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        HyperosPageRoute(
                          settings: const RouteSettings(
                            name: '/courses/overview',
                          ),
                          builder: (_) => const CourseOverviewScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        // 导入方法卡片
        HyperosControlCard(
          title: l10n.guideImportMethodsTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.guideImportMethodsSubtitle, style: bodyStyle),
                const SizedBox(height: 12),
                _buildNumberedLine('1', l10n.guideImportMethodStep1),
                const SizedBox(height: 10),
                _buildNumberedLine('2', l10n.guideImportMethodStep2),
                const SizedBox(height: 10),
                _buildNumberedLine('3', l10n.guideImportMethodStep3),
                const SizedBox(height: 12),
                Text(l10n.guideImportMethodExtra, style: mutedBodyStyle),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        // 最终提示卡片
        HyperosControlCard(
          title: l10n.guideFinalTipsTitle,
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTipItem(Icons.check_circle_outline, l10n.guideFinalTip1),
                const SizedBox(height: 10),
                _buildTipItem(Icons.check_circle_outline, l10n.guideFinalTip2),
                const SizedBox(height: 10),
                _buildTipItem(Icons.check_circle_outline, l10n.guideFinalTip3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortNameExampleRow(String label, String example) {
    final bodyStyle = _guideBodyStyle();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label, style: bodyStyle)),
        Expanded(child: Text(example, style: bodyStyle)),
      ],
    );
  }

  Widget _buildNumberedLine(String step, String text) {
    final colors = context.theme.colors;
    final bodyStyle = _guideBodyStyle();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: TextStyle(fontSize: 11, color: colors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: bodyStyle)),
      ],
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    final colors = context.theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _guideBodyStyle())),
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
              HyperosButton(
                label: l10n.exitAppAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: _exitWithoutConsent,
              )
            else if (showPrev)
              HyperosButton(
                label: l10n.guidePrevButton,
                variant: HyperosButtonVariant.secondary,
                onPressed: _goPrev,
              )
            else
              const Spacer(),
            const Spacer(),
            if (!isLastPage)
              HyperosButton(
                label: l10n.guideNextButton,
                onPressed: canGoNext ? _goNext : null,
              )
            else
              HyperosButton(
                label: widget.requirePrivacyConsent
                    ? l10n.agreeAndStartAction
                    : l10n.startUsingAction,
                onPressed: _finishGuide,
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

EdgeInsets _guideChevronRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.chevronRowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

EdgeInsets _guideRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

class _GuideActionTile extends StatelessWidget {
  const _GuideActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: _guideChevronRowPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _GuideIconBadge(icon: icon),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HyperosTypography.listTitle(context)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: HyperosTypography.listDetail(context)),
                ],
              ),
            ),
            SizedBox(width: HyperosTokens.titleChevronGap),
            const HyperosChevron(),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

class _GuidePermissionTile extends StatelessWidget {
  const _GuidePermissionTile({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.enabled,
    required this.enabledColor,
    required this.disabledColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String statusLabel;
  final bool enabled;
  final Color enabledColor;
  final Color disabledColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: _guideRowPadding(context),
        child: Row(
          children: [
            Icon(icon, color: enabledColor),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Text(title, style: HyperosTypography.listTitle(context)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? enabledColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: enabled
                    ? null
                    : Border.all(color: disabledColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                statusLabel,
                style: HyperosTypography.listDetail(
                  context,
                ).copyWith(color: enabled ? enabledColor : disabledColor),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
              color: enabled ? enabledColor : disabledColor,
            ),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
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
