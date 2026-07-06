import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// Action button for [HyperosDialog] — text style, Miuix dialog pattern.
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

/// HyperOS / Miuix-styled alert dialog (title + summary + text actions).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
    final titleColor = isDark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onSurface;

    final content =
        body ??
        (message != null
            ? Text(message!, style: HyperosTypography.listDetail(context))
            : null);

    final viewSize = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxDialogHeight =
        (viewSize.height - viewInsets.vertical) -
        HyperosMiuixDialog.outsideMarginVertical * 2;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: HyperosMiuixDialog.outsideMarginHorizontal,
        vertical: HyperosMiuixDialog.outsideMarginVertical,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: HyperosMiuixDialog.maxWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Material(
          color: background,
          shape: HyperosTheme.cardShape(),
          clipBehavior: Clip.antiAlias,
          child: Padding(
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
                    style: HyperosTypography.title(
                      context,
                    ).copyWith(color: titleColor),
                  ),
                  SizedBox(height: HyperosMiuixDialog.titleBottomPadding),
                ],
                if (content != null) ...[
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle(
                        style: HyperosTypography.listDetail(context),
                        child: content,
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    SizedBox(height: HyperosMiuixDialog.summaryBottomPadding),
                ],
                if (actions.isNotEmpty)
                  _HyperosDialogActions(actions: actions, isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HyperosDialogActions extends StatelessWidget {
  const _HyperosDialogActions({required this.actions, required this.isDark});

  final List<HyperosDialogAction> actions;
  final bool isDark;

  Color _labelColor(HyperosDialogAction action) {
    if (action.isDestructive) {
      return isDark
          ? HyperosMiuixDarkColors.error
          : HyperosMiuixLightColors.error;
    }
    if (action.isPrimary) {
      return isDark
          ? HyperosMiuixDarkColors.primary
          : HyperosMiuixLightColors.primary;
    }
    return isDark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final action in actions)
            TextButton(
              onPressed: action.onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  HyperosMiuixButton.minWidth,
                  HyperosMiuixButton.minHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: _labelColor(action),
                textStyle: TextStyle(
                  fontSize: HyperosMiuixTypography.button,
                  fontWeight: action.isPrimary
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }
}

/// Shows a [HyperosDialog] with Miuix window dimming.
Future<T?> showHyperosDialog<T>({
  required BuildContext context,
  String? title,
  Widget? body,
  String? message,
  List<HyperosDialogAction>? actions,
  bool barrierDismissible = true,
  bool useRootNavigator = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final dimming = isDark
      ? HyperosMiuixDarkColors.windowDimming
      : HyperosMiuixLightColors.windowDimming;

  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierColor: dimming,
    builder: (ctx) => HyperosDialog(
      title: title,
      body: body,
      message: message,
      actions: actions ?? const [],
    ),
  );
}

/// Convenience confirm dialog — returns `true` when the primary action runs.
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
        onPressed: () => Navigator.of(context).pop(false),
      ),
      HyperosDialogAction(
        label: confirmLabel,
        isPrimary: !destructive,
        isDestructive: destructive,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
}
