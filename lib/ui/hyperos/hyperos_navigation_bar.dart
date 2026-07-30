import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

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

/// HyperOS bottom navigation bar — delegates to [MiuixNavigationBar].
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
    return MiuixNavigationBar(
      children: [
        for (var i = 0; i < destinations.length; i++)
          MiuixNavigationBarItem(
            selected: i == selectedIndex,
            onPressed: i == selectedIndex
                ? null
                : () => onDestinationSelected(i),
            icon: Icon(
              i == selectedIndex
                  ? destinations[i].selectedIcon
                  : destinations[i].icon,
            ),
            label: destinations[i].label,
          ),
      ],
    );
  }
}
