import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

enum AppToastKind { info, success, warning, error }

const Duration _defaultToastDuration = Duration(seconds: 4);
const Duration _actionToastDuration = Duration(seconds: 8);

IconData _defaultIconForKind(AppToastKind kind) {
  return switch (kind) {
    AppToastKind.success => Icons.check_circle_outline_rounded,
    AppToastKind.warning => Icons.warning_amber_rounded,
    AppToastKind.error => Icons.error_outline_rounded,
    AppToastKind.info => Icons.info_outline_rounded,
  };
}

Color _iconColorForKind(BuildContext context, AppToastKind kind) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (kind) {
    AppToastKind.success =>
      isDark ? HyperosMiuixDarkColors.primary : const Color(0xFF047857),
    AppToastKind.warning =>
      isDark ? HyperosMiuixDarkColors.error : const Color(0xFFB45309),
    AppToastKind.error =>
      isDark ? HyperosMiuixDarkColors.error : HyperosMiuixLightColors.error,
    AppToastKind.info =>
      isDark ? HyperosMiuixDarkColors.primary : HyperosMiuixLightColors.primary,
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

/// Shows a transient HyperOS snackbar.
void showAppToast(
  BuildContext context, {
  required String message,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration? duration = _defaultToastDuration,
  IconData? icon,
}) {
  showHyperosRichSnackBar(
    context,
    message: message,
    description: description,
    icon: icon ?? _defaultIconForKind(kind),
    iconColor: _iconColorForKind(context, kind),
    duration: duration ?? _defaultToastDuration,
  );
}

/// Shows a snackbar with a trailing action button (e.g. undo, switch source).
void showAppToastWithAction(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration duration = _actionToastDuration,
}) {
  showHyperosRichSnackBar(
    context,
    message: message,
    description: description,
    icon: _defaultIconForKind(kind),
    iconColor: _iconColorForKind(context, kind),
    duration: duration,
    actionLabel: actionLabel,
    onAction: () {
      onAction();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    },
  );
}
