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

/// Shows the home screen top-right action menu as a Miuix list popup sheet.
///
/// The sheet shell (glass chrome, barrier, motion) is shared with every other
/// HyperOS sheet; only the content here is a list of Miuix menu rows.
Future<HomeTopMenuAction?> showHomeTopMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
}) {
  return showHomeHyperosSheet<HomeTopMenuAction>(
    context: context,
    builder: (sheetContext) =>
        _HomeTopMenuSheet(hasAvailableUpdate: hasAvailableUpdate),
  );
}

class _HomeTopMenuSheet extends StatelessWidget {
  const _HomeTopMenuSheet({required this.hasAvailableUpdate});

  final bool hasAvailableUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // Miuix menu groups are separated by a small vertical gap (no divider
    // line), matching the ListPopup / DropdownMenu rhythm of the component
    // library instead of the former 3x3 action grid.
    const groupGap = 8.0;

    Widget tile({
      required IconData icon,
      required String title,
      required HomeTopMenuAction action,
      Color? accentColor,
      bool showDot = false,
    }) {
      return _HomeMenuListTile(
        icon: icon,
        title: title,
        accentColor: accentColor,
        showDot: showDot,
        onTap: () => Navigator.of(context).pop(action),
      );
    }

    final menuColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile(
          icon: Icons.system_update_alt_rounded,
          title: l10n.homeMenuUpdateTitle,
          action: HomeTopMenuAction.update,
          accentColor: hasAvailableUpdate ? colorScheme.primary : null,
          showDot: hasAvailableUpdate,
        ),
        tile(
          icon: Icons.dashboard_customize_rounded,
          title: l10n.homeMenuOverviewTitle,
          action: HomeTopMenuAction.overview,
        ),
        tile(
          icon: Icons.bar_chart_rounded,
          title: l10n.homeMenuStatisticsTitle,
          action: HomeTopMenuAction.statistics,
        ),
        tile(
          icon: Icons.add_circle_outline_rounded,
          title: l10n.homeMenuAddCourseTitle,
          action: HomeTopMenuAction.addCourse,
        ),
        tile(
          icon: Icons.school_outlined,
          title: l10n.examListTitle,
          action: HomeTopMenuAction.exams,
        ),
        tile(
          icon: Icons.file_upload_outlined,
          title: l10n.homeMenuImportTitle,
          action: HomeTopMenuAction.importCourses,
        ),
        const SizedBox(height: groupGap),
        tile(
          icon: Icons.task_alt_outlined,
          title: l10n.homeMenuTasksTitle,
          action: HomeTopMenuAction.tasks,
        ),
        tile(
          icon: Icons.tune_rounded,
          title: l10n.homeMenuSettingsTitle,
          action: HomeTopMenuAction.settings,
        ),
        tile(
          icon: Icons.favorite_border_rounded,
          title: l10n.homeMenuCoffeeTitle,
          action: HomeTopMenuAction.support,
        ),
      ],
    );

    return HyperosSheetFrame(
      frosted: true,
      // HyperosSheetFrame supplies the shared modal material used by every
      // dialog, picker, and action sheet. The menu rows are ordinary
      // pressable rows so fast scrolling moves stable pixels instead of
      // shader/filter shapes.
      child: SingleChildScrollView(child: menuColumn),
    );
  }
}

/// Miuix menu row: 56dp tall, 20dp leading icon, body1 label, optional
/// trailing dot badge. All metrics come from the Miuix spec constants used
/// by the anchored list popups (see [HyperosMiuixBasicComponent] /
/// [HyperosMiuixDropdown]).
class _HomeMenuListTile extends StatelessWidget {
  const _HomeMenuListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accentColor,
    this.showDot = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final highlightColor = accentColor ?? Theme.of(context).colorScheme.primary;
    final titleColor = HyperosColors.onSurface(context);

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: Colors.transparent,
      highlightColor: HyperosColors.rowHighlight(context),
      child: SizedBox(
        height: HyperosMiuixBasicComponent.minHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: HyperosMiuixDropdown.insideHorizontalPadding,
            end: HyperosMiuixDropdown.insideHorizontalPadding,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: HyperosMiuixDropdown.checkIconSize,
                color: highlightColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: HyperosMiuixTypography.body1,
                    color: titleColor,
                  ),
                ),
              ),
              if (showDot) ...[
                const SizedBox(width: 12),
                // MiuixBadge without content renders the 6x6 error dot;
                // HyperosBadge only supports the overlay form, so use the
                // official badge directly for the inline trailing dot.
                const MiuixBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
