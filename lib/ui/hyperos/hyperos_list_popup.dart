import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Single item in [showHyperosListPopup].
class HyperosPopupMenuItem<T> {
  const HyperosPopupMenuItem({
    required this.label,
    required this.value,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final T value;
  final bool destructive;
  final bool enabled;
}

/// Shows a Miuix-styled anchored list popup (ListPopup / OverlayListPopup).
Future<T?> showHyperosListPopup<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<HyperosPopupMenuItem<T>> items,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark
      ? HyperosMiuixDarkColors.surfaceContainer
      : HyperosMiuixLightColors.surfaceContainer;

  return showMenu<T>(
    context: context,
    position: position,
    color: surface,
    shape: HyperosTheme.cardShape(),
    elevation: 4,
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem<T>(
          enabled: items[i].enabled,
          value: items[i].value,
          height: HyperosMiuixBasicComponent.minHeight,
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: HyperosMiuixTypography.body1,
              color: items[i].destructive
                  ? (isDark
                        ? HyperosMiuixDarkColors.error
                        : HyperosMiuixLightColors.error)
                  : (items[i].enabled
                        ? (isDark
                              ? HyperosMiuixDarkColors.onSurface
                              : HyperosMiuixLightColors.onSurface)
                        : (isDark
                              ? HyperosMiuixDarkColors.disabledOnSurface
                              : HyperosMiuixLightColors.disabledOnSurface)),
            ),
            child: Text(items[i].label),
          ),
        ),
    ],
  );
}

/// Anchor helper — positions popup below [anchorKey]'s render box.
RelativeRect hyperosPopupPositionBelow(
  BuildContext context,
  GlobalKey anchorKey, {
  double verticalGap = 4,
}) {
  final box = anchorKey.currentContext!.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero);
  final size = box.size;
  final screen = MediaQuery.sizeOf(context);

  return RelativeRect.fromLTRB(
    topLeft.dx,
    topLeft.dy + size.height + verticalGap,
    screen.width - topLeft.dx - size.width,
    screen.height - topLeft.dy - size.height - verticalGap,
  );
}
