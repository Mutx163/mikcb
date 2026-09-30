import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import 'package:share_plus/share_plus.dart';

import '../domain/time_scheme_logic.dart';
import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';
import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_session.dart';
import '../services/transfer_package.dart';
import '../services/unified_transfer_service.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/miuix_time_picker_sheet.dart';
import '../widgets/time_scheme_quick_generate_sheet.dart';
import 'location_time_match_screen.dart';
import 'qr_transfer_send_screen.dart';
import 'schedule_date_rule_screen.dart';

class TimeSchemeManagementScreen extends StatefulWidget {
  final String? initialEditSchemeId;
  final bool openCreateOnOpen;

  const TimeSchemeManagementScreen({
    super.key,
    this.initialEditSchemeId,
    this.openCreateOnOpen = false,
  });

  @override
  State<TimeSchemeManagementScreen> createState() =>
      _TimeSchemeManagementScreenState();
}

class _TimeSchemeManagementScreenState
    extends State<TimeSchemeManagementScreen> {
  bool _didOpenInitialAction = false;

  /// Usage counts are independent of the visual card and should not be
  /// recomputed every time Provider notifies during a route transition or a
  /// scroll-driven header update. Entries are filled only when their card is
  /// first built, so the route's first frame does not scan every profile.
  TimetableProvider? _usageSnapshotProvider;
  int _usageSnapshotSignature = 0;
  Map<String, _TimeSchemeUsageSummary> _usageSummaries = const {};

  /// 每个模板卡片三个点按钮的定位 key（**只是拿来量矩形**，不绑
  /// `MiuixGlassAnchor` —— 绑了上游会在弹层期间把图标设成 `contentHidden`，
  /// 复位要等退场动画播完 ≈670ms，用户读到的就是「关弹窗后三个点消失半秒多
  /// 才回来」，见 `HyperosAnchorMenuPopup.anchorBounds`）。
  final Map<String, GlobalKey> _schemeMenuAnchorKeys = {};

  /// 卡片右上角三个点菜单的显隐（弹层 [show] 的唯一来源）。
  bool _schemeMenuVisible = false;

  /// 最近一次打开的菜单会话，**收起后刻意保留**。
  ///
  /// 弹层常驻挂载、靠 [show] 切显隐，退场动画期间上游 presenter 仍要拿同一份
  /// 矩形与条目：任一变 null，presenter 的 State 会重建、入场动画当场重放。
  /// 下一张卡片打开时整体替换即可（只多留一份 [TimeScheme] 引用）。
  ///
  /// 进页面时它是 null（没打开过任何菜单）——传 null 没问题，弹层内部会兜底成
  /// `Rect.zero`，见 [HyperosAnchorMenuPopup.anchorBounds]。
  _SchemeMenuSession? _schemeMenuSession;

  /// 量出三个点按钮的**窗口坐标**（上游弹层按它定位面板）。
  ///
  /// 量不到（按钮还没 layout / 已滚出屏幕销毁）就返回 null —— 宁可这次不打开，
  /// 也不让面板贴到 (0,0)。
  Rect? _measureMenuAnchorRect(String schemeId) {
    final renderObject = _schemeMenuAnchorKeys[schemeId]
        ?.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
  }

  /// 「等菜单收完再执行动作」的时序已经收进 [HyperosAnchorMenuPopup]
  /// （`onCollapseRequested` → 退场走完 → `onSelected`），页面这侧不需要
  /// 再自己 `Future.delayed`。

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didOpenInitialAction) {
      return;
    }
    final editId = widget.initialEditSchemeId;
    final openCreate = widget.openCreateOnOpen;
    if (editId == null && !openCreate) {
      return;
    }
    _didOpenInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (editId != null) {
        _openEditor(editId);
      } else {
        _createScheme(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final schemes = provider.timeSchemes;
        final activeSchemeId = provider.activeTimeScheme?.id;
        final dateRules = provider.scheduleDateRules;
        final activeDateRule = provider.matchScheduleDateRule(DateTime.now());
        _syncUsageSnapshot(provider, schemes);

        return Stack(
          children: [
            // 弹层是 OverlayPortal，自身不占位；页面显式铺满，别让它按
            // Stack 的 loose 约束去猜尺寸。
            Positioned.fill(
              child: HyperosSubpage(
                onBack: () => Navigator.pop(context),
                title: Text(l10n.timeSchemeTitle),
                suffixes: [
                  FHeaderAction(
                    icon: const Icon(Icons.add_rounded),
                    semanticsLabel: l10n.newSchemeTooltip,
                    onPress: () => _createScheme(context),
                  ),
                ],
                child: HyperosListView(
                  // Keep the first frame light.  Building every scheme card
                  // here also calculates every card's usage summary before
                  // the route transition has had a chance to paint its first
                  // frame.  When that synchronous work is large, the route
                  // animation skips frames and looks as if it suddenly
                  // accelerates.
                  itemCount: _timeSchemeListItemCount(schemes.length),
                  itemBuilder: (context, index) => _buildTimeSchemeListItem(
                    context,
                    index,
                    l10n: l10n,
                    provider: provider,
                    schemes: schemes,
                    activeSchemeId: activeSchemeId,
                    dateRules: dateRules,
                    activeDateRule: activeDateRule,
                  ),
                ),
              ),
            ),
            // ⚠️ 必须**常驻挂载**（不要按 `!= null` 条件插拔）：上游弹层是
            // OverlayPortal + 声明式 show，插拔会让 presenter 的 State 重建、
            // 入场形变动画重放一遍（首页菜单 2026-09-20 实测踩过）。
            _buildSchemeMenuPopup(),
          ],
        );
      },
    );
  }

  /// 卡片右上角三个点菜单：上游 OS4 玻璃弹层（从按钮连续变形长出）。
  Widget _buildSchemeMenuPopup() {
    final session = _schemeMenuSession;
    return HyperosAnchorMenuPopup(
      show: _schemeMenuVisible,
      anchorBounds: session?.anchorBounds,
      entries: session?.entries ?? const [],
      onCollapseRequested: _closeSchemeMenu,
      onDismissRequest: _closeSchemeMenu,
      onSelected: (value) {
        final target = _schemeMenuSession;
        if (target != null) {
          _dispatchSchemeMenuAction(target, value);
        }
      },
    );
  }

  void _closeSchemeMenu() {
    if (!_schemeMenuVisible) {
      return;
    }
    // 只收显隐，会话（锚点 + 条目）留着给退场动画用。
    setState(() => _schemeMenuVisible = false);
  }

  /// 执行被点的那一项。**不需要自己等菜单收完** —— [HyperosAnchorMenuPopup]
  /// 已经在退场走完之后才回调这里（不等就会踩首页菜单 2026-09-15 那个坑：本页被
  /// 新路由压住后 TickerMode 被关，菜单退场动画冻在半透明）。
  Future<void> _dispatchSchemeMenuAction(
    _SchemeMenuSession session,
    Object value,
  ) async {
    if (!mounted) {
      return;
    }
    final context = this.context;
    final scheme = session.scheme;
    final usage = session.usage;
    switch (value) {
      case 'usage':
        await _showUsageDetails(context, scheme, usage);
        break;
      case 'edit':
        await _openEditor(scheme.id);
        break;
      case 'rename':
        await _renameScheme(context, scheme);
        break;
      case 'share':
        await _shareTimeScheme(context, scheme);
        break;
      case 'delete':
        await _deleteScheme(context, scheme);
        break;
      // 只弹 toast：不盖住本页，弹层已经收得差不多了，提示可以立刻给。
      case 'apply':
        await _applyScheme(context, scheme);
        break;
      case 'duplicate':
        await context.read<TimetableProvider>().duplicateTimeScheme(scheme.id);
        if (context.mounted) {
          showAppToast(
            context,
            message: AppLocalizations.of(context)!.copiedTimeSchemeMessage,
            kind: AppToastKind.success,
          );
        }
        break;
    }
  }

  void _syncUsageSnapshot(
    TimetableProvider provider,
    List<TimeScheme> schemes,
  ) {
    final profiles = provider.profiles;
    final locationTimeGroups = provider.locationTimeGroups;
    final signature = Object.hash(
      Object.hashAll(profiles.map(identityHashCode)),
      Object.hashAll(
        locationTimeGroups.map(
          identityHashCode,
        ),
      ),
      Object.hashAll(schemes.map(identityHashCode)),
    );
    if (identical(_usageSnapshotProvider, provider) &&
        _usageSnapshotSignature == signature) {
      return;
    }
    _usageSnapshotProvider = provider;
    _usageSnapshotSignature = signature;
    _usageSummaries = const {};
  }

  /// 打开某张卡片右上角的菜单：条目在这里**冻结**成一份会话。
  ///
  /// 冻结而不是每次 build 现算：弹层常驻挂载，收起后要继续拿同一份条目播
  /// 退场动画（`HyperosAnchorMenuPopup` 的类注释），现算会随 provider 通知变化。
  void _openSchemeMenu(
    TimeScheme scheme,
    _TimeSchemeUsageSummary usage,
    bool isActive,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final schemeId = scheme.id;
    // 再点同一个按钮 = 收起（系统菜单的常规手感）。
    if (_schemeMenuVisible && _schemeMenuSession?.schemeId == schemeId) {
      _closeSchemeMenu();
      return;
    }
    final anchorRect = _measureMenuAnchorRect(schemeId);
    if (anchorRect == null) {
      return;
    }
    setState(() {
      _schemeMenuVisible = true;
      _schemeMenuSession = _SchemeMenuSession(
        schemeId: schemeId,
        anchorBounds: anchorRect,
        scheme: scheme,
        usage: usage,
        entries: [
          if (!usage.isUnused)
            HyperosAnchorMenuEntry(
              label: l10n.viewUsageAction,
              value: 'usage',
            ),
          if (!isActive)
            HyperosAnchorMenuEntry(
              label: l10n.applyToCurrentTimetable,
              value: 'apply',
            ),
          HyperosAnchorMenuEntry(
            label: l10n.editSectionsAction,
            value: 'edit',
          ),
          HyperosAnchorMenuEntry(label: l10n.renameAction, value: 'rename'),
          HyperosAnchorMenuEntry(
            label: l10n.duplicateAction,
            value: 'duplicate',
          ),
          HyperosAnchorMenuEntry(
            label: l10n.shareTimeSchemeAction,
            value: 'share',
          ),
          // 删除行永远可点：上游没有 disabled 语义，禁掉反而会读成
          // "红字却点不动"。点它一定开对话框 —— 无引用时是真确认，
          // 有引用时说明是什么挡住了删除。
          HyperosAnchorMenuEntry(
            label: l10n.deleteAction,
            value: 'delete',
            destructive: true,
          ),
        ],
      );
    });
  }

  _TimeSchemeUsageSummary _usageSummaryForScheme(
    TimetableProvider provider,
    String schemeId,
  ) {
    final cachedSummary = _usageSummaries[schemeId];
    if (cachedSummary != null) {
      return cachedSummary;
    }
    final summary = _buildUsageSummary(provider, schemeId);
    _usageSummaries = {..._usageSummaries, schemeId: summary};
    return summary;
  }

  /// Returns the number of lazy list rows used by the management page.
  ///
  /// The page contains a fixed three-row prefix and then either one empty
  /// state row or alternating scheme cards and section gaps.
  int _timeSchemeListItemCount(int schemeCount) {
    if (schemeCount == 0) {
      return 4;
    }
    return 3 + schemeCount + schemeCount - 1;
  }

  Widget _buildTimeSchemeListItem(
    BuildContext context,
    int index, {
    required AppLocalizations l10n,
    required TimetableProvider provider,
    required List<TimeScheme> schemes,
    required String? activeSchemeId,
    required List<ScheduleDateRule> dateRules,
    required ScheduleDateRule? activeDateRule,
  }) {
    if (index == 0) {
      return HyperosListGroup(
        children: [
          HyperosListTile(
            icon: Icons.place_outlined,
            iconAccent: HyperosIconColors.orange,
            title: l10n.locationTimeMatchEntryTitle,
            details: provider.locationTimeGroups.isEmpty
                ? null
                : '${provider.locationTimeGroups.length}',
            onTap: () {
              Navigator.push(
                context,
                HyperosPageRoute(
                  builder: (_) => const LocationTimeMatchScreen(),
                ),
              );
            },
          ),
          HyperosListTile(
            icon: Icons.event_available_outlined,
            iconAccent: HyperosIconColors.teal,
            title: l10n.scheduleDateRuleSectionTitle,
            details: dateRules.isEmpty
                ? null
                : activeDateRule == null
                ? '${dateRules.length}'
                : l10n.scheduleDateRuleActiveToday,
            onTap: () => Navigator.push(
              context,
              HyperosPageRoute(builder: (_) => const ScheduleDateRuleScreen()),
            ),
          ),
        ],
      );
    }
    if (index == 1) {
      return const HyperosSectionGap();
    }
    if (index == 2) {
      return HyperosSectionLabel(text: l10n.timeSchemeEntryTitle);
    }

    if (schemes.isEmpty) {
      return HyperosListGroup(
        children: [
          HyperosNavTile(
            title: l10n.locationTimeMatchNeedTimeScheme,
            enabled: false,
            showChevron: false,
          ),
        ],
      );
    }

    final schemeListIndex = index - 3;
    if (schemeListIndex.isOdd) {
      return const HyperosSectionGap();
    }

    final schemeIndex = schemeListIndex ~/ 2;
    final scheme = schemes[schemeIndex];
    return _buildSchemeCard(
      context,
      scheme: scheme,
      usage: _usageSummaryForScheme(provider, scheme.id),
      isActive: scheme.id == activeSchemeId,
    );
  }

  Widget _buildSchemeCard(
    BuildContext context, {
    required TimeScheme scheme,
    required _TimeSchemeUsageSummary usage,
    required bool isActive,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HyperosIconBadge(
                icon: isActive
                    ? Icons.schedule_rounded
                    : Icons.access_time_rounded,
                accent: isActive
                    ? HyperosIconColors.teal
                    : HyperosIconColors.blue,
              ),
              const SizedBox(width: HyperosTokens.rowContentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.timeSchemeSummary(
                        scheme.sectionCount,
                        usage.profileCount,
                        usage.courseCount,
                        usage.overrideCourseCount,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: _schemeMenuAnchorKeys.putIfAbsent(
                  scheme.id,
                  GlobalKey.new,
                ),
                tooltip: l10n.moreActionsTooltip,
                onPressed: () => _openSchemeMenu(scheme, usage, isActive),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            scheme.sectionCount > 1
                ? l10n.timeSchemeStartsAt(scheme.sections.first.displayText)
                : scheme.sections.first.displayText,
            style: HyperosTypography.listDetail(context),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              l10n.usingNow,
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.primary(context)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: isActive
                      ? l10n.usingNow
                      : l10n.applyToCurrentTimetable,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: isActive
                      ? null
                      : () => _applyScheme(context, scheme),
                ),
              ),
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.editSectionsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => _openEditor(scheme.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(String schemeId) async {
    await Navigator.push(
      context,
      HyperosPageRoute(
        builder: (_) => _TimeSchemeEditorScreen(schemeId: schemeId),
      ),
    );
  }

  Future<void> _createScheme(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showAppTextInputDialog(
      context,
      title: l10n.createTimeSchemeTitle,
      confirmLabel: l10n.createAction,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timeSchemeNameLabel,
        hint: l10n.timeSchemeNameHint,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
    );

    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    final scheme = await context.read<TimetableProvider>().createTimeScheme(
      name: name,
    );
    if (!context.mounted) {
      return;
    }
    await _openEditor(scheme.id);
  }

  Future<void> _renameScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showAppTextInputDialog(
      context,
      title: l10n.renameTimeSchemeTitle,
      initialValue: scheme.name,
      bodyBuilder: (controller) => HyperosTextField(
        controller: controller,
        label: l10n.timeSchemeNameLabel,
        autofocus: true,
      ),
      validate: (value) => value.isNotEmpty,
    );

    if (!context.mounted ||
        name == null ||
        name.isEmpty ||
        name == scheme.name) {
      return;
    }

    await context.read<TimetableProvider>().renameTimeScheme(scheme.id, name);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.renamedToMessage(name),
      kind: AppToastKind.success,
    );
  }

  Future<void> _deleteScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    // Read the blockers with the same helper the provider guard uses, so the
    // dialog can never promise a delete that the guard then refuses.
    final blockers = TimeSchemeLogic.collectDeleteBlockers(
      provider.profiles,
      scheme.id,
      schemes: provider.timeSchemes,
      locationTimeGroups: provider.locationTimeGroups,
      scheduleDateRules: provider.scheduleDateRules,
    );

    if (blockers.isNotEmpty) {
      await _explainDeleteBlocked(context, scheme, blockers);
      return;
    }

    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteTimeSchemeTitle,
      message: l10n.deleteTimeSchemeMessage(scheme.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    final deleted = await provider.deleteTimeScheme(scheme.id);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: deleted
          ? l10n.deletedTimeSchemeMessage(scheme.name)
          : l10n.timeSchemeInUseMessage,
      kind: deleted ? AppToastKind.success : AppToastKind.warning,
    );
  }

  /// Shown instead of the confirm sheet when something still references the
  /// scheme.  The old flow said only "当前课表正在使用这套模板" after a delete
  /// that was already rejected, which named neither the real blocker (a profile
  /// default is not a course) nor any way out of it.
  Future<void> _explainDeleteBlocked(
    BuildContext context,
    TimeScheme scheme,
    TimeSchemeDeleteBlockers blockers,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final separator = l10n.timeSchemeBlockerListSeparator;
    final lines = <String>[
      if (blockers.profileNames.isNotEmpty)
        l10n.timeSchemeBlockedByProfiles(
          blockers.profileNames.join(separator),
        ),
      if (blockers.overrideCourseCount > 0)
        l10n.timeSchemeBlockedByOverrideCourses(
          blockers.overrideCourseCount,
        ),
      if (blockers.locationCourseCount > 0)
        l10n.timeSchemeBlockedByLocationCourses(blockers.locationCourseCount),
      if (blockers.locationGroupNames.isNotEmpty)
        l10n.timeSchemeBlockedByLocationGroups(
          blockers.locationGroupNames.join(separator),
        ),
      if (blockers.dateRuleNames.isNotEmpty)
        l10n.timeSchemeBlockedByDateRules(
          blockers.dateRuleNames.join(separator),
        ),
    ];

    final viewUsage = await showHyperosDialog<bool>(
      context: context,
      title: l10n.deleteTimeSchemeTitle,
      body: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.timeSchemeDeleteBlockedIntro,
              // Lead-in sentence stays centered — that is the dialog's own
              // convention (showHyperosDialog centers body text, same as the
              // title above).  The blocker list below is the part that opts out
              // via TextAlign.start, because a list reads wrong centered.
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.primaryText(context),
              ),
            ),
            const SizedBox(height: 12),
            // No leading dot here.  This dialog almost always has a single
            // blocker, so a bullet carries no information, and a dot painted
            // in `HyperosColors.primary` just inherits the theme accent — a
            // black seed made it read as a stray speck.  The lines are
            // self-describing ("作为主时间模板的课表：…"), so plain left-aligned
            // text reads better.
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  // showHyperosDialog wraps the whole body in a centered
                  // DefaultTextStyle, so this must be set explicitly or the
                  // line floats in the middle of the dialog.
                  textAlign: TextAlign.start,
                  style: HyperosTypography.listDetail(context),
                ),
              ),
          ],
        ),
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, false),
        ),
        HyperosDialogAction(
          label: l10n.viewUsageAction,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (viewUsage != true || !context.mounted) {
      return;
    }
    await _showUsageDetails(
      context,
      scheme,
      _usageSummaryForScheme(context.read<TimetableProvider>(), scheme.id),
    );
  }

  Future<void> _applyScheme(BuildContext context, TimeScheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final error = await context.read<TimetableProvider>().applyTimeScheme(
      scheme.id,
    );
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error),
        kind: AppToastKind.warning,
      );
      return;
    }
    showAppToast(
      context,
      message: l10n.appliedTimeSchemeMessage(scheme.name),
      kind: AppToastKind.success,
    );
  }

  /// 分享单个时间模板：弹窗选择「系统分享 / 二维码分享」。
  Future<void> _shareTimeScheme(
    BuildContext context,
    TimeScheme scheme,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showHyperosDialog<String>(
      context: context,
      title: l10n.shareTimeSchemeTitle,
      // 说明文字用主文本墨色：默认 message 样式是次级灰，液态玻璃弹窗
      // 通透材质上几乎不可见（与数据备份页同口径）。
      body: Text(
        scheme.name,
        textAlign: TextAlign.center,
        style: HyperosTypography.listDetail(context).copyWith(
          color: HyperosColors.primaryText(context),
        ),
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.shareTimeSchemeViaQr,
          onPressed: () => Navigator.pop(context, 'qr'),
        ),
        HyperosDialogAction(
          label: l10n.shareTimeSchemeViaSystem,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, 'system'),
        ),
      ],
    );
    if (!context.mounted || choice == null) {
      return;
    }
    switch (choice) {
      case 'system':
        await _shareTimeSchemeAsFile(context, scheme);
        break;
      case 'qr':
        await _shareTimeSchemeAsQr(context, scheme);
        break;
    }
  }

  /// 系统分享单个时间模板：打包只含该模板的 .mikcb 文件。
  Future<void> _shareTimeSchemeAsFile(
    BuildContext context,
    TimeScheme scheme,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    try {
      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        scope: TransferScope.timeTemplate,
        selectedTimeSchemeIds: [scheme.id],
      );
      final now = DateTime.now();
      final filename =
          'mikcb-timescheme-${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}.${DataTransferService.fileExtension}';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              package.encodeBytes(),
              mimeType: 'application/json',
              name: filename,
            ),
          ],
          text: l10n.timeSchemeShareText(scheme.name),
          subject: l10n.timeSchemeShareSubject,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.sendFailedWithError(localizeServiceError(l10n, error)),
        kind: AppToastKind.error,
      );
    }
  }

  /// 二维码分享单个时间模板：复用全屏二维码流发送页。
  Future<void> _shareTimeSchemeAsQr(
    BuildContext context,
    TimeScheme scheme,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    try {
      final package = UnifiedTransferService().buildCurrentPackage(
        provider: provider,
        channel: TransferChannel.qr,
        scope: TransferScope.timeTemplate,
        selectedTimeSchemeIds: [scheme.id],
      );
      final bytes = package.encodeBytes();
      try {
        QrTransferEncoder.preflight(bytes);
      } on QrTransferLimitException {
        if (context.mounted) {
          showAppToast(
            context,
            message: l10n.qrTransferResourceLimit,
            kind: AppToastKind.error,
          );
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      await HyperosNavigation.pushWidget<void>(
        context,
        QrTransferSendScreen(
          payloadBytes: bytes,
          title: l10n.shareTimeSchemeTitle,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        showAppToast(
          context,
          message: l10n.sendFailedWithError(localizeServiceError(l10n, error)),
          kind: AppToastKind.error,
        );
      }
    }
  }

  _TimeSchemeUsageSummary _buildUsageSummary(
    TimetableProvider provider,
    String schemeId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences = references
        .where((item) => item.usesOverride)
        .toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
        ? _formatUsageReference(l10n, references.first)
        : l10n.timeSchemeBottomUsageMulti(
            _formatUsageReference(l10n, references.first),
            references.length,
          );
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(
    AppLocalizations l10n,
    TimeSchemeCourseUsageReference reference,
  ) {
    final course = reference.course;
    final usageType = reference.usesOverride
        ? l10n.overrideTimeSchemeShortLabel
        : l10n.mainTimeSchemeLabel;
    return l10n.timeSchemeUsageReference(
      reference.profileName,
      course.name,
      _weekdayLabel(l10n, course.dayOfWeek),
      course.startSection,
      course.endSection,
      usageType,
    );
  }

  Future<void> _showUsageDetails(
    BuildContext context,
    TimeScheme scheme,
    _TimeSchemeUsageSummary usage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final directCourseReferences = usage.directCourseReferences;
    final overrideReferences = usage.overrideReferences;
    // Read through the same helper the delete guard uses, so the sections
    // below can never disagree with whether the delete is allowed.
    final provider = context.read<TimetableProvider>();
    final blockers = TimeSchemeLogic.collectDeleteBlockers(
      provider.profiles,
      scheme.id,
      schemes: provider.timeSchemes,
      locationTimeGroups: provider.locationTimeGroups,
      scheduleDateRules: provider.scheduleDateRules,
    );
    final locationGroupNames = blockers.locationGroupNames;
    final dateRuleNames = blockers.dateRuleNames;
    await showHyperosDialog<void>(
      context: context,
      title: l10n.timeSchemeUsageTitle(scheme.name),
      body: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.timeSchemeUsageIntro,
                style: HyperosTypography.listDetail(context),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TimeSchemeInfoChip(
                    label: l10n.profileCountLabel,
                    value: l10n.profileCountValue(usage.profileCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: l10n.courseCountLabel,
                    value: l10n.courseSectionCountValue(usage.courseCount),
                  ),
                  _TimeSchemeInfoChip(
                    label: l10n.overrideTimeSchemeLabel,
                    value: l10n.courseSectionCountValue(
                      usage.overrideCourseCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _UsageSection(
                title: l10n.directlyBoundProfilesTitle,
                subtitle: usage.profileCount == 0
                    ? l10n.directlyBoundProfilesEmpty
                    : l10n.directlyBoundProfilesSubtitle,
                items: usage.profileNames
                    .map((name) => _UsageLine(primary: name))
                    .toList(growable: false),
                emptyText: l10n.directlyBoundProfilesEmpty,
              ),
              const SizedBox(height: 12),
              _UsageSection(
                title: l10n.followMainSchemeCoursesTitle,
                subtitle: directCourseReferences.isEmpty
                    ? l10n.followMainSchemeCoursesEmpty
                    : l10n.followMainSchemeCoursesSubtitle,
                items: directCourseReferences
                    .map(
                      (reference) => _UsageLine(
                        primary:
                            '${reference.profileName} · ${reference.course.name}',
                        secondary: l10n.weekdaySectionRange(
                          _weekdayLabel(l10n, reference.course.dayOfWeek),
                          reference.course.startSection,
                          reference.course.endSection,
                        ),
                      ),
                    )
                    .toList(growable: false),
                emptyText: l10n.followMainSchemeCoursesEmpty,
              ),
              const SizedBox(height: 12),
              _UsageSection(
                title: l10n.overrideSchemeCoursesTitle,
                subtitle: overrideReferences.isEmpty
                    ? l10n.overrideSchemeCoursesEmpty
                    : l10n.overrideSchemeCoursesSubtitle,
                items: overrideReferences
                    .map(
                      (reference) => _UsageLine(
                        primary:
                            '${reference.profileName} · ${reference.course.name}',
                        secondary: l10n.weekdaySectionRange(
                          _weekdayLabel(l10n, reference.course.dayOfWeek),
                          reference.course.startSection,
                          reference.course.endSection,
                        ),
                      ),
                    )
                    .toList(growable: false),
                emptyText: l10n.overrideSchemeCoursesEmpty,
              ),
              // Location groups and date rules also block deletion but own no
              // courses of their own, so without these two sections the usage
              // dialog could not explain a delete the provider refuses.  Gated
              // on non-empty (unlike the three course sections above) so the
              // common one-blocker case doesn't grow two empty boxes; the
              // subtitle is a static sentence and the names live only in
              // `items` — naming them in both printed every rule twice.
              if (locationGroupNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                _UsageSection(
                  title: l10n.locationTimeMatchEntryTitle,
                  subtitle: l10n.timeSchemeBlockedLocationGroupsSubtitle,
                  items: locationGroupNames
                      .map((name) => _UsageLine(primary: name))
                      .toList(growable: false),
                ),
              ],
              if (dateRuleNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                _UsageSection(
                  title: l10n.scheduleDateRuleSectionTitle,
                  subtitle: l10n.timeSchemeBlockedDateRulesSubtitle,
                  items: dateRuleNames
                      .map((name) => _UsageLine(primary: name))
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.closeAction,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return l10n.weekdayShortMonday;
      case 2:
        return l10n.weekdayShortTuesday;
      case 3:
        return l10n.weekdayShortWednesday;
      case 4:
        return l10n.weekdayShortThursday;
      case 5:
        return l10n.weekdayShortFriday;
      case 6:
        return l10n.weekdayShortSaturday;
      case 7:
        return l10n.weekdayShortSunday;
      default:
        return dayOfWeek.toString();
    }
  }
}

/// 卡片右上角三个点菜单的**一次打开会话**。
///
/// 为什么要冻结成一份（而不是每次 build 现算）：弹层常驻挂载、靠 `show` 切显隐
/// （上游 OS4 玻璃弹层是声明式组件，条件插拔会让 State 重建、入场形变重放），
/// 收起后的退场动画期间还要继续拿同一份矩形与条目。
class _SchemeMenuSession {
  const _SchemeMenuSession({
    required this.schemeId,
    required this.anchorBounds,
    required this.scheme,
    required this.usage,
    required this.entries,
  });

  final String schemeId;

  /// 打开瞬间量到的按钮窗口坐标（退场期间面板仍按它定位，故不重新量）。
  final Rect anchorBounds;

  final TimeScheme scheme;
  final _TimeSchemeUsageSummary usage;
  final List<HyperosAnchorMenuEntry> entries;
}

class _TimeSchemeEditorScreen extends StatefulWidget {
  final String schemeId;

  const _TimeSchemeEditorScreen({required this.schemeId});

  @override
  State<_TimeSchemeEditorScreen> createState() =>
      _TimeSchemeEditorScreenState();
}

class _TimeSchemeEditorScreenState extends State<_TimeSchemeEditorScreen> {
  late final TextEditingController _nameController;
  late List<SectionTime> _sections;
  TimeSchemeQuickGeneratePreset _lastQuickGeneratePreset =
      kDefaultTimeSchemeQuickGeneratePreset;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimetableProvider>();
    final scheme = provider.timeSchemes.firstWhere(
      (item) => item.id == widget.schemeId,
    );
    _nameController = TextEditingController(text: scheme.name);
    _sections = List<SectionTime>.from(scheme.sections);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final isActive = provider.activeTimeScheme?.id == widget.schemeId;
    final usage = _buildUsageSummary(provider, widget.schemeId);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      resizeToAvoidBottomInset: true,
      title: Text(l10n.editTimeSchemeTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: _save,
        ),
      ],
      // Standard list path (header inset inside the scrollable + notification
      // bubbling) so the large title collapses; the old BodyInset +
      // includeHeaderInset:false combo swallowed vertical scroll notifications
      // and froze the large title.
      child: HyperosListView(
        children: [
          HyperosControlCard(
            title: l10n.timeSchemeNameLabel,
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HyperosTextField(
                    controller: _nameController,
                    hint: l10n.timeSchemeNameHint,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isActive) _TimeSchemeBadge(text: l10n.currentInUse),
                      _TimeSchemeInfoChip(
                        label: l10n.profileCountLabel,
                        value: l10n.profileCountValue(usage.profileCount),
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.courseCountLabel,
                        value: l10n.courseSectionCountValue(usage.courseCount),
                      ),
                      _TimeSchemeInfoChip(
                        label: l10n.overrideTimeSchemeLabel,
                        value: l10n.courseSectionCountValue(
                          usage.overrideCourseCount,
                        ),
                      ),
                    ],
                  ),
                  if (isActive || usage.courseCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      isActive && usage.courseCount > 0
                          ? l10n.timeSchemeEditorActiveAndCoursesHint
                          : isActive
                          ? l10n.timeSchemeEditorActiveHint
                          : l10n.timeSchemeEditorOverrideHint,
                      style: HyperosTypography.sectionDescription(context),
                    ),
                  ],
                  if (usage.previewText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      usage.previewText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.sectionDescription(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.sectionTimesTitle,
            subtitle: l10n.sectionTimesSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HyperosControlCardInset(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HyperosButton(
                        label: l10n.quickGenerateAction,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _openQuickGenerate,
                      ),
                      HyperosButton(
                        label: l10n.addSectionAction,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _sections.length >= 20 ? null : _addSection,
                      ),
                      HyperosButton(
                        label: l10n.removeLastSectionAction,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _sections.length <= 1
                            ? null
                            : _removeSection,
                      ),
                      HyperosButton(
                        label: l10n.resetDefaultAction,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _resetSections,
                      ),
                    ],
                  ),
                ),
                if (_sections.isNotEmpty)
                  HyperosControlCardRows(
                    children: [
                      for (var index = 0; index < _sections.length; index++)
                        HyperosListTile(
                          icon: Icons.access_time_rounded,
                          iconAccent: HyperosIconColors.teal,
                          title: l10n.sectionLabel(index + 1),
                          details:
                              '${_sections[index].startTime} - ${_sections[index].endTime}',
                          onTap: () => _editSectionTime(index),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSectionTime(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final start = await showMiuixTimePickerSheet(
      context,
      initialTime: _parseTimeOfDay(_sections[index].startTime),
      title: l10n.selectStartTimeTitle,
    );
    if (start == null || !mounted) {
      return;
    }

    final end = await showMiuixTimePickerSheet(
      context,
      initialTime: _parseTimeOfDay(_sections[index].endTime),
      title: l10n.selectEndTimeTitle,
    );
    if (end == null || !mounted) {
      return;
    }

    final editedSection = SectionTime(
      startTime: _formatTimeOfDay(start),
      endTime: _formatTimeOfDay(end),
    );
    final startMinutes = _parseTimeMinutes(editedSection.startTime);
    final endMinutes = _parseTimeMinutes(editedSection.endTime);
    if (endMinutes <= startMinutes) {
      showAppToast(
        context,
        message: l10n.timeRangeValidationNoCrossDay,
        kind: AppToastKind.warning,
      );
      return;
    }

    final nextSections = List<SectionTime>.from(_sections);
    nextSections[index] = editedSection;
    final validationMessage = validateSectionTimes(nextSections);
    if (validationMessage != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, validationMessage),
        kind: AppToastKind.warning,
      );
      return;
    }

    setState(() {
      _sections[index] = editedSection;
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(_buildNextSection(_sections.last));
    });
  }

  void _removeSection() {
    setState(() {
      _sections.removeLast();
    });
  }

  void _resetSections() {
    setState(() {
      _sections = List<SectionTime>.from(TimetableSettings.defaults().sections);
    });
  }

  _TimeSchemeUsageSummary _buildUsageSummary(
    TimetableProvider provider,
    String schemeId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final profileNames = provider.profiles
        .where((profile) => profile.settings.activeTimeSchemeId == schemeId)
        .map((profile) => profile.name)
        .toList(growable: false);
    final references = provider.getTimeSchemeCourseUsages(schemeId);
    final overrideReferences = references
        .where((item) => item.usesOverride)
        .toList(growable: false);
    final previewText = references.isEmpty
        ? null
        : references.length == 1
        ? _formatUsageReference(l10n, references.first)
        : l10n.timeSchemeBottomUsageMulti(
            _formatUsageReference(l10n, references.first),
            references.length,
          );
    return _TimeSchemeUsageSummary(
      profileNames: profileNames,
      courseReferences: references,
      overrideReferences: overrideReferences,
      previewText: previewText,
    );
  }

  String _formatUsageReference(
    AppLocalizations l10n,
    TimeSchemeCourseUsageReference reference,
  ) {
    final course = reference.course;
    final usageType = reference.usesOverride
        ? l10n.overrideTimeSchemeShortLabel
        : l10n.mainTimeSchemeLabel;
    return l10n.timeSchemeUsageReference(
      reference.profileName,
      course.name,
      _weekdayLabel(l10n, course.dayOfWeek),
      course.startSection,
      course.endSection,
      usageType,
    );
  }

  String _weekdayLabel(AppLocalizations l10n, int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return l10n.weekdayShortMonday;
      case 2:
        return l10n.weekdayShortTuesday;
      case 3:
        return l10n.weekdayShortWednesday;
      case 4:
        return l10n.weekdayShortThursday;
      case 5:
        return l10n.weekdayShortFriday;
      case 6:
        return l10n.weekdayShortSaturday;
      case 7:
        return l10n.weekdayShortSunday;
      default:
        return dayOfWeek.toString();
    }
  }

  Future<void> _openQuickGenerate() async {
    final l10n = AppLocalizations.of(context)!;
    final preset = await showTimeSchemeQuickGenerateSheet(
      context,
      initialPreset: _lastQuickGeneratePreset,
    );
    if (preset == null || !mounted) {
      return;
    }

    try {
      final sections = buildQuickSectionTimes(
        morningCount: preset.morningCount,
        afternoonCount: preset.afternoonCount,
        eveningCount: preset.eveningCount,
        morningStartTime: preset.morningStartTime,
        afternoonStartTime: preset.afternoonStartTime,
        eveningStartTime: preset.eveningStartTime,
        classDurationMinutes: preset.classDurationMinutes,
        breakDurationMinutes: preset.breakDurationMinutes,
        breakOverrideRules: preset.breakOverrideRules,
      );
      setState(() {
        _lastQuickGeneratePreset = preset;
        _sections = sections;
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error.message),
        kind: AppToastKind.error,
      );
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final message = await context.read<TimetableProvider>().updateTimeScheme(
      schemeId: widget.schemeId,
      name: _nameController.text.trim(),
      sections: _sections,
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: localizeServiceMessage(l10n, message));
      return;
    }
    Navigator.pop(context);
  }
}

class _TimeSchemeUsageSummary {
  final List<String> profileNames;
  final List<TimeSchemeCourseUsageReference> courseReferences;
  final List<TimeSchemeCourseUsageReference> overrideReferences;
  final String? previewText;

  const _TimeSchemeUsageSummary({
    required this.profileNames,
    required this.courseReferences,
    required this.overrideReferences,
    required this.previewText,
  });

  int get profileCount => profileNames.length;
  int get courseCount => courseReferences.length;
  int get overrideCourseCount => overrideReferences.length;
  List<TimeSchemeCourseUsageReference> get directCourseReferences =>
      courseReferences
          .where((item) => !item.usesOverride)
          .toList(growable: false);
  bool get isUnused => profileCount == 0 && courseCount == 0;
}

class _UsageSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_UsageLine> items;

  /// Text for the no-items case.  Optional: sections that only render when they
  /// have something to show (see the location-group / date-rule sections in
  /// [_showUsageDetails]) have no meaningful empty state to spell out, and
  /// inventing one by formatting a sentence with an empty placeholder produced
  /// text like "绑定了它的地点作息匹配：".
  final String? emptyText;

  const _UsageSection({
    required this.title,
    required this.subtitle,
    required this.items,
    this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HyperosColors.card(context),
        borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
        border: Border.all(color: HyperosColors.dividerLine(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.start,
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyText ?? subtitle,
              textAlign: TextAlign.start,
              style: HyperosTypography.listDetail(context),
            )
          else
            ...items.map((item) => item),
        ],
      ),
    );
  }
}

class _UsageLine extends StatelessWidget {
  final String primary;
  final String? secondary;

  const _UsageLine({required this.primary, this.secondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: HyperosColors.primary(context),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // showHyperosDialog's body inherits a centered DefaultTextStyle;
                // short course names would otherwise float mid-dialog instead
                // of sitting next to their bullet.
                Text(
                  primary,
                  textAlign: TextAlign.start,
                  style: HyperosTypography.listTitle(context),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    textAlign: TextAlign.start,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSchemeInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimeSchemeInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HyperosTag(label: '$label $value');
  }
}

class _TimeSchemeBadge extends StatelessWidget {
  final String text;

  const _TimeSchemeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    return HyperosTag(
      label: text,
      backgroundColor: primary.withValues(alpha: 0.12),
      textStyle: HyperosTypography.listDetail(context).copyWith(
        color: primary,
        fontSize: HyperosTokens.sectionDescriptionSize,
      ),
    );
  }
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

int _parseTimeMinutes(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

SectionTime _buildNextSection(SectionTime last) {
  final end = _parseTimeOfDay(last.endTime);
  final startMinutes = end.hour * 60 + end.minute + 10;
  final endMinutes = startMinutes + 45;
  return SectionTime(
    startTime: _minutesToTime(startMinutes),
    endTime: _minutesToTime(endMinutes),
  );
}

String _minutesToTime(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
