import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  FButtonVariant confirmVariant = FButtonVariant.primary,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      title: Text(title),
      body: Text(message),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel ?? l10n.cancelAction),
        ),
        FButton(
          variant: confirmVariant,
          onPress: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l10n.confirmImportAction),
        ),
      ],
    ),
  );
}

Future<bool?> showAppConfirmDialogWithBody(
  BuildContext context, {
  required String title,
  required Widget body,
  String? cancelLabel,
  String? confirmLabel,
  FButtonVariant confirmVariant = FButtonVariant.primary,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      title: Text(title),
      body: body,
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel ?? l10n.cancelAction),
        ),
        FButton(
          variant: confirmVariant,
          onPress: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l10n.confirmImportAction),
        ),
      ],
    ),
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
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      title: Text(title),
      body: Text(message),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(ctx),
          child: Text(cancelLabel),
        ),
        FButton(
          variant: FButtonVariant.secondary,
          onPress: () => Navigator.pop(ctx, false),
          child: Text(secondaryLabel),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: () => Navigator.pop(ctx, true),
          child: Text(primaryLabel),
        ),
      ],
    ),
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
}) {
  final l10n = AppLocalizations.of(context)!;
  return showFDialog<String>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      title: Text(title),
      body: body,
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(ctx),
          child: Text(cancelLabel ?? l10n.cancelAction),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: () {
            final value = readValue().trim();
            if (validate != null && !validate(value)) {
              return;
            }
            Navigator.pop(ctx, value);
          },
          child: Text(confirmLabel ?? l10n.saveAction),
        ),
      ],
    ),
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

  return showFDialog<int>(
    context: context,
    builder: (ctx, style, animation) => StatefulBuilder(
      builder: (context, setState) {
        return FDialog(
          title: Text(title),
          body: FTileGroup(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < options.length; i++)
                FTile(
                  title: Text(options[i]),
                  suffix: selectedIndex == i
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        )
                      : null,
                  onPress: () => setState(() => selectedIndex = i),
                ),
            ],
          ),
          actions: [
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () => Navigator.pop(ctx),
              child: Text(cancelLabel ?? l10n.cancelAction),
            ),
            FButton(
              variant: FButtonVariant.primary,
              onPress: () => Navigator.pop(ctx, selectedIndex),
              child: Text(confirmLabel ?? l10n.saveAction),
            ),
          ],
        );
      },
    ),
  );
}
