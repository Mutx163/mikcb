import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS floating pill toolbar (Miuix `FloatingToolbar`).
class HyperosFloatingToolbar extends StatelessWidget {
  const HyperosFloatingToolbar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(
      horizontal: HyperosMiuixFloatingToolbar.outsidePaddingHorizontal,
      vertical: HyperosMiuixFloatingToolbar.outsidePaddingVertical,
    ),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.surfaceContainer;
    final divider = isDark
        ? HyperosMiuixDarkColors.dividerLine
        : HyperosMiuixLightColors.dividerLine;

    return Padding(
      padding: padding,
      child: Material(
        color: background,
        elevation: HyperosMiuixFloatingToolbar.defaultShadowElevation,
        shadowColor: Colors.black.withValues(
          alpha: HyperosMiuixFloatingToolbar.shadowAlpha,
        ),
        borderRadius: BorderRadius.circular(
          HyperosMiuixFloatingToolbar.cornerRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  VerticalDivider(
                    width: HyperosMiuixFloatingToolbar.dividerWidth,
                    thickness: HyperosMiuixFloatingToolbar.dividerWidth,
                    color: divider,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
