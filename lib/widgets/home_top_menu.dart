import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

enum HomeTopMenuAction {
  update,
  overview,
  statistics,
  addCourse,
  exams,
  importCourses,
  settings,
  support,
}

/// Shows the home screen top-right action menu with Forui sheet styling.
Future<HomeTopMenuAction?> showHomeTopMenuSheet(
  BuildContext context, {
  required bool hasAvailableUpdate,
}) {
  return showHyperosSheet<HomeTopMenuAction>(
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
    final itemWidth = ((MediaQuery.sizeOf(context).width - 32 - 30) / 4).clamp(
      72.0,
      112.0,
    );

    Widget tile({
      required IconData icon,
      required String title,
      required HomeTopMenuAction action,
      Color? accentColor,
      String? badgeText,
    }) {
      return SizedBox(
        width: itemWidth,
        child: _HomeMenuActionTile(
          icon: icon,
          title: title,
          accentColor: accentColor,
          badgeText: badgeText,
          onTap: () => Navigator.of(context).pop(action),
        ),
      );
    }

    return HyperosSheetFrame(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            tile(
              icon: Icons.system_update_alt_rounded,
              title: l10n.homeMenuUpdateTitle,
              action: HomeTopMenuAction.update,
              badgeText: hasAvailableUpdate ? l10n.updateLabel : null,
              accentColor: hasAvailableUpdate ? colorScheme.primary : null,
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
        ),
      ),
    );
  }
}

class _HomeMenuActionTile extends StatelessWidget {
  const _HomeMenuActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accentColor,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = accentColor ?? colorScheme.primary;

    return HyperosCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HyperosBadge(
                label: badgeText,
                show: (badgeText ?? '').isNotEmpty,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: highlightColor, size: 24),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: typo.body.xs2.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
