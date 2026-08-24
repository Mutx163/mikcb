part of '../timetable_settings_screen.dart';

/// 圆钮图标挑选页：遍历 Miuix 扩展图标全集（MiuixIcons.extended.names），
/// 支持按名称过滤；首格为「默认（加号）」清空自定义。选择即时回调
/// onChanged（null = 恢复默认）并返回。
class _GlassDockIconPickerScreen extends StatefulWidget {
  const _GlassDockIconPickerScreen({
    required this.initialName,
    required this.onChanged,
  });

  final String? initialName;
  final ValueChanged<String?> onChanged;

  @override
  State<_GlassDockIconPickerScreen> createState() =>
      _GlassDockIconPickerScreenState();
}

class _GlassDockIconPickerScreenState
    extends State<_GlassDockIconPickerScreen> {
  late String? _selected = widget.initialName;
  String _filter = '';

  late final List<String> _allNames = MiuixIcons.extended.names;

  List<String> get _filteredNames {
    final query = _filter.trim().toLowerCase();
    if (query.isEmpty) {
      return _allNames;
    }
    return _allNames.where((n) => n.toLowerCase().contains(query)).toList();
  }

  void _select(String? name) {
    setState(() {
      _selected = name;
    });
    widget.onChanged(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filteredNames = _filteredNames;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.glassDockButtonIconTitle),
      child: HyperosListView(
        children: [
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.add_rounded,
                iconAccent: HyperosIconColors.blue,
                title: l10n.glassDockButtonIconDefault,
                details: _selected == null ? '✓' : null,
                onTap: () {
                  _select(null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const HyperosSectionGap(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _filter = value),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: '${_allNames.length} icons',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final name in filteredNames)
                  _IconCell(
                    name: name,
                    vector: MiuixIcons.extended.byName(name),
                    selected: _selected == name,
                    onTap: () {
                      _select(name);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标格：Miuix 矢量图标 + 名称小字；选中态描边主色。
class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.name,
    required this.vector,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final MiuixVectorIcon? vector;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? HyperosBlurredHeader.accentSurfaceTintColor(primary)
              : HyperosColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: vector == null
                  ? const Icon(Icons.help_outline, size: 22)
                  : MiuixIcon(vector: vector),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                fontSize: 9,
                color:
                    selected ? primary : HyperosColors.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
