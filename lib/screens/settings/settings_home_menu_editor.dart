part of '../timetable_settings_screen.dart';

/// 八宫格按钮自定义编辑器。
///
/// 顶部预览当前排列；「已启用」列表支持拖动排序与逐个移除（至少保留
/// 一个入口）；「可添加」列出尚未启用的动作，点击即加入。所有改动即时
/// 回调 [onChanged]，由外观页统一走草稿 + 自动保存队列持久化。
class _HomeGridMenuEditorScreen extends StatefulWidget {
  const _HomeGridMenuEditorScreen({
    required this.initialActions,
    required this.onChanged,
  });

  final List<HomeTopMenuAction> initialActions;
  final ValueChanged<List<HomeTopMenuAction>> onChanged;

  @override
  State<_HomeGridMenuEditorScreen> createState() =>
      _HomeGridMenuEditorScreenState();
}

class _HomeGridMenuEditorScreenState extends State<_HomeGridMenuEditorScreen> {
  late List<HomeTopMenuAction> _actions = List.of(widget.initialActions);

  int get _maxSlots => HomeGridMenu.maxSlots;

  bool get _canAdd => _actions.length < _maxSlots;

  bool get _canRemove => _actions.length > 1;

  List<HomeTopMenuAction> get _availableActions => HomeTopMenuAction.values
      .where((action) => !_actions.contains(action))
      .toList(growable: false);

  void _commit(List<HomeTopMenuAction> next) {
    setState(() {
      _actions = next;
    });
    widget.onChanged(List.of(next));
  }

  // onReorderItem 已自动校正下移时的 newIndex，无需手动 -1。
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _actions.removeAt(oldIndex);
      _actions.insert(newIndex, moved);
    });
    widget.onChanged(List.of(_actions));
  }

  void _add(HomeTopMenuAction action) {
    if (!_canAdd || _actions.contains(action)) {
      return;
    }
    _commit([..._actions, action]);
  }

  void _removeAt(int index) {
    if (!_canRemove) {
      return;
    }
    final next = List.of(_actions)..removeAt(index);
    _commit(next);
  }

  void _resetToDefault() {
    _commit([
      for (final id in HomeGridMenu.defaultActions)
        HomeTopMenuActionIdX.fromId(id),
    ].whereType<HomeTopMenuAction>().toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeGridCustomizeTitle),
      child: HyperosListView(
        children: [
          _buildPreviewCard(context, l10n),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.homeGridEditorEnabledTitle),
          _buildEnabledReorderList(context, l10n),
          HyperosSectionDescription(
            text: l10n.homeGridEditorHintBody(_maxSlots),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.homeGridEditorAvailableTitle),
          if (_availableActions.isNotEmpty)
            HyperosListGroup(
              children: [
                for (final action in _availableActions)
                  HyperosListTile(
                    icon: homeTopMenuActionIcon(action),
                    title: homeTopMenuActionTitle(l10n, action),
                    onTap: () => _add(action),
                  ),
              ],
            )
          else
            HyperosSectionDescription(
              text: l10n.homeGridEditorAllAdded,
            ),
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

  Widget _buildPreviewCard(BuildContext context, AppLocalizations l10n) {
    return HyperosCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final action in _actions)
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
                            homeTopMenuActionIcon(action),
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        homeTopMenuActionTitle(l10n, action),
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
        ],
      ),
    );
  }

  Widget _buildEnabledReorderList(BuildContext context, AppLocalizations l10n) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _actions.length,
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
        final action = _actions[index];
        return _GridSlotRow(
          key: ValueKey(action.id),
          index: index,
          icon: homeTopMenuActionIcon(action),
          title: homeTopMenuActionTitle(l10n, action),
          canRemove: _canRemove,
          onRemove: () => _removeAt(index),
          removeTooltip: l10n.homeGridEditorRemoveTooltip,
        );
      },
    );
  }
}

/// 「已启用」单行：拖动手柄 + 图标徽章 + 标题 + 移除按钮。
///
/// 视觉对齐 [HyperosListTile]（同卡色、同圆角、同 56dp 行高），但不用
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
