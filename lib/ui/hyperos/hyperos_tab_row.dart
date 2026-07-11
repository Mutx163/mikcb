import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS segmented control layout variant.
enum HyperosTabRowStyle {
  /// Gray track + white sliding pill (Miuix `TabRowWithContour`).
  contour,

  /// Blue filled selected segment with bordered unselected tabs.
  bordered,
}

/// HyperOS / Miuix segmented tab row (pill-style segment control).
class HyperosTabRow extends StatefulWidget {
  const HyperosTabRow({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
    this.style = HyperosTabRowStyle.contour,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final HyperosTabRowStyle style;

  @override
  State<HyperosTabRow> createState() => _HyperosTabRowState();
}

/// Alias for [HyperosTabRow] — common naming in settings screens.
typedef HyperosSegmentedControl = HyperosTabRow;

class _HyperosTabRowState extends State<HyperosTabRow> {
  @override
  Widget build(BuildContext context) {
    assert(widget.tabs.isNotEmpty, 'HyperosTabRow requires at least one tab');
    assert(
      widget.selectedIndex >= 0 && widget.selectedIndex < widget.tabs.length,
      'selectedIndex out of range',
    );

    if (widget.style == HyperosTabRowStyle.bordered) {
      return _BorderedTabRow(
        tabs: widget.tabs,
        selectedIndex: widget.selectedIndex,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
      );
    }

    return _ContourTabRow(
      tabs: widget.tabs,
      selectedIndex: widget.selectedIndex,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
    );
  }
}

/// Miuix `TabRowWithContour`: gray track, white sliding indicator.
class _ContourTabRow extends StatelessWidget {
  const _ContourTabRow({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.enabled,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final trackColor = HyperosColors.surface(context);
    final pillColor = HyperosColors.surfaceContainer(context);
    final selectedText = HyperosColors.onBackground(context);
    final unselectedText = HyperosColors.onSurfaceVariantSummary(context);
    final disabledText = HyperosColors.disabledOnSurface(context);

    final padding = HyperosMiuixTabRow.contourPadding;
    final spacing = HyperosMiuixTabRow.contourItemSpacing;
    final outerRadius = HyperosMiuixTabRow.contourCornerRadius + padding;
    final innerRadius = HyperosMiuixTabRow.contourCornerRadius;

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - padding * 2;
        final tabWidth = tabs.isEmpty
            ? 0.0
            : (innerWidth - spacing * (tabs.length - 1)) / tabs.length;
        final indicatorLeft = selectedIndex * (tabWidth + spacing);

        return Container(
          height: HyperosMiuixTabRow.contourHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(outerRadius),
          ),
          padding: EdgeInsets.all(padding),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(
                  milliseconds: HyperosMiuixTabRow.indicatorAnimMs,
                ),
                curve: Curves.linear,
                left: indicatorLeft,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(innerRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < tabs.length; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    Expanded(
                      child: _ContourTabLabel(
                        label: tabs[i],
                        selected: i == selectedIndex,
                        enabled: enabled,
                        selectedColor: selectedText,
                        unselectedColor: unselectedText,
                        disabledColor: disabledText,
                        onTap: () {
                          if (!enabled || i == selectedIndex) return;
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContourTabLabel extends StatelessWidget {
  const _ContourTabLabel({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.selectedColor,
    required this.unselectedColor,
    required this.disabledColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color selectedColor;
  final Color unselectedColor;
  final Color disabledColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? disabledColor
        : (selected ? selectedColor : unselectedColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(
          HyperosMiuixTabRow.contourCornerRadius,
        ),
        child: SizedBox(
          height:
              HyperosMiuixTabRow.contourHeight -
              HyperosMiuixTabRow.contourPadding * 2,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: HyperosMiuixTypography.body2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BorderedTabRow extends StatelessWidget {
  const _BorderedTabRow({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    required this.enabled,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    final onPrimary = HyperosColors.onPrimary(context);
    final onSurface = HyperosColors.onSurface(context);
    final outline = HyperosColors.outline(context);
    final disabled = HyperosColors.disabledOnSurface(context);

    return SizedBox(
      height: HyperosMiuixTabRow.height,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: HyperosMiuixTabRow.itemSpacing),
            Expanded(
              child: _BorderedTabItem(
                label: tabs[i],
                selected: i == selectedIndex,
                enabled: enabled,
                primary: primary,
                onPrimary: onPrimary,
                onSurface: onSurface,
                outline: outline,
                disabled: disabled,
                onTap: () {
                  if (!enabled || i == selectedIndex) return;
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BorderedTabItem extends StatelessWidget {
  const _BorderedTabItem({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.outline,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color outline;
  final Color disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (enabled ? primary : disabled) : Colors.transparent;
    final fg = selected
        ? (enabled ? onPrimary : onPrimary.withValues(alpha: 0.6))
        : (enabled ? onSurface : disabled);
    final borderColor = selected
        ? Colors.transparent
        : (enabled ? outline : disabled.withValues(alpha: 0.5));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(HyperosMiuixTabRow.cornerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: HyperosMiuixTabRow.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              HyperosMiuixTabRow.cornerRadius,
            ),
            border: selected
                ? null
                : Border.all(
                    width: HyperosMiuixTabRow.unselectedBorderWidth,
                    color: borderColor,
                  ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: HyperosMiuixTabRow.itemHorizontalPadding,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: HyperosMiuixTypography.body2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
