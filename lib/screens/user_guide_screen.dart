import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import 'course_overview_screen.dart';
import 'timetable_settings_screen.dart';

enum GuideAction {
  startUsing,
  importCourses,
  restoreBackup,
}

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
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus(showLoading: false));
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
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      return;
    }
    await _refreshStatus(showLoading: false);
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
    // If consent is required and the user swiped past the privacy page
    // without checking the checkbox, snap back.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        body: Column(
          children: [
            _buildProgressBar(theme, l10n, colorScheme),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _buildWelcomePage(theme, l10n, colorScheme),
                  _buildPrivacyPage(theme, l10n),
                  _buildPermissionsPage(theme, l10n, colorScheme),
                  _buildTipsPage(theme, l10n, colorScheme),
                ],
              ),
            ),
            _buildBottomBar(theme, l10n, colorScheme),
          ],
        ),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────

  Widget _buildProgressBar(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_currentPage + 1} / $_totalPages',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _buildPageTitle(l10n),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
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

 // ── Language selector ────────────────────────────────────────

  List<DropdownMenuItem<String>> buildLocaleDropdownItems(
    BuildContext context,
  ) {
    final map = buildLocaleMenuMap(context);
    return map.entries
        .map(
          (e) => DropdownMenuItem<String>(
            value: e.value,
            child: Text(e.key),
          ),
        )
        .toList();
  }

  Widget _buildLanguageSelector(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final provider = context.read<TimetableProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final currentTag =
        normalizeLocaleTagForDropdown(provider.settings.appLocaleTag);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.language_rounded, color: colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.languageSectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.languageSectionSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: DropdownButton<String>(
              value: currentTag,
              isExpanded: true,
              items: buildLocaleDropdownItems(context),
              onChanged: (value) {
                if (value == null) return;
                final next =
                    provider.settings.copyWith(appLocaleTag: value);
                provider.updateTimetableSettings(next);
              },
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox.shrink(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Welcome ─────────────────────────────────────────

  Widget _buildWelcomePage(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // App branding
        Container(
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
              Text(
                l10n.welcomeAppName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Language selector
        _buildLanguageSelector(theme, l10n, colorScheme),
        const SizedBox(height: 20),
        // Action tiles
        _WelcomeActionTile(
          icon: Icons.rocket_launch_rounded,
          title: l10n.startUsingTitle,
          subtitle: l10n.startUsingSubtitle,
          onTap: _goNext,
        ),
        const SizedBox(height: 12),
        if (widget.onImportCourses != null) ...[
          _WelcomeActionTile(
            icon: Icons.file_upload_outlined,
            title: l10n.importTimetableTitle,
            subtitle: l10n.importTimetableSubtitle,
            onTap: () => _runWelcomeAction(widget.onImportCourses!),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.onRestoreBackup != null) ...[
          _WelcomeActionTile(
            icon: Icons.restore_page_rounded,
            title: l10n.restoreBackupTitle,
            subtitle: l10n.restoreBackupSubtitle,
            onTap: () => _runWelcomeAction(widget.onRestoreBackup!),
          ),
        ],
      ],
    );
  }

  Future<void> _runWelcomeAction(Future<bool> Function() action) async {
    final imported = await action();
    if (imported && mounted) {
      Navigator.of(context).pop(GuideAction.importCourses);
    }
  }

  // ── Page 2: Privacy consent ──────────────────────────────────

  Widget _buildPrivacyPage(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    final helperText = widget.requirePrivacyConsent
        ? l10n.guidePrivacyHelperRequireConsent
        : l10n.guidePrivacyHelperViewOnly;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.school_rounded, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.requirePrivacyConsent
                    ? l10n.guidePrivacyReadBeforeUse
                    : l10n.guidePrivacyViewOnly,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Language selector
        _buildLanguageSelector(theme, l10n, colorScheme),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
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
                width: double.infinity,
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
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant),
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
        if (widget.requirePrivacyConsent) ...[
          const SizedBox(height: 16),
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
        ],
      ],
    );
  }

  // ── Page 2: Permissions ──────────────────────────────────────

  Widget _buildPermissionsPage(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _buildPermissionItems(l10n, colorScheme);
    final countableItems = items.where((item) => item.enabled != null).toList();
    final readyCount = countableItems
        .where((item) => item.enabled == true)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            l10n.guidePermissionsHeader,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.guidePermissionsSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$readyCount / ${countableItems.length} 已完成',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: countableItems.isEmpty
                              ? 0.0
                              : readyCount / countableItems.length,
                          minHeight: 6,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _refreshStatus,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.refreshStatusTooltip),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Permission list
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colorScheme.outlineVariant,
                      ),
                    _buildPermissionRow(item, colorScheme),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.guidePermissionsFooterHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_PermissionItem> _buildPermissionItems(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return [
      _PermissionItem(
        icon: Icons.notifications_active_outlined,
        iconColor: Colors.blue,
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
        iconColor: Colors.amber.shade700,
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
        iconColor: Colors.green.shade700,
        title: l10n.quickActionAutoStartTitle,
        enabled: _isAutoStartEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAutoStartSettings),
      ),
      _PermissionItem(
        icon: Icons.battery_saver_outlined,
        iconColor: Colors.orange.shade700,
        title: l10n.guideStatusBatteryOptimization,
        enabled: _isIgnoringBatteryOptimizations,
        enabledLabel: l10n.guideStatusBatteryUnrestricted,
        disabledLabel: l10n.guideStatusBatteryRestricted,
        onTap: () => _runAction(_service.openBatteryOptimizationSettings),
      ),
      _PermissionItem(
        icon: Icons.accessibility_new_rounded,
        iconColor: Colors.purple,
        title: l10n.guideStatusKeepAlive,
        enabled: _isKeepAliveAccessibilityEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAccessibilitySettings),
      ),
    ];
  }

  Widget _buildPermissionRow(_PermissionItem item, ColorScheme colorScheme) {
    final statusColor = item.enabled == null
        ? colorScheme.onSurfaceVariant
        : item.enabled!
        ? Colors.green.shade700
        : Colors.orange.shade700;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, color: item.iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.enabled == true ? item.enabledLabel : item.disabledLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            if (item.onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                item.enabled == true
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: item.enabled == true
                    ? Colors.green.shade700
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Page 3: Tips ────────────────────────────────────────────

  Widget _buildTipsPage(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text(
          l10n.guideTipsHeader,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.guideTipsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Short name
        _buildTipTile(
          theme: theme,
          colorScheme: colorScheme,
          icon: Icons.edit_note_rounded,
          title: l10n.guideShortNameAdviceTitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.guideShortNameAdviceSubtitle),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      l10n.guideShortNameRecommended,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(l10n.guideShortNameRecommendedExample)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      l10n.guideShortNameNotRecommended,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(l10n.guideShortNameNotRecommendedExample),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
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
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.guideSetCourseShortNameAction),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Import guide
        _buildTipTile(
          theme: theme,
          colorScheme: colorScheme,
          icon: Icons.import_export_rounded,
          title: l10n.guideImportMethodsTitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.guideImportMethodsSubtitle),
              const SizedBox(height: 10),
              _buildNumberedLine('1', l10n.guideImportMethodStep1),
              const SizedBox(height: 8),
              _buildNumberedLine('2', l10n.guideImportMethodStep2),
              const SizedBox(height: 8),
              _buildNumberedLine('3', l10n.guideImportMethodStep3),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.guideImportMethodExtra,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Final tips
        _buildTipTile(
          theme: theme,
          colorScheme: colorScheme,
          icon: Icons.tips_and_updates_rounded,
          title: l10n.guideFinalTipsTitle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.guideFinalTip1),
              const SizedBox(height: 8),
              Text(l10n.guideFinalTip2),
              const SizedBox(height: 8),
              Text(l10n.guideFinalTip3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipTile({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [body],
      ),
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

  // ── Bottom navigation bar ────────────────────────────────────

  Widget _buildBottomBar(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
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
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            // Left button
            if (isPrivacyPage)
              TextButton(
                onPressed: _exitWithoutConsent,
                child: Text(l10n.exitAppAction),
              )
            else if (showPrev)
              TextButton.icon(
                onPressed: _goPrev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(l10n.guidePrevButton),
              )
            else
              const Spacer(),

            const Spacer(),

            // Right button
            if (!isLastPage)
              FilledButton.icon(
                onPressed: canGoNext ? _goNext : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(l10n.guideNextButton),
              )
            else
              FilledButton.icon(
                onPressed: _finishGuide,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
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
    Navigator.of(context).pop(
      widget.requirePrivacyConsent ? GuideAction.startUsing : null,
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
}

class _WelcomeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WelcomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool? enabled;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback? onTap;

  const _PermissionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.enabled,
    required this.enabledLabel,
    required this.disabledLabel,
    this.onTap,
  });
}
