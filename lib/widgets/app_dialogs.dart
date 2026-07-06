import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  bool destructiveConfirm = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosConfirmDialog(
    context: context,
    title: title,
    message: message,
    cancelLabel: cancelLabel ?? l10n.cancelAction,
    confirmLabel: confirmLabel ?? l10n.confirmImportAction,
    destructive: destructiveConfirm,
  );
}

Future<bool?> showAppConfirmDialogWithBody(
  BuildContext context, {
  required String title,
  required Widget body,
  String? cancelLabel,
  String? confirmLabel,
  bool destructiveConfirm = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosDialog<bool>(
    context: context,
    title: title,
    body: body,
    actions: [
      HyperosDialogAction(
        label: cancelLabel ?? l10n.cancelAction,
        onPressed: () => Navigator.pop(context, false),
      ),
      HyperosDialogAction(
        label: confirmLabel ?? l10n.confirmImportAction,
        isPrimary: !destructiveConfirm,
        isDestructive: destructiveConfirm,
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
}

/// Returns `null` for cancel, `false` for secondary, `true` for primary.
Future<bool?> showAppTripleActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String secondaryLabel,
  required String primaryLabel,
}) {
  return showHyperosDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      HyperosDialogAction(
        label: cancelLabel,
        onPressed: () => Navigator.pop(context),
      ),
      HyperosDialogAction(
        label: secondaryLabel,
        onPressed: () => Navigator.pop(context, false),
      ),
      HyperosDialogAction(
        label: primaryLabel,
        isPrimary: true,
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
}

Future<String?> showAppTextInputDialog(
  BuildContext context, {
  required String title,
  required Widget body,
  String? cancelLabel,
  String? confirmLabel,
  required String Function() readValue,
  bool Function(String value)? validate,
  bool useRootNavigator = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosDialog<String>(
    context: context,
    title: title,
    body: body,
    useRootNavigator: useRootNavigator,
    actions: [
      HyperosDialogAction(
        label: cancelLabel ?? l10n.cancelAction,
        onPressed: () => Navigator.pop(context),
      ),
      HyperosDialogAction(
        label: confirmLabel ?? l10n.saveAction,
        isPrimary: true,
        onPressed: () {
          final value = readValue().trim();
          if (validate != null && !validate(value)) {
            return;
          }
          Navigator.pop(context, value);
        },
      ),
    ],
  );
}

Future<int?> showAppSingleChoiceDialog(
  BuildContext context, {
  required String title,
  required List<String> options,
  int initialIndex = 0,
  String? cancelLabel,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  var selectedIndex = initialIndex.clamp(
    0,
    options.isEmpty ? 0 : options.length - 1,
  );

  return showDialog<int>(
    context: context,
    barrierColor: Theme.of(context).brightness == Brightness.dark
        ? HyperosMiuixDarkColors.windowDimming
        : HyperosMiuixLightColors.windowDimming,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return HyperosDialog(
            title: title,
            body: HyperosChoiceGroup(
              children: [
                for (var i = 0; i < options.length; i++)
                  HyperosChoiceTile(
                    title: options[i],
                    selected: selectedIndex == i,
                    highlightSelectedText: true,
                    onTap: () => setState(() => selectedIndex = i),
                  ),
              ],
            ),
            actions: [
              HyperosDialogAction(
                label: cancelLabel ?? l10n.cancelAction,
                onPressed: () => Navigator.pop(ctx),
              ),
              HyperosDialogAction(
                label: confirmLabel ?? l10n.saveAction,
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx, selectedIndex),
              ),
            ],
          );
        },
      );
    },
  );
}
