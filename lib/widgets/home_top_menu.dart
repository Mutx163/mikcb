import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';

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
    const tileSpacing = 10.0;
    const tileHorizontalPadding = 14.0;
    // Phone visual cap: tiles stay at most this wide so icon wells don't stretch.
    const maxTileWidth = 112.0;
    const minTileWidth = 64.0;
    const columnsPerRow = 4;

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

    return HyperosSheetFrame(
      frosted: true,
      // HyperosSheetFrame supplies the shared modal material used by every
      // dialog, picker, and action sheet. Only the eight moving action tiles
      // use stable tint surfaces.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Width is already after floating outer inset + frame padding.
          final gapCount = columnsPerRow - 1;
          final availableWidth = constraints.maxWidth;
          final hasBoundedWidth = availableWidth.isFinite && availableWidth > 0;
          final rawItemWidth = hasBoundedWidth
              ? (availableWidth - tileSpacing * gapCount) / columnsPerRow
              : maxTileWidth;
          // Keep phone sizing: never grow past [maxTileWidth]. Extra sheet
          // width on tablets is distributed as equal gaps between tiles.
          final itemWidth = rawItemWidth.clamp(minTileWidth, maxTileWidth);
          final shouldSpreadAcrossWidth =
              hasBoundedWidth && rawItemWidth > maxTileWidth;
          // Explicit gap so the row's intrinsic width equals the sheet width
          // (spaceBetween alone fails when the Row shrink-wraps).
          final itemGap = shouldSpreadAcrossWidth
              ? (availableWidth - itemWidth * columnsPerRow) / gapCount
              : tileSpacing;
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
            // Phone: fixed 10px gaps (existing look).
            // Tablet: same tile width, larger equal gaps so the row fills width.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) SizedBox(width: itemGap),
                  tiles[index],
                ],
              ],
            );
          }

          final menuColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
          );

          // The sheet owns the only live glass backdrop. The action tiles are
          // deliberately ordinary rounded tint surfaces so fast scrolling
          // moves stable pixels instead of eight shader/filter shapes.
          return SingleChildScrollView(child: menuColumn);
        },
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
    final useLiquidGlassTint =
        FrostedAppearanceScope.of(context).glassMode ==
            FrostedGlassMode.liquidGlass &&
        !LiquidGlassDegradation.shouldDegrade(context);
    final tileTint = useLiquidGlassTint
        ? HyperosBlurredHeader.nestedLiquidTileTintColor(context)
        : HyperosBlurredHeader.nestedSurfaceTintColor(context, withBlur: false);

    final tile = Material(
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
    );

    // Keep the sheet as the only live backdrop blur. The eight tiles move
    // inside a scroll view; a separate BackdropFilter or refraction shape per
    // tile can leave stale rounded-corner textures during a fast direction
    // change. The tint and rounded geometry preserve the existing hierarchy.
    return ClipRRect(
      borderRadius: HyperosTheme.cardBorderRadius,
      child: ColoredBox(color: tileTint, child: tile),
    );
  }
}
