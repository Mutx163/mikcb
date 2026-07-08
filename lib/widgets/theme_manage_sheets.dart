import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/app_dialogs.dart';

String themeConfigModeLabel(BuildContext context, String? mode) {
  final l10n = AppLocalizations.of(context)!;
  switch (mode) {
    case 'light':
      return l10n.themeModeLight;
    case 'dark':
      return l10n.themeModeDark;
    case 'system':
    default:
      return l10n.themeModeSystem;
  }
}

void showThemeFeedbackToast(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  AppToastKind kind = AppToastKind.info,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (onUndo != null) {
    showAppToastWithAction(
      context,
      message: message,
      actionLabel: l10n.themeUndo,
      onAction: onUndo,
      kind: kind,
    );
    return;
  }
  showAppToast(context, message: message, kind: kind);
}

Future<bool> showThemeDeleteConfirmDialog(
  BuildContext context, {
  required String name,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHyperosConfirmDialog(
    context: context,
    title: l10n.confirmDeleteTitle,
    message: l10n.themeDeleteConfirmMessage(name),
    cancelLabel: l10n.cancelAction,
    confirmLabel: l10n.deleteAction,
    destructive: true,
  ).then((value) => value ?? false);
}

Future<bool?> showThemeUnsavedChangesDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppTripleActionDialog(
    context,
    title: l10n.themeUnsavedChangesTitle,
    message: l10n.themeUnsavedChangesMessage,
    cancelLabel: l10n.cancelAction,
    secondaryLabel: l10n.themeSaveCurrent,
    primaryLabel: l10n.themeDiscardAndApply,
  );
}

Future<void> showSavedThemeActionSheet(
  BuildContext context, {
  required SavedTheme theme,
  required VoidCallback onRename,
  required VoidCallback onDuplicate,
  required Future<void> Function() onDelete,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colors = context.theme.colors;

  return showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => HyperosSheet(
      title: theme.name,
      child: HyperosChoiceGroup(
        children: [
          HyperosChoiceTile(
            prefix: const Icon(Icons.drive_file_rename_outline),
            title: l10n.themeRename,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onRename();
            },
          ),
          HyperosChoiceTile(
            prefix: const Icon(Icons.copy_all_outlined),
            title: l10n.themeDuplicate,
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDuplicate();
            },
          ),
          HyperosChoiceTile(
            prefix: Icon(Icons.delete_outline, color: colors.destructive),
            title: l10n.themeDelete,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await onDelete();
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showSavedThemePreviewSheet(
  BuildContext context, {
  required String name,
  required ThemeConfig config,
  required Future<bool> Function() onApply,
}) {
  final l10n = AppLocalizations.of(context)!;
  final seedHex =
      config.seedColor ??
      (config.previewColors.isNotEmpty ? config.previewColors.first : null);

  return showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => HyperosSheet(
      title: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThemePreviewSwatches(colors: config.previewColors),
                if (config.themeMode != null || seedHex != null) ...[
                  const SizedBox(height: 16),
                  if (config.themeMode != null)
                    _ThemePreviewInfoRow(
                      label: l10n.themeModeLabel,
                      value: themeConfigModeLabel(
                        sheetContext,
                        config.themeMode,
                      ),
                    ),
                  if (seedHex != null) ...[
                    if (config.themeMode != null) const SizedBox(height: 8),
                    _ThemePreviewInfoRow(
                      label: l10n.themeSeedSectionTitle,
                      value: seedHex,
                      leading: ThemeColorDot(hex: seedHex, size: 16),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          HyperosButton(
            label: l10n.themeApply,
            expand: true,
            onPressed: () async {
              final applied = await onApply();
              if (applied && sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
          ),
        ],
      ),
    ),
  );
}

class ThemeColorDot extends StatelessWidget {
  const ThemeColorDot({super.key, required this.hex, this.size = 14});

  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.colors.border;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: parseHexColorOrFallback(
          hex,
          fallback: context.theme.colors.primary,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 0.5),
      ),
    );
  }
}

class ThemePreviewSwatches extends StatelessWidget {
  const ThemePreviewSwatches({super.key, required this.colors});

  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    final borderColor = context.theme.colors.border;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: parseHexColorOrFallback(
              hex,
              fallback: context.theme.colors.primary,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
        );
      }).toList(),
    );
  }
}

class ThemePreviewDots extends StatelessWidget {
  const ThemePreviewDots({super.key, required this.colors});

  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hex in colors.take(4)) ...[
          ThemeColorDot(hex: hex),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ThemePreviewInfoRow extends StatelessWidget {
  const _ThemePreviewInfoRow({
    required this.label,
    required this.value,
    this.leading,
  });

  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: typo.xs2.copyWith(color: colors.mutedForeground)),
        const SizedBox(width: 8),
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Expanded(
          child: Text(
            value,
            style: typo.xs2.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

Future<void> showThemeNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required void Function(String name) onSubmit,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final name = await showAppTextInputDialog(
    context,
    title: title,
    initialValue: initialName,
    bodyBuilder: (controller) => HyperosTextField(
      controller: controller,
      hint: l10n.themeNameHint,
      autofocus: true,
    ),
    validate: (value) => value.isNotEmpty,
  );
  if (name != null) {
    onSubmit(name);
  }
}

bool isSavedThemeSelected(TimetableSettings settings, SavedTheme theme) {
  return settings.themeCheckpointName == theme.name &&
      !settings.hasThemeModifications;
}

String savedThemeSeedHex(SavedTheme theme) {
  return theme.config.seedColor ??
      (theme.config.previewColors.isNotEmpty
          ? theme.config.previewColors.first
          : '#6366F1');
}

Future<bool> confirmApplyThemeWithUnsavedCheck(
  BuildContext context, {
  required VoidCallback onSaveRequested,
}) async {
  final provider = context.read<TimetableProvider>();
  if (!provider.settings.hasThemeModifications) {
    return true;
  }

  final decision = await showThemeUnsavedChangesDialog(context);
  if (!context.mounted) {
    return false;
  }
  if (decision == null) {
    return false;
  }
  if (decision == false) {
    onSaveRequested();
    return false;
  }
  return true;
}
