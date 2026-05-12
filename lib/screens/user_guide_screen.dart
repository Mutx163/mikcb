import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _isKeepAliveAccessibilityEnabled = false;
  late bool _privacyChecked;

  bool get _showPrivacyPage => widget.requirePrivacyConsent;

  int get _totalPages => _showPrivacyPage ? 3 : 2;

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

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
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

  int get _permissionReadyCount => [
        _hasNotificationPermission,
        _canPostPromoted,
        _isIgnoringBatteryOptimizations,
        _isKeepAliveAccessibilityEnabled,
      ].where((item) => item).length;

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
            _buildProgressBar(theme, colorScheme),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  if (_showPrivacyPage) _buildPrivacyPage(theme, l10n),
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

  Widget _buildProgressBar(ThemeData theme, ColorScheme colorScheme) {
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
                _buildPageTitle(),
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

  String _buildPageTitle() {
    // No l10n needed for these short labels
    if (_showPrivacyPage && _currentPage == 0) return '隐私协议';
    if ((_showPrivacyPage && _currentPage == 1) ||
        (!_showPrivacyPage && _currentPage == 0)) {
      return '系统权限';
    }
    return '使用技巧';
  }

  // ── Page 1: Privacy consent ──────────────────────────────────

  Widget _buildPrivacyPage(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Minimal welcome
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school_rounded,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '使用前请阅读并同意以下内容',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Expandable privacy full text
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            title: Text(
              '隐私协议、第三方 SDK 与免责说明',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              const Divider(),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
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
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.guideRiskParagraph2,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.guideRiskParagraph3,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.guideUmengPrivacyLink,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Privacy checkbox
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

    final readyCount = _permissionReadyCount;
    final items = _buildPermissionItems(l10n, colorScheme);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            '系统权限设置',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '完成这些设置，超级岛和提醒才能正常使用',
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
                        '$readyCount / ${items.length} 已完成',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: items.isEmpty
                              ? 0.0
                              : readyCount / items.length,
                          minHeight: 6,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
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
                    '每项点击后跳转到系统设置，设置完成后返回应用，状态会自动刷新',
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
        enabled: _isKeepAliveAccessibilityEnabled && _isIgnoringBatteryOptimizations
            ? true
            : false,
        enabledLabel: '已开启',
        disabledLabel: '建议开启',
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

  Widget _buildPermissionRow(
    _PermissionItem item,
    ColorScheme colorScheme,
  ) {
    final statusColor = item.enabled ? Colors.green.shade700 : Colors.orange.shade700;
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
                item.enabled ? item.enabledLabel : item.disabledLabel,
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
                item.enabled ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: item.enabled ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
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
          '使用技巧',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '这些随时可以在「设置」里找到',
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
                  Expanded(child: Text(l10n.guideShortNameNotRecommendedExample)),
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
                        settings: const RouteSettings(name: '/courses/overview'),
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
    final isPrivacyPage = _showPrivacyPage && isFirstPage;
    final canGoNext = !isPrivacyPage || _privacyChecked;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
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
                label: Text('上一步'),
              )
            else
              const Spacer(),

            const Spacer(),

            // Right button
            if (!isLastPage)
              FilledButton.icon(
                onPressed: canGoNext ? _goNext : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text('下一步'),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
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

class _PermissionItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool enabled;
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
