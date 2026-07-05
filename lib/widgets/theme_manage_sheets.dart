import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';

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
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      title: Text(l10n.confirmDeleteTitle),
      body: Text(l10n.themeDeleteConfirmMessage(name)),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancelAction),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

Future<bool?> showThemeUnsavedChangesDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FDialog(
      image: const Icon(Icons.save_outlined),
      title: Text(l10n.themeUnsavedChangesTitle),
      body: Text(l10n.themeUnsavedChangesMessage),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.of(ctx).pop(null),
          child: Text(l10n.cancelAction),
        ),
        FButton(
          variant: FButtonVariant.secondary,
          onPress: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.themeSaveCurrent),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.themeDiscardAndApply),
        ),
      ],
    ),
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
  final typo = context.theme.typography.body;

  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    builder: (sheetContext) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                theme.name,
                style: typo.sm.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FTileGroup(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  FTile(
                    prefix: const Icon(Icons.drive_file_rename_outline),
                    title: Text(l10n.themeRename),
                    onPress: () {
                      Navigator.of(sheetContext).pop();
                      onRename();
                    },
                  ),
                  FTile(
                    prefix: const Icon(Icons.copy_all_outlined),
                    title: Text(l10n.themeDuplicate),
                    onPress: () {
                      Navigator.of(sheetContext).pop();
                      onDuplicate();
                    },
                  ),
                  FTile(
                    prefix: Icon(
                      Icons.delete_outline,
                      color: colors.destructive,
                    ),
                    title: Text(
                      l10n.themeDelete,
                      style: TextStyle(color: colors.destructive),
                    ),
                    onPress: () async {
                      Navigator.of(sheetContext).pop();
                      await onDelete();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
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
  final colors = context.theme.colors;
  final typo = context.theme.typography.body;
  final seedHex =
      config.seedColor ??
      (config.previewColors.isNotEmpty ? config.previewColors.first : null);

  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    builder: (sheetContext) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: typo.sm.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              FCard.raw(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                          if (config.themeMode != null)
                            const SizedBox(height: 8),
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  variant: FButtonVariant.primary,
                  onPress: () async {
                    final applied = await onApply();
                    if (applied && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  prefix: const Icon(Icons.palette_outlined, size: 18),
                  child: Text(l10n.themeApply),
                ),
              ),
            ],
          ),
        ),
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
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialName);

  return showFDialog<void>(
    context: context,
    builder: (dialogContext, style, animation) => FDialog(
      title: Text(title),
      body: FTextField(
        control: FTextFieldControl.managed(controller: controller),
        hint: l10n.themeNameHint,
        autofocus: true,
      ),
      actions: [
        FButton(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancelAction),
        ),
        FButton(
          variant: FButtonVariant.primary,
          onPress: () {
            final name = controller.text.trim();
            if (name.isEmpty) {
              return;
            }
            onSubmit(name);
            Navigator.of(dialogContext).pop();
          },
          child: Text(l10n.saveAction),
        ),
      ],
    ),
  );
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
