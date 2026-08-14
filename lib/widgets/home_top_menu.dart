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
/// Rows are plain text only, matching the MIUI/HyperOS top-right menu
/// convention (icons are reserved for in-page actions, not overflow menus).
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
  final position = hyperosPopupPositionBelow(context, anchorKey);

  HyperosPopupMenuItem<HomeTopMenuAction> item({
    required String title,
    required HomeTopMenuAction action,
    Widget? trailing,
    bool gapBefore = false,
  }) {
    return HyperosPopupMenuItem<HomeTopMenuAction>(
      label: title,
      value: action,
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
        title: l10n.homeMenuUpdateTitle,
        action: HomeTopMenuAction.update,
        // The trailing dot badge marks the pending update; rows stay text
        // only so the wallpaper-aware ink keeps the menu uniform.
        trailing: hasAvailableUpdate ? const MiuixBadge() : null,
      ),
      item(
        title: l10n.homeMenuOverviewTitle,
        action: HomeTopMenuAction.overview,
      ),
      item(
        title: l10n.homeMenuStatisticsTitle,
        action: HomeTopMenuAction.statistics,
      ),
      item(
        title: l10n.homeMenuAddCourseTitle,
        action: HomeTopMenuAction.addCourse,
      ),
      item(
        title: l10n.examListTitle,
        action: HomeTopMenuAction.exams,
      ),
      item(
        title: l10n.homeMenuImportTitle,
        action: HomeTopMenuAction.importCourses,
      ),
      item(
        title: l10n.homeMenuTasksTitle,
        action: HomeTopMenuAction.tasks,
        gapBefore: true,
      ),
      item(
        title: l10n.homeMenuSettingsTitle,
        action: HomeTopMenuAction.settings,
      ),
      item(
        title: l10n.homeMenuCoffeeTitle,
        action: HomeTopMenuAction.support,
      ),
    ],
  );
}
