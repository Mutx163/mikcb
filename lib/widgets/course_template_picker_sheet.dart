import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import '../ui/hyperos/hyperos.dart';

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

  return showHyperosSheet<Course>(
    context: context,
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
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.52;

    return HyperosSheetFrame(
      chrome: HyperosSheetChrome.floating,
      frosted: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: HyperosTypography.sheetTitle(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: HyperosTypography.sectionDescription(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
          HyperosButton(
            label: l10n.cancelAction,
            variant: HyperosButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTile(
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

    return HyperosChoiceTile(
      variant: HyperosChoiceVariant.dialog,
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
      title: group.name,
      subtitle: group.teacher.isNotEmpty
          ? Text(group.teacher, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      selected: isSelected,
      highlightSelectedText: true,
      onTap: onPress,
    );
  }
}
