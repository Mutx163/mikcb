import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

double _maxMenuTitleHeight({
  required List<String> titles,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  var maxHeight = 0.0;
  for (final title in titles) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: textDirection,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    maxHeight = math.max(maxHeight, painter.height);
  }
  return maxHeight;
}

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
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    final itemWidth = ((MediaQuery.sizeOf(context).width - 32 - 30) / 4).clamp(
      72.0,
      112.0,
    );
    const tileSpacing = 10.0;
    const tileHorizontalPadding = 14.0;

    final menuTitles = [
      l10n.homeMenuUpdateTitle,
      l10n.homeMenuOverviewTitle,
      l10n.homeMenuStatisticsTitle,
      l10n.homeMenuAddCourseTitle,
      l10n.examListTitle,
      l10n.homeMenuImportTitle,
      l10n.homeMenuSettingsTitle,
      l10n.homeMenuCoffeeTitle,
    ];
    final titleStyle = typo.body.xs2.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.15,
      color: colors.foreground,
    );
    final titleAreaHeight = _maxMenuTitleHeight(
      titles: menuTitles,
      style: titleStyle,
      maxWidth: itemWidth - tileHorizontalPadding,
      textDirection: Directionality.of(context),
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
          titleStyle: titleStyle,
          titleAreaHeight: titleAreaHeight,
          accentColor: accentColor,
          badgeText: badgeText,
          onTap: () => Navigator.of(context).pop(action),
        ),
      );
    }

    Widget menuRow(List<Widget> tiles) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const SizedBox(width: tileSpacing),
            tiles[index],
          ],
        ],
      );
    }

    return HyperosSheetFrame(
      frosted: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            menuRow([
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
            ]),
            const SizedBox(height: tileSpacing),
            menuRow([
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
            ]),
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
    required this.titleStyle,
    required this.titleAreaHeight,
    required this.onTap,
    this.accentColor,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final TextStyle titleStyle;
  final double titleAreaHeight;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = accentColor ?? colorScheme.primary;
    const iconWellRadius = BorderRadius.all(Radius.circular(14));

    return HyperosFrostedSurface(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: HyperosTheme.cardBorderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HyperosBadge(
                  label: badgeText,
                  show: (badgeText ?? '').isNotEmpty,
                  child: HyperosFrostedSurface(
                    borderRadius: iconWellRadius,
                    blurEnabled: false,
                    tint: HyperosBlurredHeader.accentSurfaceTintColor(
                      highlightColor,
                    ),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: Icon(icon, color: highlightColor, size: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: titleAreaHeight,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
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
