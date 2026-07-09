import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';

/// Bottom navigation item for [HyperosNavigationBar].
class HyperosNavigationDestination {
  const HyperosNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// HyperOS bottom navigation bar (Miuix `NavigationBar` dimensions).
class HyperosNavigationBar extends StatelessWidget {
  const HyperosNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<HyperosNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
    final selected = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final unselected = isDark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosMiuixLightColors.onSurfaceVariantActions;

    // Grow the bar with system font scaling so labels are not clipped by the
    // fixed Miuix height when accessibility text sizes are enabled.
    final scaledLabel = MediaQuery.textScalerOf(
      context,
    ).scale(HyperosMiuixNavigationBar.labelFontSize);
    final labelGrowth = (scaledLabel - HyperosMiuixNavigationBar.labelFontSize)
        .clamp(0.0, double.infinity);

    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: HyperosMiuixNavigationBar.itemHeight + labelGrowth * 1.5,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _HyperosNavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    selectedColor: selected,
                    unselectedColor: unselected,
                    onTap: () {
                      if (i == selectedIndex) return;
                      HapticFeedback.selectionClick();
                      onDestinationSelected(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HyperosNavItem extends StatelessWidget {
  const _HyperosNavItem({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final HyperosNavigationDestination destination;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: HyperosMiuixNavigationBar.iconSize,
              color: color,
            ),
            SizedBox(height: HyperosMiuixNavigationBar.iconTopPadding / 4),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: HyperosMiuixNavigationBar.labelFontSize,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
