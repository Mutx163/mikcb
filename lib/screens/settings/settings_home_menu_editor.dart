part of '../timetable_settings_screen.dart';

/// 八宫格按钮自定义编辑器。
/// 候选来自 kHomeMenuCatalog（全应用的二级页面与功能），按分类分组展示；
/// 「已启用」支持拖动排序与逐个移除（至少保留一个入口）。所有改动即时
/// 回调 onChanged，由外观页统一走草稿 + 自动保存队列持久化。
class _HomeGridMenuEditorScreen extends StatefulWidget {
  const _HomeGridMenuEditorScreen({
    required this.initialIds,
    required this.onChanged,
  });

  final List<String> initialIds;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_HomeGridMenuEditorScreen> createState() =>
      _HomeGridMenuEditorScreenState();
}

class _HomeGridMenuEditorScreenState
    extends State<_HomeGridMenuEditorScreen> {
  late List<String> _ids = [
    // 目录可能随版本演进（改名/下线入口、构建模式门控）；种子阶段就丢
    // 弹当前环境不可用的 id，保证编辑器里每一行都真实可解析、可打开。
    for (final id in widget.initialIds)
      if (homeMenuEntryById(id)?.visible() ?? false) id,
  ];

  int get _maxSlots => HomeGridMenu.maxSlots;

  bool get _canAdd => _ids.length < _maxSlots;

  bool get _canRemove => _ids.length > 1;

  void _commit(List<String> next) {
    setState(() {
      _ids = next;
    });
    widget.onChanged(List.of(next));
  }

  // onReorderItem 已自动校正下移时的 newIndex，无需手动 -1。
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
    _commit(HomeGridMenu.defaultActions);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeGridCustomizeTitle),
      child: HyperosListView(
        children: [
          _buildPreviewCard(context),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.homeGridEditorEnabledTitle),
          _buildEnabledReorderList(context, l10n),
          HyperosSectionDescription(
            text: l10n.homeGridEditorHintBody(_maxSlots),
          ),
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

  /// 某分类下尚未启用的候选；全部启用时给一句说明而不是空组。
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
        // 预览是示意卡：行内与多行都在卡内水平/垂直居中，
        // 不满一行的尾排也不再靠左吊着。
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
                        homeMenuEntryById(id)?.icon ?? Icons.help_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    homeMenuEntryById(id)?.title(l10n) ?? id,
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
        final entry = homeMenuEntryById(id);
        // 「课表设置」是回到本页的稳定路径，钉死不可移除（模型层同样
        // 强制），否则删光可达设置的入口后编辑器自身就进不来了。
        final isPinned = id == HomeGridMenu.pinnedActionId;
        final canRemove = _canRemove && !isPinned;
        return _GridSlotRow(
          key: ValueKey(id),
          index: index,
          icon: entry?.icon ?? Icons.help_outline,
          title: entry?.title(l10n) ?? id,
          canRemove: canRemove,
          onRemove: () => _removeAt(index),
          removeTooltip: isPinned
              ? l10n.homeGridEditorPinnedTooltip
              : l10n.homeGridEditorRemoveTooltip,
        );
      },
    );
  }
}

/// 「已启用」单行：拖动手柄 + 图标徽章 + 标题 + 移除按钮。
/// 视觉对齐 HyperosListTile（同卡色、同圆角、同 56dp 行高），但不用
/// ListTile 本体——行尾是移除按钮而非 chevron，行首多一个拖动手柄。
class _GridSlotRow extends StatelessWidget {
  const _GridSlotRow({
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