import 'package:flutter/material.dart';
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
    // Same chrome as [HyperosTextField] / [HyperosPickerField] so frosted sheets
    // do not get opaque white list-card islands.
    if (HyperosListTileScope.maybeOf(context) != null) {
      return HyperosListTile(
        icon: icon,
        title: label,
        details: isPlaceholder ? null : value,
        onTap: onPress,
      );
    }
    return HyperosPickerField(
      label: label,
      value: value,
      icon: icon,
      isPlaceholder: isPlaceholder,
      onTap: onPress,
    );
  }
}

/// 历史建议项过滤：**大小写不敏感**的子串匹配。
///
/// 教室与老师名常是中英混排（`A101`、`B-302`、拼音教师名），按原样 `contains`
/// 会让输入小写 `a101` 的人看到「无历史记录」——他会以为记录丢了，于是手打一份
/// 小写的存进去，同一个教室从此裂成两条（还往下影响楼栋聚类与场所统计）。
/// 仓内其余过滤都先归一侧大小写：`open_source_licenses_screen.dart:116`、
/// `settings_glass_dock_icon_editor.dart:82`、`warehouse_repository_models.dart:277/327`。
List<String> filterFieldSuggestions(List<String> suggestions, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return suggestions;
  }
  return suggestions
      .where((item) => item.toLowerCase().contains(normalized))
      .toList();
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
        final filtered = filterFieldSuggestions(suggestions, query);

        // Fixed-height sheet + lazy ListView. Never paint every suggestion as a
        // chip in one frame (uniqueLocations can be huge and freeze the UI).
        final viewInsets = MediaQuery.viewInsetsOf(context);
        final availableHeight =
            MediaQuery.sizeOf(context).height - viewInsets.bottom;
        final maxHeight = availableHeight * 0.72;

        return HyperosSheetFrame(
          maxHeight: maxHeight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: maxHeight - 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: HyperosTypography.sheetTitle(context)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: HyperosColors.secondaryText(context),
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
                const SizedBox(height: 10),
                Text(
                  l10n.historyRecordsLabel,
                  style: HyperosTypography.listDetail(context),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            l10n.noHistoryRecords,
                            style: HyperosTypography.listDetail(context),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final suggestion = filtered[index];
                            final selected = query == suggestion;
                            return Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: () {
                                  controller.text = suggestion;
                                  onConfirmed();
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(
                                  HyperosTokens.controlRadius,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    suggestion,
                                    style: HyperosTypography.listTitle(context)
                                        .copyWith(
                                          color: selected
                                              ? HyperosColors.primary(context)
                                              : null,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
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
              ],
            ),
          ),
        );
      },
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
    // showHyperosSheet already offsets the sheet by viewInsets.bottom; do not
    // add keyboard padding again here or the footer/content layout breaks.
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom;
    final maxHeight = availableHeight * 0.88;

    return HyperosSheetFrame(
      maxHeight: maxHeight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
