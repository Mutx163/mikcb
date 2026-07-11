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
///
/// No-ops when [position] is null (anchor not mounted, see
/// [hyperosPopupPositionBelow]).
Future<T?> showHyperosListPopup<T>({
  required BuildContext context,
  required RelativeRect? position,
  required List<HyperosPopupMenuItem<T>> items,
}) {
  if (position == null) {
    return Future.value();
  }
  final surface = HyperosColors.surfaceContainer(context);

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
                  ? HyperosColors.error(context)
                  : (items[i].enabled
                        ? HyperosColors.onSurface(context)
                        : HyperosColors.disabledOnSurface(context)),
            ),
            child: Text(items[i].label),
          ),
        ),
    ],
  );
}

/// Anchor helper — positions popup below [anchorKey]'s render box.
///
/// Returns null when the anchor is not mounted / laid out yet; pass the result
/// straight to [showHyperosListPopup], which no-ops on null.
RelativeRect? hyperosPopupPositionBelow(
  BuildContext context,
  GlobalKey anchorKey, {
  double verticalGap = 4,
}) {
  final renderObject = anchorKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final size = renderObject.size;
  final screen = MediaQuery.sizeOf(context);

  return RelativeRect.fromLTRB(
    topLeft.dx,
    topLeft.dy + size.height + verticalGap,
    screen.width - topLeft.dx - size.width,
    screen.height - topLeft.dy - size.height - verticalGap,
  );
}
