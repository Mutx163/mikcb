part of '../timetable_settings_screen.dart';

/// 圆钮图标挑选页：遍历 Miuix 扩展图标全集（MiuixIcons.extended.names），
/// 支持按名称过滤。布局自上而下：
/// 1. 搜索框卡片（置顶，与下方网格同一缩进体系，左右边缘对齐）；
/// 2. 图标网格：首格固定为「默认（加号）」（清空自定义、恢复默认加号），
///    其后为过滤结果。
///
/// 网格按「行」惰性构建（[HyperosListView] 的 itemCount/itemBuilder 模式，
/// 见 spec hyperos-blurred-header.md 的 Heavy sub-page lists 一节）：列数由
/// 可用宽度推导，一行内各格 Expanded 均分宽度——行的左右总宽与上方搜索
/// 卡片完全一致，不再出现居中 Wrap 收窄一档的观感。
///
/// 性能：旧实现有两个掉帧根源——
/// 1. HyperosListView(children:) 是 SingleChildScrollView+Column，156 个
///    图标格一次性全部构建且常驻；
/// 2. MiuixIcon 的 painter 每次绘制都对整段 SVG 路径串重新
///    miuixParsePath，并对每个图标 saveLayer 上色。
/// 这里改为：行级惰性构建；每个图标路径只解析一次（翻转矩阵一并烘焙），
/// 由 [_CachedMiuixVectorPainter] 用缓存 Path 直接按目标尺寸绘制（扩展
/// 图标均为单路径 alpha=1，直填颜色与 SrcIn tint 视觉等价，无需 saveLayer）。
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
  /// 网格几何：沿用旧 Wrap 视觉参数——格间水平 8、行距 10、最小格宽 76；
  /// 列数按可用宽度推导后夹在 [3, _maxColumns]。
  static const _cellSpacing = 8.0;
  static const _halfCellSpacing = _cellSpacing / 2;
  static const _rowSpacing = 10.0;
  static const _minCellWidth = 76.0;
  static const _maxColumns = 6;

  /// 单元格内部密度：26 图标 + 5 间距 + 名称微字（行高由内容自然撑起）。
  static const _iconSize = 26.0;

  late String? _selected = widget.initialName;

  /// 搜索框滚动出可视区被 ListView 回收后，靠自有 controller 恢复文本
  /// （builder 列表的条目会随滚动销毁重建，裸 TextField 会丢内容）。
  late final TextEditingController _searchController;
  String _filter = '';

  /// 过滤结果缓存：只在搜索词变化时重算，build 内不做字符串处理。
  List<String> _filteredNames = const [];

  /// 路径解析缓存：name -> 已解析并烘焙翻转的 Path（视口坐标系）。
  /// Path 构建后只读共享，绘制不会修改它；页面生命周期内至多 156 条。
  final Map<String, ({Path path, double viewport})> _parsedIcons = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _recomputeFiltered();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _recomputeFiltered() {
    final query = _filter.trim().toLowerCase();
    final names = MiuixIcons.extended.names;
    _filteredNames = query.isEmpty
        ? names
        : names
              .where((n) => n.toLowerCase().contains(query))
              .toList(growable: false);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filter = value;
      _recomputeFiltered();
    });
  }

  void _select(String? name) {
    setState(() {
      _selected = name;
    });
    widget.onChanged(name);
  }

  /// 解析单个图标的 Regular 字重路径——每个图标整个页面生命周期只此一次。
  /// spec.build() 内部即 miuixParsePath（MiuixIcon 默认每次绘制都会重跑）；
  /// groupTransform（绕视口中心翻 Y）在此烘焙进 Path，绘制期不再做矩阵
  /// 变换。找不到时返回 null（格子回退问号图标）。
  ({Path path, double viewport})? _parsedIcon(String name) {
    final cached = _parsedIcons[name];
    if (cached != null) {
      return cached;
    }
    final vector = MiuixIcons.extended.byName(name);
    if (vector == null || vector.paths.isEmpty) {
      return null;
    }
    final spec = vector.paths.first;
    var parsed = spec.build();
    final transform = spec.groupTransform;
    if (transform != null) {
      parsed = parsed.transform(transform.storage);
    }
    final entry = (path: parsed, viewport: vector.viewport.width);
    _parsedIcons[name] = entry;
    return entry;
  }

  int _columnCountFor(double contentWidth) {
    if (contentWidth <= _minCellWidth) {
      return 3;
    }
    final columns =
        ((contentWidth + _cellSpacing) / (_minCellWidth + _cellSpacing))
            .floor();
    return columns.clamp(3, _maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.glassDockButtonIconTitle),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 内容宽 = 页面宽 - HyperosListView 左右 listPadding（16+16），
          // 与搜索卡片的可视边缘同源，行宽因此与其严格一致。
          final contentWidth =
              constraints.maxWidth - HyperosTokens.listPadding.horizontal;
          final columns = _columnCountFor(contentWidth);
          // 首格为「默认（加号）」，其后是过滤结果。
          final cellCount = _filteredNames.length + 1;
          final rowCount = (cellCount + columns - 1) ~/ columns;
          return HyperosListView(
            itemCount: rowCount + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSearchCard(l10n);
              }
              return _buildGridRow(
                l10n,
                rowIndex: index - 1,
                columns: columns,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchCard(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: HyperosCard(
        // 输入组件不裸放在 scaffold 背景上：搜索框填充 #F0F0F0 对页面背景
        // #F2F2F2 无对比；按 showcase 同款惯例垫卡片给表面。
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: HyperosSearchBar(
          controller: _searchController,
          hint: l10n.glassDockButtonIconSearchHint,
          onChanged: _onSearchChanged,
          onClear: () {
            _searchController.clear();
            _onSearchChanged('');
          },
        ),
      ),
    );
  }

  /// 一行 [columns] 格：Expanded 均分内容宽，行左右总宽与上方卡片一致。
  /// 首末格贴边（无外边距），相邻格之间以半间距（4+4=8）分隔；末行不足
  /// 的槽位用空占位保持已渲染格子的宽度与上方各行相同（左对齐收尾）。
  Widget _buildGridRow(
    AppLocalizations l10n, {
    required int rowIndex,
    required int columns,
  }) {
    final cellCount = _filteredNames.length + 1;
    final first = rowIndex * columns;
    final end = first + columns > cellCount ? cellCount : first + columns;
    // 不固定行高：各格内部结构一致，行高由内容自然撑起且逐行相等；
    // 系统大字号下行高随文字放大，避免固定值溢出。
    return Padding(
      padding: const EdgeInsets.only(bottom: _rowSpacing),
      child: Row(
        children: [
          for (var i = first; i < end; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i % columns == 0 ? 0 : _halfCellSpacing,
                  right: i % columns == columns - 1 ? 0 : _halfCellSpacing,
                ),
                child: _buildCell(l10n, cellIndex: i),
              ),
            ),
          for (var i = end; i < first + columns; i++)
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildCell(AppLocalizations l10n, {required int cellIndex}) {
    final isDefault = cellIndex == 0;
    final name = isDefault ? null : _filteredNames[cellIndex - 1];
    final selected = isDefault ? _selected == null : _selected == name;
    return _IconCell(
      label: isDefault ? l10n.glassDockButtonIconDefault : name!,
      selected: selected,
      parsed: isDefault ? null : _parsedIcon(name!),
      onTap: () {
        _select(name);
        Navigator.pop(context);
      },
    );
  }
}

/// 图标格：矢量图标 + 名称小字；选中态描边主色。宽度由所在行 Expanded 决定
/// （不再写死 76），高度随行高居中。
class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.label,
    required this.selected,
    required this.onTap,
    this.parsed,
  });

  final String label;
  final bool selected;

  /// 预解析的扩展图标路径；null 时回退 Material 加号图标（默认格用）。
  final ({Path path, double viewport})? parsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final iconColor = selected ? primary : MiuixContentColor.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: _GlassDockIconPickerScreenState._iconSize,
              height: _GlassDockIconPickerScreenState._iconSize,
              child: parsed != null
                  ? CustomPaint(
                      painter: _CachedMiuixVectorPainter(
                        path: parsed!.path,
                        viewport: parsed!.viewport,
                        color: iconColor,
                      ),
                    )
                  : Icon(Icons.add_rounded, size: 22, color: iconColor),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                // 11 为字阶最小档：图标名微字不再新增字号刻度
                fontSize: 11,
                color: selected
                    ? primary
                    : HyperosColors.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 用预解析好的 [Path] 直接按目标尺寸绘制扩展图标。
///
/// 与 MiuixIcon（FittedBox + CustomPaint + saveLayer tint + 每帧
/// miuixParsePath）不同：路径已解析并烘焙翻转，paint 只做一次等比缩放和
/// 一次填色——扩展图标为单路径 alpha=1，直填颜色与 SrcIn tint 视觉等价，
/// 因此无需 saveLayer。shouldRepaint 仅在颜色变化时触发，滚动不重绘路径。
class _CachedMiuixVectorPainter extends CustomPainter {
  const _CachedMiuixVectorPainter({
    required this.path,
    required this.viewport,
    required this.color,
  });

  final Path path;

  /// 路径所在的视口边长（扩展图标视口为正方形）。
  final double viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport <= 0 || size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.scale(size.width / viewport);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CachedMiuixVectorPainter oldDelegate) {
    return oldDelegate.color != color || !identical(oldDelegate.path, path);
  }
}
