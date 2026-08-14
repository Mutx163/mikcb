import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixBadge;
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

enum HomeTopMenuAction {
  update,
  overview,
  statistics,
  addCourse,
  exams,
  importCourses,
  tasks,
  settings,
  support,
}

/// Shows the home screen top-right action menu as a small anchored Miuix list
/// popup — the same chrome as every other anchored popup in the app: spring
/// reveal, glass surface, tap-outside to dismiss.
///
/// [anchorKey] must be the key of the top-right "more" button; the popup is
/// positioned just below it via [hyperosPopupPositionBelow].
Future<HomeTopMenuAction?> showHomeTopMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
  required GlobalKey anchorKey,
  Color? foregroundColor,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
  final position = hyperosPopupPositionBelow(context, anchorKey);

  HyperosPopupMenuItem<HomeTopMenuAction> item({
    required IconData icon,
    required String title,
    required HomeTopMenuAction action,
    Color? iconColor,
    Widget? trailing,
    bool gapBefore = false,
  }) {
    return HyperosPopupMenuItem<HomeTopMenuAction>(
      label: title,
      value: action,
      icon: icon,
      iconColor: iconColor,
      trailing: trailing,
      gapBefore: gapBefore,
    );
  }

  return showHyperosListPopup<HomeTopMenuAction>(
    context: context,
    position: position,
    foregroundColor: foregroundColor,
    items: [
      item(
        icon: Icons.system_update_alt_rounded,
        title: l10n.homeMenuUpdateTitle,
        action: HomeTopMenuAction.update,
        iconColor: hasAvailableUpdate ? colorScheme.primary : null,
        trailing: hasAvailableUpdate ? const MiuixBadge() : null,
      ),
      item(
        icon: Icons.dashboard_customize_rounded,
        title: l10n.homeMenuOverviewTitle,
        action: HomeTopMenuAction.overview,
      ),
      item(
        icon: Icons.bar_chart_rounded,
        title: l10n.homeMenuStatisticsTitle,
        action: HomeTopMenuAction.statistics,
      ),
      item(
        icon: Icons.add_circle_outline_rounded,
        title: l10n.homeMenuAddCourseTitle,
        action: HomeTopMenuAction.addCourse,
      ),
      item(
        icon: Icons.school_outlined,
        title: l10n.examListTitle,
        action: HomeTopMenuAction.exams,
      ),
      item(
        icon: Icons.file_upload_outlined,
        title: l10n.homeMenuImportTitle,
        action: HomeTopMenuAction.importCourses,
      ),
      item(
        icon: Icons.task_alt_outlined,
        title: l10n.homeMenuTasksTitle,
        action: HomeTopMenuAction.tasks,
        gapBefore: true,
      ),
      item(
        icon: Icons.tune_rounded,
        title: l10n.homeMenuSettingsTitle,
        action: HomeTopMenuAction.settings,
      ),
      item(
        icon: Icons.favorite_border_rounded,
        title: l10n.homeMenuCoffeeTitle,
        action: HomeTopMenuAction.support,
      ),
    ],
  );
}
