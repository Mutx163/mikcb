// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库课表导入页
// 选学校 → 选适配器 → 网页登录 → 导入的主流程页。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../../models/warehouse_macro_models.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_macro_service.dart';
import '../../../services/warehouse_repository_service.dart';
import '../../../utils/app_toast.dart';
import '../../feedback_screen.dart';
import '../import_shared.dart';
import 'warehouse_shared.dart';
import 'warehouse_adapter_web_login_screen.dart';
import 'warehouse_school_adapters_screen.dart';
import 'warehouse_custom_debug_screen.dart';

class WarehouseCourseImportScreen extends StatefulWidget {
  const WarehouseCourseImportScreen({super.key});

  @override
  State<WarehouseCourseImportScreen> createState() =>
      _WarehouseCourseImportScreenState();
}

class _WarehouseCourseImportScreenState
    extends State<WarehouseCourseImportScreen> {
  static const WarehouseRepositorySource _defaultSource =
      defaultQingyuWarehouseSource;

  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final WarehouseMacroService _macroService = WarehouseMacroService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _warehouseMoreMenuKey = GlobalKey();

  /// 仓库页「更多」菜单（上游 OS4 玻璃弹层，常驻挂载）。2026-09-28 从
  /// `showHyperosListPopup`（手搓旧实现）迁来。
  bool _warehouseMenuVisible = false;

  /// 冻结的条目。弹层常驻挂载，条目若随 build 现算会在退场途中跳内容；
  /// 冻结成「点开那一刻」也保住了旧实现的语义（禁用态是点开时的状态）。
  List<HyperosAnchorMenuEntry> _warehouseMenuEntries = const [];

  /// 锚点（更多按钮）窗口坐标，收起后**保留**到退场结束。
  Rect? _warehouseMenuAnchorBounds;
  late Future<WarehouseRootIndex> _rootIndexFuture;
  List<String> _recentSchoolIds = const [];
  String _searchQuery = '';

  /// 「按适配器（脚本）名称搜索」的全局索引；拉取失败或旧版适配仓没有该
  /// 索引时为 null，搜索退化为仅按学校名称/ID/首字母/代码匹配。
  WarehouseSearchIndex? _searchIndex;
  WarehouseFetchOptions _currentFetchOptions() {
    return currentWarehouseFetchOptions(context);
  }

  @override
  void initState() {
    super.initState();
    _rootIndexFuture = _repositoryService.fetchRootIndex(
      _defaultSource,
      options: _currentFetchOptions(),
    );
    _loadRecentSchoolIds();
    _fetchSearchIndex();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSchoolIds() async {
    final ids = await _preferencesService.getRecentSchoolIds();
    if (!mounted) return;
    setState(() {
      _recentSchoolIds = ids;
    });
  }

  /// 拉取全局脚本名索引（一次请求覆盖全部学校），到货后刷新列表让
  /// 正在输入的搜索立即生效；失败静默降级（404 = 旧版适配仓没有该索引）。
  Future<void> _fetchSearchIndex() async {
    try {
      final index = await _repositoryService.fetchSearchIndex(
        _defaultSource,
        options: _currentFetchOptions(),
      );
      if (!mounted) return;
      setState(() {
        _searchIndex = index;
      });
    } catch (_) {
      // 保持 _searchIndex 为 null：搜索仍按学校名称/ID/首字母/代码匹配。
    }
  }

  Future<void> _handleMoreAction(WarehouseImportMenuAction action) async {
    switch (action) {
      case WarehouseImportMenuAction.feedback:
        await _openMissingSchoolFeedbackGuide();
        break;
      case WarehouseImportMenuAction.customDebug:
        await _openCustomDebugRecords();
        break;
      case WarehouseImportMenuAction.executionLog:
        await openWarehouseImportExecutionLogViewer(context);
        break;
    }
  }

  Future<void> _showWarehouseMoreMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final anchorRect = measurePopupAnchorRect(_warehouseMoreMenuKey);
    if (!mounted || anchorRect == null) {
      return;
    }
    setState(() {
      _warehouseMenuVisible = true;
      _warehouseMenuAnchorBounds = anchorRect;
      _warehouseMenuEntries = [
        HyperosAnchorMenuEntry(
          label: l10n.warehouseFeedbackMissingSchoolTitle,
          value: WarehouseImportMenuAction.feedback,
        ),
        HyperosAnchorMenuEntry(
          label: l10n.warehouseCustomDebugTitle,
          value: WarehouseImportMenuAction.customDebug,
        ),
        HyperosAnchorMenuEntry(
          label: l10n.warehouseImportExecutionLogMenuLabel,
          value: WarehouseImportMenuAction.executionLog,
        ),
      ];
    });
  }

  void _closeWarehouseMenu() {
    if (!_warehouseMenuVisible) {
      return;
    }
    setState(() => _warehouseMenuVisible = false);
  }

  /// 菜单收完后执行被点的那一项（时序由 `HyperosAnchorMenuPopup` 内置）。
  Future<void> _handleWarehouseMenuSelection(Object value) async {
    if (!mounted || value is! WarehouseImportMenuAction) {
      return;
    }
    await _handleMoreAction(value);
  }

  Widget _buildWarehouseMenu() {
    return HyperosAnchorMenuPopup(
      show: _warehouseMenuVisible,
      anchorBounds: _warehouseMenuAnchorBounds,
      entries: _warehouseMenuEntries,
      onCollapseRequested: _closeWarehouseMenu,
      onDismissRequest: _closeWarehouseMenu,
      onSelected: _handleWarehouseMenuSelection,
    );
  }

  Future<void> _handleQuickImport() async {
    final l10n = AppLocalizations.of(context)!;
    final allEntries = await _macroService.getAllMacroEntries();
    if (!mounted) return;
    if (allEntries.isEmpty) {
      showImportLightTip(context, l10n.noSavedQuickImportRecords);
      return;
    }
    // 加载完整的宏记录（含学校名、适配器名）
    final records = <WarehouseMacroRecord>[];
    for (final entry in allEntries) {
      final record = await _macroService.getMacro(
        entry.schoolId,
        entry.adapterId,
      );
      if (record != null) records.add(record);
    }
    if (!mounted) return;
    if (records.isEmpty) {
      showImportLightTip(context, l10n.noSavedQuickImportRecords);
      return;
    }
    if (records.length == 1) {
      await _startQuickImport(records.first);
      return;
    }
    // 多个宏录制，弹窗选择
    final chosen = await showHyperosDialog<WarehouseMacroRecord>(
      context: context,
      title: l10n.selectQuickImportTitle,
      body: HyperosChoiceGroup(
        children: [
          for (final record in records)
            HyperosChoiceTile(
              title: record.schoolName,
              subtitle: Text(
                l10n.quickImportMacroSteps(
                  record.adapterName,
                  record.steps.length,
                ),
              ),
              trailing: const Icon(Icons.flash_on_rounded, size: 20),
              onTap: () => Navigator.pop(context, record),
            ),
        ],
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
    if (chosen != null && mounted) {
      await _startQuickImport(chosen);
    }
  }

  Future<void> _startQuickImport(WarehouseMacroRecord macro) async {
    final l10n = AppLocalizations.of(context)!;
    final customUrl = await _preferencesService.getCustomImportUrl(
      macro.adapterId,
    );
    final initialUrl = resolveWarehouseImportUrl(
      customImportUrl: customUrl,
      defaultUrl: macro.importUrl,
    );
    if (!mounted || initialUrl == null) {
      if (mounted) {
        showImportLightTip(context, l10n.noValidWarehouseLoginUrl);
      }
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import-top',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: l10n.quickImportTitle(macro.schoolName),
          initialUrl: initialUrl,
          source: _defaultSource,
          school: WarehouseSchoolEntry(
            id: macro.schoolId,
            name: macro.schoolName,
            initial: macro.schoolName.isNotEmpty ? macro.schoolName[0] : '#',
            resourceFolder: macro.schoolResourceFolder.isNotEmpty
                ? macro.schoolResourceFolder
                : macro.schoolId,
          ),
          adapter: WarehouseAdapterEntry(
            adapterId: macro.adapterId,
            adapterName: macro.adapterName,
            category: 'macro',
            assetJsPath: macro.adapterAssetJsPath.isNotEmpty
                ? macro.adapterAssetJsPath
                : 'macro/${macro.adapterId}.js',
            importUrl: macro.importUrl,
            maintainer: 'macro',
            description: AppLocalizations.of(context)!
                .courseImportQuickImportDescription(
                  macro.schoolName,
                  macro.adapterName,
                ),
          ),
          fetchOptions: _currentFetchOptions(),
          macroRecord: macro,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void showImportLightTip(BuildContext context, String message) {
    showAppLightTip(context, message: message);
  }

  Future<void> _openMissingSchoolFeedbackGuide() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldOpen = await showHyperosSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheet(
          title: l10n.warehouseMissingSchoolTitle,
          description: l10n.warehouseMissingSchoolSubtitle,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              HyperosButton(
                label: l10n.laterAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
              HyperosButton(
                label: l10n.goFeedbackAction,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        );
      },
    );
    if (shouldOpen == true && mounted) {
      await Navigator.of(context).push(
        HyperosPageRoute(
          settings: const RouteSettings(name: '/feedback'),
          builder: (_) => const FeedbackScreen(),
        ),
      );
    }
  }

  Future<void> _openCustomDebugRecords() async {
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug',
        ),
        builder: (_) => const WarehouseCustomDebugRecordsScreen(),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Positioned.fill(child: _buildWarehouseBody(l10n)),
        // ⚠️ 常驻挂载，条件插拔会让上游 presenter 的 State 重建、入场动画重放。
        _buildWarehouseMenu(),
      ],
    );
  }

  Widget _buildWarehouseBody(AppLocalizations l10n) {
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.importMethodWarehouseTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.flash_on_rounded),
          semanticsLabel: l10n.quickImportTooltip,
          onPress: _handleQuickImport,
        ),
        Builder(
          key: _warehouseMoreMenuKey,
          builder: (context) => FHeaderAction(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: l10n.moreActionsTooltip,
            onPress: _showWarehouseMoreMenu,
          ),
        ),
      ],
      headerExtension: HyperosBlurredHeaderExtension(
        child: Row(
          children: [
            Expanded(
              child: HyperosTextField(
                controller: _searchController,
                hint: l10n.searchSchoolHint,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (_searchQuery.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              HyperosIconButton(
                icon: Icons.close_rounded,
                tooltip: l10n.clearSearchTooltip,
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            ],
          ],
        ),
      ),
      // Standard scroll path so the large title collapses with scroll (see the
      // ICS import screen above); centered states inset manually below.
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<WarehouseRootIndex>(
                  future: _rootIndexFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Non-scroll centered view: inset below the bar manually.
                      return HyperosBlurredBodyInset(
                        child: importLoadingCenter(),
                      );
                    }
                    if (snapshot.hasError) {
                      return HyperosListView(
                        children: [
                          HyperosSectionLabel(
                            text: l10n.warehouseRootLoadFailedTitle,
                          ),
                          HyperosControlCard(
                            child: HyperosControlCardInset(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  importListDetail(
                                    context,
                                    localizeServiceError(l10n, snapshot.error!),
                                  ),
                                  const SizedBox(height: 12),
                                  HyperosButton(
                                    label: l10n.reloadAction,
                                    variant: HyperosButtonVariant.secondary,
                                    onPressed: () {
                                      setState(() {
                                        _rootIndexFuture = _repositoryService
                                            .fetchRootIndex(
                                              _defaultSource,
                                              options: _currentFetchOptions(),
                                            );
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final allSchools = [...?snapshot.data?.schools]
                      ..sort((left, right) {
                        // 通用教务/工具类学校置顶
                        final leftIsGeneric = left.name.contains('通用');
                        final rightIsGeneric = right.name.contains('通用');
                        if (leftIsGeneric != rightIsGeneric) {
                          return leftIsGeneric ? -1 : 1;
                        }
                        final initialCompare = left.initial.compareTo(
                          right.initial,
                        );
                        if (initialCompare != 0) return initialCompare;
                        return left.name.compareTo(right.name);
                      });
                    final keyword = _searchQuery.trim();
                    final adapterMatches =
                        _searchIndex?.matchedAdapterNamesBySchool(keyword) ??
                        const <String, List<String>>{};
                    final filteredSchools = filterWarehouseSchools(
                      allSchools,
                      _searchQuery,
                      adapterMatches: adapterMatches,
                    );
                    final beans = schoolsToBeans(
                      filteredSchools,
                      _recentSchoolIds,
                    );
                    final sections = schoolsToSections(beans);
                    final indexTags = sections
                        .map((section) => section.tag)
                        .toList(growable: false);
                    final isSearching = _searchQuery.trim().isNotEmpty;
                    if (sections.isEmpty) {
                      // Non-scroll centered view: inset below the bar manually.
                      return HyperosBlurredBodyInset(
                        child: Center(
                          child: HyperosEmptyState(
                            icon: Icons.search_off_rounded,
                            title: isSearching
                                ? l10n.noMatchingSchools
                                : l10n.noAvailableSchools,
                            subtitle: isSearching
                                ? l10n.searchSchoolSuggestion
                                : null,
                            // 搜索无结果时给出反馈入口，而不是干巴巴的空态：点击后
                            // 打开「缺少学校？」引导（含去反馈页提交 Issue 的渠道提示）。
                            action: isSearching
                                ? HyperosButton(
                                    label:
                                        l10n.warehouseFeedbackMissingSchoolTitle,
                                    variant: HyperosButtonVariant.secondary,
                                    dense: true,
                                    onPressed: _openMissingSchoolFeedbackGuide,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }
                    // 字母索引条 + 分组列表。2026-09-28 曾为排查「进学校页底下
                    // 整页黑」临时换成普通列表；黑带真因后来定案在转场视差补底
                    // （hyperos_navigation.dart 的零尺寸常驻子级塌高），与本页
                    // 视口无关，索引条在此恢复。
                    // Header inset inside the scrollable so rows slide under
                    // the frosted bar (mirrors HyperosListView's default).
                    final headerInset = HyperosBlurredHeaderScope.insetOf(
                      context,
                    );
                    return AzListView(
                      data: sections,
                      itemCount: sections.length,
                      padding: EdgeInsets.fromLTRB(16, headerInset, 16, 16),
                      indexBarData: isSearching ? const [] : indexTags,
                      indexBarOptions: IndexBarOptions(
                        needRebuild: true,
                        hapticFeedback: true,
                        textStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              fontSize: HyperosMiuixTypography.footnote2,
                              color: HyperosColors.secondaryText(context),
                            ),
                        selectTextStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              fontSize: HyperosMiuixTypography.footnote2,
                              color: HyperosColors.primary(context),
                            ),
                        selectItemDecoration: BoxDecoration(
                          color: HyperosColors.primary(
                            context,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        indexHintDecoration: BoxDecoration(
                          color: HyperosColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        indexHintTextStyle: HyperosTypography.title(
                          context,
                        ).copyWith(color: HyperosColors.primary(context)),
                      ),
                      indexHintBuilder: (context, tag) => Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: HyperosColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: HyperosTypography.title(
                            context,
                          ).copyWith(color: HyperosColors.primary(context)),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HyperosChoiceGroup(
                              children: [
                                for (final bean in section.items)
                                  HyperosChoiceTile(
                                    prefix: ImportInitialBadge(
                                      label: bean.school.initial,
                                    ),
                                    title: bean.school.name,
                                    subtitle: Text(
                                      _schoolRowSubtitle(
                                        bean,
                                        adapterMatches,
                                        l10n,
                                      ),
                                    ),
                                    trailing: const HyperosChevron(),
                                    onTap: () =>
                                        _openWarehouseSchool(bean.school),
                                  ),
                              ],
                            ),
                            if (index < sections.length - 1)
                              const HyperosSectionGap(),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _openWarehouseSchool(WarehouseSchoolEntry school) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: RouteSettings(name: '/courses/import/warehouse/${school.id}'),
        builder: (_) => WarehouseSchoolAdaptersScreen(
          source: _defaultSource,
          school: school,
          fetchOptions: _currentFetchOptions(),
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 搜索行副标题：按脚本名命中时回显命中的适配器名（说明这所学校为什么
  /// 出现，如「通用工具与服务」下的 WakeUp 口令导入）；其余保持原提示。
  String _schoolRowSubtitle(
    WarehouseSchoolBean bean,
    Map<String, List<String>> adapterMatches,
    AppLocalizations l10n,
  ) {
    final matched = adapterMatches[bean.school.id];
    if (matched != null && matched.isNotEmpty) {
      return l10n.warehouseMatchedAdaptersLabel(matched.join('、'));
    }
    return bean.isRecent
        ? l10n.recentSchoolLabel
        : l10n.warehouseSchoolTapHint;
  }
}


