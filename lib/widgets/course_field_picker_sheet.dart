import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

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
    final theme = context.theme;

    return FTile(
      prefix: Icon(icon),
      title: Text(label),
      details: Text(
        value,
        style: theme.typography.body.sm.copyWith(
          fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
          color: isPlaceholder ? theme.colors.mutedForeground : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Icon(
        Icons.chevron_right_rounded,
        color: theme.colors.mutedForeground,
      ),
      onPress: onPress,
    );
  }
}

/// Picker sheet with search + history chips, matching add-course flow.
Future<void> showCourseFieldPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> suggestions,
  required TextEditingController controller,
  VoidCallback? onConfirmed,
}) {
  final l10n = AppLocalizations.of(context)!;
  final originalText = controller.text;
  var confirmed = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final filtered = controller.text.isEmpty
              ? suggestions
              : suggestions.where((s) => s.contains(controller.text)).toList();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.theme.typography.body.lg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                FTextField(
                  control: FTextFieldControl.managed(controller: controller),
                  hint: l10n.manualInputLabel,
                  prefixBuilder: (context, style, variants) =>
                      const Icon(Icons.search),
                  suffixBuilder: controller.text.isNotEmpty
                      ? (context, style, variants) => IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: controller.clear,
                        )
                      : null,
                  onSubmit: (_) {
                    confirmed = true;
                    onConfirmed?.call();
                    Navigator.pop(sheetContext);
                  },
                ),
                if (filtered.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                    children: filtered.map((s) {
                      return ActionChip(
                        label: Text(s),
                        onPressed: () {
                          controller.text = s;
                          confirmed = true;
                          onConfirmed?.call();
                          Navigator.pop(sheetContext);
                        },
                      );
                    }).toList(),
                  ),
                ] else if (suggestions.isNotEmpty &&
                    controller.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.noHistoryRecords,
                    style: context.theme.typography.body.xs2.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FButton(
                    onPress: () {
                      confirmed = true;
                      onConfirmed?.call();
                      Navigator.pop(sheetContext);
                    },
                    child: Text(l10n.saveAction),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    if (!confirmed) {
      controller.text = originalText;
    }
  });
}
