import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

SnackBar _buildHyperosSnackBar({
  required BuildContext context,
  required Widget content,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(
    milliseconds: HyperosMiuixSnackbar.durationShortMs,
  ),
}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: HyperosColors.inverseSurface(context),
    elevation: HyperosMiuixSnackbar.shadowRadius,
    margin: const EdgeInsets.fromLTRB(
      HyperosMiuixSnackbar.outerPaddingHorizontal,
      HyperosMiuixSnackbar.outerPaddingTop,
      HyperosMiuixSnackbar.outerPaddingHorizontal,
      HyperosMiuixSnackbar.hostBottomPadding,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HyperosMiuixSnackbar.cornerRadius),
    ),
    content: content,
    duration: duration,
    action: actionLabel != null && onAction != null
        ? SnackBarAction(
            label: actionLabel,
            textColor: HyperosColors.primary(context),
            onPressed: onAction,
          )
        : null,
  );
}

TextStyle _messageStyle(BuildContext context) {
  return TextStyle(
    fontSize: HyperosMiuixTypography.body2,
    fontWeight: FontWeight.w500,
    color: HyperosColors.onInverseSurface(context),
  );
}

TextStyle _descriptionStyle(BuildContext context) {
  final onBackground = HyperosColors.onInverseSurface(context);
  return TextStyle(
    fontSize: HyperosMiuixTypography.footnote1,
    height: 1.5,
    color: onBackground.withValues(alpha: 0.78),
  );
}

/// Shows a HyperOS-styled snackbar via [ScaffoldMessenger].
void showHyperosSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(
    milliseconds: HyperosMiuixSnackbar.durationShortMs,
  ),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _buildHyperosSnackBar(
      context: context,
      content: Text(message, style: _messageStyle(context)),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );
}

/// Rich snackbar with optional icon and secondary line (app toast pattern).
void showHyperosRichSnackBar(
  BuildContext context, {
  required String message,
  String? description,
  IconData? icon,
  Color? iconColor,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(
    milliseconds: HyperosMiuixSnackbar.durationShortMs,
  ),
}) {
  final defaultIconColor = HyperosColors.onInverseSurface(context);

  final content = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: iconColor ?? defaultIconColor),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: _messageStyle(context)),
            if (description != null) ...[
              const SizedBox(height: HyperosTokens.titleCaptionGap),
              Text(description, style: _descriptionStyle(context)),
            ],
          ],
        ),
      ),
    ],
  );

  ScaffoldMessenger.of(context).showSnackBar(
    _buildHyperosSnackBar(
      context: context,
      content: content,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );
}

/// HyperOS-styled snackbar widget (for custom [ScaffoldMessenger] hosts).
class HyperosSnackBar extends SnackBar {
  HyperosSnackBar({
    super.key,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    super.duration = const Duration(
      milliseconds: HyperosMiuixSnackbar.durationShortMs,
    ),
    required BuildContext context,
  }) : super(
         behavior: SnackBarBehavior.floating,
         backgroundColor: HyperosColors.inverseSurface(context),
         elevation: HyperosMiuixSnackbar.shadowRadius,
         margin: const EdgeInsets.fromLTRB(
           HyperosMiuixSnackbar.outerPaddingHorizontal,
           HyperosMiuixSnackbar.outerPaddingTop,
           HyperosMiuixSnackbar.outerPaddingHorizontal,
           HyperosMiuixSnackbar.hostBottomPadding,
         ),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(
             HyperosMiuixSnackbar.cornerRadius,
           ),
         ),
         content: Text(message, style: _messageStyle(context)),
         action: actionLabel != null && onAction != null
             ? SnackBarAction(
                 label: actionLabel,
                 textColor: HyperosColors.primary(context),
                 onPressed: onAction,
               )
             : null,
       );
}
