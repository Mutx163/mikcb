import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

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
  return showFSheet<HomeTopMenuAction>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
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
    final colors = context.theme.colors;
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

    return Container(
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
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  tile(
                    icon: Icons.system_update_alt_rounded,
                    title: l10n.homeMenuUpdateTitle,
                    action: HomeTopMenuAction.update,
                    badgeText: hasAvailableUpdate ? l10n.updateLabel : null,
                    accentColor: hasAvailableUpdate
                        ? colorScheme.primary
                        : null,
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
            ],
          ),
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
    final labelFontSize = (typo.body.xs3.fontSize ?? 10) * 0.85;

    return FCard.raw(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: highlightColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: highlightColor, size: 24),
                    ),
                    if ((badgeText ?? '').isNotEmpty)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: FBadge(
                          variant: FBadgeVariant.primary,
                          style: FBadgeStyleDelta.delta(
                            contentStyle: FBadgeContentStyleDelta.delta(
                              padding: EdgeInsetsGeometryDelta.value(
                                const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                              ),
                              labelTextStyle: TextStyleDelta.delta(
                                fontSize: typo.body.xs3.fontSize,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ),
                          child: Text(badgeText!),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: typo.body.xs3.copyWith(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
