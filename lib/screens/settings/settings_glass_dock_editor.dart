part of '../timetable_settings_screen.dart';

/// 玻璃坞底栏按钮自定义编辑器。
///
/// 候选 = 视图切换（日课表/周课表，由首页宿主处理）∪ 八宫格目录全部
/// 可见条目；最多 [HomeDockMenu.maxSlots] 个，支持拖动排序与移除。
/// 改动即时回调 onChanged，由「首页与导航」页统一走草稿 + 自动保存。
class _GlassDockEditorScreen extends StatefulWidget {
  const _GlassDockEditorScreen({
    required this.initialIds,
    required this.onChanged,
  });

  final List<String> initialIds;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_GlassDockEditorScreen> createState() =>
      _GlassDockEditorScreenState();
}

class _GlassDockEditorScreenState extends State<_GlassDockEditorScreen> {
  late List<String> _ids = [
    // 种子阶段丢弃当前环境不可用的 id，保证每行都真实可解析。
    for (final id in widget.initialIds)
      if (_isAvailable(id)) id,
  ];

  bool _isAvailable(String id) {
    if (id == kGlassDockActionDay || id == kGlassDockActionWeek) {
      return true;
    }
    return homeMenuEntryById(id)?.visible() ?? false;
  }

  String _label(AppLocalizations l10n, String id) =>
      glassDockActionLabel(l10n, id);

  IconData _icon(String id) => glassDockActionIcon(id);

  int get _maxSlots => HomeDockMenu.maxSlots;

  bool get _canAdd => _ids.length < _maxSlots;

  bool get _canRemove => _ids.length > 1;

  void _commit(List<String> next) {
    setState(() {
      _ids = next;
    });
    widget.onChanged(List.of(next));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _ids.removeAt(oldIndex);
      _ids.insert(newIndex, moved);
    });
    widget.onChanged(List.of(_ids));
  }

  void _add(String id) {
    if (!_canAdd || _ids.contains(id)) {
      return;
    }
    _commit([..._ids, id]);
  }

  void _removeAt(int index) {
    if (!_canRemove) {
      return;
    }
    final next = List.of(_ids)..removeAt(index);
    _commit(next);
  }

  void _resetToDefault() {
    _commit(HomeDockMenu.defaultActions);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.glassDockCustomizeTitle),
      child: HyperosListView(
        children: [
          _buildPreviewCard(context),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.homeGridEditorEnabledTitle),
          _buildEnabledReorderList(context, l10n),
          HyperosSectionDescription(
            text: l10n.homeGridEditorHintBody(_maxSlots),
          ),
          // 视图切换伪分组：日/周是动作而非页面，排在目录分类之前。
          ..._buildViewSwitchGroup(context, l10n),
          for (final category in HomeMenuEntryCategory.values) ...[
            const HyperosSectionGap(),
            HyperosSectionLabel(
              text: homeMenuEntryCategoryLabel(l10n, category),
            ),
            ..._buildAvailableGroup(context, l10n, category),
          ],
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.restart_alt_rounded,
                iconAccent: HyperosIconColors.red,
                title: l10n.homeGridEditorResetAction,
                onTap: _resetToDefault,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildViewSwitchGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final candidates = [
      for (final id in const [kGlassDockActionDay, kGlassDockActionWeek])
        if (!_ids.contains(id)) id,
    ];
    if (candidates.isEmpty) {
      return const [];
    }
    return [
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.homeDockEditorViewCategory),
      HyperosListGroup(
        children: [
          for (final id in candidates)
            HyperosListTile(
              icon: _icon(id),
              title: _label(l10n, id),
              details: _canAdd ? null : l10n.homeGridEditorMaxReached,
              onTap: _canAdd ? () => _add(id) : null,
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildAvailableGroup(
    BuildContext context,
    AppLocalizations l10n,
    HomeMenuEntryCategory category,
  ) {
    final candidates = kHomeMenuCatalog
        .where(
          (entry) =>
              entry.category == category &&
              entry.visible() &&
              !_ids.contains(entry.id),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return [
        HyperosSectionDescription(text: l10n.homeGridEditorAllAdded),
      ];
    }
    return [
      HyperosListGroup(
        children: [
          for (final entry in candidates)
            HyperosListTile(
              icon: entry.icon,
              title: entry.title(l10n),
              details: _canAdd ? null : l10n.homeGridEditorMaxReached,
              onTap: _canAdd ? () => _add(entry.id) : null,
            ),
        ],
      ),
    ];
  }

  Widget _buildPreviewCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final id in _ids)
            SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HyperosBlurredHeader.accentSurfaceTintColor(
                        Theme.of(context).colorScheme.primary,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(14),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _icon(id),
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _label(l10n, id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnabledReorderList(BuildContext context, AppLocalizations l10n) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _ids.length,
      onReorderItem: _reorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final elevation = Tween<double>(begin: 0, end: 6).animate(animation);
            return Material(
              elevation: elevation.value,
              borderRadius: BorderRadius.circular(16),
              color: HyperosColors.card(context),
              child: child,
            );
          },
        );
      },
      itemBuilder: (context, index) {
        final id = _ids[index];
        return _DockSlotRow(
          key: ValueKey(id),
          index: index,
          icon: _icon(id),
          title: _label(l10n, id),
          canRemove: _canRemove,
          onRemove: () => _removeAt(index),
          removeTooltip: l10n.homeGridEditorRemoveTooltip,
        );
      },
    );
  }
}

/// 「已启用」单行：拖动手柄 + 图标徽章 + 标题 + 移除按钮（对齐八宫格）。
class _DockSlotRow extends StatelessWidget {
  const _DockSlotRow({
    super.key,
    required this.index,
    required this.icon,
    required this.title,
    required this.canRemove,
    required this.onRemove,
    required this.removeTooltip,
  });

  final int index;
  final IconData icon;
  final String title;
  final bool canRemove;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: HyperosColors.card(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 32,
                  height: 56,
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 20,
                      color: HyperosColors.secondaryText(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            HyperosIconBadge(icon: icon, accent: HyperosIconColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyperosTypography.listTitle(context),
              ),
            ),
            IconButton(
              tooltip: removeTooltip,
              onPressed: canRemove ? onRemove : null,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: canRemove
                    ? HyperosIconColors.red
                    : HyperosColors.secondaryText(context).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
