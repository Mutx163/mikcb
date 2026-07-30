import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// HyperOS segmented control layout variant — selects the Miuix tab row style.
enum HyperosTabRowStyle {
  /// Gray track + white sliding pill (Miuix `TabRowWithContour`).
  contour,

  /// Blue filled selected segment with bordered unselected tabs.
  bordered,
}

/// HyperOS segmented tab row — delegates to [MiuixTabRow] / [MiuixTabRowWithContour].
class HyperosTabRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty, 'HyperosTabRow requires at least one tab');
    assert(
      selectedIndex >= 0 && selectedIndex < tabs.length,
      'selectedIndex out of range',
    );

    final onTabSelected = enabled ? onChanged : (_) {};
    switch (style) {
      case HyperosTabRowStyle.bordered:
        return MiuixTabRow(
          tabs: tabs,
          selectedTabIndex: selectedIndex,
          onTabSelected: onTabSelected,
        );
      case HyperosTabRowStyle.contour:
        return MiuixTabRowWithContour(
          tabs: tabs,
          selectedTabIndex: selectedIndex,
          onTabSelected: onTabSelected,
        );
    }
  }
}

/// Alias for [HyperosTabRow] — common naming in settings screens.
typedef HyperosSegmentedControl = HyperosTabRow;
