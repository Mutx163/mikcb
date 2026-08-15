// HyperOS 玻璃坞底部导航：胶囊形液态玻璃药丸 + 内部半透明高光滑块。
//
// 使用项目统一的液态玻璃材质（MikcbLiquidGlassTokens / superellipse 形状、
// HyperosLiquidGlassSurface 层策略），与弹窗、顶栏、菜单的玻璃效果完全一致；
// 不做 FakeGlass 降级包装。交互与 iOS 26 液态玻璃 Tab 一致：
// - 单击某项切换；
// - 长按后左右拖动，高光实时跟随手指，松手吸附到最近一项；
// - 滑块（高光）无描边无阴影，只有外层玻璃保留光学边缘；
// - 外层圆角 = 高度的一半（胶囊形），滑块圆角与外部一致。

import 'package:flutter/material.dart';

import 'hyperos_liquid_glass_surface.dart';

/// 单个玻璃坞 Tab 项。
class HyperosLiquidGlassTabBarItem {
  const HyperosLiquidGlassTabBarItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// 胶囊形液态玻璃 Tab 切换条（玻璃坞形态的底部导航）。
class HyperosLiquidGlassTabBar extends StatefulWidget {
  const HyperosLiquidGlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 52,
    this.iconSize = 22,
    this.activeColor,
    this.inactiveColor,
    this.highlightColor,
    this.labelStyle,
  });

  /// 至少两项。
  final List<HyperosLiquidGlassTabBarItem> items;

  /// 当前选中项；点击或拖动落位时通过 [onTap] 回调。
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// 药丸整体高度（外层圆角 = height / 2，胶囊形）。
  final double height;

  /// 图标尺寸。
  final double iconSize;

  /// 选中/高亮项的图标与文字颜色；默认主题 primary。
  final Color? activeColor;

  /// 未选中项的图标与文字颜色。
  final Color? inactiveColor;

  /// 滑块高光颜色；默认半透明白（不透明边框/阴影一律不画）。
  final Color? highlightColor;

  /// 文字样式；默认 9.5sp 半粗。
  final TextStyle? labelStyle;

  @override
  State<HyperosLiquidGlassTabBar> createState() =>
      _HyperosLiquidGlassTabBarState();
}

class _HyperosLiquidGlassTabBarState extends State<HyperosLiquidGlassTabBar> {
  /// 拖动中的对齐值（-1 最左 … 1 最右）；null 表示未在拖动。
  double? _dragAlignment;
  bool _isDragging = false;

  /// 拖动过程中被手指扫过的项（实时高光反馈）。
  int? _highlightedIndex;

  int get _lastIndex => widget.items.length - 1;

  double _getAlignment(int index) {
    if (_lastIndex <= 0) {
      return 0.0;
    }
    return -1.0 + (index * 2 / _lastIndex);
  }

  void _updateHighlightedIndex() {
    if (!_isDragging || _dragAlignment == null) {
      _highlightedIndex = null;
      return;
    }
    final normalized = (_dragAlignment! + 1) / 2;
    final index = (normalized * _lastIndex).round();
    _highlightedIndex = index.clamp(0, _lastIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? colorScheme.primary;
    final inactiveColor =
        widget.inactiveColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.62)
            : Colors.black.withValues(alpha: 0.48));
    final highlightColor =
        widget.highlightColor ?? Colors.white.withValues(alpha: 0.34);
    final labelStyle =
        widget.labelStyle ??
        TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          height: 1.1,
          color: isDark ? Colors.white : Colors.black,
        );
    final height = widget.height;
    final radius = height / 2;

    return HyperosLiquidGlassSurface(
      role: HyperosLiquidGlassRole.nestedTile,
      borderRadius: radius,
      contentLegibilityFill: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / widget.items.length;
          final totalDragWidth = constraints.maxWidth - itemWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _dragAlignment = _getAlignment(widget.currentIndex);
                _updateHighlightedIndex();
              });
            },
            onHorizontalDragUpdate: (details) {
              if (!_isDragging) {
                return;
              }
              setState(() {
                final deltaAlignment =
                    (details.primaryDelta! / totalDragWidth) * 2.0;
                _dragAlignment = (_dragAlignment! + deltaAlignment).clamp(
                  -1.0,
                  1.0,
                );
                _updateHighlightedIndex();
              });
            },
            onHorizontalDragEnd: (details) {
              setState(() {
                _isDragging = false;
                _highlightedIndex = null;
                final currentA = _dragAlignment!;
                final normalized = (currentA + 1) / 2;
                final nearestIndex = (normalized * _lastIndex).round();
                widget.onTap(nearestIndex);
              });
            },
            onHorizontalDragCancel: () {
              setState(() {
                _isDragging = false;
                _highlightedIndex = null;
              });
            },
            child: SizedBox(
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 高光滑块：圆角与外部胶囊一致，纯色无描边、无阴影。
                  AnimatedAlign(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      _isDragging
                          ? _dragAlignment!
                          : _getAlignment(widget.currentIndex),
                      0,
                    ),
                    child: Container(
                      width: itemWidth - 10,
                      height: height - 10,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: _GlassTabBarItemView(
                            icon: widget.items[i].icon,
                            label: widget.items[i].label,
                            isActive:
                                widget.currentIndex == i ||
                                _highlightedIndex == i,
                            isSelected: widget.currentIndex == i,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            iconSize: widget.iconSize,
                            labelStyle: labelStyle,
                            onTap: () => widget.onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassTabBarItemView extends StatelessWidget {
  const _GlassTabBarItemView({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.iconSize,
    required this.labelStyle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final double iconSize;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(icon, size: iconSize, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
