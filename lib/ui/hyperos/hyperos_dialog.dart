import 'package:flutter/material.dart';

import 'hyperos_controls.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_sheet.dart';
import 'hyperos_theme.dart';

/// Action button for [HyperosDialog] — maps to solid [HyperosButton] variants.
class HyperosDialogAction {
  const HyperosDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;
}

/// HyperOS bottom floating alert card (title + body + solid action buttons).
///
/// Uses [HyperosSheetFrame] frosted glass (sigma from 外观与配色 settings).
class HyperosDialog extends StatelessWidget {
  const HyperosDialog({
    super.key,
    this.title,
    this.body,
    this.message,
    this.actions = const [],
  });

  final String? title;
  final Widget? body;
  final String? message;
  final List<HyperosDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final detailStyle = HyperosTypography.listDetail(context);
    final Widget? content;
    if (body != null) {
      content = body;
    } else if (message != null) {
      content = Text(message!, textAlign: TextAlign.center, style: detailStyle);
    } else {
      content = null;
    }

    final maxCardHeight = MediaQuery.sizeOf(context).height * 0.72;
    final maxBodyHeight = maxCardHeight * 0.55;

    return HyperosSheetFrame(
      chrome: HyperosSheetChrome.floating,
      frosted: true,
      padding: const EdgeInsets.fromLTRB(
        HyperosMiuixDialog.insideMarginHorizontal,
        HyperosMiuixDialog.insideMarginVertical,
        HyperosMiuixDialog.insideMarginHorizontal,
        HyperosMiuixDialog.insideMarginVertical,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: HyperosTypography.sheetTitle(context),
            ),
            SizedBox(height: HyperosMiuixDialog.titleBottomPadding),
          ],
          if (content != null) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBodyHeight),
              child: SingleChildScrollView(
                child: DefaultTextStyle(
                  style: detailStyle,
                  textAlign: TextAlign.center,
                  child: content,
                ),
              ),
            ),
            if (actions.isNotEmpty)
              SizedBox(height: HyperosMiuixDialog.summaryBottomPadding + 8),
          ],
          if (actions.isNotEmpty) _HyperosDialogActions(actions: actions),
        ],
      ),
    );
  }
}

class _HyperosDialogActions extends StatelessWidget {
  const _HyperosDialogActions({required this.actions});

  final List<HyperosDialogAction> actions;

  HyperosButtonVariant _variantFor(HyperosDialogAction action) {
    if (action.isDestructive) {
      return HyperosButtonVariant.destructive;
    }
    if (action.isPrimary) {
      return HyperosButtonVariant.primary;
    }
    return HyperosButtonVariant.secondary;
  }

  Widget _button(HyperosDialogAction action) {
    return HyperosButton(
      label: action.label,
      variant: _variantFor(action),
      expand: true,
      fitLabel: true,
      onPressed: action.onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) {
      return _button(actions.first);
    }

    if (actions.length == 2) {
      return Row(
        children: [
          Expanded(child: _button(actions[0])),
          const SizedBox(width: 12),
          Expanded(child: _button(actions[1])),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _button(actions[index]),
        ],
      ],
    );
  }
}

/// Shows a HyperOS bottom floating alert (sheet), not a center Material dialog.
Future<T?> showHyperosDialog<T>({
  required BuildContext context,
  String? title,
  Widget? body,
  String? message,
  List<HyperosDialogAction>? actions,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  return showHyperosSheet<T>(
    context: context,
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: HyperosColors.windowDimming(context),
    builder: (sheetContext) => HyperosDialog(
      title: title,
      body: body,
      message: message,
      actions: actions ?? const [],
    ),
  );
}

/// Convenience confirm sheet — returns `true` when the primary action runs.
Future<bool?> showHyperosConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? body,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return showHyperosDialog<bool>(
    context: context,
    title: title,
    message: message,
    body: body,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    actions: [
      HyperosDialogAction(
        label: cancelLabel,
        onPressed: () => navigator.pop(false),
      ),
      HyperosDialogAction(
        label: confirmLabel,
        isPrimary: !destructive,
        isDestructive: destructive,
        onPressed: () => navigator.pop(true),
      ),
    ],
  );
}
