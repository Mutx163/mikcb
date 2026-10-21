import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/glass_mode_choice.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/hex_color.dart';
import '../services/miui_live_activities_service.dart';
import '../widgets/third_party_disclaimer_card.dart';
import 'course_overview_screen.dart';
import 'settings/settings_shared.dart';

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

  /// 自有的折叠行为对象：大标题的收缩状态**跟着当前页走**。外壳共享一份
  /// behavior 时，横向切页不产生纵向通知，上一页滚出的「小字」会带进新页
  /// （2026-10-21 用户真机反馈的两条：切页后延迟一秒弹大字、切回滚过的页
  /// 却是大字）。自持 behavior 后由本页在 [_onPageChanged] 里按新页的
  /// 滚动位置立刻设对，外壳的自动重置（只对它自建的 behavior）跳过。
  final HyperosExitUntilCollapsedScrollBehavior _collapseBehavior =
      HyperosExitUntilCollapsedScrollBehavior(requireOuterScrollable: false);

  /// 每页最近一次滚动时记录的折叠偏移（只有**当前页**会滚，记录即准确）。
  /// 切页时按它恢复标题状态：顶部的页 → 大字，滚过的页 → 小字。
  final Map<int, double> _lastCollapseOffsetByPage = {};

  bool _isLoading = true;
  bool _hasNotificationPermission = false;
  bool _hasPromotedPermission = false;
  bool _canPostPromoted = false;
  bool _isIgnoringBatteryOptimizations = false;
  bool _isKeepAliveAccessibilityEnabled = false;
  bool _isAutoStartEnabled = false;
  bool _hasDoNotDisturbAccess = false;
  late bool _privacyChecked;
  Timer? _settingsPollTimer;

  /// 欢迎 · 隐私 · 权限 · 个性化定制 · 使用技巧。
  int get _totalPages => 5;

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
      _hasDoNotDisturbAccess,
    ].join(',');
  }

  void _startSettingsStatusPoll({required String baselineKey}) {
    _settingsPollTimer?.cancel();
    var ticks = 0;
    var refreshInFlight = false;
    _settingsPollTimer = Timer.periodic(const Duration(milliseconds: 450), (
      timer,
    ) async {
      ticks++;
      if (!mounted || ticks > 30) {
        timer.cancel();
        return;
      }
      // 回调是 async：_refreshStatus 超过 450ms 时跳过本轮，避免轮询
      // 重叠造成状态抖动。
      if (refreshInFlight) {
        return;
      }
      refreshInFlight = true;
      try {
        await _refreshStatus(showLoading: false);
      } finally {
        refreshInFlight = false;
      }
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
    final hasDoNotDisturbAccess = await _service.isDoNotDisturbAccessGranted();

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
      _hasDoNotDisturbAccess = hasDoNotDisturbAccess;
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
    if (!mounted || !_pageController.hasClients) {
      return;
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: 300.scaledMs,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 纵向滚动经过本监听（只有**当前页**会滚），把它的折叠偏移记下来；
  /// 返回 false 继续冒泡，外壳的磨砂/折叠处理照常。
  bool _handleActivePageScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final metrics = notification.metrics;
      final scrolled = metrics.pixels - metrics.minScrollExtent;
      // 与外壳 _syncOffsetToPosition 同一套推导：向上滚 → 折叠（负值），
      // 顶部/回弹 → 0（展开）。
      _lastCollapseOffsetByPage[_currentPage] = scrolled <= 0
          ? 0.0
          : -scrolled;
    }
    return false;
  }

  /// 换页：标题状态**立刻**换成新页该有的样子——顶部的页大字、滚过的页
  /// 小字（2026-10-21 用户反馈：切页后延迟一秒才弹大字、切回滚过的页
  /// 却是大字）。先清行为对象里锚在旧页坐标上的残留锁，再按记录的偏移
  /// 设值；没有记录（首次到这页）即展开。
  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _collapseBehavior.resetToExpanded();
    final offset = _lastCollapseOffsetByPage[page] ?? 0.0;
    if (offset < 0) {
      _collapseBehavior.state.heightOffset = offset;
    }
  }

  void _goPrev() {
    if (!mounted || !_pageController.hasClients) {
      return;
    }
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: 300.scaledMs,
        curve: Curves.easeOutCubic,
      );
    }
  }

  String normalizeLocaleTagForDropdown(String? tag) {
    if (tag == null || tag.isEmpty) return '';
    return tag.replaceAll('_', '-');
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
            onPress: _refreshStatus,
          ),
        ],
        title: Text(_buildPageTitle(l10n)),
        collapsibleScrollBehavior: _collapseBehavior,
        bottomBar: _buildBottomBar(l10n),
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleActivePageScroll,
          child: PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: _onPageChanged,
            children: _guidePages(l10n),
          ),
        ),
      ),
    );
  }

  /// Pages mounted in the [PageView]. Before privacy consent the guide ends
  /// at the privacy page: later pages stay unmounted, so a forward swipe dies
  /// at a real scroll boundary (native clamp, no snap-back) instead of
  /// overshooting into pages it would have to bounce out of.
  List<Widget> _guidePages(AppLocalizations l10n) {
    if (!widget.requirePrivacyConsent || _privacyChecked) {
      return [
        _buildWelcomePage(l10n),
        _buildPrivacyPage(l10n),
        _buildPermissionsPage(l10n),
        _buildPersonalizePage(l10n),
        _buildTipsPage(l10n),
      ];
    }
    return [_buildWelcomePage(l10n), _buildPrivacyPage(l10n)];
  }

  /// 分页圆点：底栏内与翻页按钮同一行，**整屏水平居中**（Stack 对齐），
  /// 尺寸 8dp、间距 8dp。
  ///
  /// 位置沿革：曾在顶栏（2026-10-20 首版，Baymard 点名「放顶部是无理由引入
  /// 摩擦」）→ 移到底栏独占一行（研究结论：底部居中是移动端惯例）→
  /// 并进按钮行但用 Row+Spacer（在首页向左偏半个按钮宽）→ 2026-10-21
  /// 改 Stack 整屏居中（用户反馈：第一步时圆点不在左右居中）。
  ///
  /// 另两条依据（Baymard《Page Control UI》）：
  /// - **尺寸**：圆点直径至少 8–10px，间距不小于直径——太小的点是低质量
  ///   实现的典型症状；
  /// - **状态区分不能只靠颜色**：当前页用主色、其余淡灰，色盲用户也分得清。
  ///
  /// 5 个点落在 3–7 的舒适区，数量没问题。
  Widget _buildPageDots() {
    final primary = HyperosColors.primary(context);
    final inactive = HyperosColors.secondaryText(context).withValues(alpha: 0.3);
    // 页码语义由圆点整组承担（Semantics label）：顶栏曾有一行「3 / 5」文字
    // 承担它，2026-10-21 随大标题页名化一并删去（位置孤悬左上、且与圆点
    // 重复），读屏的位置播报就落到这里——label 数字语言中立，不新增 l10n 键。
    return Semantics(
      label: '${_currentPage + 1} / $_totalPages',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _totalPages; i++)
              Padding(
                // 间距 8：不小于圆点直径（规范要求）。
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  // 时长走统一换算（scaledMs）跟随「页面转场速度」设置。
                  duration: 200.scaledMs,
                  curve: Curves.easeOut,
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage ? primary : inactive,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildPageTitle(AppLocalizations l10n) {
    if (_currentPage == 0) return l10n.welcomeTitle;
    if (_currentPage == 1) return l10n.guidePrivacyPageTitle;
    if (_currentPage == 2) return l10n.guidePermissionsPageTitle;
    if (_currentPage == 3) return l10n.guidePersonalizePageTitle;
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
              onChanged: (value) async {
                final next = provider.settings.copyWith(appLocaleTag: value);
                // 同 `_persistSettings`：这里原先既不 await 也不 catch，
                // 落盘失败时语言选择静默回弹。
                await _persistSettings(provider, next);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 标准列表容器：组件库 [HyperosListView] 自带折叠顶栏 inset（与旧手写
  /// 的 headerInset+8 首屏让位完全等价），滚动时行内容仍从磨砂栏下穿过；
  /// 横向翻页边界由 PageView 自身的 ClampingScrollPhysics 负责，与纵向
  /// 列表物理解耦。五个引导页共享同一条 ModalRoute，若都落到路由级默认
  /// key，PageStorage 会互相恢复彼此的滚动偏移——每页必须传独立 storageId。
  Widget _buildGuideList({
    required String storageId,
    required List<Widget> children,
  }) {
    return HyperosListView(
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      pageStorageKey: PageStorageKey<String>('user-guide-$storageId'),
    );
  }

  Widget _buildWelcomePage(AppLocalizations l10n) {
    return _buildGuideList(
      storageId: 'welcome',
      children: [
        HyperosCard(
          // 与库默认（16）同节奏：欢迎卡不再单养 20 的内边距。
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.welcomeAppName,
                style: HyperosTypography.title(context),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                style: HyperosTypography.listDetail(context),
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
              // 不再配副标题：原「直接进入软件，并继续完成首次使用说明」与实际
              // 行为不符（本行只是翻到下一页隐私页），且属于说两遍的填充文字。
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
    if (widget.requirePrivacyConsent && !_privacyChecked) {
      // Must accept privacy before import/restore can complete onboarding.
      if (mounted && _pageController.hasClients) {
        await _pageController.animateToPage(
          1,
          duration: 280.scaledMs,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
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

    return _buildGuideList(
      storageId: 'privacy',
      children: [
        HyperosListGroup(
          children: [
            Padding(
              padding: HyperosTokens.rowPaddingUniform,
              child: Row(
                children: [
                  const _GuideIconBadge(icon: Icons.school_rounded),
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

    return _buildGuideList(
      storageId: 'permissions',
      children: [
        // 不画分组标签：顶栏页标题已经是「系统权限」，同一屏再写一次
        // 「系统权限设置」纯属重复（用户反馈）。列表直接开在下面。
        // 摘要卡：副标题 + 就绪计数 + 进度条。刷新入口只保留顶栏
        // action——从系统设置返回本页时生命周期与轮询会自动刷新，
        // 卡内不再重复放一颗 secondary 按钮。
        HyperosControlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.guidePermissionsSubtitle,
                style: HyperosTypography.listDetail(context),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.guidePermissionsProgressLabel(
                  readyCount,
                  countableItems.length,
                ),
                style: HyperosTypography.listTitle(context),
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
        accent: HyperosIconColors.blue,
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
        accent: HyperosIconColors.purple,
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
        accent: HyperosIconColors.green,
        title: l10n.quickActionAutoStartTitle,
        enabled: _isAutoStartEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAutoStartSettings),
      ),
      _PermissionItem(
        icon: Icons.battery_saver_outlined,
        accent: HyperosIconColors.teal,
        title: l10n.guideStatusBatteryOptimization,
        enabled: _isIgnoringBatteryOptimizations,
        enabledLabel: l10n.guideStatusBatteryUnrestricted,
        disabledLabel: l10n.guideStatusBatteryRestricted,
        onTap: () => _runAction(_service.openBatteryOptimizationSettings),
      ),
      _PermissionItem(
        icon: Icons.accessibility_new_rounded,
        accent: HyperosIconColors.orange,
        title: l10n.guideStatusKeepAlive,
        enabled: _isKeepAliveAccessibilityEnabled,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openAccessibilitySettings),
      ),
      // 勿扰权限原先没有任何入口：用户只能在点了课前通知上的静音/免打扰
      // 按钮、什么都没发生之后，才从 Toast 里知道还缺这项授权。
      _PermissionItem(
        icon: Icons.do_not_disturb_on_outlined,
        accent: HyperosIconColors.indigo,
        title: l10n.guideStatusDoNotDisturbAccess,
        subtitle: l10n.guideStatusDoNotDisturbAccessHint,
        enabled: _hasDoNotDisturbAccess,
        enabledLabel: l10n.guideStatusEnabled,
        disabledLabel: l10n.guideStatusDisabled,
        onTap: () => _runAction(_service.openDoNotDisturbAccessSettings),
      ),
    ];
  }

  Widget _buildPermissionTile(_PermissionItem item) {
    // HyperOS 设置行范式：彩底圆角方徽章 + 标题 + 右侧灰色状态字 + 细
    // chevron（同系统权限管理）。状态不再用自绘描边胶囊表达，避免与
    // 尾部勾/箭头形成双重状态指示器。
    final subtitle = item.subtitle;
    return HyperosListTile(
      icon: item.icon,
      iconAccent: item.accent,
      title: item.title,
      subtitle: subtitle,
      details: item.enabled == true ? item.enabledLabel : item.disabledLabel,
      onTap: item.onTap,
    );
  }

  /// 个性化定制页：首次进入引导时即可选择默认材质、深浅色与主题色。
  /// 所有选择直接写入 [TimetableProvider] 并立即生效，之后仍可在
  /// 「设置 → 外观」中修改。选项行 / 分段 / 色板全部使用组件库现成
  /// 组件（HyperosChoiceTile 单选行、HyperosTabRow 分段、HyperOS 色板）。
  Widget _buildPersonalizePage(AppLocalizations l10n) {
    final provider = context.watch<TimetableProvider?>();
    // 与欢迎页语言选择器同策略：Provider 不在树上（裸测试宿主）时整页隐藏。
    if (provider == null) return const SizedBox.shrink();
    final settings = provider.settings;
    final currentEffect = glassModeChoiceOf(settings);

    return _buildGuideList(
      storageId: 'personalize',
      children: [
        // 菜单样式卡：8833fcd 八宫格唯一化时随设置收敛移除；应用户要求
        // 与「首页与导航」的菜单形态选择器一同恢复。
        HyperosControlCard(
          title: l10n.guidePersonalizeMenuStyleTitle,
          child: HyperosControlCardInset(
            child: Column(
              children: [
                _guideOptionRow(
                  context,
                  title: l10n.homeMenuStyleList,
                  summary: l10n.homeMenuStyleListSubtitle,
                  selected: settings.homeMenuStyle == HomeMenuStyle.list,
                  // showDivider 画在该行下方：画在首行才是两选项之间。
                  showDivider: true,
                  onTap: () => _updateSettings(
                    _currentSettings.copyWith(
                      homeMenuStyle: HomeMenuStyle.list,
                    ),
                  ),
                ),
                _guideOptionRow(
                  context,
                  title: l10n.homeMenuStyleGrid,
                  summary: l10n.homeMenuStyleGridSubtitle,
                  selected: settings.homeMenuStyle == HomeMenuStyle.grid,
                  onTap: () => _updateSettings(
                    _currentSettings.copyWith(
                      homeMenuStyle: HomeMenuStyle.grid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.frostedGlassModeLabel,
          child: HyperosControlCardInset(
            child: Column(
              children: [
                for (final (index, effect) in _guideVisualEffectOptions.indexed)
                  _guideOptionRow(
                    context,
                    title: _guideVisualEffectLabel(l10n, effect),
                    summary: _guideVisualEffectDescription(l10n, effect),
                    selected: currentEffect == effect,
                    // showDivider 画在该行下方：末行不画，否则三档只有
                    // 两条线且最后一条悬在卡片底边。
                    showDivider: index < _guideVisualEffectOptions.length - 1,
                    onTap: () => _applyVisualEffect(effect),
                  ),
                // 玻璃两档专属提示：首启没有壁纸，玻璃面没有可采样的背景，
                // 课程卡片此刻全按实体渲染——不提示会被当成「选了没生效」。
                // 实体档不吃壁纸，覆盖面已写进描述，不再加字。
                if (currentEffect != GlassModeChoice.solid) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.guideVisualEffectWallpaperHint,
                      style: _guideMutedBodyStyle(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.guidePersonalizeThemeModeTitle,
          child: HyperosControlCardInset(
            child: HyperosTabRow(
              tabs: [
                for (final mode in AppThemeMode.values)
                  appThemeModeLabel(l10n, mode),
              ],
              selectedIndex: AppThemeMode.values.indexOf(settings.appThemeMode),
              onChanged: (index) =>
                  _applyAppThemeMode(AppThemeMode.values[index]),
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.guidePersonalizeSeedColorTitle,
          child: HyperosControlCardInset(
            child: HyperosHexColorChipGroup(
              colorHexes: [
                for (final theme in ForuiTheme.values) theme.seedHex,
              ],
              // 名字跟随色块：中性灰/锌灰/石板灰三个深色 seed 色块肉眼几乎
              // 无法区分，带名字才能分辨。
              labels: [
                for (final theme in ForuiTheme.values)
                  foruiThemeLabel(l10n, theme),
              ],
              selectedHex: settings.foruiTheme.seedHex,
              onSelectedHex: _applyForuiThemeSeed,
              // 尽量两行放完且各行数量接近相等（11 色 → 6×2 末行 5），
              // 避免自动流式换行的参差排布；chipSize 44 为「小米原色」等
              // 四字名称留余量（42 会截字）。
              columns: (ForuiTheme.values.length + 1) ~/ 2,
              chipSize: 44,
              colorParser: (hex) => parseHexColorOrFallback(
                hex,
                fallback: HyperosIconColors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TimetableSettings get _currentSettings =>
      context.read<TimetableProvider>().settings;

  void _updateSettings(TimetableSettings next) {
    final provider = context.read<TimetableProvider?>();
    if (provider == null) return;
    unawaited(_persistSettings(provider, next));
  }

  /// `updateTimetableSettings` 在落盘失败时**回滚内存并 rethrow**
  /// （timetable_provider.dart:3848-3867），`unawaited` 就等于把这条文档化的
  /// 失败丢掉：用户的语言/主题选择自己跳回旧值、零提示，异常还落进 zone。
  /// 设置页六个站点都用 `reportSettingsPersistFailure` 接了它，引导页不能例外
  /// —— 首次启动的用户此刻还没有"去设置页重试"的意识。
  Future<void> _persistSettings(
    TimetableProvider provider,
    TimetableSettings next,
  ) async {
    try {
      await provider.updateTimetableSettings(next);
    } catch (_) {
      reportSettingsPersistFailure(this);
    }
  }

  void _applyAppThemeMode(AppThemeMode mode) =>
      _updateSettings(_currentSettings.copyWith(appThemeMode: mode));

  void _applyForuiTheme(ForuiTheme theme) => _updateSettings(
    _currentSettings.copyWith(foruiTheme: theme, themeSeedColor: theme.seedHex),
  );

  /// 色板回调：按种子色反查 [ForuiTheme] 再应用（色值来自同一份 [ForuiTheme]）。
  void _applyForuiThemeSeed(String seedHex) {
    final theme = ForuiTheme.values.firstWhere(
      (t) => t.seedHex.toUpperCase() == seedHex.toUpperCase(),
      orElse: () => ForuiTheme.blue,
    );
    _applyForuiTheme(theme);
  }

  /// 「默认材质」三档写入：直接委派给 [applyGlassModeChoice]（设置页材质
  /// 面板「默认材质」三格分段的唯一写入口），避免引导页与设置页各自维护
  /// 一套映射、日后再漂移。
  ///
  /// **柔光玻璃 2026-09-22 从引导页撤下**（整机只认实体 / 液态两种材质，
  /// 而它此前是唯一还能选到柔光的入口）；存量柔光值读盘即归液态，见
  /// `.agents/notes/implemented/simplification/2026-09-22-retire-soft-glass-mode.md`。
  void _applyVisualEffect(GlassModeChoice effect) {
    _updateSettings(applyGlassModeChoice(_currentSettings, effect));
  }

  Widget _buildTipsPage(AppLocalizations l10n) {
    final bodyStyle = _guideBodyStyle();
    final mutedBodyStyle = _guideMutedBodyStyle();

    return _buildGuideList(
      storageId: 'tips',
      children: [
        // 不再画「使用技巧」分组标签：大标题已经是「使用技巧」，
        // 同一屏重复第二遍。列表直接开在下面。
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
    final bodyStyle = _guideBodyStyle();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HyperosColors.primary(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(fontSize: 11, color: HyperosColors.primary(context)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: bodyStyle)),
      ],
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HyperosColors.primary(context)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _guideBodyStyle())),
      ],
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _totalPages - 1;
    final showPrev = !isFirstPage;
    final isPrivacyPage = widget.requirePrivacyConsent && _currentPage == 1;
    final canGoNext = !isPrivacyPage || _privacyChecked;

    // Container outside SafeArea so the gesture-indicator inset is filled
    // with the same color as the page (fixes the white-strip / blue mismatch).
    // No top border — the bar should sit flush against content.
    final barBackground = HyperosColors.scaffoldBackground(context);
    return Container(
      color: barBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          // Stack 而非 Row+Spacer：圆点必须**整屏水平居中**。Row+Spacer 的
          // 空档分在「左缘 / 左按钮」与「下一步」之间——第一步没有左按钮时
          // 圆点居中的是那段空档，向左偏约半个按钮宽（用户反馈）。
          // Stack 对齐让圆点不随按钮宽度偏移；按钮行定高度，圆点 8dp 在
          // 同一行内垂直居中。圆点是非交互装饰（ExcludeSemantics + 无手势），
          // 与按钮几何不重叠（360dp 屏中间空档 ≥100dp、圆点 72dp）。
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
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
                    ),
                  const Spacer(),
                  if (!isLastPage)
                    HyperosButton(
                      label: l10n.guideNextButton,
                      onPressed: canGoNext ? _goNext : null,
                    )
                  else
                    HyperosButton(
                      // 首启收尾是「同意并开始使用」；从设置复看时用户早就在
                      // 用软件了，「开始使用」与场景错位，改「知道了」
                      //（[AppLocalizations.gotItAction]，现成通用键）。
                      label: widget.requirePrivacyConsent
                          ? l10n.agreeAndStartAction
                          : l10n.gotItAction,
                      onPressed: _finishGuide,
                    ),
                ],
              ),
              if (_totalPages > 1) _buildPageDots(),
            ],
          ),
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
  const _GuideIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Solid HyperOS badge: brand-blue fill, white glyph. Deliberately reads
    // from HyperosColors, not context.theme.colors — the Material scheme
    // stays at the framework default (never customized in _appThemeData),
    // whose M3 seed purple rendered as near-black fills in light mode.
    return Container(
      // 44/12 是库里「卡片 leading 徽章」的既有规格（[HyperosSummaryCard]，
      // showcase 摘要卡同款写法）。旧值 40/圆角 12/图标 20 是第三个自定
      // 规格——与权限页行徽章 26/7 并存时，同一条引导流程两套徽章。
      width: HyperosSummaryCard.leadingSize,
      height: HyperosSummaryCard.leadingSize,
      decoration: BoxDecoration(
        color: HyperosColors.primary(context),
        borderRadius: BorderRadius.circular(HyperosSummaryCard.leadingRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: HyperosColors.onPrimary(context)),
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

class _GuideActionTile extends StatelessWidget {
  const _GuideActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// 可选副标题：只在能补充「这一行点下去会得到什么」时给。
  /// 纯导航说明（「可随时在设置里改」这类）一律不给——引导页越短越好。
  /// 无副标题时行高退回单行标准（56），不空撑两行。
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final subtitle = this.subtitle;

    final row = ConstrainedBox(
      // 两行文本走两行标准（72）——与权限页两行行一致；44 徽章 + 上下 13
      // 内边距 = 70，低于 72 时由 minHeight 兜底。无副标题时退回单行（56）。
      constraints: BoxConstraints(
        minHeight: subtitle == null
            ? HyperosTokens.listRowMinHeight
            : HyperosTokens.listRowTwoLineMinHeight,
      ),
      child: Padding(
        padding: _guideChevronRowPadding(context),
        child: Row(
          children: [
            _GuideIconBadge(icon: icon),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HyperosTypography.listTitle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HyperosTokens.titleChevronGap),
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

class _PermissionItem {
  final IconData icon;

  /// 徽章底色，取自 HyperOS 图标彩板（[HyperosIconColors]）。
  final Color accent;
  final String title;

  /// 行内补充说明。只在「为什么要点这一项」不 obvious 时给（目前只有勿扰权限），
  /// 其余行保持单行标题，避免权限清单被说明文字压长。
  final String? subtitle;
  final bool? enabled;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback? onTap;

  const _PermissionItem({
    required this.icon,
    required this.accent,
    required this.title,
    required this.enabled,
    required this.enabledLabel,
    required this.disabledLabel,
    this.subtitle,
    this.onTap,
  });
}

/// 引导页「默认材质」两档的展示顺序：模糊+折射（液态）→ 不模糊（实体）。
/// 与设置页材质面板总闸同一套 [GlassModeChoice]——选中项
/// 推导用 [glassModeChoiceOf]、写入用 [applyGlassModeChoice]，引导页不再
/// 私养一份映射。柔光玻璃 2026-09-22 撤下、高斯模糊 2026-09-30 撤下
/// （两者存量值都在读盘时归到液态）。
const List<GlassModeChoice> _guideVisualEffectOptions = <GlassModeChoice>[
  GlassModeChoice.liquidGlass,
  GlassModeChoice.solid,
];

String _guideVisualEffectLabel(
  AppLocalizations l10n,
  GlassModeChoice effect,
) => switch (effect) {
  GlassModeChoice.liquidGlass => l10n.frostedGlassModeLiquid,
  GlassModeChoice.solid => l10n.guidePersonalizeVisualEffectSolid,
};

String _guideVisualEffectDescription(
  AppLocalizations l10n,
  GlassModeChoice effect,
) => switch (effect) {
  GlassModeChoice.liquidGlass => l10n.guideVisualEffectLiquidDesc,
  GlassModeChoice.solid => l10n.guideVisualEffectSolidDesc,
};

/// 个性化页通用单选偏好行：组件库 [HyperosChoiceTile]（radio 变体）。
///
/// 旧实现直接用 flutter_miuix 的 RadioButtonPreference 并取 Material
/// colorScheme 配色，但 `_appThemeData` 从不定制 colorScheme——所谓
/// 「跟随主题种子色」实际是框架默认 M3 紫，与本页实时切换的种子色和
/// 全页 HyperOS 蓝都不一致。改走 facade 语义配色后不再依赖 Material
/// scheme；行内分割线用 ChoiceTile 自带的缩进 divider。
Widget _guideOptionRow(
  BuildContext context, {
  required String title,
  required String summary,
  required bool selected,
  required VoidCallback onTap,
  bool showDivider = false,
}) {
  return HyperosChoiceTile(
    title: title,
    subtitle: Text(summary),
    selected: selected,
    showDivider: showDivider,
    onTap: onTap,
  );
}
