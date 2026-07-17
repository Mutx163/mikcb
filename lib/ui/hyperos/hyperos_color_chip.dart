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
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  /// Defaults to [HyperosRadius.chipRadius] for [size].
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = radius ?? HyperosRadius.chipRadius(size);
    final outline = selected
        ? HyperosColors.onSurface(context)
        : HyperosColors.outline(context);

    return Material(
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
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;
  final double spacing;
  final double runSpacing;

  /// When true, each row spreads chips so left/right edge gaps match (Miuix card pickers).
  final bool distributeHorizontally;

  @override
  Widget build(BuildContext context) {
    return _hyperosColorChipWrap(
      distributeHorizontally: distributeHorizontally,
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final color in colors)
          HyperosColorChip(
            color: color,
            selected: color.toARGB32() == selectedColor.toARGB32(),
            onTap: () => onSelected(color),
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
  });

  final List<String> colorHexes;
  final String selectedHex;
  final ValueChanged<String> onSelectedHex;
  final Color Function(String hex) colorParser;
  final double spacing;
  final double runSpacing;
  final bool distributeHorizontally;

  @override
  Widget build(BuildContext context) {
    return _hyperosColorChipWrap(
      distributeHorizontally: distributeHorizontally,
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final hex in colorHexes)
          HyperosColorChip(
            color: colorParser(hex),
            selected: hex.toUpperCase() == selectedHex.toUpperCase(),
            onTap: () => onSelectedHex(hex),
          ),
      ],
    );
  }
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
    runAlignment: WrapAlignment.start,
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
