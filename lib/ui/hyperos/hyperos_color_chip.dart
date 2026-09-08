import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_radius.dart';
import 'hyperos_theme.dart';

/// Selectable color swatch for theme / appearance pickers.
class HyperosColorChip extends StatelessWidget {
  const HyperosColorChip({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 42,
    this.radius,
    this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  /// 色块下方的可选名称（主题名等）。用于区分肉眼几乎相同的近黑色 seed
  /// （中性灰/锌灰/石板灰）——仅靠色块三个摆在一起无法辨认。
  final String? label;

  /// Defaults to [HyperosRadius.chipRadius] for [size].
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = radius ?? HyperosRadius.chipRadius(size);
    final outline = selected
        ? HyperosColors.onSurface(context)
        : HyperosColors.outline(context);

    final Widget chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(cornerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(color: outline, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  color: _contrastIconColor(color),
                  size: size * 0.45,
                )
              : null,
        ),
      ),
    );
    final label = this.label;
    if (label == null) {
      return chip;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        const SizedBox(height: 4),
        SizedBox(
          width: size,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: selected
                  ? HyperosColors.primary(context)
                  : HyperosColors.onSurfaceVariantActions(context),
            ),
          ),
        ),
      ],
    );
  }

  static Color _contrastIconColor(Color background) {
    return background.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }
}

/// Wrap layout for [HyperosColorChip] rows inside control cards.
class HyperosColorChipGroup extends StatelessWidget {
  const HyperosColorChipGroup({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
    this.spacing = 12,
    this.runSpacing = 12,
    this.distributeHorizontally = true,
    this.columns,
    this.chipSize = 42,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;
  final double spacing;
  final double runSpacing;

  /// When true, each row spreads chips so left/right edge gaps match (Miuix card pickers).
  final bool distributeHorizontally;

  /// 固定列数：每行恰好 [columns] 颗并均分铺满可用宽度，各行节奏一致，
  /// 避免自动流式换行出现「上 6 下 4」的参差行。null 时保持自动流式；
  /// 可用宽度放不下目标列数（含最小间距）时也回退为自动流式。
  final int? columns;

  /// 色块边长。网格布局按它计算列距，同时透传给每颗 [HyperosColorChip]。
  final double chipSize;

  @override
  Widget build(BuildContext context) {
    return _hyperosColorChipLayout(
      columns: columns,
      chipSize: chipSize,
      spacing: spacing,
      runSpacing: runSpacing,
      distributeHorizontally: distributeHorizontally,
      children: [
        for (final color in colors)
          HyperosColorChip(
            color: color,
            selected: color.toARGB32() == selectedColor.toARGB32(),
            onTap: () => onSelected(color),
            size: chipSize,
          ),
      ],
    );
  }
}

/// Hex-string variant of [HyperosColorChipGroup].
class HyperosHexColorChipGroup extends StatelessWidget {
  const HyperosHexColorChipGroup({
    super.key,
    required this.colorHexes,
    required this.selectedHex,
    required this.onSelectedHex,
    required this.colorParser,
    this.spacing = 12,
    this.runSpacing = 12,
    this.distributeHorizontally = true,
    this.columns,
    this.chipSize = 42,
    this.labels,
  });

  final List<String> colorHexes;
  final String selectedHex;
  final ValueChanged<String> onSelectedHex;
  final Color Function(String hex) colorParser;
  final double spacing;
  final double runSpacing;
  final bool distributeHorizontally;

  /// See [HyperosColorChipGroup.columns].
  final int? columns;

  /// See [HyperosColorChipGroup.chipSize].
  final double chipSize;

  /// 与 [colorHexes] 等长（或 null）的每个色块名称；非空时色块下方
  /// 显示名字，用于区分肉眼几乎相同的深色 seed（中性灰/锌灰/石墨灰）。
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    return _hyperosColorChipLayout(
      columns: columns,
      chipSize: chipSize,
      spacing: spacing,
      runSpacing: runSpacing,
      distributeHorizontally: distributeHorizontally,
      children: [
        for (final (index, hex) in colorHexes.indexed)
          HyperosColorChip(
            color: colorParser(hex),
            selected: hex.toUpperCase() == selectedHex.toUpperCase(),
            onTap: () => onSelectedHex(hex),
            size: chipSize,
            label: labels != null ? labels![index] : null,
          ),
      ],
    );
  }
}

/// 按 [_hyperosColorChipWrap] 的规则排布；[columns] 非空时改为等分网格：
/// 每行恰好 columns 颗、按可用宽度均分列距，末行不足时保持同一列距左对齐。
Widget _hyperosColorChipLayout({
  required int? columns,
  required double chipSize,
  required double spacing,
  required double runSpacing,
  required bool distributeHorizontally,
  required List<Widget> children,
}) {
  if (columns == null || columns < 1) {
    return _hyperosColorChipWrap(
      distributeHorizontally: distributeHorizontally,
      spacing: spacing,
      runSpacing: runSpacing,
      children: children,
    );
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final neededWidth = columns * chipSize + (columns - 1) * spacing;
      if (children.isEmpty || maxWidth < neededWidth) {
        // 宽度不足以容纳目标列数（含最小间距）→ 回退自动流式换行。
        return _hyperosColorChipWrap(
          distributeHorizontally: distributeHorizontally,
          spacing: spacing,
          runSpacing: runSpacing,
          children: children,
        );
      }
      final gap = (maxWidth - columns * chipSize) / (columns - 1);
      final rows = <List<Widget>>[
        for (var i = 0; i < children.length; i += columns)
          children.sublist(i, math.min(i + columns, children.length)),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: runSpacing),
            Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) SizedBox(width: gap),
                  rows[r][c],
                ],
              ],
            ),
          ],
        ],
      );
    },
  );
}

Widget _hyperosColorChipWrap({
  required bool distributeHorizontally,
  required double spacing,
  required double runSpacing,
  required List<Widget> children,
}) {
  final wrap = Wrap(
    alignment: distributeHorizontally
        ? WrapAlignment.spaceBetween
        : WrapAlignment.start,
    spacing: spacing,
    runSpacing: runSpacing,
    children: children,
  );

  if (!distributeHorizontally) {
    return wrap;
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(width: constraints.maxWidth, child: wrap);
    },
  );
}
