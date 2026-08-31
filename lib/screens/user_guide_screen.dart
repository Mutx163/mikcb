import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
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
    if (!mounted || !_pageController.hasClients) {
      return;
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _goPrev() {
    if (!mounted || !_pageController.hasClients) {
      return;
    }
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
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
        title: Text(
          widget.requirePrivacyConsent
              ? l10n.firstUseGuideTitle
              : l10n.guideAndPermissionsTitle,
        ),
        headerExtension: _buildProgressBar(l10n),
        bottomBar: _buildBottomBar(l10n),
        child: PageView(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: _onPageChanged,
          children: _guidePages(l10n),
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

  Widget _buildProgressBar(AppLocalizations l10n) {
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
                style: HyperosTypography.sectionDescription(context),
              ),
              const SizedBox(width: 8),
              Text(
                _buildPageTitle(l10n),
                style: HyperosTypography.sectionDescription(context).copyWith(
                  color: HyperosColors.primary(context),
                ),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.welcomeAppName, style: HyperosTypography.title(context)),
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
    if (widget.requirePrivacyConsent && !_privacyChecked) {
      // Must accept privacy before import/restore can complete onboarding.
      if (mounted && _pageController.hasClients) {
        await _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 280),
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
        HyperosSectionLabel(text: l10n.guidePermissionsHeader),
        const SizedBox(height: 8),
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
    ];
  }

  Widget _buildPermissionTile(_PermissionItem item) {
    // HyperOS 设置行范式：彩底圆角方徽章 + 标题 + 右侧灰色状态字 + 细
    // chevron（同系统权限管理）。状态不再用自绘描边胶囊表达，避免与
    // 尾部勾/箭头形成双重状态指示器。
    return HyperosListTile(
      icon: item.icon,
      iconAccent: item.accent,
      title: item.title,
      details: item.enabled == true ? item.enabledLabel : item.disabledLabel,
      onTap: item.onTap,
    );
  }

  /// 个性化定制页：首次进入引导时即可选择视觉效果、深浅色与主题色。
  /// 所有选择直接写入 [TimetableProvider] 并立即生效，之后仍可在
  /// 「设置 → 外观」中修改。选项行 / 分段 / 色板全部使用组件库现成
  /// 组件（HyperosChoiceTile 单选行、HyperosTabRow 分段、HyperOS 色板）。
  Widget _buildPersonalizePage(AppLocalizations l10n) {
    final provider = context.watch<TimetableProvider?>();
    // 与欢迎页语言选择器同策略：Provider 不在树上（裸测试宿主）时整页隐藏。
    if (provider == null) return const SizedBox.shrink();
    final settings = provider.settings;
    final currentEffect = _guideVisualEffectOf(settings);

    return _buildGuideList(
      storageId: 'personalize',
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
          child: Text(l10n.guidePersonalizeSubtitle, style: _guideMutedBodyStyle()),
        ),
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
                  onTap: () =>
                      _updateSettings(
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
                  showDivider: true,
                  onTap: () =>
                      _updateSettings(
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
          title: l10n.guidePersonalizeVisualEffectTitle,
          child: HyperosControlCardInset(
            child: Column(
              children: [
                for (final (index, effect) in _guideVisualEffectOptions.indexed)
                  _guideOptionRow(
                    context,
                    title: _guideVisualEffectLabel(l10n, effect),
                    summary: _guideVisualEffectDescription(l10n, effect),
                    selected: currentEffect == effect,
                    showDivider: index > 0,
                    onTap: () => _applyVisualEffect(effect),
                  ),
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
              onChanged: (index) => _applyAppThemeMode(AppThemeMode.values[index]),
            ),
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          title: l10n.guidePersonalizeSeedColorTitle,
          child: HyperosControlCardInset(
            child: HyperosHexColorChipGroup(
              colorHexes: [for (final theme in ForuiTheme.values) theme.seedHex],
              selectedHex: settings.foruiTheme.seedHex,
              onSelectedHex: _applyForuiThemeSeed,
              // 尽量两行放完且各行数量相等（当前 10 色 → 5×2），
              // 避免自动流式换行的「上 6 下 4」参差排布。
              columns: (ForuiTheme.values.length + 1) ~/ 2,
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
    unawaited(provider.updateTimetableSettings(next));
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

  /// 视觉效果三档与设置字段的映射：
  /// - 高斯模糊 → 开模糊 + gaussian 模式；
  /// - 液态玻璃 → 开模糊 + liquidGlass 模式；
  /// - 实体卡片 → 直接关闭模糊总开关（所有表面回落实体卡片）。
  void _applyVisualEffect(_GuideVisualEffect effect) {
    switch (effect) {
      case _GuideVisualEffect.gaussian:
        _updateSettings(
          _currentSettings.copyWith(
            frostedBlurEnabled: true,
            frostedGlassMode: FrostedGlassMode.gaussian,
          ),
        );
      case _GuideVisualEffect.liquidGlass:
        _updateSettings(
          _currentSettings.copyWith(
            frostedBlurEnabled: true,
            frostedGlassMode: FrostedGlassMode.liquidGlass,
          ),
        );
      case _GuideVisualEffect.solid:
        _updateSettings(_currentSettings.copyWith(frostedBlurEnabled: false));
    }
  }

  Widget _buildTipsPage(AppLocalizations l10n) {
    final bodyStyle = _guideBodyStyle();
    final mutedBodyStyle = _guideMutedBodyStyle();

    return _buildGuideList(
      storageId: 'tips',
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
            style: HyperosTypography.listDetail(context).copyWith(
              fontSize: 11,
              color: HyperosColors.primary(context),
            ),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: HyperosColors.primary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: HyperosColors.onPrimary(context)),
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
    this.onTap,
  });
}

/// 引导页「视觉效果」三档选择。与设置字段的映射见
/// [_UserGuideScreenState._applyVisualEffect]。
enum _GuideVisualEffect { gaussian, liquidGlass, solid }

const List<_GuideVisualEffect> _guideVisualEffectOptions = <_GuideVisualEffect>[
  _GuideVisualEffect.gaussian,
  _GuideVisualEffect.liquidGlass,
  _GuideVisualEffect.solid,
];

/// 从当前设置推导引导页视觉效果选中项（模糊关 → 实体卡片）。
_GuideVisualEffect _guideVisualEffectOf(TimetableSettings settings) {
  if (!settings.frostedBlurEnabled) return _GuideVisualEffect.solid;
  if (settings.frostedGlassMode == FrostedGlassMode.liquidGlass) {
    return _GuideVisualEffect.liquidGlass;
  }
  return _GuideVisualEffect.gaussian;
}

String _guideVisualEffectLabel(AppLocalizations l10n, _GuideVisualEffect effect) =>
    switch (effect) {
      _GuideVisualEffect.gaussian => l10n.frostedGlassModeGaussian,
      _GuideVisualEffect.liquidGlass => l10n.frostedGlassModeLiquid,
      _GuideVisualEffect.solid => l10n.guidePersonalizeVisualEffectSolid,
    };

String _guideVisualEffectDescription(
  AppLocalizations l10n,
  _GuideVisualEffect effect,
) => switch (effect) {
  _GuideVisualEffect.gaussian => l10n.guideVisualEffectGaussianDesc,
  _GuideVisualEffect.liquidGlass => l10n.guideVisualEffectLiquidDesc,
  _GuideVisualEffect.solid => l10n.guideVisualEffectSolidDesc,
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
