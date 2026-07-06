import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Tappable row that opens [showCourseFieldPickerSheet].
class CourseFieldPickerTile extends StatelessWidget {
  const CourseFieldPickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onPress,
    this.isPlaceholder = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPress;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return HyperosListTile(
      icon: icon,
      title: label,
      details: isPlaceholder ? null : value,
      onTap: onPress,
    );
  }
}

/// Picker sheet with search + history chips, using Forui bottom sheet styling.
Future<void> showCourseFieldPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> suggestions,
  required TextEditingController controller,
  VoidCallback? onConfirmed,
}) {
  final originalText = controller.text;
  var confirmed = false;

  void markConfirmed() {
    confirmed = true;
    onConfirmed?.call();
  }

  return showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => _CourseFieldPickerSheetBody(
      title: title,
      suggestions: suggestions,
      controller: controller,
      onConfirmed: markConfirmed,
    ),
  ).whenComplete(() {
    if (!confirmed) {
      controller.text = originalText;
    }
  });
}

class _CourseFieldPickerSheetBody extends StatelessWidget {
  const _CourseFieldPickerSheetBody({
    required this.title,
    required this.suggestions,
    required this.controller,
    required this.onConfirmed,
  });

  final String title;
  final List<String> suggestions;
  final TextEditingController controller;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final query = controller.text.trim();
        final filtered = query.isEmpty
            ? suggestions
            : suggestions.where((s) => s.contains(query)).toList();

        return PickerSheetScaffold(
          actions: Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.cancelAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HyperosButton(
                  label: l10n.saveAction,
                  expand: true,
                  onPressed: () {
                    onConfirmed();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: HyperosTypography.sheetTitle(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color: context.theme.colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: HyperosTextField(
                      controller: controller,
                      hint: l10n.manualInputLabel,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        onConfirmed();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: controller.clear,
                    ),
                ],
              ),
              if (filtered.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.historyRecordsLabel,
                  style: context.theme.typography.body.xs2.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in filtered)
                      _HistorySuggestionChip(
                        label: suggestion,
                        selected: query == suggestion,
                        onSelected: () {
                          controller.text = suggestion;
                          onConfirmed();
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ] else if (suggestions.isNotEmpty && query.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.noHistoryRecords,
                  style: context.theme.typography.body.xs2.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistorySuggestionChip extends StatelessWidget {
  const _HistorySuggestionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = selected ? colorScheme.primary : colors.foreground;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? highlight.withValues(alpha: 0.14)
                : colors.muted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? highlight.withValues(alpha: 0.45)
                  : colors.border,
            ),
          ),
          child: Text(
            label,
            style: typo.xs2.copyWith(
              color: highlight,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared bottom-sheet scaffold: scrollable body + pinned footer actions.
class PickerSheetScaffold extends StatelessWidget {
  const PickerSheetScaffold({
    super.key,
    required this.child,
    required this.actions,
  });

  final Widget child;
  final Widget actions;

  static const _footerHeight = 48.0;
  static const _footerGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return HyperosSheetFrame(
      maxHeight: maxHeight,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: _footerHeight + _footerGap,
                  ),
                  child: child,
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: actions),
              ],
            ),
          );
        },
      ),
    );
  }
}
