import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS floating pill toolbar — delegates to [MiuixFloatingToolbar].
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
    return MiuixFloatingToolbar(
      outSidePadding: padding,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: HyperosMiuixFloatingToolbar.dividerWidth,
                  thickness: HyperosMiuixFloatingToolbar.dividerWidth,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
