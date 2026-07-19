import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

enum AppToastKind { info, success, warning, error }

const Duration _defaultToastDuration = Duration(
  milliseconds: HyperosMiuixSnackbar.durationShortMs,
);
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
  return switch (kind) {
    AppToastKind.success => const Color(0xFF047857),
    AppToastKind.warning => const Color(0xFFB45309),
    AppToastKind.error => HyperosColors.error(context),
    AppToastKind.info => HyperosColors.primary(context),
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

/// Shows a transient HyperOS system-style frosted toast.
///
/// Milky frosted shell + black regular label. Insets: 2 字 left/right,
/// 1 字 top/bottom (≈ 3 字 high single-line shell). Content width, no swipe
/// dismiss, auto-hide.
///
/// Icons are omitted by default so single-line height matches system toast;
/// pass [icon] or [showKindIcon] when a leading glyph is required.
void showAppToast(
  BuildContext context, {
  required String message,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration? duration = _defaultToastDuration,
  IconData? icon,
  bool showKindIcon = false,
}) {
  final resolvedIcon =
      icon ?? (showKindIcon ? _defaultIconForKind(kind) : null);
  showHyperosRichSnackBar(
    context,
    message: message,
    description: description,
    icon: resolvedIcon,
    iconColor: resolvedIcon == null ? null : _iconColorForKind(context, kind),
    duration: duration ?? _defaultToastDuration,
  );
}

/// Shows a frosted toast with a trailing action label (e.g. undo).
void showAppToastWithAction(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  String? description,
  AppToastKind kind = AppToastKind.info,
  Duration duration = _actionToastDuration,
  bool showKindIcon = false,
}) {
  final resolvedIcon = showKindIcon ? _defaultIconForKind(kind) : null;
  showHyperosRichSnackBar(
    context,
    message: message,
    description: description,
    icon: resolvedIcon,
    iconColor: resolvedIcon == null ? null : _iconColorForKind(context, kind),
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
