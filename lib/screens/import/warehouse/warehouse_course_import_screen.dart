// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库课表导入页
// 选学校 → 选适配器 → 网页登录 → 导入的主流程页。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:azlistview/azlistview.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../../models/warehouse_macro_models.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_macro_service.dart';
import '../../../services/warehouse_repository_service.dart';
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

  /// 学校列表的滚动与字母条控制器。AzListView 内置的跳转是
  /// `jumpTo(index)`（对齐到视口顶部），在本页会被悬浮顶栏盖住跳到
  /// 的那一组第一行，所以这里自建字母条、跳转时按顶栏高度留位。
  /// 详见 [_jumpToSchoolTag]。
  final ItemScrollController _schoolItemScrollController =
      ItemScrollController();
  final ItemPositionsListener _schoolItemPositionsListener =
      ItemPositionsListener.create();
  final IndexBarDragListener _schoolIndexDragListener =
      IndexBarDragListener.create();
  final IndexBarController _schoolIndexBarController = IndexBarController();

  /// 当前渲染的分组（build 里更新），字母条跳转与高亮联动读它。
  List<WarehouseSchoolSection> _currentSections = const [];
  String _schoolSelectedTag = '';

  /// 上一次 build 的索引 tag 表。搜索会让上游 `data.indexOf(tag)` 返回 -1，
  /// 字母条整体熄灭；清空搜索后若首组 tag 与搜索前相同，
  /// [_syncSchoolIndexHighlight] 的 `!=` 守卫会判成「没变」不再推一次，
  /// 字母条可能一个都不亮。索引表一变就复位守卫。
  List<String> _schoolIndexTags = const [];

  /// 列表视口高度（build 里由 LayoutBuilder 量）。跳转对齐的分母必须是
  /// **视口**高度而不是屏幕高（上游 `ItemScrollController.jumpTo` 的
  /// alignment 是视口内的比例，positioned_list.dart:169-172）；今天两者
  /// 恰好相等只是列表铺满全屏的巧合，加了底栏 / 改成 resize 就会整体偏。
  /// 存字段而不是在手势回调里读 MediaQuery：在回调里
  /// `dependOnInheritedWidgetOfExactType` 会给 State 注册继承依赖
  /// （本仓库 hyperos_blurred_header.dart:52-65 专门为这类场景留了
  /// `insetOfUntracked`）。
  double _schoolViewportHeight = 0;

  /// 顶栏实测高度（列表自己的 padding 用的就是这个值）。跳转对齐必须跟它
  /// 同源，不能用 `contentTopInsetWithExtension` 那个写死估算
  /// （44+4+68）——系统字号放大把搜索框撑高时估算不会跟着变。
  double _schoolHeaderInset = 0;

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
    _schoolIndexDragListener.dragDetails.addListener(_onSchoolIndexDrag);
    _schoolItemPositionsListener.itemPositions.addListener(
      _syncSchoolIndexHighlight,
    );
  }

  @override
  void dispose() {
    _schoolIndexDragListener.dragDetails.removeListener(_onSchoolIndexDrag);
    _schoolItemPositionsListener.itemPositions.removeListener(
      _syncSchoolIndexHighlight,
    );
    _searchController.dispose();
    super.dispose();
  }

  /// 字母条手势 → 跳到对应分组。`alignment` 把落点压到顶栏之下：
  /// 0 = 视口顶部（会被悬浮顶栏盖住第一行），这里按顶栏高度折算，
  /// 保证跳到的第一所学校完整可见。
  ///
  /// 松手那一拍要额外回灌一次高亮（见 [_resyncSchoolIndexHighlight]），
  /// 否则最后一组不够高撑满视口时，字母条会永远停在拖到的那个字母上。
  void _onSchoolIndexDrag() {
    final details = _schoolIndexDragListener.dragDetails.value;
    final action = details.action;
    if (action == IndexBarDragDetails.actionDown ||
        action == IndexBarDragDetails.actionUpdate) {
      final tag = details.tag;
      if (tag == null || tag.isEmpty) {
        return;
      }
      _schoolSelectedTag = tag;
      _jumpToSchoolTag(tag);
      return;
    }
    if (action == IndexBarDragDetails.actionUp ||
        action == IndexBarDragDetails.actionEnd ||
        action == IndexBarDragDetails.actionCancel) {
      _resyncSchoolIndexHighlight();
    }
  }

  /// 松手后把字母条高亮拉回列表的真实位置。
  ///
  /// 起因是上下游两套高亮在按住期间会分家：真正改高亮的
  /// `IndexBarController.updateTagIndex` 被上游 `_updateTagIndex` 的
  /// `if (_isActionDown()) return;` 挡掉（azlistview index_bar.dart:447-451），
  /// 而 [_syncSchoolIndexHighlight] 照常改 `_schoolSelectedTag`。等最后一组
  /// 不够高撑满约 82% 屏时（真实数据 Z 组 20 所 ≈ 1440px，高屏滚不到顶），
  /// 字母条亮着「Z」而列表顶部其实是「Y」；松手也不会改，要再滚一下才纠正。
  ///
  /// 所以这里先把守卫值复位（否则 `!=` 判成「没变」而不推），再延迟一拍
  /// 重算：`_onSchoolIndexDrag` 跑在 ValueNotifier 的分发里、早于 IndexBar
  /// 自己的 `_valueChanged`，此刻它的 `action` 还是 actionUpdate，直接推会被
  /// 自己挡掉；延到本轮事件处理结束后 action 已是 actionEnd，推得进去。
  void _resyncSchoolIndexHighlight() {
    _schoolSelectedTag = '';
    scheduleMicrotask(() {
      if (!mounted) return;
      _syncSchoolIndexHighlight();
    });
  }

  void _jumpToSchoolTag(String tag) {
    var index = -1;
    for (var i = 0; i < _currentSections.length; i++) {
      if (_currentSections[i].getSuspensionTag() == tag) {
        index = i;
        break;
      }
    }
    if (index == -1 || !_schoolItemScrollController.isAttached) {
      return;
    }
    // 视口高与顶栏高都在 build 里量好存字段（见 [_schoolViewportHeight] /
    // [_schoolHeaderInset]）：alignment 的分母是视口不是屏幕，顶栏高要与
    // 列表 padding 同源，都不能在这里现算。
    final viewportHeight = _schoolViewportHeight;
    final alignment = viewportHeight <= 0
        ? 0.0
        : (_schoolHeaderInset / viewportHeight).clamp(0.0, 0.9);
    _schoolItemScrollController.jumpTo(index: index, alignment: alignment);
  }

  /// 随列表滚动高亮字母条当前字母（与 AzListView 内置逻辑一致）。
  void _syncSchoolIndexHighlight() {
    if (_currentSections.isEmpty) {
      return;
    }
    final positions = _schoolItemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return;
    }
    final first = positions
        .where((position) => position.itemTrailingEdge > 0)
        .reduce(
          (min, position) =>
              position.itemTrailingEdge < min.itemTrailingEdge ? position : min,
        );
    if (first.index < 0 || first.index >= _currentSections.length) {
      return;
    }
    final tag = _currentSections[first.index].getSuspensionTag();
    if (_schoolSelectedTag != tag) {
      _schoolSelectedTag = tag;
      _schoolIndexBarController.updateTagIndex(tag);
    }
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
                  return HyperosBlurredBodyInset(child: importLoadingCenter());
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
                    // 按归一化首字母排即可：通用学校在 schoolsToBeans 里已
                    // 另起「通」块置顶。这里若再把通用整体提前、却保留
                    // 各自原首字母，就会把同字母拆成两段（如超星 C 在最前、
                    // 重庆 C 在中间），索引条出现两个 C，AzListView 点第二
                    // 个永远跳到第一个（只取首个相等 tag）。
                    final leftInitial = left.initial.trim().toUpperCase();
                    final rightInitial = right.initial.trim().toUpperCase();
                    final initialCompare = leftInitial.compareTo(rightInitial);
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
                final beans = schoolsToBeans(filteredSchools, _recentSchoolIds);
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
                                label: l10n.warehouseFeedbackMissingSchoolTitle,
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
                final headerInset = HyperosBlurredHeaderScope.insetOf(context);
                // 字母条跳转与高亮联动读它（_onSchoolIndexDrag）。
                _currentSections = sections;
                // 搜索时字母条熄灭、上游 indexOf 返回 -1；清空搜索后若首组
                // tag 与搜索前相同，守卫会判成「没变」不再推一次，字母条
                // 一个都不亮。索引表一变就复位守卫，等下一次位置回调补推。
                if (!listEquals(_schoolIndexTags, indexTags)) {
                  _schoolIndexTags = indexTags;
                  _schoolSelectedTag = '';
                }
                final schoolIndexBarOptions = IndexBarOptions(
                  needRebuild: true,
                  // hapticFeedback 保持默认 false：上游对每个字母都调
                  // `HapticFeedback.vibrate()`（重震，index_bar.dart
                  // :525-529），一次划过 20 个字母就是 20 次重震；包没给
                  // 轻重粒度的开关，要轻反馈只能整个关掉。
                  textStyle: HyperosTypography.listDetail(context).copyWith(
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
                  // 平时一层薄衬底：条子 30×336 就压在十几行学校名上，
                  // 完全透明时深色主题下两边糊成一团（Container 的 color
                  // 与 decoration 互斥，只能给 decoration）。
                  decoration: BoxDecoration(
                    color: HyperosColors.card(context).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  downDecoration: BoxDecoration(
                    color: HyperosColors.card(context).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  // indexHintDecoration / indexHintTextStyle 不给了：传了
                  // indexHintBuilder 后上游 _buildIndexHint 直接短路返回
                  // builder（index_bar.dart:326-329），这两项是死配置。
                  // 真正生效的配色统一写在下面的 schoolIndexHint 里。
                );
                Widget schoolIndexHint(BuildContext context, String tag) =>
                    Container(
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
                    );
                // AzListView 内置字母条跳转对齐到视口顶部，会被本页悬浮
                // 顶栏盖住落点分组的第一行，所以内置条藏起（indexBarData
                // 置空），另叠一个自建条，跳转时按顶栏高度留位。
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // 视口高、顶栏高写进字段供手势回调读（见字段注释）。
                    final viewportHeight = constraints.maxHeight;
                    _schoolViewportHeight = viewportHeight;
                    _schoolHeaderInset = headerInset;
                    // 条子高度按可用高度封顶：真实数据 20~21 组 × 默认 16px
                    // = 320~336px，横屏视口（约 360px）已在边缘，再多几个
                    // 首字母或分屏小窗就 RenderFlex overflow，超出父盒的
                    // 首尾字母还会因为命中测试按裁剪后的盒子而点不到。
                    // warehouseIndexBarGeometry 已把总高封在视口的 82%
                    // 以内，这里拿到的尺寸不会超过父盒。
                    final barGeometry = warehouseIndexBarGeometry(
                      tagCount: indexTags.length,
                      availableHeight: viewportHeight,
                    );
                    // 字母条可见时把列表右边距让出来：BaseIndexBar 手势是
                    // HitTestBehavior.translucent，原来只有 16px 右距，
                    // 条子压住每行最右 14px，点那一竖不会打开学校而是跳组
                    // （行根本收不到指针）。搜索时条子空数据、不占位。
                    final rightInset = warehouseSchoolListRightInset(
                      indexBarWidth: barGeometry.width,
                      indexBarVisible: !isSearching,
                    );
                    return Stack(
                      children: [
                        AzListView(
                          data: sections,
                          itemCount: sections.length,
                          itemScrollController: _schoolItemScrollController,
                          itemPositionsListener: _schoolItemPositionsListener,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            headerInset,
                            rightInset,
                            16,
                          ),
                          indexBarData: const [],
                          itemBuilder: (context, index) {
                            final section = sections[index];
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 组首字母。字母条是唯一的「我在哪组」线索，
                                // 没有它跳到 H 之后屏幕上没有任何 H 字样
                                // （组间只有 HyperosSectionGap）。
                                _buildSchoolGroupHeader(section.tag),
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
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IndexBar(
                            data: isSearching ? const [] : indexTags,
                            options: schoolIndexBarOptions,
                            controller: _schoolIndexBarController,
                            indexBarDragListener: _schoolIndexDragListener,
                            indexHintBuilder: schoolIndexHint,
                            itemHeight: barGeometry.itemHeight,
                            height: barGeometry.height,
                          ),
                        ),
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

  /// 组首字母标题（组与组之间的「我在哪组」线索）。
  ///
  /// 没用 AzListView 的 `susItemBuilder`：它的吸顶副本只可能落在视口 top
  /// （suspension_view.dart:114-128 里 top 恒 ≤ 0），正好被本页悬浮顶栏盖住，
  /// 等于多画一份看不见的 widget。就地放在组首行，简单也够用。
  Widget _buildSchoolGroupHeader(String tag) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HyperosSectionLabel(text: tag),
    );
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
    return bean.isRecent ? l10n.recentSchoolLabel : l10n.warehouseSchoolTapHint;
  }
}
