import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';

import '../services/miui_live_activities_service.dart';
import 'course_overview_screen.dart';

class UserGuideScreen extends StatefulWidget {
  final bool requirePrivacyConsent;
  final bool initialPrivacyChecked;

  const UserGuideScreen({
    super.key,
    this.requirePrivacyConsent = false,
    this.initialPrivacyChecked = false,
  });

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen>
    with WidgetsBindingObserver {
  final MiuiLiveActivitiesService _service = MiuiLiveActivitiesService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _isKeepAliveAccessibilityEnabled = false;
  bool _isNearBottom = false;
  late bool _privacyChecked;
  int _androidVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _privacyChecked = widget.initialPrivacyChecked;
    _scrollController.addListener(_handleScroll);
    _refreshStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus(showLoading: false));
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextValue = position.pixels >= position.maxScrollExtent - 48;
    if (nextValue != _isNearBottom) {
      setState(() {
        _isNearBottom = nextValue;
      });
    }
  }

  Future<void> _refreshStatus({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final promotedSupport = await _service.checkPromotedSupport();
    final hasNotificationPermission =
        await _service.checkNotificationPermission();
    final isIgnoringBatteryOptimizations =
        await _service.isIgnoringBatteryOptimizations();
    final isKeepAliveAccessibilityEnabled =
        await _service.isKeepAliveAccessibilityEnabled();

    if (!mounted) {
      return;
    }
    setState(() {
      _androidVersion = (promotedSupport['androidVersion'] as int?) ?? 0;
      _hasNotificationPermission =
          promotedSupport['hasNotificationPermission'] == true ||
              hasNotificationPermission;
      _hasPromotedPermission = promotedSupport['hasPromotedPermission'] == true;
      _canPostPromoted = promotedSupport['canPostPromoted'] == true;
      _isIgnoringBatteryOptimizations = isIgnoringBatteryOptimizations;
      _isKeepAliveAccessibilityEnabled = isKeepAliveAccessibilityEnabled;
      _isLoading = false;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      return;
    }
    await _refreshStatus(showLoading: false);
  }

  Future<void> _scrollMore() async {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = (_scrollController.offset + 420).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
        canPop: !widget.requirePrivacyConsent,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.requirePrivacyConsent,
            title: Text(
              widget.requirePrivacyConsent
                  ? l10n.firstUseGuideTitle
                  : l10n.guideAndPermissionsTitle,
            ),
            actions: [
              IconButton(
                tooltip: l10n.refreshStatusTooltip,
                onPressed: _refreshStatus,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildHeroCard(theme, l10n),
              const SizedBox(height: 16),
              _buildQuickActionsCard(theme, l10n),
              const SizedBox(height: 16),
              _buildStatusCard(theme),
              const SizedBox(height: 16),
              _buildPermissionChecklistCard(theme),
              const SizedBox(height: 16),
              _buildShortNameCard(theme),
              const SizedBox(height: 16),
              _buildImportGuideCard(theme),
              const SizedBox(height: 16),
              _buildPrivacyConsentCard(theme),
              const SizedBox(height: 16),
              _buildTipsCard(theme),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(theme, l10n),
        ));
  }

  Widget _buildHeroCard(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    final readyCount = [
      _hasNotificationPermission,
      _canPostPromoted,
      _isIgnoringBatteryOptimizations,
    ].where((item) => item).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.guideHeroTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.guideHeroSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(Icons.security_rounded, l10n.guideChipPermissions),
              _buildHeroChip(
                  Icons.system_update_alt_rounded, l10n.guideHyperOsChip),
              _buildHeroChip(Icons.edit_note_rounded, l10n.guideChipShortName),
              _buildHeroChip(Icons.import_export_rounded, l10n.guideChipImport),
              _buildHeroChip(
                Icons.check_circle_rounded,
                l10n.guideChipReadyCount(readyCount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_up_alt_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isNearBottom
                        ? l10n.guideBottomReachedHint
                        : l10n.guideScrollHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _runAction(() async {
                await _service.requestNotificationPermission();
              }),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.guideRequestNotificationFirst),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickSetupTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.quickSetupSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _buildQuickActionButton(
                  icon: Icons.notifications_outlined,
                  title: l10n.quickActionNotificationsTitle,
                  subtitle: l10n.quickActionNotificationsSubtitle,
                  onTap: () => _runAction(_service.openNotificationSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.star_border_rounded,
                  title: l10n.quickActionIslandTitle,
                  subtitle: l10n.quickActionIslandSubtitle,
                  onTap: () => _runAction(_service.openPromotedSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.play_circle_outline_rounded,
                  title: l10n.quickActionAutoStartTitle,
                  subtitle: l10n.quickActionAutoStartSubtitle,
                  onTap: () => _runAction(_service.openAutoStartSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.battery_saver_outlined,
                  title: l10n.quickActionBatteryTitle,
                  subtitle: l10n.quickActionBatterySubtitle,
                  onTap: () =>
                      _runAction(_service.openBatteryOptimizationSettings),
                ),
                _buildQuickActionButton(
                  icon: Icons.accessibility_new_rounded,
                  title: l10n.quickActionKeepAliveTitle,
                  subtitle: l10n.quickActionKeepAliveSubtitle,
                  onTap: () => _runAction(_service.openAccessibilitySettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guideStatusTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildStatusTile(
                icon: Icons.notifications_active_outlined,
                title: l10n.guideStatusNotificationPermission,
                value: _hasNotificationPermission ? l10n.guideStatusEnabled : l10n.guideStatusDisabled,
                success: _hasNotificationPermission,
              ),
              _buildStatusTile(
                icon: Icons.auto_awesome,
                title: l10n.guideStatusIslandSupport,
                value: _canPostPromoted
                    ? l10n.guideStatusSystemAllowed
                    : (_hasPromotedPermission ? l10n.guideStatusEnabledPending : l10n.guideStatusSuggestedCheck),
                success: _canPostPromoted,
              ),
              _buildStatusTile(
                icon: Icons.battery_charging_full_outlined,
                title: l10n.guideStatusBatteryOptimization,
                value: _isIgnoringBatteryOptimizations ? l10n.guideStatusBatteryUnrestricted : l10n.guideStatusBatteryRestricted,
                success: _isIgnoringBatteryOptimizations,
              ),
              _buildStatusTile(
                icon: Icons.accessibility_new_rounded,
                title: l10n.guideStatusKeepAlive,
                value: _isKeepAliveAccessibilityEnabled ? l10n.guideStatusEnabled : l10n.guideStatusDisabled,
                success: _isKeepAliveAccessibilityEnabled,
              ),
              _buildStatusTile(
                icon: Icons.phone_android_outlined,
                title: l10n.guideStatusAndroidVersion,
                value: _androidVersion > 0 ? 'Android $_androidVersion' : l10n.guideStatusVersionUnknown,
                success: _androidVersion >= 13,
              ),
              _buildStatusTile(
                icon: Icons.star_border_rounded,
                title: l10n.guideStatusIslandSystemSupport,
                value: l10n.guideStatusIslandSystemRequirement,
                success: _canPostPromoted,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.guideStatusIslandHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionChecklistCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guidePermissionChecklistTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guidePermissionChecklistSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildChecklistTile(
              step: '1',
              icon: Icons.notifications_outlined,
              title: l10n.guideChecklistRequestNotificationTitle,
              subtitle: l10n.guideChecklistRequestNotificationSubtitle,
              onTap: () => _runAction(() async {
                await _service.requestNotificationPermission();
              }),
            ),
            _buildChecklistTile(
              step: '2',
              icon: Icons.tune,
              title: l10n.guideChecklistOpenNotificationTitle,
              subtitle: l10n.guideChecklistOpenNotificationSubtitle,
              onTap: () => _runAction(_service.openNotificationSettings),
            ),
            _buildChecklistTile(
              step: '3',
              icon: Icons.star_border,
              title: l10n.guideChecklistOpenIslandTitle,
              subtitle: l10n.guideChecklistOpenIslandSubtitle,
              onTap: () => _runAction(_service.openPromotedSettings),
            ),
            _buildChecklistTile(
              step: '4',
              icon: Icons.play_circle_outline,
              title: l10n.guideChecklistOpenAutoStartTitle,
              subtitle: l10n.guideChecklistOpenAutoStartSubtitle,
              onTap: () => _runAction(_service.openAutoStartSettings),
            ),
            _buildChecklistTile(
              step: '5',
              icon: Icons.battery_saver_outlined,
              title: l10n.guideChecklistOpenBatteryTitle,
              subtitle: l10n.guideChecklistOpenBatterySubtitle,
              onTap: () => _runAction(_service.openBatteryOptimizationSettings),
            ),
            _buildChecklistTile(
              step: '6',
              icon: Icons.accessibility_new_rounded,
              title: l10n.guideChecklistOpenKeepAliveTitle,
              subtitle: l10n.guideChecklistOpenKeepAliveSubtitle,
              onTap: () => _runAction(_service.openAccessibilitySettings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortNameCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guideShortNameAdviceTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guideShortNameAdviceSubtitle,
            ),
            const SizedBox(height: 12),
            _buildTipLine(l10n.guideShortNameRecommended, l10n.guideShortNameRecommendedExample),
            const SizedBox(height: 6),
            _buildTipLine(l10n.guideShortNameNotRecommended, l10n.guideShortNameNotRecommendedExample),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/courses/overview'),
                      builder: (_) => const CourseOverviewScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.guideSetCourseShortNameAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportGuideCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guideImportMethodsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guideImportMethodsSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildNumberedLine(
              '1',
              l10n.guideImportMethodStep1,
            ),
            const SizedBox(height: 8),
            _buildNumberedLine(
              '2',
              l10n.guideImportMethodStep2,
            ),
            const SizedBox(height: 8),
            _buildNumberedLine(
              '3',
              l10n.guideImportMethodStep3,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.guideImportMethodExtra,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guideFinalTipsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.guideFinalTip1,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guideFinalTip2,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guideFinalTip3,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyConsentCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final helperText = widget.requirePrivacyConsent
        ? l10n.guidePrivacyHelperRequireConsent
        : l10n.guidePrivacyHelperViewOnly;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.guidePrivacySectionTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.guidePrivacyParagraph1,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guidePrivacyParagraph2,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guidePrivacyParagraph3,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.guidePrivacyParagraph4,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.guideRiskTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.guideRiskParagraph1,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.guideRiskParagraph2,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.guideRiskParagraph3,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helperText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.guideUmengPrivacyLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.requirePrivacyConsent) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _privacyChecked = !_privacyChecked;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _privacyChecked,
                        onChanged: (value) {
                          setState(() {
                            _privacyChecked = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          l10n.guidePrivacyConsentLabel,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (widget.requirePrivacyConsent)
                  TextButton(
                    onPressed: _exitWithoutConsent,
                    child: Text(l10n.exitAppAction),
                  ),
                if (widget.requirePrivacyConsent) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.requirePrivacyConsent
                        ? l10n.guideRequireConsentHint
                        : l10n.guideContinueHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!_isNearBottom)
                  FilledButton.icon(
                    onPressed: _scrollMore,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    label: Text(l10n.continueReadingAction),
                  )
                else
                  FilledButton.icon(
                    onPressed: widget.requirePrivacyConsent
                        ? (_privacyChecked
                            ? () => Navigator.of(context).pop(true)
                            : null)
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      widget.requirePrivacyConsent
                          ? l10n.agreeAndStartAction
                          : l10n.startUsingAction,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildHeroChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistTile({
    required String step,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                child: Text(
                  step,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String value,
    required bool success,
  }) {
    final color = success ? Colors.green.shade700 : Colors.orange.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildNumberedLine(String step, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            step,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
