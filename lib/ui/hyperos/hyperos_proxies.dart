import 'package:flutter/material.dart';

/// Temporary compatibility widget until all FHeaderAction usages are
/// migrated to HyperosIconButton.
class FHeaderAction extends StatelessWidget {
  const FHeaderAction({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPress,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    IconData? iconData;
    if (icon is Icon) {
      iconData = (icon as Icon).icon;
    }
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        icon: iconData != null ? Icon(iconData) : icon,
        onPressed: onPress,
        tooltip: semanticsLabel,
      ),
    );
  }
}
