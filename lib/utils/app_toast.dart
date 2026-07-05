import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum AppToastKind { info, success, warning, error }

const Duration _defaultToastDuration = Duration(seconds: 4);
const Duration _actionToastDuration = Duration(seconds: 8);

FToastVariant _variantForKind(AppToastKind kind) {
  return switch (kind) {
    AppToastKind.error => FToastVariant.destructive,
    _ => FToastVariant.primary,
  };
}

IconData _defaultIconForKind(AppToastKind kind) {
  return switch (kind) {
    AppToastKind.success => Icons.check_circle_outline_rounded,
    AppToastKind.warning => Icons.warning_amber_rounded,
    AppToastKind.error => Icons.error_outline_rounded,
    AppToastKind.info => Icons.info_outline_rounded,
  };
}

/// Short transient toast for lightweight validation hints.
void showAppLightTip(
  BuildContext context, {
  required String message,
  AppToastKind kind = AppToastKind.info,
}) {
  if (message.trim().isEmpty) {
    return;
  }
  showAppToast(
    context,
    message: message,
    kind: kind,
    duration: const Duration(seconds: 2),
  );
}

/// Shows a transient Forui toast. Requires [FToaster] above this context.
void showAppToast(
  BuildContext context, {
  required String message,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration? duration = _defaultToastDuration,
  IconData? icon,
}) {
  showFToast(
    context: context,
    variant: _variantForKind(kind),
    icon: Icon(icon ?? _defaultIconForKind(kind), size: 18),
    title: Text(message),
    description: description == null ? null : Text(description),
    duration: duration,
  );
}

/// Shows a toast with a trailing action button (e.g. undo, switch source).
void showAppToastWithAction(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration duration = _actionToastDuration,
}) {
  showFToast(
    context: context,
    variant: _variantForKind(kind),
    icon: Icon(_defaultIconForKind(kind), size: 18),
    title: Text(message),
    description: description == null ? null : Text(description),
    duration: duration,
    suffixBuilder: (ctx, entry) => IntrinsicHeight(
      child: FButton(
        variant: FButtonVariant.secondary,
        onPress: () {
          onAction();
          entry.dismiss();
        },
        child: Text(actionLabel),
      ),
    ),
  );
}
