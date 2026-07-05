import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';

/// Bottom sheet for picking an existing course group (reuse template / link exam).
Future<Course?> showCourseTemplatePickerSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<CourseGroup> courseGroups,
  String? selectedCourseId,
}) {
  if (courseGroups.isEmpty) {
    return Future.value(null);
  }

  return showFSheet<Course>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    mainAxisMaxRatio: null,
    builder: (sheetContext) => _CourseTemplatePickerSheetBody(
      title: title,
      subtitle: subtitle,
      courseGroups: courseGroups,
      selectedCourseId: selectedCourseId,
    ),
  );
}

class _CourseTemplatePickerSheetBody extends StatelessWidget {
  const _CourseTemplatePickerSheetBody({
    required this.title,
    this.subtitle,
    required this.courseGroups,
    this.selectedCourseId,
  });

  final String title;
  final String? subtitle;
  final List<CourseGroup> courseGroups;
  final String? selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final sheetBackground = colorScheme.surface;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.52;
    final descriptionStyle = typo.body.xs.copyWith(
      color: colors.mutedForeground,
      height: 1.4,
    );

    return Material(
      color: sheetBackground,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sheetBackground,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: SingleChildScrollView(
                    child: FTileGroup(
                      label: Text(title),
                      description: subtitle == null
                          ? null
                          : Text(
                              subtitle!,
                              maxLines: null,
                              overflow: TextOverflow.clip,
                              style: descriptionStyle,
                            ),
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final group in courseGroups)
                          _buildCourseTile(
                            context,
                            group: group,
                            isSelected: group.courses.any(
                              (course) => course.id == selectedCourseId,
                            ),
                            onPress: () =>
                                Navigator.pop(context, group.courses.first),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FButton(
                  variant: FButtonVariant.secondary,
                  onPress: () => Navigator.pop(context),
                  child: Text(l10n.cancelAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FTile _buildCourseTile(
    BuildContext context, {
    required CourseGroup group,
    required bool isSelected,
    required VoidCallback onPress,
  }) {
    final representative = group.courses.first;
    final courseColor = parseHexColorOrFallback(
      representative.color,
      fallback: Theme.of(context).colorScheme.primary,
    );

    return FTile(
      prefix: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: courseColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: courseColor, shape: BoxShape.circle),
        ),
      ),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      details: group.teacher.isNotEmpty
          ? Text(group.teacher, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      suffix: isSelected
          ? Icon(Icons.check_rounded, color: courseColor, size: 20)
          : Icon(
              Icons.chevron_right_rounded,
              color: context.theme.colors.mutedForeground,
              size: 20,
            ),
      onPress: onPress,
    );
  }
}
